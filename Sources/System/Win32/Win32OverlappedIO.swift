/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Overlapped I/O: a handle opened with FILE_FLAG_OVERLAPPED, whose reads and
// writes return before they finish, and the completion ports that report
// them. The kernel uses an operation's OVERLAPPED structure and buffer until
// it finishes, which no Swift lifetime can express, so the operations that
// take them are @unsafe, and their callers keep both alive.

// MARK: - The handle

@available(System 199, *)
extension Win32 {
  /// An open file, device, or pipe for overlapped I/O, whose reads and
  /// writes return before they finish.
  ///
  /// This type owns its handle, as ``Win32/FileHandle`` does, and its
  /// `open` applies `FILE_FLAG_OVERLAPPED` itself. It has none of
  /// `FileHandle`'s synchronous reads and writes, which aren't memory-safe
  /// on an overlapped handle: Windows can still be writing into their
  /// memory when they return.
  ///
  /// Each operation takes an `OVERLAPPED` structure, which says where it
  /// reads or writes and identifies it while it's pending, and a buffer.
  /// Windows uses both until the operation finishes, so they must stay
  /// allocated, at the same addresses, until ``result(of:wait:)`` reports
  /// the operation, a ``Win32/CompletionPort`` does, or its event is
  /// signaled; an operation still pending when its handle closes is
  /// canceled, and still uses them until it finishes. An overlapped handle
  /// has no file pointer: each operation names its offset.
  ///
  /// The corresponding C type is `HANDLE`, opened with
  /// `FILE_FLAG_OVERLAPPED`.
  @frozen @safe
  public struct OverlappedFileHandle: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw handle opened for overlapped I/O, taking ownership of
    /// it.
    ///
    /// Returns `nil` if `raw` is `NULL` or `INVALID_HANDLE_VALUE`. This
    /// initializer doesn't check that `raw` is overlapped, or that it isn't
    /// a socket, which must be closed with `closesocket`.
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
    /// The handle is closed whether this method returns or throws. Closing
    /// it cancels its pending operations, which still use their
    /// `OVERLAPPED` structures and buffers until they finish.
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

@available(System 199, *)
extension Win32.OverlappedFileHandle {
  /// Opens or creates a file, device, or pipe for overlapped I/O.
  ///
  /// The parameters and errors are those of
  /// ``Win32/FileHandle/open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``,
  /// with `FILE_FLAG_OVERLAPPED` added to `flags`.
  ///
  /// The corresponding C function is `CreateFileW`, with
  /// `FILE_FLAG_OVERLAPPED`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    disposition: Win32.CreationDisposition = .openExisting,
    attributes: Win32.FileAttributes = [],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil
  ) throws(Win32.Error) -> Win32.OverlappedFileHandle {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    let opened = try Win32._createFile(
      path,
      access: access.rawValue,
      shareMode: shareMode.rawValue,
      disposition: disposition.rawValue,
      flagsAndAttributes: attributes.rawValue | flags.rawValue,
      inheritable: inheritable,
      securityDescriptor: rawDescriptor,
      templateFile: nil,
      overlapped: true
    ).get()
    return Win32.OverlappedFileHandle(_owning: opened.handle)
  }
}

// MARK: - Operations

