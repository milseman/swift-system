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
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported Platform")
#endif

// MARK: - IPv4 Host Addresses

@available(System 199, *)
extension IPv4Address {
  /// An IPv4 host address: the 32 bits that name a host, without a port.
  ///
  ///     let group = IPv4Address.Host("239.1.2.3")!
  ///     try socket.joinMulticastGroup(group)
  ///
  /// An ``IPv4Address`` is a host address and a port.
  ///
  /// The corresponding C type is `in_addr`.
  @frozen
  public struct Host: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    /// The C address, whose `s_addr` is in network byte order.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.InAddr

    /// Creates a host address from a C address.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.InAddr) { self.rawValue = rawValue }

    /// Creates a host address from its 32 bits as an integer,
    /// the first byte most significant:
    /// `Host(integerValue: 0x7F00_0001)` is 127.0.0.1.
    @_alwaysEmitIntoClient
    public init(integerValue: UInt32) {
      var address = in_addr()
      address.s_addr = integerValue.bigEndian
      self.init(rawValue: address)
    }

    /// The host address's 32 bits as an integer,
    /// the first byte most significant: 127.0.0.1 is `0x7F00_0001`.
    @_alwaysEmitIntoClient
    public var integerValue: UInt32 { UInt32(bigEndian: rawValue.s_addr) }

    /// Creates a host address from its four bytes, in the order they're
    /// written: `Host(127, 0, 0, 1)`.
    @_alwaysEmitIntoClient
    public init(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) {
      self.init(integerValue: UInt32(a) << 24 | UInt32(b) << 16 | UInt32(c) << 8 | UInt32(d))
    }

    /// Creates a host address from its four bytes, in network order,
    /// or returns `nil` if there aren't exactly four.
    @_alwaysEmitIntoClient
    public init?(bytes: some Collection<UInt8>) {
      guard bytes.count == 4 else { return nil }
      var address = in_addr()
      withUnsafeMutableBytes(of: &address) { $0.copyBytes(from: bytes) }
      self.init(rawValue: address)
    }

    /// Calls `body` with the host address's four bytes, in network order.
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R>(
      _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
      try Swift.withUnsafeBytes(of: rawValue, body)
    }

    /// Parses a host address in dotted-decimal form, such as `"192.0.2.1"`,
    /// or returns `nil` if the string isn't one.
    ///
    /// The corresponding C function is `inet_pton`, with `AF_INET`.
    public init?(_ string: String) {
      var address = in_addr()
      let result = string.withCString { system_inet_pton(AF_INET, $0, &address) }
      guard result == 1 else { return nil }
      self.init(rawValue: address)
    }

    /// The host address in dotted-decimal form, such as `"192.0.2.1"`.
    ///
    /// The corresponding C function is `inet_ntop`, with `AF_INET`.
    public var description: String {
      var address = rawValue
      return _formatHostAddress(AF_INET, &address, capacity: Int(INET_ADDRSTRLEN))
    }

    /// Any address: 0.0.0.0, which binds a socket to every local address.
    ///
    /// The corresponding C constant is `INADDR_ANY`.
    @_alwaysEmitIntoClient
    public static var any: Host { Host(integerValue: UInt32(INADDR_ANY)) }

    /// The loopback address, 127.0.0.1.
    ///
    /// The corresponding C constant is `INADDR_LOOPBACK`.
    @_alwaysEmitIntoClient
    public static var loopback: Host { Host(integerValue: UInt32(INADDR_LOOPBACK)) }

    /// The broadcast address, 255.255.255.255.
    ///
    /// The corresponding C constant is `INADDR_BROADCAST`.
    @_alwaysEmitIntoClient
    public static var broadcast: Host { Host(integerValue: UInt32(INADDR_BROADCAST)) }

    @_alwaysEmitIntoClient
    public static func == (lhs: Host, rhs: Host) -> Bool {
      lhs.rawValue.s_addr == rhs.rawValue.s_addr
    }

    @_alwaysEmitIntoClient
    public func hash(into hasher: inout Hasher) {
      hasher.combine(rawValue.s_addr)
    }
  }

  /// Creates an IPv4 socket address from a host address and a port.
  ///
  /// - Parameters:
  ///   - host: The host address.
  ///   - port: The port number in host byte order.
  @_alwaysEmitIntoClient
  public init(host: Host, port: UInt16) {
    var address = sockaddr_in()
    #if SYSTEM_PACKAGE_DARWIN
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    #endif
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = host.rawValue
    self.init(address)
  }

  /// The socket address's host address.
  ///
  /// The corresponding C field is `sin_addr`.
  @_alwaysEmitIntoClient
  public var host: Host { Host(rawValue: _storage.sin_addr) }
}

// MARK: - IPv6 Host Addresses

