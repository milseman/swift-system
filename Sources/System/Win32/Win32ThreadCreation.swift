/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Creating threads

@available(System 199, *)
extension Win32.ThreadHandle {
  /// Creates a thread that runs a closure.
  ///
  /// - Parameters:
  ///   - stackSize: The size of the thread's stack reservation, in bytes:
  ///     the most its stack can grow to. Windows rounds it up to its
  ///     allocation granularity, 64 KiB. `nil` takes the executable's
  ///     default, which the linker sets, and is 1 MiB unless it's told
  ///     otherwise.
  ///   - suspended: Whether the thread starts suspended, to run once
  ///     ``resume()`` resumes it.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of the returned handle.
  ///   - body: The closure for the new thread to run. The thread exits when
  ///     the closure returns, with an exit code of 0.
  ///
  /// - Returns: A handle to the new thread, with every access right.
  ///
  /// The closure is sent to the new thread, so it can capture values that
  /// aren't `Sendable`, as long as the caller doesn't use them afterward.
  ///
  /// The thread runs whether or not the handle stays open: closing it, as
  /// its `deinit` does, lets the thread finish on its own. To wait for the
  /// thread, as POSIX's `pthread_join` does, call ``waitForExit()``.
  ///
  /// Throws ``Win32/Error/invalidParameter`` for a negative `stackSize`, or
  /// one that a `DWORD` can't hold.
  ///
  /// The corresponding C function is `_beginthreadex`, which Microsoft
  /// documents for threads that call the C runtime, as Swift code does,
  /// rather than `CreateThread`.
  @_alwaysEmitIntoClient
  public static func create(
    stackSize: Int? = nil,
    suspended: Bool = false,
    inheritable: Bool = false,
    _ body: sending @escaping () -> Void
  ) throws(Win32.Error) -> Win32.ThreadHandle {
    let handle = try Win32._createThread(
      stackSize: stackSize, suspended: suspended, inheritable: inheritable, body
    ).get()
    return Win32.ThreadHandle(_owning: handle)
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createThread(
    stackSize: Int?,
    suspended: Bool,
    inheritable: Bool,
    _ body: sending @escaping () -> Void
  ) -> Result<HANDLE, Win32.Error> {
    var flags: UInt32 = suspended ? _CREATE_SUSPENDED : 0
    var size: UInt32 = 0
    if let stackSize {
      guard let exact = UInt32(exactly: stackSize) else { return .failure(.invalidParameter) }
      size = exact
      // Otherwise the size is the stack's initial commitment.
      flags |= _STACK_SIZE_PARAM_IS_A_RESERVATION
    }
    var security = SECURITY_ATTRIBUTES(
      nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
      lpSecurityDescriptor: nil,
      bInheritHandle: WindowsBool(inheritable))
    let context = Unmanaged.passRetained(_Win32ThreadStart(body)).toOpaque()
    // A failure of CreateThread inside leaves its last error. The C
    // runtime's own failure, to allocate the thread's start data, leaves
    // none, only errno's ENOMEM.
    SetLastError(0)
    let handle = system__beginthreadex(&security, size, context, flags)
    let lastError = GetLastError()
    guard handle != 0 else {
      // The thread didn't start, so nothing else will release the closure.
      Unmanaged<_Win32ThreadStart>.fromOpaque(context).release()
      return .failure(lastError == 0 ? .notEnoughMemory : Win32.Error(lastError))
    }
    return .success(HANDLE(bitPattern: handle)!)
  }
}

// The closure that a new thread runs, passed to it through `_beginthreadex`'s
// argument.
internal final class _Win32ThreadStart {
  internal let body: () -> Void

  internal init(_ body: @escaping () -> Void) {
    self.body = body
  }
}

// The body of every thread that `Win32.ThreadHandle.create` starts; see
// system__beginthreadex.
internal func _win32ThreadStart(_ context: UnsafeMutableRawPointer?) {
  let start = Unmanaged<_Win32ThreadStart>.fromOpaque(context!).takeRetainedValue()
  start.body()
}

// MARK: - Names

@available(System 199, *)
extension Win32.ThreadHandle {
  /// The thread's name, which debuggers and crash reports show, or an
  /// empty string if it has none.
  ///
  /// Needs ``Win32/ThreadAccess/queryLimitedInformation``.
  ///
  /// The corresponding C function is `GetThreadDescription`.
  @_alwaysEmitIntoClient
  public func name() throws(Win32.Error) -> String {
    try Win32._threadName(_handle).get()
  }

  /// Sets the thread's name, which debuggers and crash reports show.
  ///
  /// Needs ``Win32/ThreadAccess/setLimitedInformation``. Throws
  /// ``Win32/Error/invalidParameter`` if `name` contains a null character.
  ///
  /// The corresponding C function is `SetThreadDescription`.
  @_alwaysEmitIntoClient
  public func setName(_ name: String) throws(Win32.Error) {
    try Win32._setThreadName(_handle, name).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _threadName(_ handle: HANDLE) -> Result<String, Win32.Error> {
    var name: PWSTR? = nil
    let result = system_GetThreadDescription(handle, &name)
    // The description is allocated for the caller to free, even when it's
    // empty.
    defer {
      if let name { _ = system_LocalFree(name) }
    }
    guard result >= 0, let name else {
      return .failure(Win32.Error(_win32Error(fromHRESULT: result)))
    }
    return .success(String(platformString: name))
  }

  @usableFromInline
  internal static func _setThreadName(_ handle: HANDLE, _ name: String) -> Result<Void, Win32.Error> {
    var units = Array(name.utf16)
    guard !units.contains(0) else { return .failure(.invalidParameter) }
    units.append(0)
    let result = units.withUnsafeBufferPointer { system_SetThreadDescription(handle, $0.baseAddress!) }
    guard result >= 0 else { return .failure(Win32.Error(_win32Error(fromHRESULT: result))) }
    return .success(())
  }
}

// MARK: - Yielding

@available(System 199, *)
extension Win32 {
  /// Offers the processor to another thread that's ready to run on it.
  ///
  /// - Returns: Whether another thread ran. If none was ready, the call
  ///   returns at once.
  ///
  /// Unlike ``sleep(for:)`` with a duration of zero, this yields only to a
  /// thread on the calling thread's processor.
  ///
  /// The corresponding C function is `SwitchToThread`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task.yield(), or await a condition instead of spinning")
  @discardableResult
  public static func yield() -> Bool {
    _yield()
  }

  @usableFromInline
  internal static func _yield() -> Bool {
    system_SwitchToThread()
  }
}

#endif // os(Windows)
