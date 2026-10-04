/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
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

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

@available(System 199, *)
extension CInterop {
  /// A message header, and the number of bytes sent or received with it:
  /// an element of the vectors that `sendmmsg` and `recvmmsg` take.
  ///
  /// This is a Swift structure with the C structure's layout,
  /// since glibc and Musl declare `struct mmsghdr` only with `_GNU_SOURCE`,
  /// and Darwin not at all.
  /// Its fields have the C names.
  ///
  /// The corresponding C type is `struct mmsghdr`.
  @frozen
  public struct MMsgHdr {
    /// The message's header.
    ///
    /// The corresponding C field is `msg_hdr`.
    public var msg_hdr: MsgHdr

    /// The number of bytes sent or received with the message,
    /// which `sendmmsg` and `recvmmsg` set.
    ///
    /// The corresponding C field is `msg_len`.
    public var msg_len: CUnsignedInt

    /// Creates an element from a message header.
    @_alwaysEmitIntoClient
    public init(msg_hdr: MsgHdr, msg_len: CUnsignedInt = 0) {
      self.msg_hdr = msg_hdr
      self.msg_len = msg_len
    }
  }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Sends several messages with one call.
  ///
  /// - Parameters:
  ///   - messages: The messages to send, in order.
  ///     Each message header's pointers must be valid for the call's
  ///     duration, as for ``sendMessage(_:flags:retryOnInterrupt:)``;
  ///     the call sets each sent message's `msg_len`
  ///     to the number of bytes sent.
  ///   - flags: Message flags for every message.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before sending anything.
  ///     The default is `true`.
  /// - Returns: The number of messages sent, from the first,
  ///   which is fewer than `messages.count`
  ///   when a message after the first can't be sent,
  ///   for example because a nonblocking socket's buffer is full.
  ///   Sending the rest reports that message's error.
  ///   No messages return 0 without a call.
  ///
  /// The corresponding C function is `sendmmsg`.
  /// Darwin has no `sendmmsg`, so there this method calls `sendmsg`
  /// for each message in turn,
  /// throws the first message's error, and stops short at a later one's.
  @_alwaysEmitIntoClient
  public func sendMessages(
    _ messages: UnsafeMutableBufferPointer<CInterop.MMsgHdr>,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _sendMessages(messages, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _sendMessages(
    _ messages: UnsafeMutableBufferPointer<CInterop.MMsgHdr>,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    guard !messages.isEmpty else { return .success(0) }
    #if SYSTEM_PACKAGE_DARWIN
    return _eachMessage(messages, retryOnInterrupt: retryOnInterrupt) { header in
      system_sendmsg(self.rawValue, header, flags.rawValue)
    }
    #else
    let count = CUnsignedInt(clamping: messages.count)
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_sendmmsg(self.rawValue, UnsafeMutableRawPointer(messages.baseAddress), count, flags.rawValue)
    }.map(Int.init)
    #endif
  }

  /// Receives several messages with one call.
  ///
  /// - Parameters:
  ///   - messages: The headers to receive the messages into, in order.
  ///     Each message header describes the buffers for one message,
  ///     as for ``receiveMessage(_:flags:retryOnInterrupt:)``;
  ///     the call updates each received message's header,
  ///     as `recvmsg` does, and sets its `msg_len`
  ///     to the number of bytes received.
  ///   - flags: Message flags for every message.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before receiving anything.
  ///     The default is `true`.
  /// - Returns: The number of messages received, from the first.
  ///   On a nonblocking socket, that's as many as were waiting.
  ///   A blocking socket waits for `messages.count` of them,
  ///   unless `flags` includes Linux's `MSG_WAITFORONE`.
  ///   An error after the first message ends the call short,
  ///   and the next call reports it, if it persists.
  ///   No messages return 0 without a call.
  ///
  /// There's no timeout parameter: `recvmmsg`'s is checked only after each
  /// message arrives, so it can't end a wait for the first one,
  /// as its Linux manual page's bugs section says.
  /// Use ``setReceiveTimeout(_:)`` or a nonblocking socket.
  ///
  /// The corresponding C function is `recvmmsg`.
  /// Darwin has no `recvmmsg`, so there this method calls `recvmsg`
  /// for each message in turn,
  /// throws the first message's error, and stops short at a later one's.
  @_alwaysEmitIntoClient
  public func receiveMessages(
    _ messages: UnsafeMutableBufferPointer<CInterop.MMsgHdr>,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _receiveMessages(messages, flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _receiveMessages(
    _ messages: UnsafeMutableBufferPointer<CInterop.MMsgHdr>,
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    guard !messages.isEmpty else { return .success(0) }
    #if SYSTEM_PACKAGE_DARWIN
    return _eachMessage(messages, retryOnInterrupt: retryOnInterrupt) { header in
      system_recvmsg(self.rawValue, header, flags.rawValue)
    }
    #else
    let count = CUnsignedInt(clamping: messages.count)
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_recvmmsg(self.rawValue, UnsafeMutableRawPointer(messages.baseAddress), count, flags.rawValue)
    }.map(Int.init)
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Calls `transfer` for each message's header in turn, recording each
  /// result as the message's length, as sendmmsg and recvmmsg do: the first
  /// message's error is the result, and a later one's ends the loop short.
  internal func _eachMessage(
    _ messages: UnsafeMutableBufferPointer<CInterop.MMsgHdr>,
    retryOnInterrupt: Bool,
    _ transfer: (UnsafeMutablePointer<CInterop.MsgHdr>) -> Int
  ) -> Result<Int, Errno> {
    for index in messages.indices {
      let element = messages.baseAddress! + index
      let header = element.pointer(to: \.msg_hdr)!
      // Retry an interruption only before anything is transferred.
      let result = valueOrErrno(retryOnInterrupt: retryOnInterrupt && index == 0) {
        transfer(header)
      }
      switch result {
      case .success(let length):
        element.pointee.msg_len = CUnsignedInt(truncatingIfNeeded: length)
      case .failure(let error):
        return index == 0 ? .failure(error) : .success(index)
      }
    }
    return .success(messages.count)
  }
  #endif
}

// MARK: - Batches of Buffers

@available(System 199, *)
extension SocketDescriptor {
  /// A message that ``receiveMessages(into:flags:retryOnInterrupt:)``
  /// received.
  @frozen
  public struct ReceivedMessage: Sendable {
    /// The number of bytes received into the message's buffer.
    public var byteCount: Int

    /// The address the message came from,
    /// which is empty for a connected stream socket's messages.
    public var sender: SocketAddress

    /// Flags that describe the message,
    /// such as ``MessageFlags/dataTruncated`` if a datagram didn't fit
    /// in its buffer.
    public var flags: MessageFlags

    /// Creates a received message's description.
    @_alwaysEmitIntoClient
    public init(byteCount: Int, sender: SocketAddress, flags: MessageFlags) {
      self.byteCount = byteCount
      self.sender = sender
      self.flags = flags
    }
  }

  /// Sends several messages with one call, each from a buffer of its own.
  ///
  ///     let sent = try socket.sendMessages([header, body], to: destination)
  ///
  /// - Parameters:
  ///   - messages: The messages' bytes, in order, one buffer a message.
  ///   - address: The destination of every message,
  ///     for a socket that isn't connected,
  ///     or `nil`, the default, for a connected socket.
  ///   - flags: Message flags for every message.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before sending anything.
  ///     The default is `true`.
  /// - Returns: The number of messages sent, from the first,
  ///   as for the form that takes `CInterop.MMsgHdr`s.
  ///
  /// This method builds the message headers itself,
  /// so it needs nothing from the C library.
  /// To send ancillary messages too, or to reuse headers,
  /// use the form that takes `CInterop.MMsgHdr`s.
  ///
  /// The corresponding C function is `sendmmsg`.
  /// Darwin has no `sendmmsg`, so there this method calls `sendmsg`
  /// for each message in turn.
  @_alwaysEmitIntoClient
  public func sendMessages(
    _ messages: some Collection<UnsafeRawBufferPointer>,
    to address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _sendBuffers(
      Array(messages.lazy.map { ($0, address) }),
      flags: flags, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Sends several messages with one call, each from a buffer of its own
  /// and to an address of its own.
  ///
  ///     let sent = try socket.sendMessages([(reply, client), (other, peer)])
  ///
  /// - Parameters:
  ///   - messages: The messages, in order: each one's bytes and destination.
  ///   - flags: Message flags for every message.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before sending anything.
  ///     The default is `true`.
  /// - Returns: The number of messages sent, from the first.
  ///
  /// The corresponding C function is `sendmmsg`.
  /// Darwin has no `sendmmsg`, so there this method calls `sendmsg`
  /// for each message in turn.
  @_alwaysEmitIntoClient
  public func sendMessages(
    _ messages: some Collection<(UnsafeRawBufferPointer, SocketAddress)>,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _sendBuffers(
      Array(messages.lazy.map { ($0.0, Optional($0.1)) }),
      flags: flags, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Receives several messages with one call, each into a buffer of its own.
  ///
  ///     let received = try socket.receiveMessages(into: buffers)
  ///     for (message, buffer) in zip(received, buffers) {
  ///       handle(buffer.prefix(message.byteCount), from: message.sender)
  ///     }
  ///
  /// - Parameters:
  ///   - buffers: The buffers to receive the messages into, in order,
  ///     one a message.
  ///   - flags: Message flags for every message.
  ///   - retryOnInterrupt: Whether to retry the call
  ///     if it throws ``Errno/interrupted`` before receiving anything.
  ///     The default is `true`.
  /// - Returns: The messages received, in the order of the buffers
  ///   they were received into: as many as were waiting,
  ///   on a nonblocking socket,
  ///   as for the form that takes `CInterop.MMsgHdr`s.
  ///
  /// This method builds the message headers itself,
  /// so it needs nothing from the C library.
  /// To receive ancillary messages too, or to reuse headers,
  /// use the form that takes `CInterop.MMsgHdr`s.
  ///
  /// The corresponding C function is `recvmmsg`.
  /// Darwin has no `recvmmsg`, so there this method calls `recvmsg`
  /// for each message in turn.
  @_alwaysEmitIntoClient
  public func receiveMessages(
    into buffers: some Collection<UnsafeMutableRawBufferPointer>,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> [ReceivedMessage] {
    try _receiveBuffers(Array(buffers), flags: flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _sendBuffers(
    _ messages: [(UnsafeRawBufferPointer, SocketAddress?)],
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    let count = messages.count
    guard count > 0 else { return .success(0) }
    return withUnsafeTemporaryAllocation(of: CInterop.IOVec.self, capacity: count) { vectors in
      withUnsafeTemporaryAllocation(of: SocketAddress.self, capacity: count) { addresses in
        withUnsafeTemporaryAllocation(of: CInterop.MMsgHdr.self, capacity: count) { headers in
          for (i, (bytes, address)) in messages.enumerated() {
            vectors.initializeElement(at: i, to: CInterop.IOVec(
              iov_base: UnsafeMutableRawPointer(mutating: bytes.baseAddress),
              iov_len: bytes.count))
            addresses.initializeElement(at: i, to: address ?? SocketAddress())
            var header = CInterop.MsgHdr()
            header.msg_iov = vectors.baseAddress! + i
            header.msg_iovlen = 1
            if let address {
              header.msg_name = UnsafeMutableRawPointer(
                (addresses.baseAddress! + i).pointer(to: \._storage)!)
              header.msg_namelen = address._length
            }
            headers.initializeElement(at: i, to: CInterop.MMsgHdr(msg_hdr: header))
          }
          // The elements are all trivial, so they needn't be deinitialized.
          return _sendMessages(headers, flags: flags, retryOnInterrupt: retryOnInterrupt)
        }
      }
    }
  }

  @usableFromInline
  internal func _receiveBuffers(
    _ buffers: [UnsafeMutableRawBufferPointer],
    flags: MessageFlags,
    retryOnInterrupt: Bool
  ) -> Result<[ReceivedMessage], Errno> {
    let count = buffers.count
    guard count > 0 else { return .success([]) }
    let capacity = CInterop.SockLen(MemoryLayout<sockaddr_storage>.size)
    return withUnsafeTemporaryAllocation(of: CInterop.IOVec.self, capacity: count) { vectors in
      withUnsafeTemporaryAllocation(of: SocketAddress.self, capacity: count) { addresses in
        withUnsafeTemporaryAllocation(of: CInterop.MMsgHdr.self, capacity: count) { headers in
          for (i, buffer) in buffers.enumerated() {
            vectors.initializeElement(at: i, to: CInterop.IOVec(
              iov_base: buffer.baseAddress, iov_len: buffer.count))
            addresses.initializeElement(at: i, to: SocketAddress())
            var header = CInterop.MsgHdr()
            header.msg_iov = vectors.baseAddress! + i
            header.msg_iovlen = 1
            header.msg_name = UnsafeMutableRawPointer(
              (addresses.baseAddress! + i).pointer(to: \._storage)!)
            header.msg_namelen = capacity
            headers.initializeElement(at: i, to: CInterop.MMsgHdr(msg_hdr: header))
          }
          return _receiveMessages(headers, flags: flags, retryOnInterrupt: retryOnInterrupt)
            .map { received in
              (0 ..< received).map { i in
                var sender = addresses[i]
                sender._length = min(headers[i].msg_hdr.msg_namelen, capacity)
                return ReceivedMessage(
                  byteCount: Int(headers[i].msg_len),
                  sender: sender,
                  flags: MessageFlags(rawValue: headers[i].msg_hdr.msg_flags))
              }
            }
        }
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#endif // !os(WASI)
