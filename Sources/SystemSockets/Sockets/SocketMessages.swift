/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
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

// MARK: - Control message layout

// The arithmetic behind the CMSG_* macros, which Swift can't import.
//
// A control buffer is a sequence of messages. Each one is a cmsghdr, then
// its payload. Both start at an offset from the start of the buffer that is
// a multiple of the platform's alignment: 4 bytes on Darwin
// (__DARWIN_ALIGN32), sizeof(size_t) on Linux (CMSG_ALIGN), and sizeof(long)
// on the BSDs (_ALIGN). A header's cmsg_len counts the header, the padding
// after it and the payload, but not the padding before the next message.
@usableFromInline
internal enum _ControlMessageLayout {
  @inlinable
  internal static var alignment: Int {
    #if SYSTEM_PACKAGE_DARWIN
    MemoryLayout<UInt32>.size
    #else
    MemoryLayout<Int>.size
    #endif
  }

  @inlinable
  internal static func align(_ length: Int) -> Int {
    (length + alignment - 1) & ~(alignment - 1)
  }

  /// `sizeof(struct cmsghdr)`.
  @inlinable
  internal static var headerSize: Int { MemoryLayout<CInterop.CMsgHdr>.size }

  /// How far a message's payload is from its header: `CMSG_DATA(cmsg) - cmsg`.
  ///
  /// This is `headerSize` on Darwin and Linux, but on FreeBSD, where the
  /// header is 12 bytes, the payload starts 16 bytes in.
  @inlinable
  internal static var payloadOffset: Int { align(headerSize) }

  /// `CMSG_SPACE(payloadSize)`.
  @inlinable
  internal static func space(_ payloadSize: Int) -> Int {
    payloadOffset + align(payloadSize)
  }

  /// `CMSG_LEN(payloadSize)`.
  @inlinable
  internal static func length(_ payloadSize: Int) -> Int {
    payloadOffset + payloadSize
  }

  /// The `cmsg_len` of the message at `offset` in `bytes`, or `nil` if no
  /// valid message starts there.
  ///
  /// A valid message's header fits in the buffer, its length covers at least
  /// the header and its padding, and the whole message fits in the buffer.
  /// Checking all three, where the C macros check fewer, means that corrupt
  /// or truncated data ends the collection rather than leading outside the
  /// buffer or into a loop.
  @inlinable
  internal static func messageLength(
    at offset: Int, in bytes: UnsafeRawBufferPointer
  ) -> Int? {
    guard offset >= 0, bytes.count - offset >= headerSize else { return nil }
    let header = bytes.loadUnaligned(fromByteOffset: offset, as: CInterop.CMsgHdr.self)
    // cmsg_len is a socklen_t on Darwin and musl, and a size_t on glibc.
    guard let length = Int(exactly: header.cmsg_len),
          length >= payloadOffset, length <= bytes.count - offset
    else { return nil }
    return length
  }

  /// The offset of the first message in `bytes`, or `nil` if there's none.
  ///
  /// This corresponds to the C macro `CMSG_FIRSTHDR`.
  @inlinable
  internal static func firstOffset(in bytes: UnsafeRawBufferPointer) -> Int? {
    messageLength(at: 0, in: bytes) == nil ? nil : 0
  }

  /// The offset of the message after the one at `offset`, whose `cmsg_len`
  /// is `length`, or `nil` if there's none.
  ///
  /// This corresponds to the C macro `CMSG_NXTHDR`.
  @inlinable
  internal static func offset(
    after offset: Int, length: Int, in bytes: UnsafeRawBufferPointer
  ) -> Int? {
    let next = offset + align(length)
    return messageLength(at: next, in: bytes) == nil ? nil : next
  }

  /// The file descriptors in the payload of an `SCM_RIGHTS` message.
  @inlinable
  internal static func fileDescriptors(
    in payload: UnsafeRawBufferPointer
  ) -> [FileDescriptor] {
    let stride = MemoryLayout<CInt>.stride
    return (0 ..< payload.count / stride).map {
      FileDescriptor(rawValue: payload.loadUnaligned(fromByteOffset: $0 * stride, as: CInt.self))
    }
  }
}

// MARK: - Ancillary message buffers

