/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Access rights

@available(System 199, *)
extension Win32 {
  /// The access rights to request for a process handle.
  ///
  /// Each operation on ``Win32/ProcessHandle`` says which rights it needs.
  /// An open fails with ``Win32/Error/accessDenied`` if the process's
  /// security descriptor withholds any right it requests, so request only
  /// the ones you use.
  ///
  /// The corresponding C type is `ACCESS_MASK`, as `OpenProcess`'s
  /// `dwDesiredAccess`.
  @frozen
  public struct ProcessAccess: OptionSet, Sendable, Hashable, Codable {
    /// The raw C access mask.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed access mask from a raw C access mask.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The right to end the process.
    ///
    /// The corresponding C constant is `PROCESS_TERMINATE`.
    @_alwaysEmitIntoClient
    public static var terminate: ProcessAccess { ProcessAccess(rawValue: 0x0001) }

    /// The right to create a thread in the process.
    ///
    /// The corresponding C constant is `PROCESS_CREATE_THREAD`.
    @_alwaysEmitIntoClient
    public static var createThread: ProcessAccess { ProcessAccess(rawValue: 0x0002) }

    /// The right to change the process's address space, such as by
    /// allocating or protecting its memory.
    ///
    /// The corresponding C constant is `PROCESS_VM_OPERATION`.
    @_alwaysEmitIntoClient
    public static var virtualMemoryOperation: ProcessAccess { ProcessAccess(rawValue: 0x0008) }

    /// The right to read the process's memory.
    ///
    /// The corresponding C constant is `PROCESS_VM_READ`.
    @_alwaysEmitIntoClient
    public static var virtualMemoryRead: ProcessAccess { ProcessAccess(rawValue: 0x0010) }

    /// The right to write the process's memory.
    ///
    /// The corresponding C constant is `PROCESS_VM_WRITE`.
    @_alwaysEmitIntoClient
    public static var virtualMemoryWrite: ProcessAccess { ProcessAccess(rawValue: 0x0020) }

    /// The right to duplicate a handle into or out of the process.
    ///
    /// The corresponding C constant is `PROCESS_DUP_HANDLE`.
    @_alwaysEmitIntoClient
    public static var duplicateHandle: ProcessAccess { ProcessAccess(rawValue: 0x0040) }

    /// The right to create a process with this one as its parent.
    ///
    /// The corresponding C constant is `PROCESS_CREATE_PROCESS`.
    @_alwaysEmitIntoClient
    public static var createProcess: ProcessAccess { ProcessAccess(rawValue: 0x0080) }

    /// The right to set the process's memory limits.
    ///
    /// The corresponding C constant is `PROCESS_SET_QUOTA`.
    @_alwaysEmitIntoClient
    public static var setQuota: ProcessAccess { ProcessAccess(rawValue: 0x0100) }

    /// The right to set information about the process, such as its
    /// priority class.
    ///
    /// The corresponding C constant is `PROCESS_SET_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var setInformation: ProcessAccess { ProcessAccess(rawValue: 0x0200) }

    /// The right to read information about the process, such as its token,
    /// exit code, and priority class.
    ///
    /// A handle with this right also has ``queryLimitedInformation``.
    ///
    /// The corresponding C constant is `PROCESS_QUERY_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var queryInformation: ProcessAccess { ProcessAccess(rawValue: 0x0400) }

    /// The right to suspend and resume the process.
    ///
    /// The corresponding C constant is `PROCESS_SUSPEND_RESUME`.
    @_alwaysEmitIntoClient
    public static var suspendResume: ProcessAccess { ProcessAccess(rawValue: 0x0800) }

    /// The right to read some information about the process, such as its
    /// ID, exit code, and image name.
    ///
    /// Windows grants this right more readily than ``queryInformation``,
    /// such as for a process of another user.
    ///
    /// The corresponding C constant is `PROCESS_QUERY_LIMITED_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var queryLimitedInformation: ProcessAccess {
      ProcessAccess(rawValue: 0x1000)
    }

