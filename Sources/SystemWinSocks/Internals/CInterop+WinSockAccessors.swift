/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Accessors for the Winsock structures that SystemWinSocks vends, with
// SystemSockets' names, so that code that reads and builds them compiles on
// both, and so that a client that doesn't import WinSDK can use them under
// MemberImportVisibility. They also hide what Winsock spells differently:
// in_addr's s_addr and in6_addr's s6_addr are macros for union members,
// which Swift can't import.
//
// The names are Swift names, never the C fields', so that a file that
// imports both SystemWinSocks and WinSDK sees no ambiguity. An initializer
// whose parameters all have defaults is also the zero value, as C's zero
// initializer is, so its defaults are all zero: the family is
// `.unspecified`. Winsock's structures have no length field.
//
// A port is in host byte order, as IPv4Address's is, though the C field
// holds it in network byte order; other fields are as C holds them.

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - sockaddr

@available(System 199, *)
extension CInterop.SockAddr {
  /// Creates a socket address header from its family, by default zero.
  ///
  /// The corresponding C field is `sa_family`.
  @_alwaysEmitIntoClient
  public init(family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0)) {
    self = CInterop.SockAddr()
    self.family = family
  }

  /// The address's family.
  ///
  /// The corresponding C field is `sa_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(sa_family)) }
    set { sa_family = .init(newValue.rawValue) }
  }
}

// MARK: - sockaddr_in

@available(System 199, *)
extension CInterop.SockAddrIn {
  /// Creates an IPv4 socket address from its fields, by default all zero.
  ///
  /// A usable address has the family ``SocketDescriptor/Domain/ipv4``.
  /// ``IPv4Address`` is the Swift type for these addresses.
  ///
  /// The corresponding C fields are `sin_family`, `sin_port`, and `sin_addr`.
  @_alwaysEmitIntoClient
  public init(
    family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0),
    port: UInt16 = 0,
    address: CInterop.InAddr = CInterop.InAddr()
  ) {
    self = CInterop.SockAddrIn()
    self.family = family
    self.port = port
    self.address = address
  }

  /// The address's family.
  ///
  /// The corresponding C field is `sin_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(sin_family)) }
    set { sin_family = .init(newValue.rawValue) }
  }

  /// The port, in host byte order.
  ///
  /// The corresponding C field is `sin_port`, in network byte order.
  @_alwaysEmitIntoClient
  public var port: UInt16 {
    get { UInt16(bigEndian: sin_port) }
    set { sin_port = newValue.bigEndian }
  }

  /// The host address.
  ///
  /// The corresponding C field is `sin_addr`.
  @_alwaysEmitIntoClient
  public var address: CInterop.InAddr {
    get { sin_addr }
    set { sin_addr = newValue }
  }
}

// MARK: - sockaddr_in6

@available(System 199, *)
extension CInterop.SockAddrIn6 {
  /// Creates an IPv6 socket address from its fields, by default all zero.
  ///
  /// A usable address has the family ``SocketDescriptor/Domain/ipv6``.
  /// ``IPv6Address`` is the Swift type for these addresses.
  ///
  /// The corresponding C fields are `sin6_family`, `sin6_port`,
  /// `sin6_flowinfo`, `sin6_addr`, and `sin6_scope_id`.
  @_alwaysEmitIntoClient
  public init(
    family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0),
    port: UInt16 = 0,
    flowInfo: UInt32 = 0,
    address: CInterop.In6Addr = CInterop.In6Addr(),
    scopeID: UInt32 = 0
  ) {
    self = CInterop.SockAddrIn6()
    self.family = family
    self.port = port
    self.flowInfo = flowInfo
    self.address = address
    self.scopeID = scopeID
  }

  /// The address's family.
  ///
  /// The corresponding C field is `sin6_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(sin6_family)) }
    set { sin6_family = .init(newValue.rawValue) }
  }

  /// The port, in host byte order.
  ///
  /// The corresponding C field is `sin6_port`, in network byte order.
  @_alwaysEmitIntoClient
  public var port: UInt16 {
    get { UInt16(bigEndian: sin6_port) }
    set { sin6_port = newValue.bigEndian }
  }

  /// The flow information, as the field holds it, in network byte order,
  /// as ``IPv6Address/flowLabel`` reports it.
  ///
  /// The corresponding C field is `sin6_flowinfo`.
  @_alwaysEmitIntoClient
  public var flowInfo: UInt32 {
    get { sin6_flowinfo }
    set { sin6_flowinfo = newValue }
  }

  /// The host address.
  ///
  /// The corresponding C field is `sin6_addr`.
  @_alwaysEmitIntoClient
  public var address: CInterop.In6Addr {
    get { sin6_addr }
    set { sin6_addr = newValue }
  }

  /// The scope ID, such as a link-local address's interface index.
  ///
  /// The corresponding C field is `sin6_scope_id`, a member of a union
  /// with `sin6_scope_struct`.
  @_alwaysEmitIntoClient
  public var scopeID: UInt32 {
    get { sin6_scope_id }
    set { sin6_scope_id = newValue }
  }
}

