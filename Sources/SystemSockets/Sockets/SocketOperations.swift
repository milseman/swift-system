/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(WASI)

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

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
  /// The corresponding C function is `socket`.
  @_alwaysEmitIntoClient
  public static func open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    retryOnInterrupt: Bool = true
  ) throws -> SocketDescriptor {
    try _open(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_socket(domain.rawValue, type.rawValue, `protocol`.rawValue)
    }.map(SocketDescriptor.init(rawValue:))
  }

  /// Creates a pair of connected sockets.
  ///
  /// - Parameters:
  ///   - domain: The protocol family for communication.
  ///   - type: The semantics of communication.
  ///   - protocol: The particular protocol to use. The default is `.default`,
  ///     which typically selects the appropriate protocol for the domain/type
  ///     combination.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The pair of socket descriptors.
  ///
  /// The two sockets are connected to each other and indistinguishable.
  /// Which domains are supported varies by platform;
  /// `.local` is the most widely supported.
  ///
  /// The corresponding C function is `socketpair`.
  @_alwaysEmitIntoClient
  public static func pair(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    retryOnInterrupt: Bool = true
  ) throws -> (SocketDescriptor, SocketDescriptor) {
    try _pair(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _pair(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    retryOnInterrupt: Bool
  ) -> Result<(SocketDescriptor, SocketDescriptor), Errno> {
    var fds: (CInt, CInt) = (-1, -1)
    return withUnsafeMutablePointer(to: &fds) { pointer in
      pointer.withMemoryRebound(to: CInt.self, capacity: 2) { fds in
        valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
          system_socketpair(domain.rawValue, type.rawValue, `protocol`.rawValue, fds)
        }.map { _ in (SocketDescriptor(rawValue: fds[0]), SocketDescriptor(rawValue: fds[1])) }
      }
    }
  }

  /// Closes the socket.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public func close() throws {
    try _close().get()
  }

  @usableFromInline
  internal func _close() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_close(self.rawValue)
    }
  }

  /// Shuts down part of a full-duplex connection.
  ///
  /// - Parameter how: Which parts of the connection to shut down.
  ///
  /// The corresponding C function is `shutdown`.
  @_alwaysEmitIntoClient
  public func shutdown(_ how: ShutdownKind) throws {
    try _shutdown(how).get()
  }

  @usableFromInline
  internal func _shutdown(_ how: ShutdownKind) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
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
  public func bind(to address: SocketAddress) throws {
    try _bind(to: address).get()
  }

  @usableFromInline
  internal func _bind(to address: SocketAddress) -> Result<(), Errno> {
    address.withUnsafePointer { addr, len in
      nothingOrErrno(retryOnInterrupt: false) {
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
  public func listen(backlog: Int) throws {
    try _listen(backlog: backlog).get()
  }

  @usableFromInline
  internal func _listen(backlog: Int) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_listen(self.rawValue, CInt(backlog))
    }
  }

  /// Accepts a connection on the socket.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// The corresponding C function is `accept`.
  @_alwaysEmitIntoClient
  public func accept(retryOnInterrupt: Bool = true) throws -> SocketDescriptor {
    try _accept(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(retryOnInterrupt: Bool) -> Result<SocketDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_accept(self.rawValue, nil, nil)
    }.map(SocketDescriptor.init(rawValue:))
  }

  /// Accepts a connection and returns the client's address.
  ///
  /// - Parameters:
  ///   - client: A socket address buffer to receive the client's address.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// The corresponding C function is `accept`.
  @_alwaysEmitIntoClient
  public func accept(
    client: inout SocketAddress,
    retryOnInterrupt: Bool = true
  ) throws -> SocketDescriptor {
    try _accept(client: &client, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    client: inout SocketAddress,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Errno> {
    client._withUnsafeMutablePointer { addr, len in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_accept(self.rawValue, addr, &len)
      }.map(SocketDescriptor.init(rawValue:))
    }
  }

  /// Initiates a connection on the socket.
  ///
  /// - Parameter address: The address to connect to.
  ///
  /// The corresponding C function is `connect`.
  @_alwaysEmitIntoClient
  public func connect(to address: SocketAddress) throws {
    try _connect(to: address).get()
  }

  @usableFromInline
  internal func _connect(to address: SocketAddress) -> Result<(), Errno> {
    address.withUnsafePointer { addr, len in
      nothingOrErrno(retryOnInterrupt: false) {
        system_connect(self.rawValue, addr, len)
      }
    }
  }
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
  /// The corresponding C function is `send`.
  @_alwaysEmitIntoClient
  public func send(
    _ buffer: UnsafeRawBufferPointer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _send(buffer, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _send(
    _ buffer: UnsafeRawBufferPointer,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_send(self.rawValue, buffer.baseAddress, buffer.count, flags.rawValue)
    }
  }

  /// Receives data from the socket.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes received.
  ///
  /// The corresponding C function is `recv`.
  @_alwaysEmitIntoClient
  public func receive(
    into buffer: UnsafeMutableRawBufferPointer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _receive(into: buffer, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receive(
    into buffer: UnsafeMutableRawBufferPointer,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_recv(self.rawValue, buffer.baseAddress, buffer.count, flags.rawValue)
    }
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
  ) throws -> Int {
    try _send(buffer, to: address, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _send(
    _ buffer: UnsafeRawBufferPointer,
    to address: SocketAddress,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    address.withUnsafePointer { addr, addrlen in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_sendto(
          self.rawValue,
          buffer.baseAddress,
          buffer.count,
          flags.rawValue,
          addr,
          addrlen
        )
      }
    }
  }

  /// Receives data and returns the sender's address.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - sender: A buffer to receive the sender's address.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted.
  /// - Returns: The number of bytes received.
  ///
  /// The corresponding C function is `recvfrom`.
  @_alwaysEmitIntoClient
  public func receive(
    into buffer: UnsafeMutableRawBufferPointer,
    sender: inout SocketAddress,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _receive(into: buffer, sender: &sender, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receive(
    into buffer: UnsafeMutableRawBufferPointer,
    sender: inout SocketAddress,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    sender._withUnsafeMutablePointer { addr, len in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_recvfrom(
          self.rawValue,
          buffer.baseAddress,
          buffer.count,
          flags.rawValue,
          addr,
          &len
        )
      }
    }
  }
}

// MARK: - Message-based Send and Receive

@available(System 199, *)
extension SocketDescriptor {
  /// Sends a message with optional ancillary data.
  ///
  /// - Parameters:
  ///   - data: The data to send.
  ///   - ancillaryMessages: Ancillary (control) messages to send with the data,
  ///     such as file descriptors, or `nil` for none.
  ///   - address: The destination address, for a socket that isn't connected,
  ///     or `nil`.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes sent.
  ///
  /// The corresponding C function is `sendmsg`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func sendMessage(
    _ data: RawSpan,
    ancillaryMessages: AncillaryMessageBuffer? = nil,
    to address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try data.withUnsafeBytes { bytes throws(Errno) -> Int in
      try _sendMessage(
        bytes,
        ancillaryMessages: ancillaryMessages,
        to: address,
        flags: flags,
        retryOnInterrupt: retryOnInterrupt
      ).get()
    }
  }

  @usableFromInline
  internal func _sendMessage(
    _ buffer: UnsafeRawBufferPointer,
    ancillaryMessages: AncillaryMessageBuffer?,
    to address: SocketAddress?,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    var iov = CInterop.IOVec(
      iov_base: UnsafeMutableRawPointer(mutating: buffer.baseAddress),
      iov_len: buffer.count
    )
    // The header's pointers are valid only inside these closures,
    // so the header is built, and sent, in the innermost one.
    return withUnsafeMutablePointer(to: &iov) { iov in
      _withControlBytes(of: ancillaryMessages) { control in
        _withAddress(address) { name, nameLength in
          var header = CInterop.MsgHdr()
          header.msg_name = UnsafeMutableRawPointer(mutating: name)
          header.msg_namelen = nameLength
          header.msg_iov = iov
          header.msg_iovlen = 1
          header.msg_control = UnsafeMutableRawPointer(mutating: control.baseAddress)
          header.msg_controllen = .init(control.count)
          return _sendMessage(header, flags: flags, retryOnInterrupt: retryOnInterrupt)
        }
      }
    }
  }

  /// Receives a message and its ancillary data.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - ancillaryMessages: The buffer to receive ancillary (control) messages
  ///     into, which this method empties first.
  ///     It receives at most its ``AncillaryMessageBuffer/capacity``;
  ///     use ``AncillaryMessageBuffer/init(minimumCapacity:)``
  ///     or ``AncillaryMessageBuffer/reserveCapacity(_:)`` to make room.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes received, and flags that describe the
  ///   message, such as ``MessageFlags/controlTruncated`` if some ancillary
  ///   messages didn't fit.
  ///
  /// This method receives into the uninitialized part of `buffer`,
  /// after any bytes already there,
  /// and adds the number of bytes received to its initialized count.
  ///
  /// If some ancillary messages don't fit,
  /// the system discards them, and any file descriptors they pass.
  /// It reports that with ``MessageFlags/controlTruncated``,
  /// except that on Darwin a buffer with no capacity,
  /// which passes `recvmsg` no control buffer, gets no flag.
  ///
  /// The corresponding C function is `recvmsg`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func receiveMessage(
    into buffer: inout OutputRawSpan,
    ancillaryMessages: inout AncillaryMessageBuffer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (byteCount: Int, flags: MessageFlags) {
    try buffer.withUnsafeMutableBytes { buf, count throws(Errno) in
      let received = try _receiveMessage(
        into: UnsafeMutableRawBufferPointer(rebasing: buf[count...]),
        ancillaryMessages: &ancillaryMessages,
        sender: nil,
        flags: flags,
        retryOnInterrupt: retryOnInterrupt
      ).get()
      count += received.byteCount
      return received
    }
  }

  /// Receives a message, its ancillary data, and the address it was sent from.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to receive data into.
  ///   - ancillaryMessages: The buffer to receive ancillary (control) messages
  ///     into, which this method empties first.
  ///     It receives at most its ``AncillaryMessageBuffer/capacity``;
  ///     use ``AncillaryMessageBuffer/init(minimumCapacity:)``
  ///     or ``AncillaryMessageBuffer/reserveCapacity(_:)`` to make room.
  ///   - sender: The address to set to the sender's.
  ///     A connected stream socket's messages have no sender,
  ///     and leave it empty.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes received, and flags that describe the
  ///   message, such as ``MessageFlags/dataTruncated`` if a datagram
  ///   didn't fit in `buffer`.
  ///
  /// This method receives into the uninitialized part of `buffer`,
  /// after any bytes already there,
  /// and adds the number of bytes received to its initialized count.
  ///
  /// The corresponding C function is `recvmsg`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func receiveMessage(
    into buffer: inout OutputRawSpan,
    ancillaryMessages: inout AncillaryMessageBuffer,
    sender: inout SocketAddress,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (byteCount: Int, flags: MessageFlags) {
    try buffer.withUnsafeMutableBytes { buf, count throws(Errno) in
      let received = try withUnsafeMutablePointer(to: &sender) { sender in
        _receiveMessage(
          into: UnsafeMutableRawBufferPointer(rebasing: buf[count...]),
          ancillaryMessages: &ancillaryMessages,
          sender: sender,
          flags: flags,
          retryOnInterrupt: retryOnInterrupt
        )
      }.get()
      count += received.byteCount
      return received
    }
  }

  @usableFromInline
  internal func _receiveMessage(
    into buffer: UnsafeMutableRawBufferPointer,
    ancillaryMessages: inout AncillaryMessageBuffer,
    sender: UnsafeMutablePointer<SocketAddress>?,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<(byteCount: Int, flags: MessageFlags), Errno> {
    var iov = CInterop.IOVec(iov_base: buffer.baseAddress, iov_len: buffer.count)
    return withUnsafeMutablePointer(to: &iov) { iov in
      ancillaryMessages._withMutableCInterop(entireCapacity: true) { control, controlLength in
        func receive(
          _ name: UnsafeMutablePointer<CInterop.SockAddr>?,
          _ nameLength: inout CInterop.SockLen
        ) -> Result<(byteCount: Int, flags: MessageFlags), Errno> {
          var header = CInterop.MsgHdr()
          header.msg_name = UnsafeMutableRawPointer(name)
          header.msg_namelen = nameLength
          header.msg_iov = iov
          header.msg_iovlen = 1
          header.msg_control = control
          header.msg_controllen = .init(controlLength)
          let result = _receiveMessage(&header, flags: flags, retryOnInterrupt: retryOnInterrupt)
          // recvmsg reports the lengths of the address and the ancillary
          // messages it received in the header. A failed call received none.
          let succeeded = (try? result.get()) != nil
          nameLength = succeeded ? header.msg_namelen : 0
          controlLength = succeeded ? CInterop.SockLen(header.msg_controllen) : 0
          return result.map { (byteCount: $0, flags: MessageFlags(rawValue: header.msg_flags)) }
        }
        guard let sender else {
          var noName: CInterop.SockLen = 0
          return receive(nil, &noName)
        }
        return sender.pointee._withUnsafeMutablePointer { name, nameLength in
          receive(name, &nameLength)
        }
      }
    }
  }

  /// Sends the message that a message header describes.
  ///
  /// The header lists the data to send, in its I/O vectors,
  /// and may give a destination address and ancillary messages.
  /// Its pointers must be valid for the duration of the call.
  /// This is the form to use to gather data from several buffers,
  /// or to reuse message headers and buffers you manage.
  ///
  /// - Parameters:
  ///   - header: The message header.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes sent.
  ///
  /// The corresponding C function is `sendmsg`.
  @_alwaysEmitIntoClient
  public func sendMessage(
    _ header: CInterop.MsgHdr,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _sendMessage(header, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _sendMessage(
    _ header: CInterop.MsgHdr,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    withUnsafePointer(to: header) { header in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_sendmsg(self.rawValue, header, flags.rawValue)
      }
    }
  }

  /// Receives a message into the buffers that a message header describes.
  ///
  /// The header lists the buffers to receive the data into,
  /// in its I/O vectors, and may give buffers for the sender's address
  /// and for ancillary messages, with their lengths.
  /// Its pointers must be valid for the duration of the call.
  /// This is the form to use to scatter data into several buffers,
  /// or to reuse buffers you manage.
  ///
  /// On return, the header describes what the call received:
  /// its `msg_namelen` is the length of the sender's address,
  /// its `msg_controllen` the length of the ancillary messages,
  /// which `UnsafeAncillaryMessages(header)` reads,
  /// and its `msg_flags` are flags such as ``MessageFlags/dataTruncated``.
  ///
  /// - Parameters:
  ///   - header: The message header.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes received.
  ///
  /// The corresponding C function is `recvmsg`.
  @_alwaysEmitIntoClient
  public func receiveMessage(
    _ header: inout CInterop.MsgHdr,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _receiveMessage(&header, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receiveMessage(
    _ header: inout CInterop.MsgHdr,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    withUnsafeMutablePointer(to: &header) { header in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_recvmsg(self.rawValue, header, flags.rawValue)
      }
    }
  }
}

/// Calls `body` with the bytes of the ancillary messages,
/// or with an empty buffer if there are none.
@available(System 199, *)
internal func _withControlBytes<R>(
  of messages: SocketDescriptor.AncillaryMessageBuffer?,
  _ body: (UnsafeRawBufferPointer) throws -> R
) rethrows -> R {
  guard let messages else { return try body(UnsafeRawBufferPointer(start: nil, count: 0)) }
  return try messages._withUnsafeBytes(body)
}

/// Calls `body` with a pointer to the address and its length,
/// or with `nil` and 0 if there's no address.
@available(System 199, *)
internal func _withAddress<R>(
  _ address: SocketAddress?,
  _ body: (UnsafePointer<CInterop.SockAddr>?, CInterop.SockLen) throws -> R
) rethrows -> R {
  guard let address else { return try body(nil, 0) }
  return try address.withUnsafePointer(body)
}

// MARK: - Socket Information

@available(System 199, *)
extension SocketDescriptor {
  /// Gets the local address of the socket.
  ///
  /// - Parameter address: A buffer to receive the local address.
  ///
  /// The corresponding C function is `getsockname`.
  @_alwaysEmitIntoClient
  public func getLocalAddress(into address: inout SocketAddress) throws {
    try _getLocalAddress(into: &address).get()
  }

  @usableFromInline
  internal func _getLocalAddress(into address: inout SocketAddress) -> Result<(), Errno> {
    address._withUnsafeMutablePointer { addr, len in
      nothingOrErrno(retryOnInterrupt: false) {
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
  public func getPeerAddress(into address: inout SocketAddress) throws {
    try _getPeerAddress(into: &address).get()
  }

  @usableFromInline
  internal func _getPeerAddress(into address: inout SocketAddress) -> Result<(), Errno> {
    address._withUnsafeMutablePointer { addr, len in
      nothingOrErrno(retryOnInterrupt: false) {
        system_getpeername(self.rawValue, addr, &len)
      }
    }
  }
}

#endif // !os(WASI)