    /// The right to set some information about the process.
    ///
    /// The corresponding C constant is `PROCESS_SET_LIMITED_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var setLimitedInformation: ProcessAccess { ProcessAccess(rawValue: 0x2000) }

    /// The right to delete the process object.
    ///
    /// The corresponding C constant is `DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: ProcessAccess { ProcessAccess(rawValue: 0x0001_0000) }

    /// The right to read the process's security descriptor, not including
    /// its system access control list.
    ///
    /// The corresponding C constant is `READ_CONTROL`.
    @_alwaysEmitIntoClient
    public static var readControl: ProcessAccess { ProcessAccess(rawValue: 0x0002_0000) }

    /// The right to change the process's discretionary access control list.
    ///
    /// The corresponding C constant is `WRITE_DAC`.
    @_alwaysEmitIntoClient
    public static var writeDAC: ProcessAccess { ProcessAccess(rawValue: 0x0004_0000) }

    /// The right to change the process's owner.
    ///
    /// The corresponding C constant is `WRITE_OWNER`.
    @_alwaysEmitIntoClient
    public static var writeOwner: ProcessAccess { ProcessAccess(rawValue: 0x0008_0000) }

    /// The right to wait for the process to exit.
    ///
    /// The corresponding C constant is `SYNCHRONIZE`.
    @_alwaysEmitIntoClient
    public static var synchronize: ProcessAccess { ProcessAccess(rawValue: 0x0010_0000) }

    /// Every right a process handle can have.
    ///
    /// The corresponding C constant is `PROCESS_ALL_ACCESS`.
    @_alwaysEmitIntoClient
    public static var all: ProcessAccess { ProcessAccess(rawValue: 0x001F_FFFF) }

    /// Every right the access check finds the caller entitled to.
    ///
    /// This doesn't name a right, and never appears in a mask the system
    /// reports.
    ///
    /// The corresponding C constant is `MAXIMUM_ALLOWED`.
    @_alwaysEmitIntoClient
    public static var maximumAllowed: ProcessAccess { ProcessAccess(rawValue: 0x0200_0000) }
  }
}

// MARK: - The handle

// A HANDLE is an unsafe pointer, which isn't Sendable. The handle owns its
// pointer uniquely, and Windows allows a handle's use from any thread, so it
// conforms with @unchecked, like the file handles.

@available(System 199, *)
extension Win32 {
  /// An open process.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope and
  /// discards the error. Closing a process handle doesn't end the process.
  ///
  /// The process object outlives the process: while any handle to it is
  /// open, the process's exit code stays readable, and its ID can't name
  /// another process. Any handle with the access rights can wait for the
  /// process to exit or read its exit code. Unlike a POSIX child, a process
  /// needs no reaping, and its creator has no rights over it that another
  /// handle lacks.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct ProcessHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw process handle, such as the `hProcess` that
    /// `CreateProcessW` reports, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL`, which `OpenProcess` returns when it
    /// fails. `raw` can be the pseudo handle that `GetCurrentProcess`
    /// returns, whose value is also `INVALID_HANDLE_VALUE`'s; see
    /// ``current``.
    ///
    /// - Warning: This initializer doesn't check that `raw` is a handle to
    ///   a process.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw else { return nil }
      self._handle = raw
    }

    /// The raw C handle. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawHandle: HANDLE { _handle }

    /// Gives up ownership and returns the raw handle.
    ///
    /// The caller becomes responsible for closing it.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> HANDLE {
      let handle = _handle
      discard self
      return handle
    }

    /// Closes this handle.
    ///
    /// The handle is closed whether this method returns or throws. The
    /// process keeps running.
    ///
    /// The corresponding C function is `CloseHandle`.
    @_alwaysEmitIntoClient
    public consuming func close() throws(Win32.Error) {
      let handle = _handle
      discard self
      try Win32._closeHandle(handle).get()
    }

    deinit {
      _ = system_CloseHandle(_handle)
    }
  }
}

// MARK: - Opening

