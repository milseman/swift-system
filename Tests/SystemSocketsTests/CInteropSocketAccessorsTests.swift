/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The accessors of CInterop+SocketAccessors.swift read and write the C
// fields they name. This file imports the C library, as a client that uses
// both would, and so also checks that the two sets of names don't collide.

#if !os(Windows) && !os(WASI)

import Testing

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

import SystemPackage
import SystemSockets

/// Whether two values of a C type have the same bytes.
private func sameBytes<T>(_ a: T, _ b: T) -> Bool {
  withUnsafeBytes(of: a) { a in withUnsafeBytes(of: b) { b in a.elementsEqual(b) } }
}

@Suite("Socket structure accessors")
private struct CInteropSocketAccessorsTests {
  @available(System 199, *)
  @Test func messageHeaders() {
    var vector = CInterop.IOVec()
    var name = sockaddr_storage()
    var header = withUnsafeMutablePointer(to: &vector) { vector in
      withUnsafeMutablePointer(to: &name) { name in
        CInterop.MsgHdr(
          name: UnsafeMutableRawPointer(name), nameLength: 16, vectors: vector, vectorCount: 1,
          controlLength: 0, flags: .dataTruncated)
      }
    }
    #expect(header.msg_namelen == 16 && header.msg_iovlen == 1)
    #expect(header.msg_flags == CInt(MSG_TRUNC))
    header.controlLength = 24
    header.flags = []
    #expect(header.msg_controllen == 24 && header.msg_flags == 0)
    #expect(header.vectorCount == 1 && header.nameLength == 16)
    // msghdr has padding, which Swift doesn't keep when it copies a value,
    // so compare its fields.
    let zero = CInterop.MsgHdr()
    #expect(zero.name == nil && zero.nameLength == 0 && zero.vectors == nil)
    #expect(zero.vectorCount == 0 && zero.control == nil && zero.controlLength == 0)
    #expect(zero.flags.isEmpty)

    var control = CInterop.CMsgHdr(length: 20, level: .socket, type: .rights)
    #expect(control.cmsg_len == 20 && control.cmsg_level == SOL_SOCKET)
    #expect(control.cmsg_type == CInt(SCM_RIGHTS))
    control.level = .ip
    #expect(control.cmsg_level == CInt(IPPROTO_IP))
    #expect(sameBytes(CInterop.CMsgHdr(), cmsghdr()))
  }

