/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import Testing
import WinSDK

@testable import SystemWinSocks
import SystemPackage

// Addresses and their text forms: no sockets, so nothing here reaches the
// network.
@Suite("Socket Address (Winsock)")
private struct SocketAddressTests {
  @available(System 199, *)
  @Test func familiesMatchTheSDK() {
    #expect(SocketAddress.Family.unspecified.rawValue == ADDRESS_FAMILY(WinSDK.AF_UNSPEC))
    #expect(SocketAddress.Family.local.rawValue == ADDRESS_FAMILY(WinSDK.AF_UNIX))
    #expect(SocketAddress.Family.ipv4.rawValue == ADDRESS_FAMILY(WinSDK.AF_INET))
    #expect(SocketAddress.Family.ipv6.rawValue == ADDRESS_FAMILY(WinSDK.AF_INET6))
    #expect(SocketAddress.Family.ipv6.description == "ipv6")
  }

  @available(System 199, *)
  @Test func capacitiesMatchTheSDK() {
    #expect(IPv4Address.Host.descriptionCapacity == Int(WinSDK.INET_ADDRSTRLEN))
    #expect(IPv6Address.Host.descriptionCapacity == Int(WinSDK.INET6_ADDRSTRLEN))
  }

  @available(System 199, *)
  @Test func ipv4Addresses() throws {
    let address = try #require(IPv4Address("127.0.0.1", port: 8080))
    #expect(address.port == 8080)
    #expect(address.addressString == "127.0.0.1")
    #expect(address.description == "127.0.0.1:8080")
    #expect(address == IPv4Address.loopback(port: 8080))
    #expect(address.host == .loopback)
    #expect(IPv4Address.any(port: 1).host == .any)
    #expect(IPv4Address("256.0.0.1", port: 0) == nil)
    #expect(IPv4Address("1.2.3", port: 0) == nil)
    let literal: IPv4Address = "192.0.2.1:53"
    #expect(literal.host == IPv4Address.Host(192, 0, 2, 1))
    #expect(literal.port == 53)
  }

  @available(System 199, *)
  @Test func ipv6Addresses() throws {
    let address = try #require(IPv6Address("::1", port: 80))
    #expect(address.addressString == "::1")
    #expect(address.description == "[::1]:80")
    #expect(address == IPv6Address.loopback(port: 80))
    #expect(IPv6Address.any(port: 0).host == .any)
    #expect(IPv6Address("2001:db8::1", port: 0)?.addressString == "2001:db8::1")
    // A scope isn't part of a host address.
    #expect(IPv6Address.Host("fe80::1%4") == nil)
    let scoped = IPv6Address(host: .loopback, port: 7, flowLabel: 0, scopeID: 4)
    #expect(scoped.scopeID == 4)
    let literal: IPv6Address = "[2001:db8::2]:443"
    #expect(literal.port == 443)
  }

  @available(System 199, *)
  @Test func hostAddresses() {
    #expect(IPv4Address.Host.loopback.description == "127.0.0.1")
    #expect(IPv4Address.Host.any.description == "0.0.0.0")
    #expect(IPv4Address.Host.broadcast.integerValue == 0xFFFF_FFFF)
    #expect(IPv4Address.Host(integerValue: 0x7F00_0001) == .loopback)
    // In network order: the first byte is 127.
    IPv4Address.Host.loopback.withUnsafeBytes { bytes in
      #expect(Array(bytes) == [127, 0, 0, 1])
    }
    #expect(IPv4Address.Host(bytes: [192, 0, 2, 1]) == IPv4Address.Host("192.0.2.1"))
    #expect(IPv4Address.Host(bytes: [1, 2, 3]) == nil)

    #expect(IPv6Address.Host.loopback.description == "::1")
    #expect(IPv6Address.Host.any.description == "::")
    IPv6Address.Host.loopback.withUnsafeBytes { bytes in
      #expect(Array(bytes) == Array(repeating: 0, count: 15) + [1])
    }
    #expect(IPv6Address.Host("::ffff:192.0.2.1")?.description == "::ffff:192.0.2.1")
  }

