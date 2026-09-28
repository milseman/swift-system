/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Accessors for the socket structures that SystemSockets vends, so that a
// client that doesn't import the C library can read and build them under
// MemberImportVisibility, as SystemPackage's CInterop+Accessors.swift does
// for its structures.
//
// The names are Swift names, never the C fields', so that a file that
// imports both SystemSockets and the C library sees no ambiguity. An
// initializer whose parameters all have defaults is also the zero value, as
// C's zero initializer is, so its defaults are all zero: the family is
// `.unspecified`, and on Darwin and the BSDs the length field is 0.
//
// A port is in host byte order, as IPv4Address's is, though the C field
// holds it in network byte order; other fields are as C holds them.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
@_implementationOnly import CSystem
import Glibc
#elseif canImport(Musl)
@_implementationOnly import CSystem
import Musl
#elseif canImport(Android)
@_implementationOnly import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

import SystemPackage

// MARK: - msghdr

@available(System 199, *)
extension CInterop.MsgHdr {
  /// Creates a message header from its fields, by default all zero.
  ///
  /// The corresponding C fields are `msg_name`, `msg_namelen`, `msg_iov`,
  /// `msg_iovlen`, `msg_control`, `msg_controllen`, and `msg_flags`.
  @_alwaysEmitIntoClient
  public init(
    name: UnsafeMutableRawPointer? = nil,
    nameLength: Int = 0,
    vectors: UnsafeMutablePointer<CInterop.IOVec>? = nil,
    vectorCount: Int = 0,
    control: UnsafeMutableRawPointer? = nil,
    controlLength: Int = 0,
    flags: SocketDescriptor.MessageFlags = []
  ) {
    self = CInterop.MsgHdr()
    self.name = name
    self.nameLength = nameLength
    self.vectors = vectors
    self.vectorCount = vectorCount
    self.control = control
    self.controlLength = controlLength
    self.flags = flags
  }

  /// The address the message is sent to, or the buffer to receive the
  /// sender's address into.
  ///
  /// The corresponding C field is `msg_name`.
  @_alwaysEmitIntoClient
  public var name: UnsafeMutableRawPointer? {
    get { msg_name }
    set { msg_name = newValue }
  }

  /// The address's length in bytes.
  ///
  /// The corresponding C field is `msg_namelen`.
  @_alwaysEmitIntoClient
  public var nameLength: Int {
    get { Int(msg_namelen) }
    set { msg_namelen = .init(newValue) }
  }

  /// The I/O vectors that describe the message's data.
  ///
  /// The corresponding C field is `msg_iov`.
  @_alwaysEmitIntoClient
  public var vectors: UnsafeMutablePointer<CInterop.IOVec>? {
    get { msg_iov }
    set { msg_iov = newValue }
  }

  /// The number of I/O vectors.
  ///
  /// The corresponding C field is `msg_iovlen`,
  /// a `size_t` on glibc and an `int` elsewhere.
  @_alwaysEmitIntoClient
  public var vectorCount: Int {
    get { Int(msg_iovlen) }
    set { msg_iovlen = .init(newValue) }
  }

  /// The ancillary messages to send, or the buffer to receive them into.
  ///
  /// The corresponding C field is `msg_control`.
  @_alwaysEmitIntoClient
  public var control: UnsafeMutableRawPointer? {
    get { msg_control }
    set { msg_control = newValue }
  }

  /// The ancillary messages' length in bytes.
  ///
  /// The corresponding C field is `msg_controllen`,
  /// a `size_t` on glibc and a `socklen_t` elsewhere.
  @_alwaysEmitIntoClient
  public var controlLength: Int {
    get { Int(msg_controllen) }
    set { msg_controllen = .init(newValue) }
  }

  /// Flags that describe a received message.
  ///
  /// The corresponding C field is `msg_flags`.
  @_alwaysEmitIntoClient
  public var flags: SocketDescriptor.MessageFlags {
    get { SocketDescriptor.MessageFlags(rawValue: msg_flags) }
    set { msg_flags = newValue.rawValue }
  }
}