@available(System 199, *)
extension Win32.OverlappedFileHandle {
  /// Starts reading into a buffer.
  ///
  /// - Parameters:
  ///   - buffer: The memory to read into, which must stay allocated until
  ///     the read finishes. A buffer of more than `DWORD.max` bytes throws
  ///     ``Win32/Error/invalidParameter``.
  ///   - offset: Where in the file to read. A device or pipe without
  ///     positions ignores it; pass 0.
  ///   - overlapped: The structure that identifies the read, which must
  ///     stay allocated, at the same address, until the read finishes. This
  ///     method sets its offset, and clears its status; its `hEvent` stays
  ///     as the caller set it, to `NULL` or to an event that the read
  ///     signals when it finishes.
  /// - Returns: The number of bytes read, if the read finished at once, or
  ///   `nil` if it's pending.
  ///
  /// A read at or past the end of a file throws ``Win32/Error/endOfFile``,
  /// and one from a pipe whose writer closed ``Win32/Error/brokenPipe``,
  /// whether now or when it finishes, where `FileHandle`'s reads return 0:
  /// a completion port reports them as failures too. A message longer than
  /// the buffer, from a message-mode pipe, is a short read; the rest
  /// follows.
  ///
  /// A handle associated with a ``Win32/CompletionPort`` queues a packet
  /// for the read even when it finishes at once, so another thread can
  /// receive it, and free `overlapped`, before this method returns; this
  /// method doesn't read `overlapped` after it starts the read.
  ///
  /// The corresponding C function is `ReadFile`, with an `OVERLAPPED`.
  @_alwaysEmitIntoClient
  @unsafe
  public func read(
    into buffer: UnsafeMutableRawBufferPointer,
    fromAbsoluteOffset offset: Int64,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Int? {
    try Win32._startOverlapped(
      _handle, buffer.baseAddress, buffer.count, offset: offset, overlapped: overlapped,
      write: false
    ).get()
  }

  /// Starts writing a buffer.
  ///
  /// - Parameters:
  ///   - buffer: The bytes to write, which must stay allocated, and
  ///     unchanged, until the write finishes. A buffer of more than
  ///     `DWORD.max` bytes throws ``Win32/Error/invalidParameter``.
  ///   - offset: Where in the file to write. A device or pipe without
  ///     positions ignores it; pass 0.
  ///   - overlapped: The structure that identifies the write, with the
  ///     same requirements as for ``read(into:fromAbsoluteOffset:overlapped:)``.
  /// - Returns: The number of bytes written, if the write finished at once,
  ///   or `nil` if it's pending.
  ///
  /// The corresponding C function is `WriteFile`, with an `OVERLAPPED`.
  @_alwaysEmitIntoClient
  @unsafe
  public func write(
    _ buffer: UnsafeRawBufferPointer,
    toAbsoluteOffset offset: Int64,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Int? {
    try Win32._startOverlapped(
      _handle, UnsafeMutableRawPointer(mutating: buffer.baseAddress), buffer.count,
      offset: offset, overlapped: overlapped, write: true
    ).get()
  }

  /// The result of an operation that this handle started.
  ///
  /// - Parameters:
  ///   - overlapped: The structure the operation was started with.
  ///   - wait: Whether to wait for a pending operation to finish.
  /// - Returns: The number of bytes the operation transferred, or `nil` if
  ///   it's still pending and `wait` is `false`.
  ///
  /// The operation's own failure is thrown, such as
  /// ``Win32/Error/operationAborted`` for one that was canceled.
  ///
  /// Waiting with an `OVERLAPPED` whose `hEvent` is `NULL` waits on the
  /// handle, which every operation on it signals, so it's reliable only
  /// while one operation at a time is pending.
  ///
  /// The corresponding C function is `GetOverlappedResult`.
  @_alwaysEmitIntoClient
  @unsafe
  public func result(
    of overlapped: UnsafeMutablePointer<OVERLAPPED>, wait: Bool
  ) throws(Win32.Error) -> Int? {
    try Win32._overlappedResult(
      _handle, overlapped, milliseconds: wait ? _INFINITE : 0
    ).get()
  }

  /// The result of an operation that this handle started, waiting for at
  /// most a duration.
  ///
  /// - Parameters:
  ///   - overlapped: The structure the operation was started with.
  ///   - timeout: How long to wait. A duration of zero or less checks
  ///     without waiting, and a positive one rounds up to a whole
  ///     millisecond.
  /// - Returns: The number of bytes the operation transferred, or `nil` if
  ///   it's still pending when the time is up.
  ///
  /// See ``result(of:wait:)``.
  ///
  /// The corresponding C function is `GetOverlappedResultEx`.
  @_alwaysEmitIntoClient
  @unsafe
  public func result(
    of overlapped: UnsafeMutablePointer<OVERLAPPED>, timeout: Duration
  ) throws(Win32.Error) -> Int? {
    try Win32._overlappedResult(_handle, overlapped, timeout: timeout).get()
  }

  /// Cancels a pending operation that this process started on this handle.
  ///
  /// - Parameter overlapped: The structure the operation was started with.
  /// - Returns: Whether the operation was pending. Canceling doesn't wait:
  ///   the operation still finishes, with ``Win32/Error/operationAborted``,
  ///   or with its result if it finished first, and uses its memory until
  ///   then.
  ///
  /// The corresponding C function is `CancelIoEx`.
  @_alwaysEmitIntoClient
  @unsafe
  @discardableResult
  public func cancel(_ overlapped: UnsafeMutablePointer<OVERLAPPED>) throws(Win32.Error) -> Bool {
    try Win32._cancelIO(_handle, overlapped).get()
  }

  /// Cancels every pending operation that this process started on this
  /// handle.
  ///
  /// - Returns: Whether any operation was pending. As with ``cancel(_:)``,
  ///   each still finishes, and uses its memory until then.
  ///
  /// The corresponding C function is `CancelIoEx`, with a `NULL`
  /// `OVERLAPPED`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func cancelAll() throws(Win32.Error) -> Bool {
    try Win32._cancelIO(_handle, nil).get()
  }
}

// MARK: - Completion ports

@available(System 199, *)
extension Win32 {
  /// An I/O completion port: a queue of packets that report finished
  /// overlapped operations, which threads wait on.
  ///
  /// This type owns its handle. Call ``close()`` to close it and report any
  /// error. Otherwise, `deinit` closes the handle and discards the error. A
  /// thread waiting in ``dequeue(timeout:)`` when the port closes throws.
  ///
  /// The corresponding C type is `HANDLE`, from `CreateIoCompletionPort`.
  @frozen @safe
  public struct CompletionPort: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _handle: HANDLE

