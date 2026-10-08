/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Overlapped socket I/O, as SystemPackage's Win32OverlappedIO.swift has it
// for files: sends and receives that return before they finish, and the
// completion ports that report them. The kernel uses an operation's
// OVERLAPPED structure and buffer until it finishes, which no Swift
// lifetime can express, so the operations that take them are @unsafe, and
// their callers keep both alive. open's sockets are overlapped already
// (WSA_FLAG_OVERLAPPED), as socket's are.

// MARK: - Completion ports

@available(System 199, *)
extension Win32.CompletionPort {
  /// Associates a socket with this port, which then receives a packet for
  /// each of the socket's overlapped operations.
  ///
  /// - Parameters:
  ///   - socket: The socket. A socket can be associated with one port, for
  ///     as long as it's open; a second association throws
  ///     ``Win32/Error/invalidParameter``.
  ///   - key: A value for the socket's packets to carry, such as an index
  ///     into the caller's table of sockets.
  ///
  /// A packet for a socket operation that failed carries the Win32 code
  /// that the kernel's status maps to, such as `ERROR_NETNAME_DELETED`
  /// for a connection the peer reset, rather than Winsock's code;
  /// ``SocketDescriptor/result(of:wait:)`` reports Winsock's.
  ///
  /// The corresponding C function is `CreateIoCompletionPort`.
  @_alwaysEmitIntoClient
  public func associate(_ socket: SocketDescriptor, key: UInt) throws(Win32.Error) {
    try SocketDescriptor._associate(socket.rawValue, with: unsafeRawHandle, key: key).get()
  }
}

// MARK: - Overlapped operations

@available(System 199, *)
extension SocketDescriptor {
  /// Starts sending a buffer, overlapped.
  ///
  /// - Parameters:
  ///   - buffer: The bytes to send, which must stay allocated, and
  ///     unchanged, until the send finishes. A buffer of more than
  ///     `UInt32.max` bytes throws ``Win32/Error/invalidParameter``.
  ///   - flags: Message flags.
  ///   - overlapped: The structure that identifies the send while it's
  ///     pending. It must stay allocated, at the same address, until the
  ///     send finishes; this method clears its status fields first.
  /// - Returns: The number of bytes sent, if the send finished at once,
  ///   or `nil` if it's pending.
  ///
  /// A socket associated with a ``Win32/CompletionPort`` queues a packet for
  /// the send even when it finishes at once, so another thread can receive
  /// it, and free `overlapped`, before this method returns; this method
  /// doesn't read `overlapped` after it starts the send.
  ///
  /// The corresponding C function is `WSASend`, with a `WSAOVERLAPPED`.
  @_alwaysEmitIntoClient
  @unsafe
  public func send(
    _ buffer: UnsafeRawBufferPointer,
    flags: MessageFlags = .none,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Int? {
    try _startOverlapped(
      UnsafeMutableRawPointer(mutating: buffer.baseAddress), buffer.count,
      flags: flags, overlapped: overlapped, send: true
    ).get()
  }

  /// Starts receiving into a buffer, overlapped.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive into, which must stay allocated,
  ///     and unused, until the receive finishes. A buffer of more than
  ///     `UInt32.max` bytes throws ``Win32/Error/invalidParameter``.
  ///   - flags: Message flags.
  ///   - overlapped: The structure that identifies the receive, with the
  ///     same requirements as for ``send(_:flags:overlapped:)``.
  /// - Returns: The number of bytes received, if the receive finished at
  ///   once, or `nil` if it's pending.
  ///
  /// The corresponding C function is `WSARecv`, with a `WSAOVERLAPPED`.
  @_alwaysEmitIntoClient
  @unsafe
  public func receive(
    into buffer: UnsafeMutableRawBufferPointer,
    flags: MessageFlags = .none,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Int? {
    try _startOverlapped(
      buffer.baseAddress, buffer.count, flags: flags, overlapped: overlapped, send: false
    ).get()
  }

  /// The result of an overlapped operation that this socket started.
  ///
  /// - Parameters:
  ///   - overlapped: The structure the operation was started with.
  ///   - wait: Whether to wait for a pending operation to finish, which
  ///     Winsock allows only for an operation whose `OVERLAPPED` has an
  ///     event in `hEvent`.
  /// - Returns: The number of bytes the operation transferred, or `nil` if
  ///   it's still pending and `wait` is `false`.
  ///
  /// The operation's own failure is thrown, as Winsock's code, such as
  /// ``Win32/Error/connectionReset``, or ``Win32/Error/operationAborted``
  /// for one that was canceled.
  ///
  /// The corresponding C function is `WSAGetOverlappedResult`.
  @_alwaysEmitIntoClient
  @unsafe
  public func result(
    of overlapped: UnsafeMutablePointer<OVERLAPPED>, wait: Bool
  ) throws(Win32.Error) -> Int? {
    try _overlappedResult(overlapped, wait: wait).get()
  }

  /// Cancels a pending operation that this process started on this socket.
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
    try _cancelIO(overlapped).get()
  }

  /// Cancels every pending operation that this process started on this
  /// socket.
  ///
  /// - Returns: Whether any operation was pending. As with ``cancel(_:)``,
  ///   each still finishes, and uses its memory until then.
  ///
  /// The corresponding C function is `CancelIoEx`, with a `NULL`
  /// `OVERLAPPED`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func cancelAll() throws(Win32.Error) -> Bool {
    try _cancelIO(nil).get()
  }

  /// The socket as a kernel handle, which Windows' own providers make it.
  @usableFromInline
  internal var _handle: HANDLE? {
    HANDLE(bitPattern: UInt(rawValue))
  }

  @usableFromInline
  internal static func _associate(
    _ socket: SOCKET, with port: HANDLE, key: UInt
  ) -> Result<Void, Win32.Error> {
    guard let handle = HANDLE(bitPattern: UInt(socket)) else { return .failure(.invalidHandle) }
    // Returns the port it was given.
    guard system_CreateIoCompletionPort(handle, port, ULONG_PTR(key), 0) != nil else {
      return .failure(Win32.Error(rawValue: GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal func _startOverlapped(
    _ address: UnsafeMutableRawPointer?,
    _ count: Int,
    flags: MessageFlags,
    overlapped: UnsafeMutablePointer<OVERLAPPED>,
    send: Bool
  ) -> Result<Int?, Win32.Error> {
    guard let length = ULONG(exactly: count) else { return .failure(.invalidParameter) }
    overlapped.pointee.Internal = 0
    overlapped.pointee.InternalHigh = 0
    // Winsock captures the buffer descriptions before it returns, so they
    // can be the call's own; the bytes are the caller's.
    var vector = CInterop.IOVec(base: address, length: Int(length))
    // Once the call returns, the OVERLAPPED isn't read again: a completion
    // port's waiter can take the packet and free it at once, even for an
    // operation that finished in the call. A count Winsock writes during
    // the call is the caller's, and means something only then.
    var transferred: DWORD = 0
    var receiveFlags = DWORD(bitPattern: flags.rawValue)
    let result = send
      ? system_WSASend(rawValue, &vector, 1, &transferred, receiveFlags, overlapped)
      : system_WSARecv(rawValue, &vector, 1, &transferred, &receiveFlags, overlapped)
    guard result == _SOCKET_ERROR else { return .success(Int(transferred)) }
    let error = _lastWinsockError()
    if error == .ioPending { return .success(nil) }
    return .failure(error)
  }

  @usableFromInline
  internal func _overlappedResult(
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>, wait: Bool
  ) -> Result<Int?, Win32.Error> {
    var transferred: DWORD = 0
    var flags: DWORD = 0
    guard system_WSAGetOverlappedResult(rawValue, overlapped, &transferred, wait, &flags) else {
      let error = _lastWinsockError()
      // Not done yet.
      if error.rawValue == _WSA_IO_INCOMPLETE { return .success(nil) }
      return .failure(error)
    }
    return .success(Int(transferred))
  }

  @usableFromInline
  internal func _cancelIO(_ overlapped: UnsafeMutablePointer<OVERLAPPED>?) -> Result<Bool, Win32.Error> {
    guard let handle = _handle else { return .failure(.invalidHandle) }
    guard system_CancelIoEx(handle, overlapped) else {
      let error = GetLastError()
      // Nothing pending to cancel.
      if error == _ERROR_NOT_FOUND { return .success(false) }
      return .failure(Win32.Error(rawValue: error))
    }
    return .success(true)
  }
}

#endif // os(Windows)
