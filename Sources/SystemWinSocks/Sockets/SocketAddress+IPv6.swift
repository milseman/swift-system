/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

/// An IPv6 socket address.
///
/// An IPv6 address consists of a 128-bit IP address, a 16-bit port number,
/// a flow label, and a scope ID.
@frozen
@available(System 199, *)
public struct IPv6Address: Sendable, Hashable {
  /// The underlying C structure.
  @usableFromInline
  internal var _storage: CInterop.SockAddrIn6

  /// Creates an IPv6 address from a raw `SOCKADDR_IN6`.
  @_alwaysEmitIntoClient
  public init(_ sockaddr: CInterop.SockAddrIn6) {
    _storage = sockaddr
  }

  /// Creates an IPv6 address from an address string and port.
  ///
  /// - Parameters:
  ///   - address: The IPv6 address string (e.g., "::1" or "2001:db8::1").
  ///   - port: The port number in host byte order.
  /// - Returns: `nil` if the address string is invalid.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET6`.
  @_alwaysEmitIntoClient
  public init?(_ address: String, port: UInt16) {
    var addr = CInterop.SockAddrIn6(family: .ipv6, port: port)
    let result = address.withCString { cString in
      system_inet_pton(SocketDescriptor.Domain.ipv6.rawValue, cString, &addr.sin6_addr)
    }

    guard result == 1 else { return nil }
    _storage = addr
  }

  /// Creates an IPv6 address representing any address (::).
  ///
  /// - Parameter port: The port number in host byte order.
  @_alwaysEmitIntoClient
  public static func any(port: UInt16) -> IPv6Address {
    IPv6Address(CInterop.SockAddrIn6(family: .ipv6, port: port, address: Host.any.rawValue))
  }

  /// Creates an IPv6 address representing the loopback address (::1).
  ///
  /// - Parameter port: The port number in host byte order.
  @_alwaysEmitIntoClient
  public static func loopback(port: UInt16) -> IPv6Address {
    IPv6Address(CInterop.SockAddrIn6(family: .ipv6, port: port, address: Host.loopback.rawValue))
  }
}

// MARK: - Properties

@available(System 199, *)
extension IPv6Address {
  /// The port number in host byte order.
  @_alwaysEmitIntoClient
  public var port: UInt16 {
    UInt16(bigEndian: _storage.sin6_port)
  }

  /// The flow label.
  @_alwaysEmitIntoClient
  public var flowLabel: UInt32 {
    _storage.sin6_flowinfo
  }

  /// The scope ID.
  @_alwaysEmitIntoClient
  public var scopeID: UInt32 {
    _storage.sin6_scope_id
  }

  /// The IP address as a string.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET6`.
  public var addressString: String {
    host.description
  }
}

// MARK: - Pointer Access

@available(System 199, *)
extension IPv6Address {
  /// Calls the given closure with a pointer to the underlying socket address.
  @_alwaysEmitIntoClient
  public func withUnsafePointer<R>(
    _ body: (UnsafePointer<CInterop.SockAddr>, CInterop.SockLen) throws -> R
  ) rethrows -> R {
    try Swift.withUnsafePointer(to: _storage) { storage in
      try storage.withMemoryRebound(to: CInterop.SockAddr.self, capacity: 1) { sockaddr in
        try body(sockaddr, CInterop.SockLen(MemoryLayout<CInterop.SockAddrIn6>.size))
      }
    }
  }
}

// MARK: - CustomStringConvertible

@available(System 199, *)
extension IPv6Address: CustomStringConvertible {
  public var description: String {
    "[\(addressString)]:\(port)"
  }
}

// MARK: - ExpressibleByStringLiteral

@available(System 199, *)
extension IPv6Address: ExpressibleByStringLiteral {
  /// Creates an IPv6 address from a string literal.
  ///
  /// The format is "[address]:port" (e.g., "[::1]:8080") or "address"
  /// for port 0.
  public init(stringLiteral value: String) {
    var address = value
    var port: UInt16 = 0

    // Handle [address]:port format
    if value.hasPrefix("[") {
      if let closeBracket = value.lastIndex(of: "]") {
        address = String(value[value.index(after: value.startIndex)..<closeBracket])
        let afterBracket = value.index(after: closeBracket)
        if afterBracket < value.endIndex && value[afterBracket] == ":" {
          let portStart = value.index(after: afterBracket)
          if let p = UInt16(value[portStart...]) {
            port = p
          }
        }
      }
    }

    guard let addr = IPv6Address(address, port: port) else {
      fatalError("Invalid IPv6 address literal: \(value)")
    }
    self = addr
  }
}

// MARK: - Equatable and Hashable

@available(System 199, *)
extension IPv6Address {
  @_alwaysEmitIntoClient
  public static func == (lhs: IPv6Address, rhs: IPv6Address) -> Bool {
    Swift.withUnsafeBytes(of: lhs._storage) { lhsBytes in
      Swift.withUnsafeBytes(of: rhs._storage) { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }

  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    Swift.withUnsafeBytes(of: _storage) { bytes in
      hasher.combine(bytes: bytes)
    }
  }
}

// MARK: - SocketAddress Integration

@available(System 199, *)
extension SocketAddress {
  /// Creates a socket address from an IPv6 address.
  @_alwaysEmitIntoClient
  public init(ipv6: IPv6Address) {
    self.init()
    ipv6.withUnsafePointer { addr, len in
      withUnsafeMutableBytes(of: &_storage) { dest in
        dest.copyMemory(from: UnsafeRawBufferPointer(start: addr, count: Int(len)))
      }
      _length = len
    }
  }

  /// The address as an IPv6 address, if applicable.
  @_alwaysEmitIntoClient
  public var ipv6: IPv6Address? {
    guard family == .ipv6 else { return nil }
    return Swift.withUnsafeBytes(of: _storage) { buffer in
      IPv6Address(buffer.loadUnaligned(as: CInterop.SockAddrIn6.self))
    }
  }
}

#endif // os(Windows)
