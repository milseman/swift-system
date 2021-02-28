/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor {
  public struct ControlMessageBuffer {
    internal var _buffer: _RawBuffer
    internal var _endOffset: Int

    /// Initialize a new empty control message buffer of the
    /// specified minimum capacity.
    internal init(minimumCapacity: Int) {
      let headerSize = MemoryLayout<CInterop.CMsgHdr>.size
      let capacity = Swift.max(headerSize + 1, minimumCapacity)
      _buffer = _RawBuffer(
        unsafeUninitializedMinimumCapacity: capacity
      ) { buffer in
        assert(buffer.count >= capacity)
        return buffer.count
      }
      _endOffset = 0
    }

    internal var _headerSize: Int { MemoryLayout<CInterop.CMsgHdr>.size }

    public mutating func removeAll() {
      _endOffset = 0
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
      _buffer.ensureUnique(capacity: minimumCapacity)
    }

    public mutating func appendMessage(
      level: CInt,
      type: CInt,
      data: UnsafeRawBufferPointer
    ) {
      let headerSize = _headerSize
      let delta = _headerSize + data.count
      _buffer.ensureUnique(capacity: _endOffset + delta)
      _buffer.withUnsafeMutableBytes { buffer in
        assert(buffer.count >= _endOffset + delta)
        let p = buffer.baseAddress! + _endOffset
        let header = p.bindMemory(to: CInterop.CMsgHdr.self, capacity: 1)
        header.pointee.cmsg_len = CInterop.SockLen(headerSize + data.count)
        header.pointee.cmsg_level = level
        header.pointee.cmsg_type = type
        if data.count > 0 {
          (p + headerSize).copyMemory(
            from: data.baseAddress!,
            byteCount: data.count)
        }
      }
      _endOffset += delta
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
extension SocketDescriptor.ControlMessageBuffer: Collection {
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

  public struct Message {
    internal var _base: SocketDescriptor.ControlMessageBuffer
    internal var _offset: Int

    internal init(_base: SocketDescriptor.ControlMessageBuffer, offset: Int) {
      self._base = _base
      self._offset = offset
    }
  }

  public var startIndex: Index { Index(_offset: 0) }
  public var endIndex: Index { Index(_offset: _endOffset) }
  public var isEmpty: Bool { _endOffset == 0 }

  public var count: Int {
    _withUnsafeBytes { buffer in
      var count = 0
      var p = buffer.baseAddress!
      let end = buffer.baseAddress! + buffer.count
      while p <= end - _headerSize {
        count += 1
        let header = p.assumingMemoryBound(to: CInterop.CMsgHdr.self)
        let length = Int(header.pointee.cmsg_len)
        p += length
      }
      return count
    }
  }

  public func index(after i: Index) -> Index {
    precondition(i._offset != _endOffset, "Can't advance past endIndex")
    precondition(i._offset >= 0 && i._offset + _headerSize <= _endOffset,
                 "Invalid index")
    let delta: Int = _withUnsafeBytes { buffer in
      let p = (buffer.baseAddress! + i._offset)
        .assumingMemoryBound(to: CInterop.CMsgHdr.self)
      return Int(p.pointee.cmsg_len)
    }
    if i._offset + delta + _headerSize > _endOffset {
      return endIndex
    }
    return Index(_offset: i._offset + delta)
  }

  public subscript(position: Index) -> Message {
    precondition(
      position._offset >= 0 && position._offset + _headerSize <= _endOffset,
      "Invalid index")
    return Element(_base: self, offset: position._offset)
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor.ControlMessageBuffer.Message {
  internal var _header: CInterop.CMsgHdr {
    _base._withUnsafeBytes { buffer in
      assert(_offset + _base._headerSize <= buffer.count)
      let p = buffer.baseAddress! + _offset
      let header = p.assumingMemoryBound(to: CInterop.CMsgHdr.self)
      return header.pointee
    }
  }

  public var level: CInt {
    _header.cmsg_level
  }

  public var type: CInt {
    _header.cmsg_type
  }

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

extension Optional where Wrapped == SocketDescriptor.ControlMessageBuffer {
  internal func _withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    guard let messages = self else {
      return try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }
    return try messages._withUnsafeBytes(body)
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketDescriptor {
  public func sendMessage(
    _ message: UnsafeRawBufferPointer,
    control: ControlMessageBuffer? = nil,
    to address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try address._withUnsafeBytes { rawAddress in
      try control._withUnsafeBytes { rawControl in
        var iov = CInterop.IOVec()
        iov.iov_base = UnsafeMutableRawPointer(mutating: message.baseAddress)
        iov.iov_len = message.count
        return try withUnsafePointer(to: &iov) { iov in
          var m = CInterop.MsgHdr()
          m.msg_name = UnsafeMutableRawPointer(mutating: rawAddress.baseAddress)
          m.msg_namelen = UInt32(rawAddress.count)
          m.msg_iov = UnsafeMutablePointer(mutating: iov)
          m.msg_iovlen = 1
          m.msg_control = UnsafeMutableRawPointer(mutating: rawControl.baseAddress)
          m.msg_controllen = CInterop.SockLen(rawControl.count)
          m.msg_flags = flags.rawValue
          return try withUnsafePointer(to: &m) { message in
            try _sendmsg(
              message,
              flags.rawValue,
              retryOnInterrupt: retryOnInterrupt
            ).get()
          }
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
    into buffer: UnsafeMutableRawBufferPointer,
    from address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try address._withUnsafeBytes { rawAddress in
      var iov = CInterop.IOVec()
      iov.iov_base = buffer.baseAddress
      iov.iov_len = buffer.count
      return try withUnsafeMutablePointer(to: &iov) { iov in
        var m = CInterop.MsgHdr()
        m.msg_name = UnsafeMutableRawPointer(mutating: rawAddress.baseAddress)
        m.msg_namelen = UInt32(rawAddress.count)
        m.msg_iov = UnsafeMutablePointer(mutating: iov)
        m.msg_iovlen = 1
        m.msg_control = nil
        m.msg_controllen = 0
        m.msg_flags = flags.rawValue
        return try withUnsafeMutablePointer(to: &m) { message in
          try _recvmsg(
            message,
            flags.rawValue,
            retryOnInterrupt: retryOnInterrupt
          ).get()
        }
      }
    }
  }

  public func receiveMessage(
    into buffer: UnsafeMutableRawBufferPointer,
    control: inout ControlMessageBuffer,
    from address: SocketAddress? = nil,
    flags: MessageFlags = .none,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    control._endOffset = control._buffer.capacity
    let (result, controlLength): (Result<Int, Errno>, Int)
    (result, controlLength) = address._withUnsafeBytes { rawAddress in
      control._withUnsafeMutableBytes { rawControl in
        var iov = CInterop.IOVec()
        iov.iov_base = buffer.baseAddress
        iov.iov_len = buffer.count
        return withUnsafeMutablePointer(to: &iov) { iov in
          var m = CInterop.MsgHdr()
          m.msg_name = UnsafeMutableRawPointer(mutating: rawAddress.baseAddress)
          m.msg_namelen = UInt32(rawAddress.count)
          m.msg_iov = iov
          m.msg_iovlen = 1
          m.msg_control = rawControl.baseAddress
          m.msg_controllen = CInterop.SockLen(rawControl.count)
          m.msg_flags = flags.rawValue
          let result = withUnsafePointer(to: &m) { message in
            _sendmsg(
              message,
              flags.rawValue,
              retryOnInterrupt: retryOnInterrupt
            )
          }
          return (result, Int(m.msg_controllen))
        }
      }
    }
    control._endOffset = Swift.min(controlLength, control._buffer.capacity)
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
