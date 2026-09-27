/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

import SystemPackage
import SystemSockets

@Suite("Host addresses")
private struct SocketAddressHostTests {
  @available(System 199, *)
  @Test func ipv4ParsesAndFormats() throws {
    let host = try #require(IPv4Address.Host("192.0.2.1"))
    #expect(host.description == "192.0.2.1")
    #expect(host.integerValue == 0xC000_0201)
    #expect(host == IPv4Address.Host(192, 0, 2, 1))
    #expect(host == IPv4Address.Host(integerValue: 0xC000_0201))
    #expect(host.withUnsafeBytes { Array($0) } == [192, 0, 2, 1])
    #expect(IPv4Address.Host(bytes: [192, 0, 2, 1]) == host)
    #expect(IPv4Address.Host(bytes: [192, 0, 2]) == nil)
    for invalid in ["", "256.0.0.1", "1.2.3", "::1", "1.2.3.4 ", "example.com"] {
      #expect(IPv4Address.Host(invalid) == nil, "\(invalid)")
    }
    #expect(Set([host, IPv4Address.Host(192, 0, 2, 1), .loopback]).count == 2)
  }

  @available(System 199, *)
  @Test func ipv4Constants() {
    #expect(IPv4Address.Host.any.description == "0.0.0.0")
    #expect(IPv4Address.Host.loopback.description == "127.0.0.1")
    #expect(IPv4Address.Host.broadcast.description == "255.255.255.255")
    #expect(IPv4Address.Host.loopback.integerValue == 0x7F00_0001)
  }

  @available(System 199, *)
  @Test func ipv4SocketAddressesHaveHosts() throws {
    let address = IPv4Address(host: .loopback, port: 8080)
    #expect(address.host == .loopback)
    #expect(address.port == 8080)
    #expect(address.description == "127.0.0.1:8080")
    #expect(address == IPv4Address.loopback(port: 8080))
    #expect(try #require(IPv4Address("10.1.2.3", port: 1)).host == IPv4Address.Host(10, 1, 2, 3))
  }

  @available(System 199, *)
  @Test func ipv6ParsesAndFormats() throws {
    let host = try #require(IPv6Address.Host("2001:DB8:0:0::1"))
    // The text form of RFC 5952: lowercase, with the longest run of zeros elided.
    #expect(host.description == "2001:db8::1")
    let bytes: [UInt8] = [0x20, 0x01, 0x0d, 0xb8] + Array(repeating: 0, count: 11) + [1]
    #expect(host.withUnsafeBytes { Array($0) } == bytes)
    #expect(IPv6Address.Host(bytes: bytes) == host)
    #expect(IPv6Address.Host(bytes: bytes.dropLast()) == nil)
    #expect(try #require(IPv6Address.Host("::ffff:192.0.2.1")).description == "::ffff:192.0.2.1")
    for invalid in ["", "1.2.3.4", "2001:db8::1::2", "fe80::1%en0", "gggg::"] {
      #expect(IPv6Address.Host(invalid) == nil, "\(invalid)")
    }
    #expect(Set([host, IPv6Address.Host(bytes: bytes)!, .loopback]).count == 2)
  }

  @available(System 199, *)
  @Test func ipv6Constants() {
    #expect(IPv6Address.Host.any.description == "::")
    #expect(IPv6Address.Host.loopback.description == "::1")
    #expect(IPv6Address.Host.any != .loopback)
  }

  @available(System 199, *)
  @Test func ipv6SocketAddressesHaveHosts() throws {
    let address = IPv6Address(host: .loopback, port: 443, scopeID: 1)
    #expect(address.host == .loopback)
    #expect(address.port == 443)
    #expect(address.scopeID == 1)
    #expect(IPv6Address(host: .any, port: 0) == IPv6Address.any(port: 0))
  }
}

#endif // !os(Windows)
