/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Socket Creation and Lifecycle

@available(System 199, *)
extension SocketDescriptor {
  /// Creates an endpoint for communication.
  ///
  /// - Parameters:
  ///   - domain: The protocol family for communication.
  ///   - type: The semantics of communication.
  ///   - protocol: The particular protocol to use. The default is `.default`,
  ///     which typically selects the appropriate protocol for the domain/type
  ///     combination (e.g., TCP for IPv4/stream).
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor.
  ///
  /// The socket supports overlapped I/O, so that it can be associated with
  /// a completion port, as `socket`'s sockets do; its blocking operations
  /// still block. Child processes don't inherit it, as POSIX's
  /// `SOCK_CLOEXEC` arranges.
  ///
  /// The first call in a process starts Winsock, with `WSAStartup`, and
  /// throws its error if that fails.
  ///
  /// The corresponding C function is `WSASocketW`, with `WSA_FLAG_OVERLAPPED`
  /// and `WSA_FLAG_NO_HANDLE_INHERIT`.
  @_alwaysEmitIntoClient
  public static func open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _open(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    _startWinsock().flatMap {
      socketOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_WSASocketW(
          domain.rawValue, type.rawValue, `protocol`.rawValue,
          _WSA_FLAG_OVERLAPPED | _WSA_FLAG_NO_HANDLE_INHERIT)
      }.map(SocketDescriptor.init(rawValue:))
    }
  }

  /// Closes the socket.
  ///
  /// On a nonblocking socket whose ``setLinger(_:)`` time isn't zero,
  /// closing throws ``Win32/Error/wouldBlock`` while unsent data remains,
  /// and the socket stays open.
  ///
  /// The corresponding C function is `closesocket`.
  @_alwaysEmitIntoClient
  public func close() throws(Win32.Error) {
    try _close().get()
  }

  @usableFromInline
  internal func _close() -> Result<(), Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_closesocket(self.rawValue)
    }
  }

  /// Shuts down part of a full-duplex connection.
  ///
  /// - Parameter how: Which parts of the connection to shut down.
  ///
  /// The corresponding C function is `shutdown`.
  @_alwaysEmitIntoClient
  public func shutdown(_ how: ShutdownKind) throws(Win32.Error) {
    try _shutdown(how).get()
  }

  @usableFromInline
  internal func _shutdown(_ how: ShutdownKind) -> Result<(), Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_shutdown(self.rawValue, how.rawValue)
    }
  }
}

// MARK: - Connection Operations

@available(System 199, *)
extension SocketDescriptor {
  /// Binds a socket to an address.
  ///
  /// - Parameter address: The socket address to bind to.
  ///
  /// The corresponding C function is `bind`.
  @_alwaysEmitIntoClient
  public func bind(to address: SocketAddress) throws(Win32.Error) {
    try _bind(to: address).get()
  }

