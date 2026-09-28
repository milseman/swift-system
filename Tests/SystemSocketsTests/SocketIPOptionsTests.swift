/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

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

/// The loopback interface's index.
private let loopbackIndex: UInt32 = {
  #if SYSTEM_PACKAGE_DARWIN
  if_nametoindex("lo0")
  #else
  if_nametoindex("lo")
  #endif
}()

@Suite("IP and IPv6 socket options")
private struct SocketIPOptionsTests {
  @available(System 199, *)
  private func withSocket<R>(
    _ domain: SocketDescriptor.Domain, _ type: SocketDescriptor.ConnectionType = .datagram,
    _ body: (SocketDescriptor) throws -> R
  ) throws -> R {
    let socket = try SocketDescriptor.open(domain, type, options: .closeOnExec)
    defer { try? socket.close() }
    return try body(socket)
  }

  @available(System 199, *)
  @Test func ipv4Options() throws {
    try withSocket(.ipv4) { socket throws in
      try socket.setTimeToLive(33)
      #expect(try socket.timeToLive() == 33)
      try socket.setTypeOfService(0x28)
      #expect(try socket.typeOfService() == 0x28)
      #expect(try socket.getIPOption(.typeOfService) == 0x28)

      #expect(try !socket.receivesTypeOfService())
      try socket.setReceivesTypeOfService(true)
      #expect(try socket.receivesTypeOfService())
      try socket.setReceivesIPv4PacketInfo(true)
      #expect(try socket.receivesIPv4PacketInfo())
    }
  }

  @available(System 199, *)
  @Test func ipv4MulticastOptions() throws {
    try withSocket(.ipv4) { socket throws in
      #expect(try socket.multicastTimeToLive() == 1)
      try socket.setMulticastTimeToLive(5)
      #expect(try socket.multicastTimeToLive() == 5)
      #expect(try socket.ipv4MulticastLoopback())
      try socket.setIPv4MulticastLoopback(false)
      #expect(try !socket.ipv4MulticastLoopback())
      #expect(try socket.ipv4MulticastInterface() == .any)
      try socket.setIPv4MulticastInterface(.loopback)
      #expect(try socket.ipv4MulticastInterface() == .loopback)
    }
  }

  @available(System 199, *)
  @Test func joiningAndLeavingAnIPv4Group() throws {
    try withSocket(.ipv4) { socket throws in
      let group = try #require(IPv4Address.Host("239.255.42.99"))
      try socket.joinMulticastGroup(group, interface: .loopback)
      // A second join of the same group on the same interface fails.
      #expect(throws: Errno.self) { try socket.joinMulticastGroup(group, interface: .loopback) }
      try socket.leaveMulticastGroup(group, interface: .loopback)
      #expect(throws: Errno.self) { try socket.leaveMulticastGroup(group, interface: .loopback) }
    }
  }

  @available(System 199, *)
  @Test func ipv6Options() throws {
    try withSocket(.ipv6) { socket throws in
      try socket.setIPv6Only(true)
      #expect(try socket.isIPv6Only())
      try socket.setIPv6Only(false)
      #expect(try !socket.isIPv6Only())
      #expect(try socket.getIPv6Option(.v6Only) == 0)

      try socket.setUnicastHops(12)
      #expect(try socket.unicastHops() == 12)
      try socket.setTrafficClass(0x2A)
      #expect(try socket.trafficClass() == 0x2A)
      try socket.setReceivesTrafficClass(true)
      #expect(try socket.receivesTrafficClass())
      // On Darwin, this checks RFC 3542's IPV6_RECVPKTINFO, which System spells out.
      try socket.setReceivesIPv6PacketInfo(true)
      #expect(try socket.receivesIPv6PacketInfo())
    }
  }

