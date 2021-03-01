/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor {
  /// A reusable collection of variable-sized ancillary messages
  /// sent or received over a socket. These represent protocol control
  /// related messages or other miscellaneous ancillary data.
  ///
  /// Corresponds to a buffer of `struct cmsghdr` messages in C, as used
  /// by `sendmsg` and `recmsg`.
  public struct AncillaryMessageBuffer {
    internal var _buffer: _RawBuffer
    internal var _endOffset: Int

    /// Initialize a new empty ancillary message buffer of the
    /// specified minimum capacity (in bytes).
    internal init(minimumCapacity: Int) {
      let headerSize = MemoryLayout<CInterop.CMsgHdr>.size
      let capacity = Swift.max(headerSize + 1, minimumCapacity)
      _buffer = _RawBuffer(minimumCapacity: capacity)
      _endOffset = 0
    }

    internal var _headerSize: Int { MemoryLayout<CInterop.CMsgHdr>.size }
    internal var _capacity: Int { _buffer.capacity }

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
      level: SocketDescriptor.Option.Level,
      type: SocketDescriptor.Option,
      data: UnsafeRawBufferPointer
    ) {
      appendMessage(
        level: level,
        type: type,
        unsafeUninitializedCapacity: data.count
      ) { buffer in
        if data.count > 0 {
          buffer.baseAddress!.copyMemory(
            from: data.baseAddress!,
            byteCount: data.count)
        }
        return data.count
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
      level: SocketDescriptor.Option.Level,
      type: SocketDescriptor.Option,
      unsafeUninitializedCapacity capacity: Int,
      initializingWith body: (UnsafeMutableRawBufferPointer) throws -> Int
    ) rethrows {
      precondition(capacity >= 0)
      let headerSize = _headerSize
      let delta = _headerSize + capacity
      _buffer.ensureUnique(capacity: _endOffset + delta)
      let messageLength: Int = try _buffer.withUnsafeMutableBytes { buffer in
        assert(buffer.count >= _endOffset + delta)
        let p = buffer.baseAddress! + _endOffset
        let header = p.bindMemory(to: CInterop.CMsgHdr.self, capacity: 1)
        header.pointee.cmsg_level = level.rawValue
        header.pointee.cmsg_type = type.rawValue
        let length = try body(
          UnsafeMutableRawBufferPointer(start: p + headerSize, count: capacity))
        precondition(length > 0 && length <= capacity)
        header.pointee.cmsg_len = CInterop.SockLen(headerSize + length)
        return length
      }
      _endOffset += messageLength
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
      _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
      return try _buffer.withUnsafeMutableBytes { buffer in
        assert(buffer.count >= _endOffset)
        let buffer = UnsafeMutableRawBufferPointer(rebasing: buffer.prefix(_endOffset))
        return try body(buffer)
      }
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
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
  public var startIndex: Index { Index(_offset: 0) }

  /// The index after the last message in the collection.
  public var endIndex: Index { Index(_offset: _endOffset) }

  /// True if the collection contains no elements.
  public var isEmpty: Bool { _endOffset == 0 }

  /// Return the length (in bytes) of the message at the specified index, or
  /// nil if the index isn't valid, or it addresses a corrupt message.
  internal func _length(at i: Index) -> Int? {
    _withUnsafeBytes { buffer in
      guard i._offset >= 0 && i._offset + _headerSize <= buffer.count else {
        return nil
      }
      let p = (buffer.baseAddress! + i._offset)
        .assumingMemoryBound(to: CInterop.CMsgHdr.self)
      let length = Int(p.pointee.cmsg_len)

      // Cut the list short at the first sign of corrupt data.
      // Messages must not be shorter than their header, and they must fit
      // entirely in the buffer.
      if length < _headerSize || i._offset + length > buffer.count {
        return nil
      }
      return length
    }
  }

  /// Returns the index immediately following `i` in the collection.
  ///
  /// - Complexity: O(1)
  public func index(after i: Index) -> Index {
    precondition(i._offset != _endOffset, "Can't advance past endIndex")
    precondition(i._offset >= 0 && i._offset + _headerSize <= _endOffset,
                 "Invalid index")
    guard let length = _length(at: i) else { return endIndex }
    return Index(_offset: i._offset + length)
  }

  /// Returns the message at the given position, which must be a valid index
  /// in this collection.
  ///
  /// The returned value merely refers to a slice of the entire buffer, so
  /// it contains a shared regerence to it.
  ///
  /// To reduce memory use and to prevent unnecessary copy-on-write copying, do
  /// not save `Message` values -- instead, copy out the data you need to hold
  /// on to into standalone storage.
  public subscript(position: Index) -> Message {
    guard let _ = _length(at: position) else {
      preconditionFailure("Invalid index")
    }
    return Element(_base: self, offset: position._offset)
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor.AncillaryMessageBuffer.Message {
  internal var _header: CInterop.CMsgHdr {
    _base._withUnsafeBytes { buffer in
      assert(_offset + _base._headerSize <= buffer.count)
      let p = buffer.baseAddress! + _offset
      let header = p.assumingMemoryBound(to: CInterop.CMsgHdr.self)
      return header.pointee
    }
  }

  /// The protocol of the message.
  public var level: SocketDescriptor.Option.Level {
    .init(rawValue: _header.cmsg_level)
  }

  /// The protocol-specific type of the message.
  public var type: SocketDescriptor.Option {
    .init(rawValue: _header.cmsg_type)
  }

  /// Calls `body` with an unsafe raw buffer pointer containing the
  /// message payload.
  ///
  /// - Note: The buffer passed to `body` does not include storage reserved
  ///    for holding the message header, such as the `level` and `type` values.
  ///    To access header information, you have to use the corresponding
  ///    properties.
  public func withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try _base._withUnsafeBytes { buffer in
      assert(_offset + _base._headerSize <= buffer.count)
      let p = buffer.baseAddress! + _offset
      let header = p.assumingMemoryBound(to: CInterop.CMsgHdr.self)
      let length = Int(header.pointee.cmsg_len)
      let data = p + _base._headerSize
      let count = Swift.min(_offset + length, buffer.count)
      return try body(UnsafeRawBufferPointer(start: data, count: count))
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor {
  /// Holds reusable metadata buffers and other ancillary information
  /// required by `sendMessage` and `receiveMessage`.
  ///
  /// This struct corresponds to the C `struct msghdr`, although it doesn't
  /// directly represent that type. (It's a memory-safe variant of it without
  /// the parts representing buffers for regular I/O data.)
  public struct MessageHeader {
    /// Message flags.
    ///
    /// `receiveMessage` sets this on return indicating condititions of
    /// the received message (`.endOfRecord`, `.dataTruncated`,
    /// `.ancillaryTruncated`, `.outOfBand`).
    ///
    /// `sendMessage` ignores this field.
    public var flags: MessageFlags = .none

    /// The address of the remote end of the collection.
    ///
    /// The `receiveMessage` method overwrites the original address with the
    /// address of the sender of the message. (If the address is unavailable,
    /// the `family` will be `.unspecified`.)
    ///
    /// For `sendMessage`, this identifies the address of the intended recipient.
    /// (Set the `family` to `.unspecified` if you don't need/want to specify a
    /// recipient.)
    public var remoteAddress: SocketAddress

    /// A buffer holding protocol control messages or other ancillary data.
    public var ancillaryMessages: AncillaryMessageBuffer

    /// Initialize a new reusable message header, with components of the
    /// specified preallocated storage capacity.
    ///
    /// - Parameter flag: The desired message flags. By default, no flags are set.
    /// - Parameter addressCapacity: The desired capacity (in bytes) of the
    ///    `remoteAddress` buffer. By default, the buffer will be large enough
    ///    to hold an IPv4/IPv6 address.
    /// - Parameter ancillaryCapacity: The desired capacity (in bytes) if
    ///    the buffer holding ancillary/control messages. The capacity is
    ///    zero by default, meaning no space is allocated.
    public init(
      flags: MessageFlags = .none,
      addressCapacity: Int = SocketAddress.defaultCapacity,
      ancillaryCapacity: Int = 0
    ) {
      self.flags = flags
      self.remoteAddress = SocketAddress(minimumCapacity: addressCapacity)
      self.ancillaryMessages = AncillaryMessageBuffer(minimumCapacity: ancillaryCapacity)
    }

    internal func _withUnsafeBuffers<R>(
      _ body: (
        MessageFlags,
        UnsafeRawBufferPointer,
        UnsafeRawBufferPointer
      ) throws -> R
    ) rethrows -> R {
      try remoteAddress.withUnsafeBytes { remoteAddress in
        try ancillaryMessages._withUnsafeBytes { ancillaryMessages in
          try body(flags, remoteAddress, ancillaryMessages)
        }
      }
    }

    internal mutating func _withUnsafeMutableBuffers<R>(
      _ body: (
        inout MessageFlags,
        UnsafeMutableRawBufferPointer,
        UnsafeMutableRawBufferPointer
      ) throws -> R
    ) rethrows -> R {
      try remoteAddress._withUnsafeMutableBytes { remoteAddress in
        try ancillaryMessages._withUnsafeMutableBytes { ancillaryMessages in
          try body(&flags, remoteAddress, ancillaryMessages)
        }
      }
    }
  }

  public func sendMessage(
    header: MessageHeader,
    bytes: UnsafeRawBufferPointer,
    flags: MessageFlags = [],
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try header._withUnsafeBuffers { msgflags, remoteAddress, ancillaryMessages in
      var iov = CInterop.IOVec()
      iov.iov_base = UnsafeMutableRawPointer(mutating: bytes.baseAddress)
      iov.iov_len = bytes.count
      return try withUnsafePointer(to: &iov) { iov in
        var m = CInterop.MsgHdr()
        m.msg_name = UnsafeMutableRawPointer(mutating: remoteAddress.baseAddress)
        m.msg_namelen = UInt32(remoteAddress.count)
        m.msg_iov = UnsafeMutablePointer(mutating: iov)
        m.msg_iovlen = 1
        m.msg_control = UnsafeMutableRawPointer(mutating: ancillaryMessages.baseAddress)
        m.msg_controllen = CInterop.SockLen(ancillaryMessages.count)
        m.msg_flags = msgflags.rawValue
        return try withUnsafePointer(to: &m) { message in
          try _sendmsg(message, flags.rawValue,
                       retryOnInterrupt: retryOnInterrupt).get()
        }
      }
    }
  }

  internal func _sendmsg(
    _ message: UnsafePointer<CInterop.MsgHdr>,
    _ flags: CInt,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_sendmsg(self.rawValue, message, flags)
    }
  }

  public func receiveMessage(
    header: inout MessageHeader,
    bytes: UnsafeMutableRawBufferPointer,
    flags: MessageFlags = [],
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    let (result, senderLength, ancillaryLength): (Result<Int, Errno>, Int, Int)
    (result, senderLength, ancillaryLength) =
      header._withUnsafeMutableBuffers { msgflags, remoteAddress, ancillaryMessages in
        var iov = CInterop.IOVec()
        iov.iov_base = bytes.baseAddress
        iov.iov_len = bytes.count
        return withUnsafePointer(to: &iov) { iov in
          var m = CInterop.MsgHdr()
          m.msg_name = remoteAddress.baseAddress
          m.msg_namelen = UInt32(remoteAddress.count)
          m.msg_iov = UnsafeMutablePointer(mutating: iov)
          m.msg_iovlen = 1
          m.msg_control = UnsafeMutableRawPointer(mutating: ancillaryMessages.baseAddress)
          m.msg_controllen = CInterop.SockLen(ancillaryMessages.count)
          m.msg_flags = msgflags.rawValue
          let result = withUnsafeMutablePointer(to: &m) { m in
            _recvmsg(m, flags.rawValue, retryOnInterrupt: retryOnInterrupt)
          }
          return (result, Int(m.msg_namelen), Int(m.msg_controllen))
        }
      }
    if case .success = result {
      precondition(senderLength <= header.remoteAddress._capacity)
      precondition(ancillaryLength <= header.ancillaryMessages._capacity)
      header.remoteAddress._length = senderLength
      header.ancillaryMessages._endOffset = ancillaryLength
    } else {
      header.remoteAddress._length = 0
      header.ancillaryMessages._endOffset = 0
    }
    return try result.get()
  }

  internal func _recvmsg(
    _ message: UnsafeMutablePointer<CInterop.MsgHdr>,
    _ flags: CInt,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_recvmsg(self.rawValue, message, flags)
    }
  }
}
