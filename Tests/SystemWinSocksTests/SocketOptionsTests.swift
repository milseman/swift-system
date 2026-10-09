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

// Options on sockets of the test's own. The sockets that bind take a
// loopback address and a port the system picks; the multicast test joins its
// group on the loopback interface, so its datagram and its membership report
// stay on this host.
@Suite("Socket Options (Winsock)")
private struct SocketOptionsTests {
  @available(System 199, *)
  @Test func namesMatchTheSDK() {
    #expect(SocketDescriptor.OptionLevel.socket.rawValue == WinSDK.SOL_SOCKET)
    #expect(SocketDescriptor.OptionLevel.ip.rawValue == WinSDK.IPPROTO_IP)
    #expect(SocketDescriptor.OptionLevel.ipv6.rawValue == WinSDK.IPPROTO_IPV6.rawValue)
    #expect(SocketDescriptor.OptionLevel.tcp.rawValue == WinSDK.IPPROTO_TCP.rawValue)
    #expect(SocketDescriptor.OptionLevel.udp.rawValue == WinSDK.IPPROTO_UDP.rawValue)

    typealias Socket = SocketDescriptor.SocketOption
    #expect(Socket.debug.rawValue == WinSDK.SO_DEBUG)
    #expect(Socket.reuseAddress.rawValue == WinSDK.SO_REUSEADDR)
    #expect(Socket.keepAlive.rawValue == WinSDK.SO_KEEPALIVE)
    #expect(Socket.dontRoute.rawValue == WinSDK.SO_DONTROUTE)
    #expect(Socket.linger.rawValue == WinSDK.SO_LINGER)
    #expect(Socket.broadcast.rawValue == WinSDK.SO_BROADCAST)
    #expect(Socket.sendBufferSize.rawValue == WinSDK.SO_SNDBUF)
    #expect(Socket.receiveBufferSize.rawValue == WinSDK.SO_RCVBUF)
    #expect(Socket.error.rawValue == WinSDK.SO_ERROR)
    #expect(Socket.type.rawValue == WinSDK.SO_TYPE)
    #expect(Socket.receiveTimeout.rawValue == WinSDK.SO_RCVTIMEO)
    #expect(Socket.sendTimeout.rawValue == WinSDK.SO_SNDTIMEO)
    // SO_EXCLUSIVEADDRUSE is ((int)(~SO_REUSEADDR)), which doesn't import.
    #expect(Socket.exclusiveAddressUse.rawValue == ~WinSDK.SO_REUSEADDR)
    #expect(Socket.reuseUnicastPort.rawValue == WinSDK.SO_REUSE_UNICASTPORT)

    typealias TCP = SocketDescriptor.TCPOption
    #expect(TCP.noDelay.rawValue == WinSDK.TCP_NODELAY)
    #expect(TCP.maxSegmentSize.rawValue == WinSDK.TCP_MAXSEG)
    #expect(TCP.keepAliveIdle.rawValue == WinSDK.TCP_KEEPIDLE)
    #expect(TCP.keepAliveInterval.rawValue == WinSDK.TCP_KEEPINTVL)
    #expect(TCP.keepAliveCount.rawValue == WinSDK.TCP_KEEPCNT)

    typealias IP = SocketDescriptor.IPOption
    #expect(IP.timeToLive.rawValue == WinSDK.IP_TTL)
    #expect(IP.typeOfService.rawValue == WinSDK.IP_TOS)
    #expect(IP.receiveTypeOfService.rawValue == WinSDK.IP_RECVTOS)
    #expect(IP.packetInfo.rawValue == WinSDK.IP_PKTINFO)
    #expect(IP.receivePacketInfo.rawValue == WinSDK.IP_PKTINFO)
    #expect(IP.headerIncluded.rawValue == WinSDK.IP_HDRINCL)
    #expect(IP.multicastInterface.rawValue == WinSDK.IP_MULTICAST_IF)
    #expect(IP.multicastTimeToLive.rawValue == WinSDK.IP_MULTICAST_TTL)
    #expect(IP.multicastLoopback.rawValue == WinSDK.IP_MULTICAST_LOOP)
    #expect(IP.addMembership.rawValue == WinSDK.IP_ADD_MEMBERSHIP)
    #expect(IP.dropMembership.rawValue == WinSDK.IP_DROP_MEMBERSHIP)

    typealias IPv6 = SocketDescriptor.IPv6Option
    #expect(IPv6.v6Only.rawValue == WinSDK.IPV6_V6ONLY)
    #expect(IPv6.unicastHops.rawValue == WinSDK.IPV6_UNICAST_HOPS)
    #expect(IPv6.trafficClass.rawValue == WinSDK.IPV6_TCLASS)
    #expect(IPv6.receiveTrafficClass.rawValue == WinSDK.IPV6_RECVTCLASS)
    #expect(IPv6.packetInfo.rawValue == WinSDK.IPV6_PKTINFO)
    #expect(IPv6.receivePacketInfo.rawValue == WinSDK.IPV6_PKTINFO)
    #expect(IPv6.multicastInterface.rawValue == WinSDK.IPV6_MULTICAST_IF)
    #expect(IPv6.multicastHops.rawValue == WinSDK.IPV6_MULTICAST_HOPS)
    #expect(IPv6.multicastLoopback.rawValue == WinSDK.IPV6_MULTICAST_LOOP)
    #expect(IPv6.joinGroup.rawValue == WinSDK.IPV6_JOIN_GROUP)
    #expect(IPv6.leaveGroup.rawValue == WinSDK.IPV6_LEAVE_GROUP)
  }