@available(System 199, *)
extension SocketDescriptor {
  /// A reusable collection of variable-sized ancillary messages
  /// sent or received over a socket. These represent protocol control
  /// related messages or other miscellaneous ancillary data.
  ///
  /// Each message has a protocol level, such as ``OptionLevel/socket``,
  /// a type that is specific to that level, such as ``Option/rights``,
  /// and a payload of bytes.
  ///
  /// Corresponds to a buffer of `struct cmsghdr` messages in C, as used
  /// by `sendmsg` and `recvmsg`, laid out as the `CMSG_*` macros
  /// lay them out.
  public struct AncillaryMessageBuffer {
    internal var _buffer: _RawBuffer
    internal var _endOffset: Int

    /// Initialize a new empty ancillary message buffer with no preallocated
    /// storage.
    public init() {
      _buffer = _RawBuffer()
      _endOffset = 0
    }

    /// Initialize a new empty ancillary message buffer of the
    /// specified minimum capacity (in bytes).
    ///
    /// To receive messages, a buffer needs room for them:
    /// use ``space(forPayloadSize:)`` to add up how much.
    public init(minimumCapacity: Int) {
      precondition(minimumCapacity >= 0, "Negative capacity")
      _buffer = _RawBuffer(minimumCapacity: minimumCapacity)
      _endOffset = 0
    }

    /// The number of bytes the buffer can hold without reallocating,
    /// which is how many bytes of messages it can receive.
    public var capacity: Int { _buffer.capacity }

    /// The number of bytes that the messages in the buffer take up,
    /// including the padding between them.
    ///
    /// This is the length of the control buffer that the buffer passes
    /// to `sendmsg`, or that `recvmsg` wrote into it.
    public var byteCount: Int { _endOffset }

    /// Remove all messages currently in this buffer, preserving storage
    /// capacity.
    ///
    /// This invalidates all indices in the collection.
    ///
    /// - Complexity: O(1). Does not reallocate the buffer.
    public mutating func removeAll() {
      _endOffset = 0
    }

    /// Reserve enough storage capacity to hold `minimumCapacity` bytes' worth
    /// of messages without having to reallocate storage.
    ///
    /// This does not invalidate any indices.
    ///
    /// - Complexity: O(max(`minimumCapacity`, `capacity`)), where `capacity` is
    ///     the current storage capacity. This potentially needs to reallocate
    ///     the buffer and copy existing messages.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
      _buffer.ensureUnique(capacity: minimumCapacity)
    }

    /// Append a message with the specified data to the end of this buffer,
    /// resizing it if necessary.
    ///
    /// This does not invalidate any existing indices, but it updates `endIndex`.
    ///
    /// - Complexity: Amortized O(`data.count`), when averaged over multiple
    ///    calls. This method reallocates the buffer if there isn't enough
    ///    capacity or if the storage is shared with another value.
    public mutating func appendMessage(
      level: SocketDescriptor.OptionLevel,
      type: SocketDescriptor.Option,
      bytes: UnsafeRawBufferPointer
    ) {
      appendMessage(
        level: level,
        type: type,
        unsafeUninitializedCapacity: bytes.count
      ) { buffer in
        assert(buffer.count >= bytes.count)
        if bytes.count > 0 {
          buffer.baseAddress!.copyMemory(
            from: bytes.baseAddress!,
            byteCount: bytes.count)
        }
        return bytes.count
      }
    }

    /// Append a message with the specified data to the end of this buffer,
    /// resizing it if necessary.
    ///
    /// This does not invalidate any existing indices, but it updates `endIndex`.
    ///
    /// - Complexity: Amortized O(`data.byteCount`), when averaged over
    ///    multiple calls. This method reallocates the buffer if there isn't
    ///    enough capacity or if the storage is shared with another value.
    @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
    public mutating func appendMessage(
      level: SocketDescriptor.OptionLevel,
      type: SocketDescriptor.Option,
      bytes: RawSpan
    ) {
      bytes.withUnsafeBytes { bytes in
        appendMessage(level: level, type: type, bytes: bytes)
      }
    }