// MARK: - cmsghdr

@available(System 199, *)
extension CInterop.CMsgHdr {
  /// Creates an ancillary message header from its fields,
  /// by default all zero.
  ///
  /// The corresponding C fields are `cmsg_len`, `cmsg_level`,
  /// and `cmsg_type`.
  @_alwaysEmitIntoClient
  public init(
    length: Int = 0,
    level: SocketDescriptor.OptionLevel = SocketDescriptor.OptionLevel(rawValue: 0),
    type: SocketDescriptor.Option = SocketDescriptor.Option(rawValue: 0)
  ) {
    self = CInterop.CMsgHdr()
    self.length = length
    self.level = level
    self.type = type
  }

  /// The message's length in bytes, its header included.
  ///
  /// The corresponding C field is `cmsg_len`,
  /// a `size_t` on glibc and a `socklen_t` elsewhere.
  @_alwaysEmitIntoClient
  public var length: Int {
    get { Int(cmsg_len) }
    set { cmsg_len = .init(newValue) }
  }

  /// The message's protocol level.
  ///
  /// The corresponding C field is `cmsg_level`.
  @_alwaysEmitIntoClient
  public var level: SocketDescriptor.OptionLevel {
    get { SocketDescriptor.OptionLevel(rawValue: cmsg_level) }
    set { cmsg_level = newValue.rawValue }
  }

  /// The message's protocol-specific type.
  ///
  /// The corresponding C field is `cmsg_type`.
  @_alwaysEmitIntoClient
  public var type: SocketDescriptor.Option {
    get { SocketDescriptor.Option(rawValue: cmsg_type) }
    set { cmsg_type = newValue.rawValue }
  }
}

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

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The address's length in bytes.
  ///
  /// The corresponding C field is `sa_len`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { sa_len }
    set { sa_len = newValue }
  }
  #endif

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

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The address's length in bytes.
  ///
  /// The corresponding C field is `sin_len`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { sin_len }
    set { sin_len = newValue }
  }
  #endif

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

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The address's length in bytes.
  ///
  /// The corresponding C field is `sin6_len`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { sin6_len }
    set { sin6_len = newValue }
  }
  #endif

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
  /// The corresponding C field is `sin6_scope_id`.
  @_alwaysEmitIntoClient
  public var scopeID: UInt32 {
    get { sin6_scope_id }
    set { sin6_scope_id = newValue }
  }
}

// MARK: - sockaddr_un

@available(System 199, *)
extension CInterop.SockAddrUn {
  /// Creates a Unix-domain socket address from its fields,
  /// by default all zero.
  ///
  /// A usable address has the family ``SocketDescriptor/Domain/local``.
  /// ``UnixAddress`` is the Swift type for these addresses.
  ///
  /// The corresponding C fields are `sun_family` and `sun_path`.
  @_alwaysEmitIntoClient
  public init(
    family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0),
    path: FilePath = FilePath()
  ) {
    self = CInterop.SockAddrUn()
    self.family = family
    self.path = path
  }

  /// The number of bytes a path can have, not counting its terminating
  /// null character: 103 on Darwin and 107 on Linux.
  @_alwaysEmitIntoClient
  public static var pathCapacity: Int {
    MemoryLayout.size(ofValue: CInterop.SockAddrUn().sun_path) - 1
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The address's length in bytes.
  ///
  /// The corresponding C field is `sun_len`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { sun_len }
    set { sun_len = newValue }
  }
  #endif

  /// The address's family.
  ///
  /// The corresponding C field is `sun_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(sun_family)) }
    set { sun_family = .init(newValue.rawValue) }
  }

  /// The socket's path, up to the first null character.
  ///
  /// Setting a path longer than ``pathCapacity`` bytes is a precondition
  /// failure; the rest of the field is set to zero.
  /// An abstract address, which Linux gives a name that starts with a null
  /// character, reads as an empty path.
  ///
  /// The corresponding C field is `sun_path`.
  public var path: FilePath {
    get {
      withUnsafeBytes(of: sun_path) { bytes in
        let path = bytes.prefix { $0 != 0 }
        return FilePath(String(decoding: path, as: UTF8.self))
      }
    }
    set {
      let capacity = Self.pathCapacity
      newValue.withPlatformString { path in
        let count = system_strlen(path)
        precondition(count <= capacity, "sockaddr_un path longer than \(capacity) bytes")
        withUnsafeMutableBytes(of: &sun_path) { field in
          field.initializeMemory(as: UInt8.self, repeating: 0)
          field.copyMemory(from: UnsafeRawBufferPointer(start: path, count: count))
        }
      }
    }
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

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The stored address's length in bytes.
  ///
  /// The corresponding C field is `ss_len`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { ss_len }
    set { ss_len = newValue }
  }
  #endif

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
  /// The corresponding C field is `s_addr`, in network byte order.
  @_alwaysEmitIntoClient
  public init(integerValue: UInt32 = 0) {
    self = CInterop.InAddr()
    self.integerValue = integerValue
  }

  /// The address's 32 bits as an integer, the first byte most significant.
  ///
  /// The corresponding C field is `s_addr`, in network byte order.
  @_alwaysEmitIntoClient
  public var integerValue: UInt32 {
    get { UInt32(bigEndian: s_addr) }
    set { s_addr = newValue.bigEndian }
  }
}

