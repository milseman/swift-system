/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

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

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