    /// Append a message with the supplied data to the end of this buffer,
    /// resizing it if necessary. The message payload is initialized with the
    /// supplied closure, which needs to return the final message length.
    ///
    /// This does not invalidate any existing indices, but it updates `endIndex`.
    ///
    /// - Complexity: Amortized O(`data.count`), when averaged over multiple
    ///    calls. This method reallocates the buffer if there isn't enough
    ///    capacity or if the storage is shared with another value.
    public mutating func appendMessage(
      level: SocketDescriptor.OptionLevel,
      type: SocketDescriptor.Option,
      unsafeUninitializedCapacity capacity: Int,
      initializingWith body: (UnsafeMutableRawBufferPointer) throws -> Int
    ) rethrows {
      precondition(capacity >= 0)
      typealias Layout = _ControlMessageLayout
      let start = _endOffset
      _buffer.ensureUnique(capacity: start + Layout.space(capacity))
      let messageSpace: Int = try _buffer.withUnsafeMutableBytes { buffer in
        assert(buffer.count >= start + Layout.space(capacity))
        let payloadStart = start + Layout.payloadOffset
        let length = try body(UnsafeMutableRawBufferPointer(
          rebasing: buffer[payloadStart ..< payloadStart + capacity]))
        precondition(length >= 0 && length <= capacity)

        var header = CInterop.CMsgHdr()
        header.cmsg_len = .init(Layout.length(length))
        header.cmsg_level = level.rawValue
        header.cmsg_type = type.rawValue
        buffer.storeBytes(of: header, toByteOffset: start, as: CInterop.CMsgHdr.self)
        // Zero the padding after the header and after the payload,
        // so the buffer never sends stale bytes.
        let end = start + Layout.space(length)
        UnsafeMutableRawBufferPointer(
          rebasing: buffer[start + Layout.headerSize ..< payloadStart]
        ).initializeMemory(as: UInt8.self, repeating: 0)
        UnsafeMutableRawBufferPointer(
          rebasing: buffer[payloadStart + length ..< end]
        ).initializeMemory(as: UInt8.self, repeating: 0)
        return end - start
      }
      _endOffset += messageSpace
    }

    /// Appends a message that passes file descriptors
    /// to the process at the other end of a local socket.
    ///
    /// The receiver gets new descriptors in its own process,
    /// which refer to the same open files as `descriptors` do in this one.
    /// Sending them doesn't close them here.
    ///
    /// The corresponding C constant is `SCM_RIGHTS`,
    /// at the `SOL_SOCKET` level.
    public mutating func appendFileDescriptors(
      _ descriptors: some Collection<FileDescriptor>
    ) {
      let stride = MemoryLayout<CInt>.stride
      appendMessage(
        level: .socket,
        type: .rights,
        unsafeUninitializedCapacity: descriptors.count * stride
      ) { payload in
        var offset = 0
        for descriptor in descriptors {
          payload.storeBytes(of: descriptor.rawValue, toByteOffset: offset, as: CInt.self)
          offset += stride
        }
        return offset
      }
    }

    /// The number of bytes that a message with a payload
    /// of the given size takes up in a buffer,
    /// including the padding that aligns the message after it.
    ///
    /// Add these up to size a buffer for the messages you expect to receive:
    /// for example, `space(forPayloadSize: 3 * MemoryLayout<CInt>.size)`
    /// makes room for three file descriptors.
    ///
    /// The corresponding C macro is `CMSG_SPACE`.
    @_alwaysEmitIntoClient
    public static func space(forPayloadSize payloadSize: Int) -> Int {
      _ControlMessageLayout.space(payloadSize)
    }

    /// The length that the header of a message with a payload
    /// of the given size records:
    /// the header, the padding after it, and the payload,
    /// without the padding before the next message.
    ///
    /// A message's payload starts `length(forPayloadSize: 0)` bytes
    /// after the start of its header.
    ///
    /// The corresponding C macro is `CMSG_LEN`.
    @_alwaysEmitIntoClient
    public static func length(forPayloadSize payloadSize: Int) -> Int {
      _ControlMessageLayout.length(payloadSize)
    }

    /// Calls the given closure with a buffer pointer to the messages,
    /// such as for the control buffer of a message header you build.
    ///
    /// The buffer covers ``byteCount`` bytes.
    /// It's valid only for the duration of the call.
    public func withUnsafeBytes<R>(
      _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
      try _withUnsafeBytes(body)
    }