@available(System 199, *)
extension CInterop.In6Addr {
  /// Creates an IPv6 host address from its sixteen bytes, in network order,
  /// by default zero.
  ///
  /// ``IPv6Address/Host`` is the Swift type for these addresses.
  ///
  /// The corresponding C field is a union, such as Darwin's `__u6_addr`.
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
  /// The corresponding C field is a union, such as Darwin's `__u6_addr`,
  /// whose name differs between C libraries.
  @_alwaysEmitIntoClient
  public var bytes: (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  ) {
    get {
      Swift.withUnsafeBytes(of: self) {
        $0.loadUnaligned(as: (
          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ).self)
      }
    }
    set {
      Swift.withUnsafeMutableBytes(of: &self) { address in
        Swift.withUnsafeBytes(of: newValue) { address.copyMemory(from: $0) }
      }
    }
  }
}

// MARK: - sockaddr_vm

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension CInterop.SockAddrVM {
  /// Creates a VM socket address from its fields, by default all zero.
  ///
  /// A usable address has the family ``SocketDescriptor/Domain/vsock``.
  /// ``VMSocketAddress`` is the Swift type for these addresses.
  ///
  /// The corresponding C fields are `svm_family`, `svm_port`, and `svm_cid`.
  @_alwaysEmitIntoClient
  public init(
    family: SocketDescriptor.Domain = SocketDescriptor.Domain(rawValue: 0),
    port: UInt32 = 0,
    contextID: UInt32 = 0
  ) {
    self = CInterop.SockAddrVM()
    self.family = family
    self.port = port
    self.contextID = contextID
  }

  /// The address's length in bytes.
  ///
  /// The corresponding C field is `svm_len`.
  @_alwaysEmitIntoClient
  public var length: UInt8 {
    get { svm_len }
    set { svm_len = newValue }
  }

  /// The address's family.
  ///
  /// The corresponding C field is `svm_family`.
  @_alwaysEmitIntoClient
  public var family: SocketDescriptor.Domain {
    get { SocketDescriptor.Domain(rawValue: CInt(svm_family)) }
    set { svm_family = .init(newValue.rawValue) }
  }

  /// The port, in host byte order, as the field holds it.
  ///
  /// The corresponding C field is `svm_port`.
  @_alwaysEmitIntoClient
  public var port: UInt32 {
    get { svm_port }
    set { svm_port = newValue }
  }

  /// The context ID, in host byte order, as the field holds it.
  ///
  /// The corresponding C field is `svm_cid`.
  @_alwaysEmitIntoClient
  public var contextID: UInt32 {
    get { svm_cid }
    set { svm_cid = newValue }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN
