/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - The handle

@available(System 199, *)
extension Win32 {
  /// An open event: a flag that threads, and processes, wait on, which one
  /// sets and another waits for.
  ///
  /// An event is signaled or not. Waiting returns once it's signaled; a
  /// manual-reset event stays signaled until ``reset()``, and wakes every
  /// waiter, while an auto-reset one is reset by the wait it ends, and
  /// wakes one waiter. An overlapped operation signals the event in its
  /// `OVERLAPPED`'s `hEvent` when it finishes, which
  /// ``overlappedEvent(queuesCompletion:)`` gives.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle at the end of its scope
  /// and discards the error.
  ///
  /// The corresponding C type is `HANDLE`.
  @frozen @safe
  public struct EventHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw event handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL`, which `CreateEventW` returns when it
    /// fails.
    ///
    /// - Warning: This initializer doesn't check that `raw` is a handle to an
    ///   event.
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
    /// The handle is closed whether this method returns or throws.
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

// MARK: - Operations

@available(System 199, *)
extension Win32.EventHandle {
  /// Creates an event.
  ///
  /// - Parameters:
  ///   - manualReset: Whether the event stays signaled until ``reset()``
  ///     resets it, waking every waiter, rather than being reset by the wait
  ///     it ends, which wakes one.
  ///   - initiallySignaled: Whether the event starts signaled. The default
  ///     is `false`.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of this handle.
  ///
  /// The corresponding C function is `CreateEventW`.
  @_alwaysEmitIntoClient
  public static func create(
    manualReset: Bool,
    initiallySignaled: Bool = false,
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.EventHandle {
    Win32.EventHandle(_owning: try Win32._createEvent(
      manualReset: manualReset, initiallySignaled: initiallySignaled, inheritable: inheritable
    ).get())
  }

  /// Signals the event, waking its waiters: every one for a manual-reset
  /// event, and one for an auto-reset event, which then resets.
  ///
  /// The corresponding C function is `SetEvent`.
  @_alwaysEmitIntoClient
  public func signal() throws(Win32.Error) {
    try Win32._signalEvent(_handle).get()
  }

  /// Resets the event, so that waits wait until it's signaled again.
  ///
  /// The corresponding C function is `ResetEvent`.
  @_alwaysEmitIntoClient
  public func reset() throws(Win32.Error) {
    try Win32._resetEvent(_handle).get()
  }

  /// Waits until the event is signaled, for at most a duration.
  ///
  /// - Parameter timeout: How long to wait, or `nil`, the default, for no
  ///   limit. A duration of zero or less checks without waiting, and a
  ///   positive one rounds up to a whole millisecond.
  /// - Returns: Whether the event was signaled. A wait that an auto-reset
  ///   event ends resets it.
  ///
  /// This method blocks the thread.
  ///
  /// The corresponding C function is `WaitForSingleObject`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func wait(timeout: Duration? = nil) throws(Win32.Error) -> Bool {
    try Win32._wait(_handle, timeout: timeout).get()
  }

  /// The value for an `OVERLAPPED`'s `hEvent`, which an overlapped
  /// operation signals when it finishes.
  ///
  /// - Parameter queuesCompletion: Whether the operation also queues a
  ///   packet to the completion port that its handle is associated with.
  ///   With `false`, the handle's low bit is set, which keeps the packet off
  ///   the port, for an operation that its starter waits for itself, as
  ///   swift-subprocess does for a read after it cancels a process's. The
  ///   default is `true`.
  ///
  /// The value is valid only while this event is alive, and the operation
  /// must finish before the event closes.
  @_alwaysEmitIntoClient
  @unsafe
  public func overlappedEvent(queuesCompletion: Bool = true) -> HANDLE {
    queuesCompletion ? _handle : HANDLE(bitPattern: UInt(bitPattern: _handle) | 1)!
  }
}

// MARK: - Waiting for several objects

@available(System 199, *)
extension Win32 {
  /// Waits until any of several objects is signaled, for at most a
  /// duration, and returns the first one's index.
  ///
  /// - Parameters:
  ///   - handles: The objects' handles, such as events', processes' and
  ///     threads', at most 64. Each must stay open until the wait returns.
  ///   - timeout: How long to wait, or `nil`, the default, for no limit. A
  ///     duration of zero or less checks without waiting, and a positive one
  ///     rounds up to a whole millisecond.
  /// - Returns: The index in `handles` of the signaled object, the lowest if
  ///   more than one is, or `nil` if the wait timed out. A wait that an
  ///   auto-reset event ends resets that event alone.
  ///
  /// Throws ``Win32/Error/invalidParameter`` for no handles or more than
  /// 64. This method blocks the thread.
  ///
  /// The corresponding C function is `WaitForMultipleObjects`, waiting for
  /// any one.
  @_alwaysEmitIntoClient
  @unsafe
  public static func waitForAny(
    _ handles: [HANDLE], timeout: Duration? = nil
  ) throws(Win32.Error) -> Int? {
    try _waitForMultiple(handles, all: false, timeout: timeout).get()
  }

  /// Waits until every one of several objects is signaled at once, for at
  /// most a duration.
  ///
  /// - Parameters:
  ///   - handles: The objects' handles, at most 64, each once. Each must
  ///     stay open until the wait returns.
  ///   - timeout: How long to wait, or `nil`, the default, for no limit, as
  ///     for ``waitForAny(_:timeout:)``.
  /// - Returns: Whether they were all signaled. The wait doesn't change any
  ///   of them until they all are, and then resets its auto-reset events.
  ///
  /// Throws ``Win32/Error/invalidParameter`` for no handles, more than 64,
  /// or one handle twice. This method blocks the thread.
  ///
  /// The corresponding C function is `WaitForMultipleObjects`, waiting for
  /// all of them.
  @_alwaysEmitIntoClient
  @unsafe
  @discardableResult
  public static func waitForAll(
    _ handles: [HANDLE], timeout: Duration? = nil
  ) throws(Win32.Error) -> Bool {
    try _waitForMultiple(handles, all: true, timeout: timeout).get() != nil
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createEvent(
    manualReset: Bool, initiallySignaled: Bool, inheritable: Bool
  ) -> Result<HANDLE, Win32.Error> {
    var securityAttributes = SECURITY_ATTRIBUTES(
      nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
      lpSecurityDescriptor: nil,
      bInheritHandle: WindowsBool(inheritable))
    guard let event = system_CreateEventW(&securityAttributes, manualReset, initiallySignaled)
    else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(event)
  }

  @usableFromInline
  internal static func _signalEvent(_ event: HANDLE) -> Result<Void, Win32.Error> {
    guard system_SetEvent(event) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _resetEvent(_ event: HANDLE) -> Result<Void, Win32.Error> {
    guard system_ResetEvent(event) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  /// The index of the signaled object, or, waiting for all, 0, or `nil` at
  /// the time-out. Like `_wait`, a time-out past `INFINITE` waits in parts.
  @usableFromInline
  internal static func _waitForMultiple(
    _ handles: [HANDLE], all: Bool, timeout: Duration?
  ) -> Result<Int?, Win32.Error> {
    guard (1..._MAXIMUM_WAIT_OBJECTS).contains(handles.count) else {
      return .failure(.invalidParameter)
    }
    let raw: [HANDLE?] = handles
    return raw.withUnsafeBufferPointer { raw in
      func waitOnce(_ milliseconds: DWORD) -> Result<Int?, Win32.Error> {
        let result = system_WaitForMultipleObjects(
          DWORD(raw.count), raw.baseAddress!, all, milliseconds)
        let count = DWORD(raw.count)
        if result < _WAIT_OBJECT_0 + count { return .success(Int(result - _WAIT_OBJECT_0)) }
        // WAIT_ABANDONED_0 and on, which only a mutex reports, and which
        // acquires it.
        if result >= _WAIT_ABANDONED_0, result < _WAIT_ABANDONED_0 + count {
          return .success(Int(result - _WAIT_ABANDONED_0))
        }
        if result == _WAIT_TIMEOUT { return .success(nil) }
        return .failure(Win32.Error(GetLastError()))
      }
      guard let timeout else { return waitOnce(_INFINITE) }
      var remaining = _win32Milliseconds(roundingUp: timeout)
      while true {
        let part = DWORD(min(remaining, UInt64(_INFINITE - 1)))
        let result = waitOnce(part)
        guard case .success(nil) = result, remaining > UInt64(part) else { return result }
        remaining -= UInt64(part)
      }
    }
  }
}

#endif // os(Windows)