    /// Calls the given closure with a buffer pointer to the buffer's whole
    /// capacity, and the number of bytes of messages in it,
    /// such as to receive messages through a message header you build.
    ///
    /// The closure sets the count to the number of bytes it leaves
    /// in the buffer, such as the `msg_controllen` that `recvmsg` reports.
    /// Messages that the new bytes don't lay out correctly
    /// end the collection, rather than trapping.
    ///
    /// The buffer pointer is valid only for the duration of the call.
    public mutating func withUnsafeMutableBytes<R>(
      _ body: (UnsafeMutableRawBufferPointer, inout Int) throws -> R
    ) rethrows -> R {
      var count = _endOffset
      return try _withMutableCInterop(entireCapacity: true) { pointer, length in
        let buffer = UnsafeMutableRawBufferPointer(
          start: pointer, count: pointer == nil ? 0 : Int(length))
        defer {
          precondition(count >= 0 && count <= buffer.count, "Count out of range")
          length = CInterop.SockLen(count)
        }
        return try body(buffer, &count)
      }
    }

    internal func _withUnsafeBytes<R>(
      _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
      try _buffer.withUnsafeBytes { buffer in
        assert(buffer.count >= _endOffset)
        let buffer = UnsafeRawBufferPointer(rebasing: buffer.prefix(_endOffset))
        return try body(buffer)
      }
    }

    internal mutating func _withUnsafeMutableBytes<R>(
      entireCapacity: Bool,
      _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
      return try _buffer.withUnsafeMutableBytes { buffer in
        assert(buffer.count >= _endOffset)
        if entireCapacity {
          return try body(buffer)
        } else {
          return try body(.init(rebasing: buffer.prefix(_endOffset)))
        }
      }
    }

    internal mutating func _withMutableCInterop<R>(
      entireCapacity: Bool,
      _ body: (UnsafeMutableRawPointer?, inout CInterop.SockLen) throws -> R
    ) rethrows -> R {
      let (result, length): (R, Int) = try _withUnsafeMutableBytes(
        entireCapacity: entireCapacity
      ) { buffer in
        var length = CInterop.SockLen(buffer.count)
        let result = try body(buffer.baseAddress, &length)
        precondition(length >= 0 && length <= buffer.count)
        return (result, Int(length))
      }
      _endOffset = length
      return result
    }
  }
}

@available(System 199, *)
extension SocketDescriptor.AncillaryMessageBuffer: Collection {
  /// The index type in an ancillary message buffer.
  @frozen
  public struct Index: Comparable, Hashable {
    @usableFromInline
    var _offset: Int

    @inlinable
    internal init(_offset: Int) {
      self._offset = _offset
    }

    @inlinable
    public static func == (left: Self, right: Self) -> Bool {
      left._offset == right._offset
    }

    @inlinable
    public static func < (left: Self, right: Self) -> Bool {
      left._offset < right._offset
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
      hasher.combine(_offset)
    }
  }

  /// An individual message inside an ancillary message buffer.
  ///
  /// Note that this is merely a reference to a slice of the underlying buffer,
  /// so it contains a shared copy of its entire storage. To prevent buffer
  /// reallocations due to copy-on-write copies, do not save instances
  /// of this type. Instead, immediately copy out any data you need to hold onto
  /// into standalone buffers.
  public struct Message {
    internal var _base: SocketDescriptor.AncillaryMessageBuffer
    internal var _offset: Int

    internal init(_base: SocketDescriptor.AncillaryMessageBuffer, offset: Int) {
      self._base = _base
      self._offset = offset
    }
  }

  /// The index of the first message in the collection, or `endIndex` if
  /// the collection contains no messages.
  ///
  /// This roughly corresponds to the C macro `CMSG_FIRSTHDR`.
  public var startIndex: Index {
    _withUnsafeBytes { buffer in
      Index(_offset: _ControlMessageLayout.firstOffset(in: buffer) ?? _endOffset)
    }
  }

  /// The index after the last message in the collection.
  public var endIndex: Index { Index(_offset: _endOffset) }