    @_alwaysEmitIntoClient
    internal init(_owning handle: HANDLE) {
      self._handle = handle
    }

    /// Adopts a raw completion port handle, taking ownership of it.
    ///
    /// Returns `nil` if `raw` is `NULL` or `INVALID_HANDLE_VALUE`. This
    /// initializer doesn't check that `raw` is a completion port.
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

    /// Closes this port.
    ///
    /// The port is closed whether this method returns or throws.
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

  /// A packet from a ``Win32/CompletionPort``: a finished overlapped
  /// operation, or one that ``Win32/CompletionPort/post(bytesTransferred:key:overlapped:)``
  /// queued.
  @frozen
  public struct Completion {
    /// The number of bytes the operation transferred.
    public let bytesTransferred: Int

    /// The key the operation's handle was associated with, or the key a
    /// posted packet carries.
    public let key: UInt

    /// The `OVERLAPPED` structure the operation was started with, or the
    /// pointer a posted packet carries, which needn't be an `OVERLAPPED`.
    public let overlapped: UnsafeMutablePointer<OVERLAPPED>?

    /// The operation's failure, or `nil` if it succeeded.
    ///
    /// A read at the end of a file reports ``Win32/Error/endOfFile``, one
    /// from a pipe whose writer closed ``Win32/Error/brokenPipe``, and a
    /// canceled operation ``Win32/Error/operationAborted``.
    public let error: Win32.Error?

    @_alwaysEmitIntoClient
    internal init(
      _bytesTransferred bytesTransferred: Int,
      key: UInt,
      overlapped: UnsafeMutablePointer<OVERLAPPED>?,
      error: Win32.Error?
    ) {
      self.bytesTransferred = bytesTransferred
      self.key = key
      self.overlapped = overlapped
      self.error = error
    }
  }
}

@available(System 199, *)
extension Win32.CompletionPort {
  /// Creates a completion port.
  ///
  /// - Parameter concurrentThreads: How many threads the system lets run
  ///   at once on the port's packets, or 0 for one per processor.
  ///
  /// The corresponding C function is `CreateIoCompletionPort`, with
  /// `INVALID_HANDLE_VALUE`.
  @_alwaysEmitIntoClient
  public static func create(concurrentThreads: Int = 0) throws(Win32.Error) -> Win32.CompletionPort {
    Win32.CompletionPort(_owning: try Win32._createCompletionPort(concurrentThreads).get())
  }