@available(System 199, *)
extension Win32.ProcessHandle {
  /// A handle to the calling process.
  ///
  /// This is the pseudo handle that `GetCurrentProcess` returns: a constant
  /// that means "the calling process", with every access right, wherever
  /// this process uses it. Closing it does nothing, so a value of it needn't
  /// be closed, and every access returns the same constant.
  ///
  /// It means the calling process only to the calling process. For a handle
  /// that another process can inherit or receive, or one that
  /// ``isInheritable()`` can describe, call ``duplicate(access:inheritable:)``,
  /// which returns a real handle to this process.
  ///
  /// The corresponding C function is `GetCurrentProcess`.
  @_alwaysEmitIntoClient
  public static var current: Win32.ProcessHandle {
    Win32.ProcessHandle(_owning: Win32._currentProcess())
  }

  /// Opens a process by its ID.
  ///
  /// - Parameters:
  ///   - id: The process's ID.
  ///   - access: The access rights to request. Each operation says which
  ///     rights it needs. An open that requests a right the process's
  ///     security descriptor withholds fails with
  ///     ``Win32/Error/accessDenied``.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of this handle.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if no process has the ID,
  /// which includes the ID of the System Idle Process, 0.
  ///
  /// An ID can be reused once its process has exited and every handle to
  /// it has closed, so an ID taken from a process that may have exited can
  /// open an unrelated process. A handle, once open, refers to one process.
  ///
  /// The corresponding C function is `OpenProcess`.
  @_alwaysEmitIntoClient
  public static func open(
    _ id: ProcessID,
    access: Win32.ProcessAccess,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ProcessHandle {
    let handle = try Win32._openProcess(
      id.rawValue, access: access.rawValue, inheritable: inheritable
    ).get()
    return Win32.ProcessHandle(_owning: handle)
  }
}

// MARK: - Operations

@available(System 199, *)
extension Win32.ProcessHandle {
  /// The process's ID.
  ///
  /// Needs ``Win32/ProcessAccess/queryLimitedInformation`` or
  /// ``Win32/ProcessAccess/queryInformation``.
  ///
  /// The corresponding C function is `GetProcessId`.
  @_alwaysEmitIntoClient
  public func processID() throws(Win32.Error) -> ProcessID {
    ProcessID(rawValue: try Win32._processID(_handle).get())
  }

  /// Waits for the process to exit.
  ///
  /// Needs ``Win32/ProcessAccess/synchronize``. Returns at once if the
  /// process has already exited.
  ///
  /// This method blocks the thread.
  ///
  /// The corresponding C function is `WaitForSingleObject`, with
  /// `INFINITE`.
  @_alwaysEmitIntoClient
  public func waitForExit() throws(Win32.Error) {
    _ = try Win32._wait(_handle, timeout: nil).get()
  }

  /// Waits for the process to exit, for at most a duration.
  ///
  /// - Parameter timeout: How long to wait. A duration of zero or less
  ///   checks without waiting, and a positive one rounds up to a whole
  ///   millisecond.
  /// - Returns: Whether the process has exited.
  ///
  /// Needs ``Win32/ProcessAccess/synchronize``.
  ///
  /// This method blocks the thread.
  ///
  /// The corresponding C function is `WaitForSingleObject`, with its results
  /// `WAIT_OBJECT_0` and `WAIT_TIMEOUT`, which this returns as true and false.
  @_alwaysEmitIntoClient
  public func waitForExit(timeout: Duration) throws(Win32.Error) -> Bool {
    try Win32._wait(_handle, timeout: timeout).get()
  }

  /// The process's exit code, or `nil` if it's still running.
  ///
  /// Windows keeps all 32 bits of the code a process exits with. A process
  /// that an unhandled exception ended reports the exception's code, such
  /// as `0xC0000005` for an access violation, and one that
  /// ``terminate(exitCode:)`` ended reports the code passed there.
  ///
  /// Needs ``Win32/ProcessAccess/synchronize`` and
  /// ``Win32/ProcessAccess/queryLimitedInformation``: `GetExitCodeProcess`
  /// reports `STILL_ACTIVE` (259) for a running process, which is also a
  /// code a process can exit with, so this method checks whether the
  /// process has exited first.
  ///
  /// The corresponding C function is `GetExitCodeProcess`, after
  /// `WaitForSingleObject` with a time-out of zero.
  @_alwaysEmitIntoClient
  public func exitCode() throws(Win32.Error) -> DWORD? {
    try Win32._exitCode(_handle).get()
  }

  /// Ends the process, which exits with a code.
  ///
  /// - Parameter exitCode: The code the process exits with.
  ///
  /// Needs ``Win32/ProcessAccess/terminate``. Every thread of the process
  /// ends without running any more of its code: its DLLs aren't notified,
  /// and data the process hasn't written is lost. Its handles close, and
  /// its child processes keep running.
  ///
  /// Termination is asynchronous: the process may still be running when
  /// this method returns. Call ``waitForExit()`` to wait for it. Ending a
  /// process that has already exited throws ``Win32/Error/accessDenied``.
  /// Ending the calling process, through ``current``, ends the calling
  /// thread with it, so the method doesn't return.
  ///
  /// The corresponding C function is `TerminateProcess`.
  @_alwaysEmitIntoClient
  public func terminate(exitCode: DWORD) throws(Win32.Error) {
    try Win32._terminateProcess(_handle, exitCode: exitCode).get()
  }

  /// Duplicates this handle within the current process.
  ///
  /// - Parameters:
  ///   - access: The duplicate's access rights. `nil` requests the same
  ///     rights this handle has.
  ///   - inheritable: Whether child processes created with handle inheritance
  ///     enabled receive a copy of the duplicate.
  ///
  /// Duplicating ``current`` returns a real handle to the calling process.
  ///
  /// - Returns: A new owned handle. The caller must close it.
  ///
  /// The corresponding C function is `DuplicateHandle`, with
  /// `DUPLICATE_SAME_ACCESS` for the same rights.
  @_alwaysEmitIntoClient
  public borrowing func duplicate(
    access: Win32.ProcessAccess? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ProcessHandle {
    let handle = try Win32._duplicateHandle(
      _handle, access: access?.rawValue, inheritable: inheritable
    ).get()
    return Win32.ProcessHandle(_owning: handle)
  }

  /// Whether child processes created with handle inheritance enabled receive
  /// a copy of this handle.
  ///
  /// The corresponding C function is `GetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func isInheritable() throws(Win32.Error) -> Bool {
    try Win32._isInheritable(_handle).get()
  }

  /// Sets whether child processes created with handle inheritance enabled
  /// receive a copy of this handle.
  ///
  /// The corresponding C function is `SetHandleInformation` with
  /// `HANDLE_FLAG_INHERIT`.
  @_alwaysEmitIntoClient
  public borrowing func setInheritable(_ value: Bool) throws(Win32.Error) {
    try Win32._setInheritable(_handle, value).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _currentProcess() -> HANDLE {
    system_GetCurrentProcess()
  }

  @usableFromInline
  internal static func _openProcess(
    _ id: DWORD, access: DWORD, inheritable: Bool
  ) -> Result<HANDLE, Win32.Error> {
    guard let handle = system_OpenProcess(access, inheritable, id) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(handle)
  }

  @usableFromInline
  internal static func _processID(_ handle: HANDLE) -> Result<DWORD, Win32.Error> {
    // No handle names the System Idle Process, the only process with ID 0,
    // so 0 is only ever the failure.
    let id = system_GetProcessId(handle)
    guard id != 0 else { return .failure(Win32.Error(GetLastError())) }
    return .success(id)
  }

  @usableFromInline
  internal static func _exitCode(_ handle: HANDLE) -> Result<DWORD?, Win32.Error> {
    switch _wait(handle, timeout: .zero) {
    case .failure(let error): return .failure(error)
    case .success(false): return .success(nil)
    case .success(true): break
    }
    var code: DWORD = 0
    guard system_GetExitCodeProcess(handle, &code) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(code)
  }

  @usableFromInline
  internal static func _terminateProcess(
    _ handle: HANDLE, exitCode: DWORD
  ) -> Result<Void, Win32.Error> {
    guard system_TerminateProcess(handle, exitCode) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
