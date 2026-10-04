/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

import SystemPackage
import SystemSockets

// Numeric hosts and services only: getaddrinfo parses them without a lookup.
@Suite("Address resolution")
private struct SocketAddressResolutionTests {
  @available(System 199, *)
  @Test func resolvesANumericHost() throws {
    let results = try SocketAddress.resolve(
      hostname: "127.0.0.1", service: "80",
      hints: .init(family: .ipv4, socketType: .stream, flags: [.numericHost, .numericService]))
    let first = try #require(results.first)
    #expect(first.family == .ipv4)
    #expect(first.socketType == .stream)
    let address = try #require(first.address.ipv4)
    #expect(address.host == .loopback)
    #expect(address.port == 80)
  }

  @available(System 199, *)
  @Test func aFailureHasTheCLibrarysMessage() {
    let error = #expect(throws: AddressResolutionError.self) {
      try SocketAddress.resolve(hostname: "not a host", hints: .init(flags: .numericHost))
    }
    #expect(error?.code == EAI_NONAME)
    #expect(error?.message == String(cString: gai_strerror(EAI_NONAME)))
    #expect(error?.message.isEmpty == false)
  }
}

#endif // !os(Windows) && !os(WASI)