  /// Associates a handle with this port, which then receives a packet for
  /// each of the handle's overlapped operations.
  ///
  /// - Parameters:
  ///   - handle: The handle. A handle can be associated with one port, for
  ///     as long as it's open; a second association throws
  ///     ``Win32/Error/invalidParameter``.
  ///   - key: A value for the handle's packets to carry, such as an index
  ///     into the caller's table of handles.
  ///
  /// An operation whose `OVERLAPPED` has an event in `hEvent` with its
  /// lowest bit set queues no packet; it's waited for some other way.
  ///
  /// The corresponding C function is `CreateIoCompletionPort`.
  @_alwaysEmitIntoClient
  public func associate(
    _ handle: borrowing Win32.OverlappedFileHandle, key: UInt
  ) throws(Win32.Error) {
    try Win32._associate(handle._handle, with: _handle, key: key).get()
  }

  /// Queues a packet, as a way for a thread to wake one that's waiting on
  /// the port.
  ///
  /// The packet's values are the caller's: the port passes them along
  /// unread.
  ///
  /// The corresponding C function is `PostQueuedCompletionStatus`.
  @_alwaysEmitIntoClient
  public func post(
    bytesTransferred: Int = 0,
    key: UInt,
    overlapped: UnsafeMutablePointer<OVERLAPPED>? = nil
  ) throws(Win32.Error) {
    try Win32._post(_handle, bytesTransferred: bytesTransferred, key: key, overlapped: overlapped)
      .get()
  }

  /// Waits for a packet and removes it from the queue.
  ///
  /// - Parameter timeout: How long to wait, or `nil` to wait with no
  ///   limit. A duration of zero or less checks without waiting, and a
  ///   positive one rounds up to a whole millisecond.
  /// - Returns: The packet, or `nil` if none came in time. A packet for an
  ///   operation that failed is returned, with its ``Win32/Completion/error``,
  ///   not thrown.
  ///
  /// Throws if the wait itself fails, as it does when the port closes
  /// while a thread waits.
  ///
  /// The corresponding C function is `GetQueuedCompletionStatus`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func dequeue(timeout: Duration? = nil) throws(Win32.Error) -> Win32.Completion? {
    try Win32._dequeue(_handle, timeout: timeout).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _startOverlapped(
    _ handle: HANDLE,
    _ address: UnsafeMutableRawPointer?,
    _ count: Int,
    offset: Int64,
    overlapped: UnsafeMutablePointer<OVERLAPPED>,
    write: Bool
  ) -> Result<Int?, Win32.Error> {
    // Negative offsets are OVERLAPPED's sentinels, as for FileHandle.
    guard offset >= 0, let count = DWORD(exactly: count) else {
      return .failure(.invalidParameter)
    }
    overlapped.pointee.Internal = 0
    overlapped.pointee.InternalHigh = 0
    overlapped.pointee.Offset = DWORD(truncatingIfNeeded: offset)
    overlapped.pointee.OffsetHigh = DWORD(truncatingIfNeeded: offset >> 32)
    // Once the call returns, the OVERLAPPED isn't read again: a completion
    // port's waiter can take the packet and free it at once, even for an
    // operation that finished in the call. A count Windows writes during
    // the call is the caller's, and means something only then.
    var transferred: DWORD = 0
    let started = write
      ? system_WriteFile(handle, address, count, &transferred, overlapped)
      : system_ReadFile(handle, address, count, &transferred, overlapped)
    let error = GetLastError()
    guard started else {
      if error == Win32.Error.ioPending.rawValue { return .success(nil) }
      if error == Win32.Error.moreData.rawValue { return .success(Int(transferred)) }
      return .failure(Win32.Error(error))
    }
    return .success(Int(transferred))
  }

  @usableFromInline
  internal static func _overlappedResult(
    _ handle: HANDLE,
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>,
    milliseconds: DWORD
  ) -> Result<Int?, Win32.Error> {
    var transferred: DWORD = 0
    let finished = milliseconds == _INFINITE
      ? system_GetOverlappedResult(handle, overlapped, &transferred, true)
      : system_GetOverlappedResultEx(handle, overlapped, &transferred, milliseconds, false)
    guard finished else {
      let error = GetLastError()
      // Not done yet: ERROR_IO_INCOMPLETE without waiting, WAIT_TIMEOUT
      // after a wait.
      if error == _ERROR_IO_INCOMPLETE || error == _WAIT_TIMEOUT { return .success(nil) }
      if error == Win32.Error.moreData.rawValue { return .success(Int(transferred)) }
      return .failure(Win32.Error(error))
    }
    return .success(Int(transferred))
  }

