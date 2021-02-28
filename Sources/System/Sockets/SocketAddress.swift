/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public struct SocketAddress {
  internal var _variant: _Variant

  public init(
    address: UnsafePointer<CInterop.SockAddr>,
    length: CInterop.SockLen
  ) {
    self.init(UnsafeRawBufferPointer(start: address, count: Int(length)))
  }

  public init(_ buffer: UnsafeRawBufferPointer) {
    self.init(unsafeUninitializedCapacity: buffer.count) { target in
      target.baseAddress!.copyMemory(
        from: buffer.baseAddress!,
        byteCount: buffer.count)
      return buffer.count
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketAddress {
  public init(
    unsafeUninitializedCapacity capacity: Int,
    initializingWith body: (UnsafeMutableRawBufferPointer) throws -> Int
  ) rethrows {
    if capacity <= MemoryLayout<_InlineStorage>.size {
      var storage = _InlineStorage()
      let length: Int = try withUnsafeMutableBytes(of: &storage) { bytes in
        let buffer = UnsafeMutableRawBufferPointer(rebasing: bytes[..<capacity])
        return try body(buffer)
      }
      precondition(length >= 0 && length <= capacity)
      self._variant = .small(length: UInt8(length), bytes: storage)
    } else {
      var count: Int? = nil
      let buffer = try _RawBuffer(
        unsafeUninitializedMinimumCapacity: capacity
      ) { buffer in
        let c = try body(buffer)
        precondition(c >= 0 && c <= capacity)
        count = c
        return capacity
      }
      self._variant = .large(length: count!, bytes: buffer)
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketAddress {
  @_alignment(8) // This must be large enough to cover any sockaddr variant
  internal struct _InlineStorage {
    /// A chunk of 28 bytes worth of integers, treated as inline storage for
    /// short `sockaddr` values.
    ///
    /// Note: 28 bytes is just enough to cover socketaddr_in6 on Darwin.
    /// The length of this struct may need to be adjusted on other platforms.
    internal let bytes: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)

    internal init() {
      bytes = (0, 0, 0, 0, 0, 0, 0)
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketAddress {
  internal enum _Variant {
    case small(length: UInt8, bytes: _InlineStorage)
    case large(length: Int, bytes: _RawBuffer)

    internal var length: Int {
      switch self {
      case let .small(length: length, bytes: _):
        return Int(length)
      case let .large(length: length, bytes: _):
        return length
      }
    }

    internal func withUnsafeBytes<R>(
      _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
      switch self {
      case let .small(length: length, bytes: bytes):
        let length = Int(length)
        assert(length <= MemoryLayout<_InlineStorage>.size)
        return try Swift.withUnsafeBytes(of: bytes) { buffer in
          try body(UnsafeRawBufferPointer(rebasing: buffer[..<length]))
        }
      case let .large(length: length, bytes: bytes):
        return try bytes.withUnsafeBytes { buffer in
          precondition(length <= buffer.count)
          let buffer = UnsafeRawBufferPointer(rebasing: buffer[..<length])
          return try body(buffer)
        }
      }
    }
  }
}

extension Optional where Wrapped == SocketAddress {
  internal func _withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    guard let address = self else {
      return try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }
    return try address.withUnsafeBytes(body)
  }
}


// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketAddress {
  /// Calls `body` with an unsafe raw buffer pointer to the raw bytes of this
  /// address. This is useful when you need to pass an address to a function
  /// that treats socket addresses as untyped raw data.
  public func withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try _variant.withUnsafeBytes(body)
  }

  /// Calls `body` with an unsafe raw buffer pointer to the
  /// raw bytes of this address. This is useful when you
  /// need to pass an address to a function that takes a
  /// a C `sockaddr` pointer along with a `socklen_t` length value.
  public func withRawAddress<R>(
    _ body: (UnsafePointer<CInterop.SockAddr>, CInterop.SockLen) throws -> R
  ) rethrows -> R {
    try _variant.withUnsafeBytes { bytes in
      let start = bytes.baseAddress!.assumingMemoryBound(to: CInterop.SockAddr.self)
      let length = CInterop.SockLen(bytes.count)
      return try body(start, length)
    }
  }

  public var family: Family {
    withRawAddress { addr, length in
      Family(rawValue: addr.pointee.sa_family)
    }
  }
}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension SocketAddress: CustomStringConvertible {
  public var description: String {
    switch family {
    case .ipv4:
      let address = IPv4(self)!
      return "SocketAddress(family: \(family)) \(address)"
    case .ipv6:
      let address = IPv6(self)!
      return "SocketAddress(family: \(family)) \(address)"
    case .local:
      let address = Local(self)!
      return "SocketAddress(family: \(family)) \(address)"
    default:
      return "SocketAddress(family: \(family))"
    }
  }
}
