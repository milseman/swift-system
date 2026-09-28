/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

import SystemPackage
#if ENABLE_MOCKING
@testable import SystemSockets
#else
import SystemSockets
#endif

@Suite("Host address text in caller memory")
private struct SocketAddressHostTextTests {
  @available(System 199, *)
  @Test func capacities() {
    #expect(IPv4Address.Host.descriptionCapacity == 16)
    #expect(IPv6Address.Host.descriptionCapacity == 46)
  }

  @available(System 199, *)
  @Test func parsesCStrings() {
    #expect("192.0.2.1".withCString { IPv4Address.Host(cString: $0) } == IPv4Address.Host(192, 0, 2, 1))
    #expect("192.0.2".withCString { IPv4Address.Host(cString: $0) } == nil)
    #expect("2001:db8::1".withCString { IPv6Address.Host(cString: $0) } == IPv6Address.Host("2001:db8::1"))
    #expect("fe80::1%en0".withCString { IPv6Address.Host(cString: $0) } == nil)
    #expect("::1".withCString { IPv6Address.Host(cString: $0) } == .loopback)
  }

  @available(System 199, *)
  @Test func writesIntoBuffers() throws {
    var buffer = [CChar](repeating: 0x7F, count: 64)
    try buffer.withUnsafeMutableBufferPointer { buffer throws in
      // The longest IPv4 text fits its capacity exactly.
      let broadcast = UnsafeMutableBufferPointer(
        rebasing: buffer[..<IPv4Address.Host.descriptionCapacity])
      #expect(try IPv4Address.Host.broadcast.description(into: broadcast) == 15)
      #expect(String(cString: broadcast.baseAddress!) == "255.255.255.255")

      // inet_ntop writes the longest address it can produce, eight groups
      // of four digits, in 39 characters; the capacity leaves room for
      // RFC 4291's mixed form.
      let longest = try #require(IPv6Address.Host("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
      let room = UnsafeMutableBufferPointer(rebasing: buffer[..<IPv6Address.Host.descriptionCapacity])
      #expect(try longest.description(into: room) == 39)
      #expect(String(cString: room.baseAddress!) == longest.description)

      // Too little room, or none, is ENOSPC.
      let small = UnsafeMutableBufferPointer(rebasing: buffer[..<4])
      #expect(throws: Errno.noSpace) { try IPv4Address.Host.loopback.description(into: small) }
      let none = UnsafeMutableBufferPointer(rebasing: buffer[..<0])
      #expect(throws: Errno.noSpace) { try IPv6Address.Host.loopback.description(into: none) }
    }
  }

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func theCalls() throws {
    try MockingDriver.withMockingEnabled { mocking in
      var buffer = [CChar](repeating: 0, count: 16)
      _ = try buffer.withUnsafeMutableBufferPointer {
        try IPv4Address.Host.loopback.description(into: $0)
      }
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "inet_ntop")
      #expect(entry?.arguments.first == AnyHashable(AF_INET))
      #expect(entry?.arguments.last == AnyHashable(CInterop.SockLen(16)))
      _ = "::1".withCString { IPv6Address.Host(cString: $0) }
      #expect(mocking.trace.dequeue()?.name == "inet_pton")
    }
  }
  #endif
}

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#endif // !os(Windows)