  @available(System 199, *)
  @Test func socketAndTCPOptions() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    #expect(try socket.getSocketOption(.type) == WinSDK.SOCK_STREAM)
    #expect(try socket.getSocketOption(.error) == 0)

    try socket.setReuseAddress()
    #expect(try socket.getSocketOption(.reuseAddress) != 0)
    try socket.setNoDelay()
    #expect(try socket.getTCPOption(.noDelay) != 0)
    try socket.setNoDelay(false)
    #expect(try socket.getTCPOption(.noDelay) == 0)

    try socket.setSocketOption(.receiveBufferSize, to: 65536)
    #expect(try socket.getSocketOption(.receiveBufferSize) == 65536)

    // Windows 10 version 1709 and later.
    try socket.setSocketOption(.keepAlive, to: 1)
    try socket.setTCPOption(.keepAliveIdle, to: 30)
    try socket.setTCPOption(.keepAliveInterval, to: 5)
    try socket.setTCPOption(.keepAliveCount, to: 3)
    #expect(try socket.getTCPOption(.keepAliveIdle) == 30)
    #expect(try socket.getTCPOption(.keepAliveInterval) == 5)
    #expect(try socket.getTCPOption(.keepAliveCount) == 3)
  }

  @available(System 199, *)
  @Test func exclusiveAddressUse() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    try socket.setSocketOption(.exclusiveAddressUse, to: 1)
    #expect(try socket.getSocketOption(.exclusiveAddressUse) != 0)
  }

  // Winsock's time-outs are DWORD milliseconds.
  @available(System 199, *)
  @Test func timeouts() throws {
    let socket = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? socket.close() }
    #expect(try socket.receiveTimeout() == nil)
    try socket.setReceiveTimeout(.milliseconds(250))
    #expect(try socket.receiveTimeout() == .milliseconds(250))
    let raw: DWORD = try socket.getOption(.socket, WinSDK.SO_RCVTIMEO)
    #expect(raw == 250)
    // Rounded up to a millisecond, and zero is the shortest, not none.
    try socket.setReceiveTimeout(.microseconds(1500))
    #expect(try socket.receiveTimeout() == .milliseconds(2))
    try socket.setReceiveTimeout(.zero)
    #expect(try socket.receiveTimeout() == .milliseconds(1))
    try socket.setReceiveTimeout(nil)
    #expect(try socket.receiveTimeout() == nil)

    try socket.setSendTimeout(.seconds(2))
    #expect(try socket.sendTimeout() == .seconds(2))
  }

  @available(System 199, *)
  @Test func receiveTimesOut() throws {
    let socket = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? socket.close() }
    try socket.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try socket.setReceiveTimeout(.milliseconds(50))
    var byte: UInt8 = 0
    #expect(throws: Win32.Error.timedOut) {
      try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
        try socket.receive(into: buffer)
      }
    }
  }

  @available(System 199, *)
  @Test func linger() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    #expect(try socket.linger() == nil)
    try socket.setLinger(.seconds(3))
    #expect(try socket.linger() == .seconds(3))
    let value: CInterop.Linger = try socket.getOption(.socket, SocketDescriptor.SocketOption.linger.rawValue)
    #expect(value.isEnabled && value.time == 3)
    // Rounded up to a second.
    try socket.setLinger(.milliseconds(1500))
    #expect(try socket.linger() == .seconds(2))
    try socket.setLinger(nil)
    #expect(try socket.linger() == nil)
  }

  @available(System 199, *)
  @Test func ipv4Options() throws {
    let socket = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? socket.close() }
    try socket.setTimeToLive(42)
    #expect(try socket.timeToLive() == 42)
    try socket.setMulticastTimeToLive(5)
    #expect(try socket.multicastTimeToLive() == 5)
    #expect(try socket.ipv4MulticastLoopback())
    try socket.setIPv4MulticastLoopback(false)
    #expect(try !socket.ipv4MulticastLoopback())
    #expect(try socket.ipv4MulticastInterface() == .any)
    try socket.setReceivesIPv4PacketInfo(true)
    #expect(try socket.receivesIPv4PacketInfo())
  }

  @available(System 199, *)
  @Test func ipv6Options() throws {
    let socket = try SocketDescriptor.open(.ipv6, .datagram)
    defer { try? socket.close() }
    // Windows' default, as Darwin's.
    #expect(try socket.isIPv6Only())
    try socket.setIPv6Only(false)
    #expect(try !socket.isIPv6Only())
    try socket.setUnicastHops(64)
    #expect(try socket.unicastHops() == 64)
    try socket.setMulticastHops(3)
    #expect(try socket.multicastHops() == 3)
    try socket.setIPv6MulticastLoopback(false)
    #expect(try !socket.ipv6MulticastLoopback())
    #expect(try socket.ipv6MulticastInterface() == 0)
    try socket.setReceivesIPv6PacketInfo(true)
    #expect(try socket.receivesIPv6PacketInfo())
  }

  // A group joined on the loopback interface, which a datagram sent from
  // the loopback interface reaches, looped back to this host.
  @available(System 199, *)
  @Test func multicastOnLoopback() throws {
    let group = try #require(IPv4Address.Host("239.255.42.99"))
    let receiver = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? receiver.close() }
    try receiver.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var bound = SocketAddress()
    try receiver.getLocalAddress(into: &bound)
    let port = try #require(bound.ipv4?.port)
    try receiver.joinMulticastGroup(group, interface: .loopback)
    try receiver.setReceiveTimeout(.seconds(2))

    let sender = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? sender.close() }
    try sender.setIPv4MulticastInterface(.loopback)
    #expect(try sender.ipv4MulticastInterface() == .loopback)
    _ = try [UInt8(9)].withUnsafeBytes { bytes throws(Win32.Error) in
      try sender.send(bytes, to: SocketAddress(ipv4: IPv4Address(host: group, port: port)))
    }
    var byte: UInt8 = 0
    let count = try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
      try receiver.receive(into: buffer)
    }
    #expect(count == 1 && byte == 9)
    try receiver.leaveMulticastGroup(group, interface: .loopback)
  }
}

#endif // os(Windows)
