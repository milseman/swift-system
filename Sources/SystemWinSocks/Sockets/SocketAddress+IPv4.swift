/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

/// An IPv4 socket address.
///
/// An IPv4 address consists of a 32-bit IP address and a 16-bit port number.
@frozen
@available(System 199, *)
public struct IPv4Address: Sendable, Equatable, Hashable {
  /// The underlying C structure.
  @usableFromInline
  internal var _storage: CInterop.SockAddrIn

  /// Creates an IPv4 address from a raw `SOCKADDR_IN`.
  @_alwaysEmitIntoClient
  public init(_ sockaddr: CInterop.SockAddrIn) {
    _storage = sockaddr
  }

  /// Creates an IPv4 address from an address string and port.
  ///
  /// - Parameters:
  ///   - address: The IPv4 address string (e.g., "127.0.0.1").
  ///   - port: The port number in host byte order.
  /// - Returns: `nil` if the address string is invalid.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET`.
  @_alwaysEmitIntoClient
  public init?(_ address: String, port: UInt16) {
    var addr = CInterop.SockAddrIn(family: .ipv4, port: port)
    let result = address.withCString { cString in
      system_inet_pton(SocketDescriptor.Domain.ipv4.rawValue, cString, &addr.sin_addr)
    }

    guard result == 1 else { return nil }
    _storage = addr
  }

  /// Creates an IPv4 address representing any address (0.0.0.0).
  ///
  /// - Parameter port: The port number in host byte order.
  @_alwaysEmitIntoClient
  public static func any(port: UInt16) -> IPv4Address {
    IPv4Address(CInterop.SockAddrIn(family: .ipv4, port: port, address: Host.any.rawValue))
  }

  /// Creates an IPv4 address representing the loopback address (127.0.0.1).
  ///
  /// - Parameter port: The port number in host byte order.
  @_alwaysEmitIntoClient
  public static func loopback(port: UInt16) -> IPv4Address {
    IPv4Address(CInterop.SockAddrIn(family: .ipv4, port: port, address: Host.loopback.rawValue))
  }
}

// MARK: - Properties

@available(System 199, *)
extension IPv4Address {
  /// The port number in host byte order.
  @_alwaysEmitIntoClient
  public var port: UInt16 {
    UInt16(bigEndian: _storage.sin_port)
  }

  /// The IP address as a string.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET`.
  public var addressString: String {
    host.description
  }
}

// MARK: - Pointer Access

@available(System 199, *)
extension IPv4Address {
  /// Calls the given closure with a pointer to the underlying socket address.
  @_alwaysEmitIntoClient
  public func withUnsafePointer<R>(
    _ body: (UnsafePointer<CInterop.SockAddr>, CInterop.SockLen) throws -> R
  ) rethrows -> R {
    try Swift.withUnsafePointer(to: _storage) { storage in
      try storage.withMemoryRebound(to: CInterop.SockAddr.self, capacity: 1) { sockaddr in
        try body(sockaddr, CInterop.SockLen(MemoryLayout<CInterop.SockAddrIn>.size))
      }
    }
  }
}

// MARK: - CustomStringConvertible

@available(System 199, *)
extension IPv4Address: CustomStringConvertible {
  public var description: String {
    "\(addressString):\(port)"
  }
}

// MARK: - ExpressibleByStringLiteral

@available(System 199, *)
extension IPv4Address: ExpressibleByStringLiteral {
  /// Creates an IPv4 address from a string literal.
  ///
  /// The format is "address:port" (e.g., "127.0.0.1:8080").
  /// If no port is specified, port 0 is used.
  public init(stringLiteral value: String) {
    let parts = value.split(separator: ":", maxSplits: 1)
    let address = String(parts[0])
    let port: UInt16 = parts.count > 1 ? UInt16(parts[1]) ?? 0 : 0

    guard let addr = IPv4Address(address, port: port) else {
      fatalError("Invalid IPv4 address literal: \(value)")
    }
    self = addr
  }
}

// MARK: - Equatable and Hashable

@available(System 199, *)
extension IPv4Address {
  @_alwaysEmitIntoClient
  public static func == (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
    lhs._storage.sin_family == rhs._storage.sin_family &&
    lhs._storage.sin_port == rhs._storage.sin_port &&
    lhs._storage.sin_addr.S_un.S_addr == rhs._storage.sin_addr.S_un.S_addr
  }

  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_storage.sin_family)
    hasher.combine(_storage.sin_port)
    hasher.combine(_storage.sin_addr.S_un.S_addr)
  }
}

// MARK: - SocketAddress Integration

@available(System 199, *)
extension SocketAddress {
  /// Creates a socket address from an IPv4 address.
  @_alwaysEmitIntoClient
  public init(ipv4: IPv4Address) {
    self.init()
    ipv4.withUnsafePointer { addr, len in
      withUnsafeMutableBytes(of: &_storage) { dest in
        dest.copyMemory(from: UnsafeRawBufferPointer(start: addr, count: Int(len)))
      }
      _length = len
    }
  }

  /// The address as an IPv4 address, if applicable.
  @_alwaysEmitIntoClient
  public var ipv4: IPv4Address? {
    guard family == .ipv4 else { return nil }
    return Swift.withUnsafeBytes(of: _storage) { buffer in
      IPv4Address(buffer.loadUnaligned(as: CInterop.SockAddrIn.self))
    }
  }
}

#endif // os(Windows)