  @available(System 199, *)
  @Test func ipv6MulticastOptions() throws {
    try withSocket(.ipv6) { socket throws in
      #expect(try socket.multicastHops() == 1)
      try socket.setMulticastHops(7)
      #expect(try socket.multicastHops() == 7)
      #expect(try socket.ipv6MulticastLoopback())
      try socket.setIPv6MulticastLoopback(false)
      #expect(try !socket.ipv6MulticastLoopback())
      #expect(try socket.ipv6MulticastInterface() == 0)
      try socket.setIPv6MulticastInterface(loopbackIndex)
      #expect(try socket.ipv6MulticastInterface() == loopbackIndex)
    }
  }

  @available(System 199, *)
  @Test func joiningAndLeavingAnIPv6Group() throws {
    try withSocket(.ipv6) { socket throws in
      let group = try #require(IPv6Address.Host("ff02::42:99"))
      try socket.joinMulticastGroup(group, interfaceIndex: loopbackIndex)
      try socket.leaveMulticastGroup(group, interfaceIndex: loopbackIndex)
      #expect(throws: Errno.self) {
        try socket.leaveMulticastGroup(group, interfaceIndex: loopbackIndex)
      }
    }
  }

  /// A raw socket needs privileges, so this runs only as root.
  @available(System 199, *)
  @Test func headerInclusion() throws {
    guard let socket = try? SocketDescriptor.open(.ipv4, .raw, protocol: .udp, options: .closeOnExec)
    else { return }
    defer { try? socket.close() }
    #expect(try !socket.includesIPHeader())
    try socket.setIncludesIPHeader(true)
    #expect(try socket.includesIPHeader())
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timeouts() throws {
    try withSocket(.ipv4) { socket throws in
      #expect(try socket.receiveTimeout() == nil)
      #expect(try socket.sendTimeout() == nil)
      // Linux keeps the time in clock ticks, which 1.5 seconds is a whole number of.
      try socket.setReceiveTimeout(.milliseconds(1500))
      #expect(try socket.receiveTimeout() == .milliseconds(1500))
      try socket.setSendTimeout(.seconds(3))
      #expect(try socket.sendTimeout() == .seconds(3))
      // Zero isn't C's "no timeout"; nil is.
      try socket.setReceiveTimeout(.zero)
      #expect(try socket.receiveTimeout() != nil)
      // Nor is a negative duration an invalid time (EDOM), sub-second or not.
      for negative: Duration in [.milliseconds(-500), .seconds(-2), .nanoseconds(-1)] {
        try socket.setReceiveTimeout(negative)
        #expect(try socket.receiveTimeout() != nil, "\(negative)")
        try socket.setSendTimeout(negative)
        #expect(try socket.sendTimeout() != nil, "\(negative)")
      }
      try socket.setReceiveTimeout(nil)
      #expect(try socket.receiveTimeout() == nil)
    }
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func aReceiveTimesOut() throws {
    let (first, second) = try SocketDescriptor.pair(.local, .stream, options: .closeOnExec)
    defer {
      try? first.close()
      try? second.close()
    }
    try second.setReceiveTimeout(.milliseconds(50))
    var byte: UInt8 = 0
    let start = ContinuousClock.now
    #expect(throws: Errno.wouldBlock) {
      try withUnsafeMutableBytes(of: &byte) { try second.receive(into: $0) }
    }
    #expect(ContinuousClock.now - start >= .milliseconds(40))
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func linger() throws {
    try withSocket(.ipv4, .stream) { socket throws in
      #expect(try socket.linger() == nil)
      try socket.setLinger(.seconds(3))
      #expect(try socket.linger() == .seconds(3))
      // Rounded up to a whole second.
      try socket.setLinger(.milliseconds(1500))
      #expect(try socket.linger() == .seconds(2))
      try socket.setLinger(.zero)
      #expect(try socket.linger() == .zero)
      try socket.setLinger(.milliseconds(-500))
      #expect(try socket.linger() == .zero)
      try socket.setLinger(nil)
      #expect(try socket.linger() == nil)
    }
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func timestamps() throws {
    try withSocket(.ipv4) { socket throws in
      #expect(try !socket.receivesTimestamps())
      try socket.setReceivesTimestamps(true)
      #expect(try socket.receivesTimestamps())
    }
  }
}

#endif // !os(Windows)