  @usableFromInline
  internal static func _overlappedResult(
    _ handle: HANDLE,
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>,
    timeout: Duration
  ) -> Result<Int?, Win32.Error> {
    // GetOverlappedResultEx takes up to INFINITE - 1 milliseconds, so a
    // longer time-out waits in parts.
    var remaining = _win32Milliseconds(roundingUp: timeout)
    while true {
      let part = DWORD(min(remaining, UInt64(_INFINITE - 1)))
      let result = _overlappedResult(handle, overlapped, milliseconds: part)
      guard case .success(nil) = result, remaining > UInt64(part) else { return result }
      remaining -= UInt64(part)
    }
  }

  @usableFromInline
  internal static func _cancelIO(
    _ handle: HANDLE, _ overlapped: UnsafeMutablePointer<OVERLAPPED>?
  ) -> Result<Bool, Win32.Error> {
    guard system_CancelIoEx(handle, overlapped) else {
      let error = GetLastError()
      // Nothing pending to cancel.
      if error == _ERROR_NOT_FOUND { return .success(false) }
      return .failure(Win32.Error(error))
    }
    return .success(true)
  }

  @usableFromInline
  internal static func _createCompletionPort(_ concurrentThreads: Int) -> Result<HANDLE, Win32.Error> {
    guard let threads = DWORD(exactly: concurrentThreads) else { return .failure(.invalidParameter) }
    guard let port = system_CreateIoCompletionPort(INVALID_HANDLE_VALUE, nil, 0, threads) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(port)
  }

  @usableFromInline
  internal static func _associate(
    _ handle: HANDLE, with port: HANDLE, key: UInt
  ) -> Result<Void, Win32.Error> {
    // Returns the port it was given.
    guard system_CreateIoCompletionPort(handle, port, key, 0) != nil else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _post(
    _ port: HANDLE,
    bytesTransferred: Int,
    key: UInt,
    overlapped: UnsafeMutablePointer<OVERLAPPED>?
  ) -> Result<Void, Win32.Error> {
    guard let count = DWORD(exactly: bytesTransferred) else { return .failure(.invalidParameter) }
    guard system_PostQueuedCompletionStatus(port, count, key, overlapped) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _dequeue(
    _ port: HANDLE, timeout: Duration?
  ) -> Result<Win32.Completion?, Win32.Error> {
    guard let timeout else { return _dequeueOnce(port, milliseconds: _INFINITE) }
    // GetQueuedCompletionStatus takes up to INFINITE - 1 milliseconds, so
    // a longer time-out waits in parts.
    var remaining = _win32Milliseconds(roundingUp: timeout)
    while true {
      let part = DWORD(min(remaining, UInt64(_INFINITE - 1)))
      let result = _dequeueOnce(port, milliseconds: part)
      guard case .success(nil) = result, remaining > UInt64(part) else { return result }
      remaining -= UInt64(part)
    }
  }

  internal static func _dequeueOnce(
    _ port: HANDLE, milliseconds: DWORD
  ) -> Result<Win32.Completion?, Win32.Error> {
    var transferred: DWORD = 0
    var key: ULONG_PTR = 0
    var overlapped: UnsafeMutablePointer<OVERLAPPED>? = nil
    let dequeued = system_GetQueuedCompletionStatus(
      port, &transferred, &key, &overlapped, milliseconds)
    let error = GetLastError()
    if !dequeued {
      // Without a packet, the wait itself failed, or timed out.
      guard overlapped != nil else {
        return error == _WAIT_TIMEOUT ? .success(nil) : .failure(Win32.Error(error))
      }
    }
    return .success(
      Win32.Completion(
        _bytesTransferred: Int(transferred), key: UInt(key), overlapped: overlapped,
        error: dequeued ? nil : Win32.Error(error)))
  }
}

#endif // os(Windows)
