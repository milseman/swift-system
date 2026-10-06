/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

/// What an entry says, copied out of the list.
@available(System 199, *)
private struct Summary {
  var name: String
  var flags: NetworkInterface.Flags
  var family: CInt?
  var address: [UInt8]?
  var netmask: [UInt8]?
  var hasBroadcast: Bool
  var hasDestination: Bool
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func summaries(_ addresses: borrowing NetworkInterface.Addresses) -> [Summary] {
  var result: [Summary] = []
  addresses.forEach { entry in
    result.append(Summary(
      name: entry.name, flags: entry.flags, family: entry.addressFamily,
      address: bytes(entry.address),
      netmask: bytes(entry.netmask),
      hasBroadcast: entry.broadcastAddress != nil,
      hasDestination: entry.destinationAddress != nil))
  }
  return result
}

/// A copy of a span's bytes. (Swift 6.2's Optional.map requires an
/// Escapable value, which a span isn't, so this unwraps with if-let.)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func bytes(_ span: RawSpan?) -> [UInt8]? {
  if let span { return span.withUnsafeBytes { Array($0) } }
  return nil
}

@Suite("Network interfaces")
private struct NetworkInterfaceTests {
  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func theLoopbackInterfaceHas127001() throws {
    let addresses = try NetworkInterface.Addresses()
    let entries = summaries(addresses)
    #expect(entries.count == addresses.count)
    #expect(entries.allSatisfy { !$0.name.isEmpty })

    let loopback = try #require(entries.first {
      $0.flags.contains(.loopback) && $0.family == AF_INET
    })
    #expect(loopback.flags.contains(.up))
    // sin_addr is at offset 4, after the length and family (or the family
    // alone on Linux) and the port.
    let address = try #require(loopback.address)
    #expect(address.count >= 8)
    #expect(Array(address[4..<8]) == [127, 0, 0, 1])
    #expect(loopback.netmask != nil)
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func broadcastAndDestinationFollowTheFlags() throws {
    let addresses = try NetworkInterface.Addresses()
    for entry in summaries(addresses) {
      if entry.hasBroadcast { #expect(entry.flags.contains(.broadcast), "\(entry.name)") }
      if entry.hasDestination { #expect(entry.flags.contains(.pointToPoint), "\(entry.name)") }
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func indexesAndNamesRoundTrip() throws {
    let addresses = try NetworkInterface.Addresses()
    let name = try #require(summaries(addresses).first { $0.flags.contains(.loopback) }?.name)
    let index = try #require(try NetworkInterface.Index(name: name))
    #expect(index.rawValue == if_nametoindex(name))
    #expect(try index.name() == name)

    #expect(try NetworkInterface.Index(name: "nosuchinterface9") == nil)
    #expect(try NetworkInterface.Index(rawValue: 0x7FFF_FFF0).name() == nil)
  }
}

#endif // !os(Windows) && !os(WASI)
