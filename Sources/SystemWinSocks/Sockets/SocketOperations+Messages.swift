/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Message-based Send and Receive

// WSASendMsg and WSARecvMsg, Winsock's sendmsg and recvmsg, are extension
// functions, which System looks up once per process (WinsockExtensions.swift).
// Windows' own providers support them on datagram and raw sockets.
// WSARecvMsg takes its flags in the header, and reports a datagram that
// doesn't fit as WSAEMSGSIZE, after filling the buffers, where POSIX's
// recvmsg returns with MSG_TRUNC.

@available(System 199, *)
extension SocketDescriptor {
  /// Sends a message with optional ancillary data.
  ///
  /// - Parameters:
  ///   - data: The data to send.
  ///   - ancillaryMessages: Ancillary (control) messages to send with the data,
  ///     or `nil` for none.
  ///   - address: The destination address, for a socket that isn't connected,
  ///     or `nil`.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes sent.
  ///
  /// Windows' own providers support this on datagram and raw sockets.
  ///
  /// The corresponding C function is `WSASendMsg`, Winsock's `sendmsg`.
  @_alwaysEmitIntoClient
  public func sendMessage(
    _ data: RawSpan,
    ancillaryMessages: AncillaryMessageBuffer? = nil,
    to address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try data.withUnsafeBytes { bytes throws(Win32.Error) -> Int in
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
  ) -> Result<Int, Win32.Error> {
    guard let length = ULONG(exactly: buffer.count) else { return .failure(.messageTooLong) }
    var vector = CInterop.IOVec(
      base: UnsafeMutableRawPointer(mutating: buffer.baseAddress), length: Int(length))
    // The header's pointers are valid only inside these closures,
    // so the header is built, and sent, in the innermost one.
    return withUnsafeMutablePointer(to: &vector) { vector in
      _withControlBytes(of: ancillaryMessages) { control in
        _withAddress(address) { name, nameLength in
          let header = CInterop.MsgHdr(
            name: UnsafeMutableRawPointer(mutating: name),
            nameLength: Int(nameLength),
            vectors: vector,
            vectorCount: 1,
            control: UnsafeMutableRawPointer(mutating: control.baseAddress),
            controlLength: control.count)
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
  /// Windows' own providers support this on datagram and raw sockets. A
  /// datagram that doesn't fit fills the buffer and throws
  /// ``Win32/Error/messageTooLong``, where POSIX returns its count with
  /// ``MessageFlags/dataTruncated``.
  ///
  /// The corresponding C function is `WSARecvMsg`, Winsock's `recvmsg`.
  @_alwaysEmitIntoClient
  public func receiveMessage(
    into buffer: inout OutputRawSpan,
    ancillaryMessages: inout AncillaryMessageBuffer,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> (byteCount: Int, flags: MessageFlags) {
    try buffer.withUnsafeMutableBytes { buf, count throws(Win32.Error) in
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
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes received, and flags that describe the
  ///   message, such as ``MessageFlags/controlTruncated``.
  ///
  /// This method receives into the uninitialized part of `buffer`,
  /// after any bytes already there,
  /// and adds the number of bytes received to its initialized count.
  /// As with ``receiveMessage(into:ancillaryMessages:flags:retryOnInterrupt:)``,
  /// a datagram that doesn't fit throws ``Win32/Error/messageTooLong``.
  ///
  /// The corresponding C function is `WSARecvMsg`, Winsock's `recvmsg`.
  @_alwaysEmitIntoClient
  public func receiveMessage(
    into buffer: inout OutputRawSpan,
    ancillaryMessages: inout AncillaryMessageBuffer,
    sender: inout SocketAddress,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> (byteCount: Int, flags: MessageFlags) {
    try buffer.withUnsafeMutableBytes { buf, count throws(Win32.Error) in
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
  ) -> Result<(byteCount: Int, flags: MessageFlags), Win32.Error> {
    var vector = CInterop.IOVec(base: buffer.baseAddress, length: Int(ULONG(clamping: buffer.count)))
    return withUnsafeMutablePointer(to: &vector) { vector in
      ancillaryMessages._withMutableCInterop(entireCapacity: true) { control, controlLength in
        func receive(
          _ name: UnsafeMutablePointer<CInterop.SockAddr>?,
          _ nameLength: inout CInterop.SockLen
        ) -> Result<(byteCount: Int, flags: MessageFlags), Win32.Error> {
          var header = CInterop.MsgHdr(
            name: UnsafeMutableRawPointer(name),
            nameLength: Int(nameLength),
            vectors: vector,
            vectorCount: 1,
            control: control,
            controlLength: Int(controlLength))
          let result = _receiveMessage(&header, flags: flags, retryOnInterrupt: retryOnInterrupt)
          // WSARecvMsg reports the lengths of the address and the ancillary
          // messages it received in the header. A failed call received none.
          let succeeded = (try? result.get()) != nil
          nameLength = succeeded ? CInterop.SockLen(header.nameLength) : 0
          controlLength = succeeded ? CInterop.SockLen(header.controlLength) : 0
          return result.map { (byteCount: $0, flags: header.flags) }
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
  /// The corresponding C function is `WSASendMsg`, Winsock's `sendmsg`.
  @_alwaysEmitIntoClient
  public func sendMessage(
    _ header: CInterop.MsgHdr,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _sendMessage(header, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _sendMessage(
    _ header: CInterop.MsgHdr,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    _winsockMessageFunctions.flatMap { functions in
      // WSASendMsg doesn't write to the header, but takes it as mutable.
      var header = header
      var sent: DWORD = 0
      return valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        functions.sendMessage(
          self.rawValue, &header, DWORD(bitPattern: flags.rawValue), &sent, nil, nil)
      }.map { _ in Int(sent) }
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
  /// its `namelen` is the length of the sender's address,
  /// its `Control.len` the length of the ancillary messages,
  /// which `UnsafeAncillaryMessages(header)` reads,
  /// and its `dwFlags` are flags such as ``MessageFlags/controlTruncated``.
  /// Winsock reads its receive flags from `dwFlags` too:
  /// this method sets them from `flags`.
  ///
  /// - Parameters:
  ///   - header: The message header.
  ///   - flags: Message flags.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The number of bytes received.
  ///
  /// The corresponding C function is `WSARecvMsg`, Winsock's `recvmsg`.
  @_alwaysEmitIntoClient
  public func receiveMessage(
    _ header: inout CInterop.MsgHdr,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    try _receiveMessage(&header, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receiveMessage(
    _ header: inout CInterop.MsgHdr,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    guard case .success(let functions) = _winsockMessageFunctions else {
      return _winsockMessageFunctions.map { _ in 0 }
    }
    var received: DWORD = 0
    return withUnsafeMutablePointer(to: &header) { header in
      valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        // A retry starts from the caller's flags again.
        header.pointee.flags = flags
        return functions.receiveMessage(self.rawValue, header, &received, nil, nil)
      }
    }.map { _ in Int(received) }
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

#endif // os(Windows)
