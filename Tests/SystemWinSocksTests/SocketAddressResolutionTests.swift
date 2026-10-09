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

// GetAddrInfoW and GetNameInfoW with numeric hosts and services only, and
// the passive lookup, which needs no name: no test asks a resolver or a
// DNS server anything.
@Suite("Address resolution (Winsock)")
private struct SocketAddressResolutionTests {
  @available(System 199, *)
  @Test func flagsMatchTheSDK() {
    typealias Flags = SocketAddress.ResolutionFlags
    #expect(Flags.passive.rawValue == WinSDK.AI_PASSIVE)
    #expect(Flags.canonicalName.rawValue == WinSDK.AI_CANONNAME)
    #expect(Flags.numericHost.rawValue == WinSDK.AI_NUMERICHOST)
    #expect(Flags.numericService.rawValue == WinSDK.AI_NUMERICSERV)
    #expect(Flags.v4Mapped.rawValue == WinSDK.AI_V4MAPPED)
    #expect(Flags.all.rawValue == WinSDK.AI_ALL)
    #expect(Flags.addressConfigured.rawValue == WinSDK.AI_ADDRCONFIG)

    typealias Reverse = SocketAddress.ReverseResolutionFlags
    #expect(Reverse.numericHost.rawValue == WinSDK.NI_NUMERICHOST)
    #expect(Reverse.numericService.rawValue == WinSDK.NI_NUMERICSERV)
    #expect(Reverse.datagram.rawValue == WinSDK.NI_DGRAM)
    #expect(Reverse.noFullyQualified.rawValue == WinSDK.NI_NOFQDN)
    #expect(Reverse.nameRequired.rawValue == WinSDK.NI_NAMEREQD)
    #expect(WinSDK.NI_MAXHOST == 1025 && WinSDK.NI_MAXSERV == 32)
  }

  @available(System 199, *)
  @Test func numericHosts() throws {
    let hints = SocketAddress.ResolutionHints(
      socketType: .stream, flags: [.numericHost, .numericService])
    let ipv4 = try SocketAddress.resolve(hostname: "127.0.0.1", service: "443", hints: hints)
    let first = try #require(ipv4.first)
    #expect(first.family == .ipv4 && first.socketType == .stream)
    #expect(first.address.ipv4 == IPv4Address.loopback(port: 443))

    let ipv6 = try SocketAddress.resolve(hostname: "::1", service: "80", hints: hints)
    #expect(try #require(ipv6.first).address.ipv6?.host == .loopback)
  }

  // The passive address of a service, for binding: the any address.
  @available(System 199, *)
  @Test func passiveLookups() throws {
    let hints = SocketAddress.ResolutionHints(
      family: .ipv4, socketType: .datagram, flags: [.passive, .numericService])
    let results = try SocketAddress.resolve(service: "53", hints: hints)
    #expect(try #require(results.first).address.ipv4 == IPv4Address.any(port: 53))
  }

  @available(System 199, *)
  @Test func failures() {
    // A numeric host that isn't one: EAI_NONAME, WSAHOST_NOT_FOUND.
    #expect(throws: AddressResolutionError(code: WinSDK.EAI_NONAME)) {
      try SocketAddress.resolve(
        hostname: "not an address", hints: SocketAddress.ResolutionHints(flags: .numericHost))
    }
    let error = AddressResolutionError(code: WinSDK.WSAHOST_NOT_FOUND)
    #expect(!error.message.isEmpty)
    #expect(error.description.hasPrefix("AddressResolutionError(11001): "))
  }

  @available(System 199, *)
  @Test func numericReverseLookups() throws {
    let address = SocketAddress(ipv4: .loopback(port: 8080))
    let result = try address.reverseLookup(flags: [.numericHost, .numericService])
    #expect(result.hostname == "127.0.0.1")
    #expect(result.service == "8080")
  }
}

#endif // os(Windows)