  /// Returns the index immediately following `i` in the collection.
  ///
  /// This roughly corresponds to the C macro `CMSG_NXTHDR`.
  ///
  /// - Complexity: O(1)
  public func index(after i: Index) -> Index {
    precondition(i._offset != _endOffset, "Can't advance past endIndex")
    return _withUnsafeBytes { buffer in
      guard let length = _ControlMessageLayout.messageLength(at: i._offset, in: buffer) else {
        preconditionFailure("Invalid index")
      }
      let next = _ControlMessageLayout.offset(after: i._offset, length: length, in: buffer)
      return Index(_offset: next ?? _endOffset)
    }
  }

  /// Returns the message at the given position, which must be a valid index
  /// in this collection.
  ///
  /// The returned value merely refers to a slice of the entire buffer, so
  /// it contains a shared reference to it.
  ///
  /// To reduce memory use and to prevent unnecessary copy-on-write copying, do
  /// not save `Message` values -- instead, copy out the data you need to hold
  /// on to into standalone storage.
  public subscript(position: Index) -> Message {
    let isValid = _withUnsafeBytes { buffer in
      _ControlMessageLayout.messageLength(at: position._offset, in: buffer) != nil
    }
    precondition(isValid, "Invalid index")
    return Element(_base: self, offset: position._offset)
  }
}

@available(System 199, *)
extension SocketDescriptor.AncillaryMessageBuffer.Message {
  internal var _header: CInterop.CMsgHdr {
    _base._withUnsafeBytes { buffer in
      buffer.loadUnaligned(fromByteOffset: _offset, as: CInterop.CMsgHdr.self)
    }
  }

  /// The protocol level of the message, such as ``SocketDescriptor/OptionLevel/socket``
  /// for the messages that pass file descriptors.
  ///
  /// The corresponding C field is `cmsg_level`.
  public var level: SocketDescriptor.OptionLevel {
    .init(rawValue: _header.cmsg_level)
  }

  /// The protocol-specific type of the message.
  ///
  /// The corresponding C field is `cmsg_type`.
  public var type: SocketDescriptor.Option {
    .init(rawValue: _header.cmsg_type)
  }

  /// Calls `body` with an unsafe raw buffer pointer containing the
  /// message payload.
  ///
  /// This roughly corresponds to the C macro `CMSG_DATA`.
  ///
  /// - Note: The buffer passed to `body` does not include storage reserved
  ///    for holding the message header, such as the `level` and `type` values.
  ///    To access header information, you have to use the corresponding
  ///    properties.
  public func withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try _base._withUnsafeBytes { buffer in
      guard let length = _ControlMessageLayout.messageLength(at: _offset, in: buffer) else {
        preconditionFailure("Invalid message")
      }
      let payloadStart = _offset + _ControlMessageLayout.payloadOffset
      return try body(UnsafeRawBufferPointer(
        rebasing: buffer[payloadStart ..< _offset + length]))
    }
  }

  /// The file descriptors that the message passes,
  /// or `nil` if it's another kind of message.
  ///
  /// Each descriptor is new in this process,
  /// and you're responsible for closing it.
  ///
  /// The corresponding C constant is `SCM_RIGHTS`,
  /// at the `SOL_SOCKET` level.
  public var fileDescriptors: [FileDescriptor]? {
    guard level == .socket, type == .rights else { return nil }
    return withUnsafeBytes { _ControlMessageLayout.fileDescriptors(in: $0) }
  }
}

// MARK: - Messages in memory you manage

@available(System 199, *)
extension SocketDescriptor {
  /// A collection of the ancillary messages in memory that you manage.
  ///
  /// Use this type to read the messages in a control buffer
  /// that isn't an ``AncillaryMessageBuffer``,
  /// such as one that a message header you built points to,
  /// after `recvmsg` or `recvmmsg` fills it in.
  /// It reads the messages where they are, without copying them.
  ///
  /// Like an `UnsafeRawBufferPointer`,
  /// this type doesn't keep its memory alive:
  /// the memory must stay valid, and unchanged,
  /// for as long as you use the collection, its indices or its messages.
  ///
  /// Iteration ends at the first header that doesn't fit in the buffer
  /// or records a length too short for a header,
  /// so corrupt or truncated data can't lead outside the buffer.
  ///
  /// The corresponding C macros are `CMSG_FIRSTHDR`, `CMSG_NXTHDR`,
  /// and `CMSG_DATA`.
  @frozen
  public struct UnsafeAncillaryMessages: Collection {
    /// The control buffer: the messages, and the padding between them.
    public let bytes: UnsafeRawBufferPointer