@available(System 199, *)
extension IPv6Address {
  /// An IPv6 host address: the 128 bits that name a host,
  /// without a port, flow label, or scope.
  ///
  ///     let group = IPv6Address.Host("ff02::1")!
  ///     try socket.joinMulticastGroup(group, interfaceIndex: 0)
  ///
  /// An ``IPv6Address`` is a host address, a port, a flow label,
  /// and a scope ID.
  ///
  /// The corresponding C type is `in6_addr`.
  @frozen
  public struct Host: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    /// The C address.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.In6Addr

    /// Creates a host address from a C address.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.In6Addr) { self.rawValue = rawValue }

    /// Creates a host address from its sixteen bytes, in network order,
    /// or returns `nil` if there aren't exactly sixteen.
    @_alwaysEmitIntoClient
    public init?(bytes: some Collection<UInt8>) {
      guard bytes.count == 16 else { return nil }
      var address = in6_addr()
      withUnsafeMutableBytes(of: &address) { $0.copyBytes(from: bytes) }
      self.init(rawValue: address)
    }

    /// Calls `body` with the host address's sixteen bytes, in network order.
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R>(
      _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
      try Swift.withUnsafeBytes(of: rawValue, body)
    }

    /// Parses a host address in the text form of RFC 4291,
    /// such as `"2001:db8::1"` or `"::ffff:192.0.2.1"`,
    /// or returns `nil` if the string isn't one.
    ///
    /// A scope, such as the `%en0` of `"fe80::1%en0"`, isn't part of a host
    /// address, and a string with one returns `nil`;
    /// ``IPv6Address/scopeID`` holds it.
    /// (Darwin's `inet_pton` accepts a scope, and for a link-local address
    /// writes the named interface's index into the address's second 16 bits,
    /// the KAME convention, where Linux's rejects it.)
    ///
    /// The corresponding C function is `inet_pton`, with `AF_INET6`.
    public init?(_ string: String) {
      guard !string.utf8.contains(UInt8(ascii: "%")) else { return nil }
      var address = in6_addr()
      let result = string.withCString { system_inet_pton(AF_INET6, $0, &address) }
      guard result == 1 else { return nil }
      self.init(rawValue: address)
    }

    /// The host address in the text form of RFC 5952, such as `"2001:db8::1"`.
    ///
    /// The corresponding C function is `inet_ntop`, with `AF_INET6`.
    public var description: String {
      var address = rawValue
      return _formatHostAddress(AF_INET6, &address, capacity: Int(INET6_ADDRSTRLEN))
    }

    /// Any address, `::`, which binds a socket to every local address.
    ///
    /// The corresponding C constant is `in6addr_any`.
    @_alwaysEmitIntoClient
    public static var any: Host { Host(rawValue: in6addr_any) }

    /// The loopback address, `::1`.
    ///
    /// The corresponding C constant is `in6addr_loopback`.
    @_alwaysEmitIntoClient
    public static var loopback: Host { Host(rawValue: in6addr_loopback) }

    @_alwaysEmitIntoClient
    public static func == (lhs: Host, rhs: Host) -> Bool {
      lhs.withUnsafeBytes { left in
        rhs.withUnsafeBytes { right in left.elementsEqual(right) }
      }
    }

    @_alwaysEmitIntoClient
    public func hash(into hasher: inout Hasher) {
      withUnsafeBytes { hasher.combine(bytes: $0) }
    }
  }

  /// Creates an IPv6 socket address from a host address, a port,
  /// and optionally a flow label and a scope ID.
  ///
  /// - Parameters:
  ///   - host: The host address.
  ///   - port: The port number in host byte order.
  ///   - flowLabel: The flow label. The default is 0.
  ///   - scopeID: The scope ID, such as a link-local address's interface
  ///     index. The default is 0.
  @_alwaysEmitIntoClient
  public init(host: Host, port: UInt16, flowLabel: UInt32 = 0, scopeID: UInt32 = 0) {
    var address = sockaddr_in6()
    #if SYSTEM_PACKAGE_DARWIN
    address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
    #endif
    address.sin6_family = sa_family_t(AF_INET6)
    address.sin6_port = port.bigEndian
    address.sin6_flowinfo = flowLabel
    address.sin6_addr = host.rawValue
    address.sin6_scope_id = scopeID
    self.init(address)
  }

  /// The socket address's host address.
  ///
  /// The corresponding C field is `sin6_addr`.
  @_alwaysEmitIntoClient
  public var host: Host { Host(rawValue: _storage.sin6_addr) }
}

/// Formats a C host address of the given family.
@available(System 199, *)
internal func _formatHostAddress<A>(
  _ family: CInt, _ address: inout A, capacity: Int
) -> String {
  withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity) { buffer in
    buffer.initialize(repeating: 0)
    let result = withUnsafePointer(to: &address) {
      system_inet_ntop(family, $0, buffer.baseAddress!, CInterop.SockLen(capacity))
    }
    // inet_ntop fails only for an unknown family or too small a buffer.
    precondition(result == 0, "inet_ntop failed")
    return String(decoding: UnsafeRawBufferPointer(buffer).prefix { $0 != 0 }, as: UTF8.self)
  }
}