// MARK: - sockaddr_storage

@available(System 199, *)
extension CInterop.SockAddrStorage {
  /// Creates socket address storage with a family, by default zero.
  ///
  /// ``SocketAddress`` is the Swift type for these addresses.
  ///
  /// The corresponding C field is `ss_family`.
  @_alwaysEmitIntoClient
  public init(family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0)) {
    self = CInterop.SockAddrStorage()
    self.family = family
  }

  /// The stored address's family.
  ///
  /// The corresponding C field is `ss_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(ss_family)) }
    set { ss_family = .init(newValue.rawValue) }
  }
}

// MARK: - in_addr and in6_addr

@available(System 199, *)
extension CInterop.InAddr {
  /// Creates an IPv4 host address from its 32 bits as an integer,
  /// the first byte most significant, by default zero:
  /// `InAddr(integerValue: 0x7F00_0001)` is 127.0.0.1.
  ///
  /// ``IPv4Address/Host`` is the Swift type for these addresses.
  ///
  /// The corresponding C field is `S_un.S_addr`, which the SDK's `s_addr`
  /// macro names, in network byte order.
  @_alwaysEmitIntoClient
  public init(integerValue: UInt32 = 0) {
    self = CInterop.InAddr()
    self.integerValue = integerValue
  }

  /// The address's 32 bits as an integer, the first byte most significant.
  ///
  /// The corresponding C field is `S_un.S_addr`, which the SDK's `s_addr`
  /// macro names, in network byte order.
  @_alwaysEmitIntoClient
  public var integerValue: UInt32 {
    get { UInt32(bigEndian: S_un.S_addr) }
    set { S_un.S_addr = newValue.bigEndian }
  }
}

@available(System 199, *)
extension CInterop.In6Addr {
  /// Creates an IPv6 host address from its sixteen bytes, in network order,
  /// by default zero.
  ///
  /// ``IPv6Address/Host`` is the Swift type for these addresses.
  ///
  /// The corresponding C field is `u.Byte`, which the SDK's `s6_addr` macro
  /// names.
  @_alwaysEmitIntoClient
  public init(
    bytes: (
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  ) {
    self = CInterop.In6Addr()
    self.bytes = bytes
  }

  /// The address's sixteen bytes, in network order.
  ///
  /// The corresponding C field is `u.Byte`, which the SDK's `s6_addr` macro
  /// names.
  @_alwaysEmitIntoClient
  public var bytes: (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  ) {
    get { u.Byte }
    set { u.Byte = newValue }
  }
}

// MARK: - linger

@available(System 199, *)
extension CInterop.Linger {
  /// Creates the value of the linger-on-close option,
  /// by default off.
  ///
  /// ``SocketDescriptor/setLinger(_:)`` sets the option from a duration;
  /// this is for code that passes the C structure itself,
  /// such as through ``SocketDescriptor/setOption(_:_:to:)``.
  ///
  /// The corresponding C fields are `l_onoff` and `l_linger`.
  @_alwaysEmitIntoClient
  public init(isEnabled: Bool = false, time: Int = 0) {
    self = CInterop.Linger()
    self.isEnabled = isEnabled
    self.time = time
  }

  /// Whether closing the socket waits for unsent data to be sent.
  ///
  /// The corresponding C field is `l_onoff`.
  @_alwaysEmitIntoClient
  public var isEnabled: Bool {
    get { l_onoff != 0 }
    set { l_onoff = newValue ? 1 : 0 }
  }

  /// How long closing the socket waits, in seconds,
  /// from 0 through 65,535, since Winsock's field is a `u_short`.
  ///
  /// The corresponding C field is `l_linger`.
  @_alwaysEmitIntoClient
  public var time: Int {
    get { Int(l_linger) }
    set { l_linger = .init(newValue) }
  }
}

#endif // os(Windows)