  @available(System 199, *)
  @Test func socketAddresses() throws {
    var generic = CInterop.SockAddr(family: .ipv6)
    #expect(generic.sa_family == sa_family_t(AF_INET6))
    generic.family = .local
    #expect(generic.family == .local)
    #expect(sameBytes(CInterop.SockAddr(), sockaddr()))

    var ipv4 = CInterop.SockAddrIn(family: .ipv4, port: 8080, address: CInterop.InAddr(integerValue: 0x7F00_0001))
    #expect(ipv4.sin_family == sa_family_t(AF_INET))
    #expect(ipv4.sin_port == UInt16(8080).bigEndian)
    #expect(ipv4.sin_addr.s_addr == INADDR_LOOPBACK.bigEndian)
    ipv4.port = 443
    #expect(ipv4.port == 443 && UInt16(bigEndian: ipv4.sin_port) == 443)
    #expect(IPv4Address(ipv4).host == .loopback)
    #expect(sameBytes(CInterop.SockAddrIn(), sockaddr_in()))

    let host6 = try #require(IPv6Address.Host("2001:db8::7"))
    var ipv6 = CInterop.SockAddrIn6(family: .ipv6, port: 53, address: host6.rawValue, scopeID: 4)
    #expect(ipv6.sin6_port == UInt16(53).bigEndian && ipv6.sin6_scope_id == 4)
    #expect(IPv6Address.Host(rawValue: ipv6.sin6_addr) == host6)
    ipv6.flowInfo = 9
    #expect(ipv6.sin6_flowinfo == 9)
    #expect(ipv6.address.bytes.15 == 7 && ipv6.address.bytes.0 == 0x20)
    ipv6.address.bytes.15 = 8
    #expect(IPv6Address.Host(rawValue: ipv6.address) == IPv6Address.Host("2001:db8::8"))
    #expect(sameBytes(CInterop.SockAddrIn6(), sockaddr_in6()))
    #expect(sameBytes(CInterop.In6Addr(), in6_addr()))

    var local = CInterop.SockAddrUn(family: .local, path: "/tmp/accessors.sock")
    #expect(local.sun_family == sa_family_t(AF_UNIX))
    #expect(local.path == "/tmp/accessors.sock")
    #expect(withUnsafeBytes(of: local.sun_path) { $0[19] } == 0)
    local.path = "/tmp/a"
    // Setting a shorter path clears the rest of the old one.
    #expect(withUnsafeBytes(of: local.sun_path) { Array($0.prefix(8)) } == Array("/tmp/a".utf8) + [0, 0])
    #if SYSTEM_PACKAGE_DARWIN
    #expect(CInterop.SockAddrUn.pathCapacity == 103)
    #else
    #expect(CInterop.SockAddrUn.pathCapacity == 107)
    #endif
    let longest = String(repeating: "x", count: CInterop.SockAddrUn.pathCapacity)
    local.path = FilePath(longest)
    #expect(local.path.string == longest)
    #expect(sameBytes(CInterop.SockAddrUn(), sockaddr_un()))

    var storage = CInterop.SockAddrStorage(family: .ipv4)
    #expect(storage.ss_family == sa_family_t(AF_INET))
    storage.family = .unspecified
    #expect(storage.ss_family == 0)
    #expect(sameBytes(CInterop.SockAddrStorage(), sockaddr_storage()))

    var host4 = CInterop.InAddr(integerValue: 0xC000_0201)
    #expect(IPv4Address.Host(rawValue: host4).description == "192.0.2.1")
    host4.integerValue = 0
    #expect(host4.s_addr == 0)
    #expect(sameBytes(CInterop.InAddr(), in_addr()))

    #if SYSTEM_PACKAGE_DARWIN
    ipv4.length = 16
    #expect(ipv4.sin_len == 16)
    var vm = CInterop.SockAddrVM(family: .vsock, port: 1024, contextID: 2)
    #expect(vm.svm_family == sa_family_t(AF_VSOCK) && vm.svm_port == 1024 && vm.svm_cid == 2)
    vm.length = 12
    #expect(vm.svm_len == 12)
    #expect(sameBytes(CInterop.SockAddrVM(), sockaddr_vm()))
    #endif
  }

  @available(System 199, *)
  @Test func lingerAccessors() {
    var value = CInterop.Linger(isEnabled: true, time: 5)
    #expect(value.l_onoff == 1 && value.l_linger == 5)
    value.isEnabled = false
    value.time = 0
    #expect(value.l_onoff == 0 && value.l_linger == 0)
    value.l_onoff = 2
    #expect(value.isEnabled)
    #expect(sameBytes(CInterop.Linger(), linger()))
  }

  /// The C structure round-trips through the generic option calls, as it
  /// does through a client's own setsockopt, and agrees with
  /// SocketDescriptor's duration-based linger().
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func lingerThroughTheOptionCalls() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    defer { try? socket.close() }
    #if SYSTEM_PACKAGE_DARWIN
    let seconds = SocketDescriptor.SocketOption.lingerSeconds.rawValue
    #else
    let seconds = SocketDescriptor.SocketOption.linger.rawValue
    #endif
    try socket.setOption(.socket, seconds, to: CInterop.Linger(isEnabled: true, time: 3))
    let value: CInterop.Linger = try socket.getOption(.socket, seconds)
    #expect(value.isEnabled && value.time == 3)
    #expect(try socket.linger() == .seconds(3))
    try socket.setLinger(nil)
    let off: CInterop.Linger = try socket.getOption(.socket, seconds)
    #expect(!off.isEnabled)
  }

  /// A path longer than the field is a precondition failure.
  @available(System 199, *)
  @Test func aPathThatDoesntFitTraps() async {
    await #expect(processExitsWith: .failure) {
      var local = CInterop.SockAddrUn()
      local.path = FilePath(String(repeating: "x", count: CInterop.SockAddrUn.pathCapacity + 1))
    }
  }
}

#endif // !os(Windows) && !os(WASI)