  @usableFromInline
  internal func _bind(to address: SocketAddress) -> Result<(), Win32.Error> {
    address.withUnsafePointer { addr, len in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_bind(self.rawValue, addr, len)
      }
    }
  }

  /// Listens for connections on the socket.
  ///
  /// Only applies to sockets of type `.stream`.
  ///
  /// - Parameter backlog: The maximum length of the pending connections queue.
  ///
  /// The corresponding C function is `listen`.
  @_alwaysEmitIntoClient
  public func listen(backlog: Int) throws(Win32.Error) {
    try _listen(backlog: backlog).get()
  }

  @usableFromInline
  internal func _listen(backlog: Int) -> Result<(), Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_listen(self.rawValue, CInt(backlog))
    }
  }

  /// Accepts a connection on the socket.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// The new socket has the listening socket's properties, and child
  /// processes don't inherit it, as they don't inherit `open`'s sockets.
  /// System arranges that just after `accept` returns, with
  /// `SetHandleInformation`, so a child that another thread creates in
  /// between, inheriting handles, can inherit it; if that fails, this
  /// method closes the socket and throws.
  ///
  /// The corresponding C function is `accept`.
  @_alwaysEmitIntoClient
  public func accept(retryOnInterrupt: Bool = true) throws(Win32.Error) -> SocketDescriptor {
    try _accept(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(retryOnInterrupt: Bool) -> Result<SocketDescriptor, Win32.Error> {
    socketOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
      system_accept(self.rawValue, nil, nil)
    }.flatMap(_notInherited)
  }

  /// Accepts a connection and returns the client's address.
  ///
  /// - Parameters:
  ///   - client: A socket address buffer to receive the client's address.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: A new socket descriptor for the accepted connection,
  ///   which, as ``accept(retryOnInterrupt:)``'s, child processes don't
  ///   inherit.
  ///
  /// The corresponding C function is `accept`.
  @_alwaysEmitIntoClient
  public func accept(
    client: inout SocketAddress,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _accept(client: &client, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    client: inout SocketAddress,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    client._withUnsafeMutablePointer { addr, len in
      socketOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_accept(self.rawValue, addr, &len)
      }
    }.flatMap(_notInherited)
  }

  /// Initiates a connection on the socket.
  ///
  /// - Parameter address: The address to connect to.
  ///
  /// A nonblocking socket throws ``Win32/Error/wouldBlock`` while the
  /// connection is in progress, where POSIX throws `EINPROGRESS`; poll for
  /// writability, then read ``SocketOption/error`` for the outcome. A
  /// connection that's refused, Windows' TCP tries twice more before
  /// throwing ``Win32/Error/connectionRefused``, so that takes a second or
  /// more, even on loopback.
  ///
  /// The corresponding C function is `connect`.
  @_alwaysEmitIntoClient
  public func connect(to address: SocketAddress) throws(Win32.Error) {
    try _connect(to: address).get()
  }

  @usableFromInline
  internal func _connect(to address: SocketAddress) -> Result<(), Win32.Error> {
    address.withUnsafePointer { addr, len in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_connect(self.rawValue, addr, len)
      }
    }
  }
}

/// Makes a socket that `accept` returned non-inheritable, as `open`'s
/// sockets are, or closes it and returns the error.
@available(System 199, *)
internal func _notInherited(_ socket: SOCKET) -> Result<SocketDescriptor, Win32.Error> {
  // A socket from Windows' own providers is a kernel handle.
  if let handle = HANDLE(bitPattern: UInt(socket)),
    !system_SetHandleInformation(handle, _HANDLE_FLAG_INHERIT, 0)
  {
    let error = Win32.Error(rawValue: GetLastError())
    _ = system_closesocket(socket)
    return .failure(error)
  }
  return .success(SocketDescriptor(rawValue: socket))
}

// MARK: - Send and Receive

@available(System 199, *)
extension SocketDescriptor {
  /// Sends data on the socket.
  ///
  /// - Parameters:
  ///   - buffer: The data to send.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes sent.
  ///
  /// Winsock takes the length as an `int`, so one call sends at most
  /// `Int32.max` bytes.
  ///
  /// The corresponding C function is `send`.
  @_alwaysEmitIntoClient
  public func send(
    _ buffer: UnsafeRawBufferPointer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _send(buffer, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _send(
    _ buffer: UnsafeRawBufferPointer,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
      system_send(self.rawValue, buffer.baseAddress, CInt(clamping: buffer.count), flags.rawValue)
    }.map(Int.init)
  }

  /// Receives data from the socket.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes received, or 0 when a stream's peer
  ///   has shut down its side.
  ///
  /// A datagram that doesn't fit in `buffer` fills it, loses the rest, and
  /// throws ``Win32/Error/messageTooLong``, where POSIX returns the count
  /// that fit. Winsock takes the length as an `int`, so one call receives
  /// at most `Int32.max` bytes.
  ///
  /// The corresponding C function is `recv`.
  @_alwaysEmitIntoClient
  public func receive(
    into buffer: UnsafeMutableRawBufferPointer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _receive(into: buffer, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receive(
    into buffer: UnsafeMutableRawBufferPointer,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
      system_recv(self.rawValue, buffer.baseAddress, CInt(clamping: buffer.count), flags.rawValue)
    }.map(Int.init)
  }

  /// Sends data to a specific address.
  ///
  /// - Parameters:
  ///   - buffer: The data to send.
  ///   - address: The destination address.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes sent.
  ///
  /// The corresponding C function is `sendto`.
  @_alwaysEmitIntoClient
  public func send(
    _ buffer: UnsafeRawBufferPointer,
    to address: SocketAddress,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _send(buffer, to: address, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _send(
    _ buffer: UnsafeRawBufferPointer,
    to address: SocketAddress,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    address.withUnsafePointer { addr, addrlen in
      valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_sendto(
          self.rawValue,
          buffer.baseAddress,
          CInt(clamping: buffer.count),
          flags.rawValue,
          addr,
          addrlen
        )
      }.map(Int.init)
    }
  }

  /// Receives data and returns the sender's address.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - sender: A buffer to receive the sender's address.
  ///     A connected stream socket's data has no sender,
  ///     and leaves it empty.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes received.
  ///
  /// As with ``receive(into:flags:retryOnInterrupt:)``, a datagram that
  /// doesn't fit throws ``Win32/Error/messageTooLong``.
  ///
  /// The corresponding C function is `recvfrom`.
  @_alwaysEmitIntoClient
  public func receive(
    into buffer: UnsafeMutableRawBufferPointer,
    sender: inout SocketAddress,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _receive(into: buffer, sender: &sender, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receive(
    into buffer: UnsafeMutableRawBufferPointer,
    sender: inout SocketAddress,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    // Winsock ignores the address of a connection-oriented socket's
    // receive, leaving the buffer and its length as they were, where POSIX
    // reports no address. Starting from an empty address, one still
    // unspecified afterward is none.
    sender.clear()
    let result = sender._withUnsafeMutablePointer { addr, len in
      valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_recvfrom(
          self.rawValue,
          buffer.baseAddress,
          CInt(clamping: buffer.count),
          flags.rawValue,
          addr,
          &len
        )
      }.map(Int.init)
    }
    if sender.family == .unspecified { sender.clear() }
    return result
  }
}

// MARK: - Socket Information

@available(System 199, *)
extension SocketDescriptor {
  /// Gets the local address of the socket.
  ///
  /// - Parameter address: A buffer to receive the local address.
  ///
  /// A socket that isn't bound throws ``Win32/Error/invalidArgument``, where
  /// POSIX reports the unspecified address.
  ///
  /// The corresponding C function is `getsockname`.
  @_alwaysEmitIntoClient
  public func getLocalAddress(into address: inout SocketAddress) throws(Win32.Error) {
    try _getLocalAddress(into: &address).get()
  }

  @usableFromInline
  internal func _getLocalAddress(into address: inout SocketAddress) -> Result<(), Win32.Error> {
    address._withUnsafeMutablePointer { addr, len in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_getsockname(self.rawValue, addr, &len)
      }
    }
  }

  /// Gets the remote address of the socket.
  ///
  /// - Parameter address: A buffer to receive the peer address.
  ///
  /// The corresponding C function is `getpeername`.
  @_alwaysEmitIntoClient
  public func getPeerAddress(into address: inout SocketAddress) throws(Win32.Error) {
    try _getPeerAddress(into: &address).get()
  }

  @usableFromInline
  internal func _getPeerAddress(into address: inout SocketAddress) -> Result<(), Win32.Error> {
    address._withUnsafeMutablePointer { addr, len in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_getpeername(self.rawValue, addr, &len)
      }
    }
  }
}

#endif // os(Windows)