    /// Creates a collection of the messages in the given control buffer.
    @inlinable
    public init(_ bytes: UnsafeRawBufferPointer) {
      self.bytes = bytes
    }

    /// Creates a collection of the messages in the control buffer
    /// of a message header.
    ///
    /// The buffer is `msg_controllen` bytes at `msg_control`.
    /// After `recvmsg`, those are the messages it received.
    @inlinable
    public init(_ header: CInterop.MsgHdr) {
      guard let control = header.msg_control else {
        self.init(UnsafeRawBufferPointer(start: nil, count: 0))
        return
      }
      self.init(UnsafeRawBufferPointer(start: control, count: Int(header.msg_controllen)))
    }

    /// A position in a collection of messages:
    /// the offset of a message's header in the control buffer.
    @frozen
    public struct Index: Comparable, Hashable {
      /// The offset of the message's header from the start of the buffer.
      public let offset: Int

      @inlinable
      internal init(offset: Int) {
        self.offset = offset
      }

      @inlinable
      public static func < (left: Self, right: Self) -> Bool {
        left.offset < right.offset
      }
    }

    /// A message in a control buffer.
    @frozen
    public struct Message {
      /// The protocol level of the message.
      ///
      /// The corresponding C field is `cmsg_level`.
      public let level: OptionLevel

      /// The protocol-specific type of the message.
      ///
      /// The corresponding C field is `cmsg_type`.
      public let type: Option

      /// The message's payload, in the control buffer.
      ///
      /// The corresponding C macro is `CMSG_DATA`.
      public let payload: UnsafeRawBufferPointer

      @inlinable
      internal init(level: OptionLevel, type: Option, payload: UnsafeRawBufferPointer) {
        self.level = level
        self.type = type
        self.payload = payload
      }

      /// The file descriptors that the message passes,
      /// or `nil` if it's another kind of message.
      ///
      /// Each descriptor is new in this process,
      /// and you're responsible for closing it.
      ///
      /// The corresponding C constant is `SCM_RIGHTS`,
      /// at the `SOL_SOCKET` level.
      @inlinable
      public var fileDescriptors: [FileDescriptor]? {
        guard level == .socket, type == .rights else { return nil }
        return _ControlMessageLayout.fileDescriptors(in: payload)
      }
    }

    /// The position of the first message,
    /// or `endIndex` if the buffer holds none.
    ///
    /// This corresponds to the C macro `CMSG_FIRSTHDR`.
    @inlinable
    public var startIndex: Index {
      Index(offset: _ControlMessageLayout.firstOffset(in: bytes) ?? bytes.count)
    }

    /// The position after the last message.
    @inlinable
    public var endIndex: Index { Index(offset: bytes.count) }

    /// Returns the position of the message after the one at `i`.
    ///
    /// This corresponds to the C macro `CMSG_NXTHDR`.
    @inlinable
    public func index(after i: Index) -> Index {
      guard let length = _ControlMessageLayout.messageLength(at: i.offset, in: bytes) else {
        preconditionFailure("Invalid index")
      }
      let next = _ControlMessageLayout.offset(after: i.offset, length: length, in: bytes)
      return Index(offset: next ?? bytes.count)
    }

    /// Returns the message at the given position.
    @inlinable
    public subscript(position: Index) -> Message {
      guard let length = _ControlMessageLayout.messageLength(at: position.offset, in: bytes) else {
        preconditionFailure("Invalid index")
      }
      let header = bytes.loadUnaligned(fromByteOffset: position.offset, as: CInterop.CMsgHdr.self)
      let payloadStart = position.offset + _ControlMessageLayout.payloadOffset
      return Message(
        level: OptionLevel(rawValue: header.cmsg_level),
        type: Option(rawValue: header.cmsg_type),
        payload: UnsafeRawBufferPointer(rebasing: bytes[payloadStart ..< position.offset + length]))
    }
  }
}
