/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && ENABLE_MOCKING

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

@testable import SystemSockets
import SystemPackage

// The level, name, and value size that each typed option passes to
// setsockopt, which records (socket, level, name, value, length).
@Suite("IP option mocks")
private struct SocketIPOptionsMockTests {
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test func settersPassTheirLevelNameAndSize() throws {
    let socket = SocketDescriptor(rawValue: 5)
    let ip = CInt(IPPROTO_IP), ipv6 = CInt(IPPROTO_IPV6)
    let int = MemoryLayout<CInt>.size, byte = 1
    #if SYSTEM_PACKAGE_DARWIN
    let (receivePacketInfo, receivePacketInfo6, linger) = (IP_RECVPKTINFO, CInt(61), SO_LINGER_SEC)
    #else
    let (receivePacketInfo, receivePacketInfo6, linger) = (IP_PKTINFO, IPV6_RECVPKTINFO, SO_LINGER)
    #endif
    let cases: [(String, CInt, CInt, Int, () throws -> Void)] = [
      ("IP_TTL", ip, IP_TTL, int, { try socket.setTimeToLive(64) }),
      ("IP_TOS", ip, IP_TOS, int, { try socket.setTypeOfService(2) }),
      ("IP_RECVTOS", ip, IP_RECVTOS, int, { try socket.setReceivesTypeOfService(true) }),
      ("IP_RECVPKTINFO", ip, receivePacketInfo, int, { try socket.setReceivesIPv4PacketInfo(true) }),
      ("IP_HDRINCL", ip, IP_HDRINCL, int, { try socket.setIncludesIPHeader(true) }),
      ("IP_MULTICAST_TTL", ip, IP_MULTICAST_TTL, byte, { try socket.setMulticastTimeToLive(2) }),
      ("IP_MULTICAST_LOOP", ip, IP_MULTICAST_LOOP, byte, { try socket.setIPv4MulticastLoopback(true) }),
      ("IP_MULTICAST_IF", ip, IP_MULTICAST_IF, 4, { try socket.setIPv4MulticastInterface(.any) }),
      ("IP_ADD_MEMBERSHIP", ip, IP_ADD_MEMBERSHIP, 8, { try socket.joinMulticastGroup(.broadcast) }),
      ("IP_DROP_MEMBERSHIP", ip, IP_DROP_MEMBERSHIP, 8, { try socket.leaveMulticastGroup(.broadcast) }),
      ("IPV6_V6ONLY", ipv6, IPV6_V6ONLY, int, { try socket.setIPv6Only(true) }),
      ("IPV6_UNICAST_HOPS", ipv6, IPV6_UNICAST_HOPS, int, { try socket.setUnicastHops(3) }),
      ("IPV6_TCLASS", ipv6, IPV6_TCLASS, int, { try socket.setTrafficClass(1) }),
      ("IPV6_RECVTCLASS", ipv6, IPV6_RECVTCLASS, int, { try socket.setReceivesTrafficClass(true) }),
      ("IPV6_RECVPKTINFO", ipv6, receivePacketInfo6, int, { try socket.setReceivesIPv6PacketInfo(true) }),
      ("IPV6_MULTICAST_HOPS", ipv6, IPV6_MULTICAST_HOPS, int, { try socket.setMulticastHops(2) }),
      ("IPV6_MULTICAST_LOOP", ipv6, IPV6_MULTICAST_LOOP, int, { try socket.setIPv6MulticastLoopback(true) }),
      ("IPV6_MULTICAST_IF", ipv6, IPV6_MULTICAST_IF, int, { try socket.setIPv6MulticastInterface(1) }),
      ("IPV6_JOIN_GROUP", ipv6, IPV6_JOIN_GROUP, 20, { try socket.joinMulticastGroup(IPv6Address.Host.any) }),
      ("IPV6_LEAVE_GROUP", ipv6, IPV6_LEAVE_GROUP, 20, { try socket.leaveMulticastGroup(IPv6Address.Host.any) }),
      ("SO_RCVTIMEO", SOL_SOCKET, SO_RCVTIMEO, MemoryLayout<timeval>.size, { try socket.setReceiveTimeout(.seconds(1)) }),
      ("SO_SNDTIMEO", SOL_SOCKET, SO_SNDTIMEO, MemoryLayout<timeval>.size, { try socket.setSendTimeout(nil) }),
      ("SO_LINGER", SOL_SOCKET, linger, 8, { try socket.setLinger(.seconds(1)) }),
      ("SO_TIMESTAMP", SOL_SOCKET, SO_TIMESTAMP, int, { try socket.setReceivesTimestamps(true) }),
    ]
    try MockingDriver.withMockingEnabled { mocking in
      for (name, level, option, size, set) in cases {
        try set()
        let entry = mocking.trace.dequeue()
        #expect(entry?.name == "setsockopt", "\(name)")
        let arguments = entry?.arguments ?? []
        #expect(arguments.count == 5, "\(name)")
        guard arguments.count == 5 else { continue }
        #expect(arguments[0] == AnyHashable(CInt(5)), "\(name)")
        #expect(arguments[1] == AnyHashable(level), "\(name)")
        #expect(arguments[2] == AnyHashable(option), "\(name)")
        #expect(arguments[4] == AnyHashable(CInterop.SockLen(size)), "\(name)")
      }
      #expect(mocking.trace.dequeue() == nil)
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
