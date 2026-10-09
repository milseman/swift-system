/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

/// A Unix domain socket address.
///
/// Unix domain socket addresses use a filesystem path to identify the socket.
///
/// Windows 10 version 1803 and later have Unix domain sockets, of the
/// ``SocketDescriptor/ConnectionType/stream`` type only: no datagrams, no
/// `socketpair`, no passing descriptors, and no abstract names. Binding
/// one creates its file, a reparse point whose tag is
/// `Win32.ReparseTag.unixDomainSocket`; closing the socket leaves the file,
/// which `Win32.deleteFile(_:)` removes, and binding a path that has a file
/// throws ``Win32/Error/addressInUse``.
@frozen
@available(System 199, *)
public struct UnixAddress: Sendable, Equatable, Hashable {
  /// The underlying C structure.
  @usableFromInline
  internal var _storage: CInterop.SockAddrUn

  /// The length of the path (not including null terminator).
  @usableFromInline
  internal var _pathLength: Int

  /// Creates a Unix address from a raw `SOCKADDR_UN`.
  @_alwaysEmitIntoClient
  public init(_ sockaddr: CInterop.SockAddrUn) {
    _storage = sockaddr
    // Calculate path length from the stored data
    _pathLength = withUnsafeBytes(of: sockaddr.sun_path) { bytes in
      bytes.prefix(while: { $0 != 0 }).count
    }
  }

  /// Creates a Unix address from a path string.
  ///
  /// - Parameter path: The filesystem path for the socket: absolute, or
  ///   relative to the current directory.
  /// - Returns: `nil` if the path's UTF-8 is longer than 107 bytes.
  ///
  /// The address holds the path as UTF-8, as the C library does on other
  /// platforms.
  ///
  /// The corresponding C type is `SOCKADDR_UN`, with `AF_UNIX`.
  @_alwaysEmitIntoClient
  public init?(_ path: String) {
    var addr = CInterop.SockAddrUn(family: .local)
    let utf8 = Array(path.utf8)
    // Leave room for null
    guard utf8.count <= CInterop.SockAddrUn.pathCapacity, !utf8.contains(0) else { return nil }
    withUnsafeMutableBytes(of: &addr.sun_path) { dest in
      dest.copyBytes(from: utf8)
    }
    _storage = addr
    _pathLength = utf8.count
  }
}

// MARK: - Properties

@available(System 199, *)
extension UnixAddress {
  /// The path as a string.
  public var path: String {
    withUnsafeBytes(of: _storage.sun_path) { bytes in
      String(decoding: bytes.prefix(_pathLength), as: UTF8.self)
    }
  }
}

// MARK: - Pointer Access

@available(System 199, *)
extension UnixAddress {
  /// Calls the given closure with a pointer to the underlying socket address.
  @_alwaysEmitIntoClient
  public func withUnsafePointer<R>(
    _ body: (UnsafePointer<CInterop.SockAddr>, CInterop.SockLen) throws -> R
  ) rethrows -> R {
    try Swift.withUnsafePointer(to: _storage) { storage in
      try storage.withMemoryRebound(to: CInterop.SockAddr.self, capacity: 1) { sockaddr in
        // Length includes sun_family plus the path (including null terminator)
        let length = MemoryLayout<CInterop.SAFamily>.size + _pathLength + 1
        return try body(sockaddr, CInterop.SockLen(length))
      }
    }
  }
}

// MARK: - CustomStringConvertible

@available(System 199, *)
extension UnixAddress: CustomStringConvertible {
  public var description: String {
    path
  }
}

// MARK: - Equatable and Hashable

@available(System 199, *)
extension UnixAddress {
  @_alwaysEmitIntoClient
  public static func == (lhs: UnixAddress, rhs: UnixAddress) -> Bool {
    lhs._pathLength == rhs._pathLength &&
    Swift.withUnsafeBytes(of: lhs._storage.sun_path) { lhsBytes in
      Swift.withUnsafeBytes(of: rhs._storage.sun_path) { rhsBytes in
        lhsBytes.prefix(lhs._pathLength).elementsEqual(rhsBytes.prefix(rhs._pathLength))
      }
    }
  }

  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_pathLength)
    Swift.withUnsafeBytes(of: _storage.sun_path) { bytes in
      hasher.combine(bytes: UnsafeRawBufferPointer(rebasing: bytes.prefix(_pathLength)))
    }
  }
}

// MARK: - SocketAddress Integration

@available(System 199, *)
extension SocketAddress {
  /// Creates a socket address from a Unix address.
  @_alwaysEmitIntoClient
  public init(unix: UnixAddress) {
    self.init()
    unix.withUnsafePointer { addr, len in
      withUnsafeMutableBytes(of: &_storage) { dest in
        dest.copyMemory(from: UnsafeRawBufferPointer(start: addr, count: Int(len)))
      }
      _length = len
    }
  }

  /// The address as a Unix address, if applicable.
  @_alwaysEmitIntoClient
  public var unix: UnixAddress? {
    guard family == .local else { return nil }
    return Swift.withUnsafeBytes(of: _storage) { buffer in
      buffer.baseAddress!.withMemoryRebound(to: CInterop.SockAddrUn.self, capacity: 1) { ptr in
        UnixAddress(ptr.pointee)
      }
    }
  }
}

#endif // os(Windows)