  @available(System 199, *)
  @Test func socketAddresses() throws {
    let ipv4 = IPv4Address.loopback(port: 9)
    let address = SocketAddress(ipv4: ipv4)
    #expect(address.family == .ipv4)
    #expect(address.length == MemoryLayout<CInterop.SockAddrIn>.size)
    #expect(address.ipv4 == ipv4)
    #expect(address.ipv6 == nil)
    #expect(address.description == "SocketAddress(127.0.0.1:9)")

    let ipv6 = IPv6Address.loopback(port: 9)
    let address6 = SocketAddress(ipv6: ipv6)
    #expect(address6.family == .ipv6)
    #expect(address6.length == MemoryLayout<CInterop.SockAddrIn6>.size)
    #expect(address6.ipv6 == ipv6)
    #expect(address6 != address)

    var empty = address
    empty.clear()
    #expect(empty.isEmpty)
    #expect(empty.description == "SocketAddress(empty)")
  }

  // Windows' inet_ntop reports too small a buffer as ERROR_INVALID_PARAMETER.
  @available(System 199, *)
  @Test func descriptionsIntoBuffers() throws {
    var buffer = [CChar](repeating: 0x7F, count: IPv4Address.Host.descriptionCapacity)
    let count = try buffer.withUnsafeMutableBufferPointer { buffer throws(Win32.Error) in
      try IPv4Address.Host.loopback.description(into: buffer)
    }
    #expect(count == 9)
    #expect(buffer[9] == 0)

    var small = [CChar](repeating: 0, count: 5)
    #expect(throws: Win32.Error.invalidParameter) {
      try small.withUnsafeMutableBufferPointer { buffer throws(Win32.Error) in
        try IPv4Address.Host.loopback.description(into: buffer)
      }
    }
    #expect(throws: Win32.Error.invalidParameter) {
      try IPv6Address.Host.loopback.description(into: UnsafeMutableBufferPointer(start: nil, count: 0))
    }
  }

  @available(System 199, *)
  @Test func parsingCStrings() {
    let host = "192.0.2.7".withCString { IPv4Address.Host(cString: $0) }
    #expect(host == IPv4Address.Host(192, 0, 2, 7))
    let host6 = "2001:db8::7".withCString { IPv6Address.Host(cString: $0) }
    #expect(host6?.description == "2001:db8::7")
    #expect("fe80::1%4".withCString { IPv6Address.Host(cString: $0) } == nil)
  }

  // System doesn't start Winsock to convert addresses. In a process of its
  // own, which has no socket yet, both conversions still work.
  @available(System 199, *)
  @Test func conversionsWorkBeforeWinsockStarts() async {
    await #expect(processExitsWith: .success) {
      precondition(IPv4Address.Host("192.0.2.1")?.description == "192.0.2.1")
      precondition(IPv6Address.Host("2001:db8::1")?.description == "2001:db8::1")
    }
  }

  @available(System 199, *)
  @Test func accessors() {
    let address = CInterop.InAddr(integerValue: 0x7F00_0001)
    #expect(address.integerValue == 0x7F00_0001)
    #expect(address.S_un.S_addr == UInt32(0x7F00_0001).bigEndian)

    let ipv4 = CInterop.SockAddrIn(family: .ipv4, port: 80, address: address)
    #expect(ipv4.sin_family == ADDRESS_FAMILY(WinSDK.AF_INET))
    #expect(ipv4.sin_port == UInt16(80).bigEndian)
    #expect(ipv4.port == 80)
    #expect(ipv4.family == .ipv4)

    let bytes: (
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
    let address6 = CInterop.In6Addr(bytes: bytes)
    #expect(address6.u.Byte.0 == 0x20 && address6.u.Byte.15 == 1)
    let ipv6 = CInterop.SockAddrIn6(family: .ipv6, port: 443, address: address6, scopeID: 3)
    #expect(ipv6.sin6_port == UInt16(443).bigEndian)
    #expect(ipv6.scopeID == 3 && ipv6.sin6_scope_id == 3)

    #expect(CInterop.SockAddrStorage(family: .ipv6).ss_family == ADDRESS_FAMILY(WinSDK.AF_INET6))
    #expect(CInterop.SockAddr(family: .ipv4).family == .ipv4)

    let linger = CInterop.Linger(isEnabled: true, time: 5)
    #expect(linger.l_onoff == 1 && linger.l_linger == 5)
  }
}

#endif // os(Windows)
