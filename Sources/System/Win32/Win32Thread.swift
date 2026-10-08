/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Thread IDs

@available(System 199, *)
extension Win32 {
  /// A Windows thread ID.
  ///
  /// An ID names a thread from its creation until the last handle to it
  /// closes, even after the thread exits. After that, Windows can give the
  /// ID to a new thread, or to a process: thread and process IDs come from
  /// one pool.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ThreadID: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C thread ID.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed thread ID from the raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Creates a strongly-typed thread ID from the raw C value.
    @_alwaysEmitIntoClient
    public init(_ rawValue: DWORD) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Win32.ThreadID {
  /// The ID of the calling thread.
  ///
  /// The corresponding C function is `GetCurrentThreadId`.
  @_alwaysEmitIntoClient
  public static var current: Win32.ThreadID { Win32.ThreadID(rawValue: _currentThreadID()) }

  @usableFromInline
  internal static func _currentThreadID() -> DWORD {
    system_GetCurrentThreadId()
  }
}

// MARK: - Access rights

@available(System 199, *)
extension Win32 {
  /// The access rights to request for a thread handle.
  ///
  /// Each operation on ``Win32/ThreadHandle`` says which rights it needs.
  ///
  /// The corresponding C type is `ACCESS_MASK`, as `OpenThread`'s
  /// `dwDesiredAccess`.
  @frozen
  public struct ThreadAccess: OptionSet, Sendable, Hashable, Codable {
    /// The raw C access mask.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed access mask from a raw C access mask.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The right to end the thread.
    ///
    /// The corresponding C constant is `THREAD_TERMINATE`.
    @_alwaysEmitIntoClient
    public static var terminate: ThreadAccess { ThreadAccess(rawValue: 0x0001) }

    /// The right to suspend and resume the thread.
    ///
    /// The corresponding C constant is `THREAD_SUSPEND_RESUME`.
    @_alwaysEmitIntoClient
    public static var suspendResume: ThreadAccess { ThreadAccess(rawValue: 0x0002) }

    /// The right to read the thread's register context.
    ///
    /// The corresponding C constant is `THREAD_GET_CONTEXT`.
    @_alwaysEmitIntoClient
    public static var getContext: ThreadAccess { ThreadAccess(rawValue: 0x0008) }

    /// The right to set the thread's register context.
    ///
    /// The corresponding C constant is `THREAD_SET_CONTEXT`.
    @_alwaysEmitIntoClient
    public static var setContext: ThreadAccess { ThreadAccess(rawValue: 0x0010) }

    /// The right to set information about the thread, such as its priority.
    ///
    /// The corresponding C constant is `THREAD_SET_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var setInformation: ThreadAccess { ThreadAccess(rawValue: 0x0020) }

    /// The right to read information about the thread, such as its exit
    /// code and priority.
    ///
    /// A handle with this right also has ``queryLimitedInformation``.
    ///
    /// The corresponding C constant is `THREAD_QUERY_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var queryInformation: ThreadAccess { ThreadAccess(rawValue: 0x0040) }

    /// The right to set the thread's impersonation token.
    ///
    /// The corresponding C constant is `THREAD_SET_THREAD_TOKEN`.
    @_alwaysEmitIntoClient
    public static var setThreadToken: ThreadAccess { ThreadAccess(rawValue: 0x0080) }

    /// The right to impersonate the thread's client.
    ///
    /// The corresponding C constant is `THREAD_IMPERSONATE`.
    @_alwaysEmitIntoClient
    public static var impersonate: ThreadAccess { ThreadAccess(rawValue: 0x0100) }

    /// The right to impersonate the thread's security context directly.
    ///
    /// The corresponding C constant is `THREAD_DIRECT_IMPERSONATION`.
    @_alwaysEmitIntoClient
    public static var directImpersonation: ThreadAccess { ThreadAccess(rawValue: 0x0200) }

    /// The right to set some information about the thread.
    ///
    /// The corresponding C constant is `THREAD_SET_LIMITED_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var setLimitedInformation: ThreadAccess { ThreadAccess(rawValue: 0x0400) }

    /// The right to read some information about the thread, such as its ID
    /// and exit code.
    ///
    /// The corresponding C constant is `THREAD_QUERY_LIMITED_INFORMATION`.
    @_alwaysEmitIntoClient
    public static var queryLimitedInformation: ThreadAccess { ThreadAccess(rawValue: 0x0800) }

    /// The right to resume the thread, but not to suspend it.
    ///
    /// The corresponding C constant is `THREAD_RESUME`.
    @_alwaysEmitIntoClient
    public static var resume: ThreadAccess { ThreadAccess(rawValue: 0x1000) }

    /// The right to delete the thread object.
    ///
    /// The corresponding C constant is `DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: ThreadAccess { ThreadAccess(rawValue: 0x0001_0000) }

    /// The right to read the thread's security descriptor, not including
    /// its system access control list.
    ///
    /// The corresponding C constant is `READ_CONTROL`.
    @_alwaysEmitIntoClient
    public static var readControl: ThreadAccess { ThreadAccess(rawValue: 0x0002_0000) }

    /// The right to change the thread's discretionary access control list.
    ///
    /// The corresponding C constant is `WRITE_DAC`.
    @_alwaysEmitIntoClient
    public static var writeDAC: ThreadAccess { ThreadAccess(rawValue: 0x0004_0000) }

    /// The right to change the thread's owner.
    ///
    /// The corresponding C constant is `WRITE_OWNER`.
    @_alwaysEmitIntoClient
    public static var writeOwner: ThreadAccess { ThreadAccess(rawValue: 0x0008_0000) }

    /// The right to wait for the thread to exit.
    ///
    /// The corresponding C constant is `SYNCHRONIZE`.
    @_alwaysEmitIntoClient
    public static var synchronize: ThreadAccess { ThreadAccess(rawValue: 0x0010_0000) }

    /// Every right a thread handle can have.
    ///
    /// The corresponding C constant is `THREAD_ALL_ACCESS`.
    @_alwaysEmitIntoClient
    public static var all: ThreadAccess { ThreadAccess(rawValue: 0x001F_FFFF) }

    /// Every right the access check finds the caller entitled to.
    ///
    /// This doesn't name a right, and never appears in a mask the system
    /// reports.
    ///
    /// The corresponding C constant is `MAXIMUM_ALLOWED`.
    @_alwaysEmitIntoClient
    public static var maximumAllowed: ThreadAccess { ThreadAccess(rawValue: 0x0200_0000) }
  }
}

// MARK: - The handle

@available(System 199, *)
extension Win32 {
  /// An open thread.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope and
  /// discards the error. Closing a thread handle doesn't end the thread.
  ///
  /// Like a process, a thread's object outlives it: while any handle to it
  /// is open, its exit code stays readable and its ID can't name another
  /// thread.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct ThreadHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw thread handle, such as the `hThread` that
    /// `CreateProcessW` reports, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL`, which the functions that return a
    /// thread handle return when they fail, or `INVALID_HANDLE_VALUE`, whose
    /// value is the pseudo handle to the calling process.
    ///
    /// - Warning: Don't pass the pseudo handle that `GetCurrentThread`
    ///   returns, which means whichever thread uses it, so it would name
    ///   another thread once sent to one. This initializer doesn't check
    ///   for it, or that `raw` is a handle to a thread.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: HANDLE?) {
      guard let raw, raw != INVALID_HANDLE_VALUE else { return nil }
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
    /// thread keeps running.
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
extension Win32.ThreadHandle {
  /// Opens a new handle to the calling thread.
  ///
  /// - Parameters:
  ///   - access: The handle's access rights. `nil` requests every right.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of this handle.
  ///
  /// Unlike the pseudo handle that `GetCurrentThread` returns, which means
  /// whichever thread uses it, this handle refers to the calling thread
  /// wherever it's used, so it can be sent to another thread.
  ///
  /// The corresponding C function is `DuplicateHandle`, with the pseudo
  /// handle that `GetCurrentThread` returns.
  @_alwaysEmitIntoClient
  public static func current(
    access: Win32.ThreadAccess? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ThreadHandle {
    let handle = try Win32._duplicateHandle(
      Win32._currentThread(), access: access?.rawValue, inheritable: inheritable
    ).get()
    return Win32.ThreadHandle(_owning: handle)
  }

  /// Opens a thread by its ID.
  ///
  /// - Parameters:
  ///   - id: The thread's ID.
  ///   - access: The access rights to request. An open that requests a
  ///     right the thread's security descriptor withholds fails with
  ///     ``Win32/Error/accessDenied``.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of this handle.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if no thread has the ID.
  ///
  /// The corresponding C function is `OpenThread`.
  @_alwaysEmitIntoClient
  public static func open(
    _ id: Win32.ThreadID,
    access: Win32.ThreadAccess,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ThreadHandle {
    let handle = try Win32._openThread(
      id.rawValue, access: access.rawValue, inheritable: inheritable
    ).get()
    return Win32.ThreadHandle(_owning: handle)
  }
}

// MARK: - Operations

@available(System 199, *)
extension Win32.ThreadHandle {
  /// The thread's ID.
  ///
  /// Needs ``Win32/ThreadAccess/queryLimitedInformation`` or
  /// ``Win32/ThreadAccess/queryInformation``.
  ///
  /// The corresponding C function is `GetThreadId`.
  @_alwaysEmitIntoClient
  public func threadID() throws(Win32.Error) -> Win32.ThreadID {
    Win32.ThreadID(rawValue: try Win32._threadID(_handle).get())
  }

  /// Waits for the thread to exit.
  ///
  /// Needs ``Win32/ThreadAccess/synchronize``. Returns at once if the
  /// thread has already exited. A thread that waits for itself waits
  /// forever.
  ///
  /// The corresponding C function is `WaitForSingleObject`, with
  /// `INFINITE`.
  @_alwaysEmitIntoClient
  public func waitForExit() throws(Win32.Error) {
    _ = try Win32._wait(_handle, timeout: nil).get()
  }

  /// Waits for the thread to exit, for at most a duration.
  ///
  /// - Parameter timeout: How long to wait. A duration of zero or less
  ///   checks without waiting, and a positive one rounds up to a whole
  ///   millisecond.
  /// - Returns: Whether the thread has exited.
  ///
  /// Needs ``Win32/ThreadAccess/synchronize``.
  ///
  /// The corresponding C function is `WaitForSingleObject`, with its results
  /// `WAIT_OBJECT_0` and `WAIT_TIMEOUT`, which this returns as true and false.
  @_alwaysEmitIntoClient
  public func waitForExit(timeout: Duration) throws(Win32.Error) -> Bool {
    try Win32._wait(_handle, timeout: timeout).get()
  }

  /// The thread's exit code, or `nil` if it's still running.
  ///
  /// A thread that ended because its process exited reports the process's
  /// exit code.
  ///
  /// Needs ``Win32/ThreadAccess/synchronize`` and
  /// ``Win32/ThreadAccess/queryLimitedInformation``: `GetExitCodeThread`
  /// reports `STILL_ACTIVE` (259) for a running thread, which is also a code
  /// a thread can exit with, so this method checks whether the thread has
  /// exited first.
  ///
  /// The corresponding C function is `GetExitCodeThread`, after
  /// `WaitForSingleObject` with a time-out of zero.
  @_alwaysEmitIntoClient
  public func exitCode() throws(Win32.Error) -> DWORD? {
    try Win32._threadExitCode(_handle).get()
  }

  /// Decrements the thread's suspend count, and resumes the thread if the
  /// count reaches zero.
  ///
  /// - Returns: The suspend count before the call: 0 if the thread wasn't
  ///   suspended, 1 if this call resumed it, and more if it's still
  ///   suspended.
  ///
  /// Needs ``Win32/ThreadAccess/suspendResume`` or
  /// ``Win32/ThreadAccess/resume``. This is how a process created with
  /// ``Win32/ProcessCreationFlags/suspended`` starts running.
  ///
  /// The corresponding C function is `ResumeThread`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func resume() throws(Win32.Error) -> DWORD {
    try Win32._resumeThread(_handle).get()
  }

  /// Increments the thread's suspend count, which stops it from running.
  ///
  /// - Returns: The suspend count before the call.
  ///
  /// Needs ``Win32/ThreadAccess/suspendResume``.
  ///
  /// - Warning: Suspending is meant for debuggers. A thread suspended while
  ///   it holds a lock, such as the heap's, blocks every thread that needs
  ///   the lock, the caller included.
  ///
  /// The corresponding C function is `SuspendThread`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func suspend() throws(Win32.Error) -> DWORD {
    try Win32._suspendThread(_handle).get()
  }

  /// Duplicates this handle within the current process.
  ///
  /// - Parameters:
  ///   - access: The duplicate's access rights. `nil` requests the same
  ///     rights this handle has.
  ///   - inheritable: Whether child processes created with handle inheritance
  ///     enabled receive a copy of the duplicate.
  ///
  /// - Returns: A new owned handle. The caller must close it.
  ///
  /// The corresponding C function is `DuplicateHandle`, with
  /// `DUPLICATE_SAME_ACCESS` for the same rights.
  @_alwaysEmitIntoClient
  public borrowing func duplicate(
    access: Win32.ThreadAccess? = nil,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.ThreadHandle {
    let handle = try Win32._duplicateHandle(
      _handle, access: access?.rawValue, inheritable: inheritable
    ).get()
    return Win32.ThreadHandle(_owning: handle)
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
  internal static func _currentThread() -> HANDLE {
    system_GetCurrentThread()
  }

  @usableFromInline
  internal static func _openThread(
    _ id: DWORD, access: DWORD, inheritable: Bool
  ) -> Result<HANDLE, Win32.Error> {
    guard let handle = system_OpenThread(access, inheritable, id) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(handle)
  }

  @usableFromInline
  internal static func _threadID(_ handle: HANDLE) -> Result<DWORD, Win32.Error> {
    // Thread IDs share a pool with process IDs, whose 0 is the System Idle
    // Process's, so 0 is only ever the failure.
    let id = system_GetThreadId(handle)
    guard id != 0 else { return .failure(Win32.Error(GetLastError())) }
    return .success(id)
  }

  @usableFromInline
  internal static func _threadExitCode(_ handle: HANDLE) -> Result<DWORD?, Win32.Error> {
    switch _wait(handle, timeout: .zero) {
    case .failure(let error): return .failure(error)
    case .success(false): return .success(nil)
    case .success(true): break
    }
    var code: DWORD = 0
    guard system_GetExitCodeThread(handle, &code) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(code)
  }

  @usableFromInline
  internal static func _resumeThread(_ handle: HANDLE) -> Result<DWORD, Win32.Error> {
    let count = system_ResumeThread(handle)
    guard count != DWORD.max else { return .failure(Win32.Error(GetLastError())) }
    return .success(count)
  }

  @usableFromInline
  internal static func _suspendThread(_ handle: HANDLE) -> Result<DWORD, Win32.Error> {
    let count = system_SuspendThread(handle)
    guard count != DWORD.max else { return .failure(Win32.Error(GetLastError())) }
    return .success(count)
  }
}

#endif // os(Windows)
