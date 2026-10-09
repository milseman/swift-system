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

// SystemWinSocks spells Winsock's constants as values; these hold each one
// to the SDK's macro. Names that macOS's C library also has are qualified,
// since the harness that compiles these files on macOS sees both.
@Suite("Winsock constants")
private struct WinsockConstantsTests {
  @available(System 199, *)
  @Test func internalConstantsMatchTheSDK() {
    #expect(_INVALID_SOCKET == WinSDK.INVALID_SOCKET)
    #expect(_SOCKET_ERROR == WinSDK.SOCKET_ERROR)
    #expect(_WSA_FLAG_OVERLAPPED == DWORD(WinSDK.WSA_FLAG_OVERLAPPED))
    #expect(_WSA_FLAG_NO_HANDLE_INHERIT == DWORD(WinSDK.WSA_FLAG_NO_HANDLE_INHERIT))
    #expect(_HANDLE_FLAG_INHERIT == WinSDK.HANDLE_FLAG_INHERIT)
  }

  @available(System 199, *)
  @Test func domainsMatchTheSDK() {
    #expect(SocketDescriptor.Domain.unspecified.rawValue == WinSDK.PF_UNSPEC)
    #expect(SocketDescriptor.Domain.local.rawValue == WinSDK.PF_UNIX)
    #expect(SocketDescriptor.Domain.ipv4.rawValue == WinSDK.PF_INET)
    #expect(SocketDescriptor.Domain.ipv6.rawValue == WinSDK.PF_INET6)
  }

  @available(System 199, *)
  @Test func connectionTypesMatchTheSDK() {
    #expect(SocketDescriptor.ConnectionType.stream.rawValue == WinSDK.SOCK_STREAM)
    #expect(SocketDescriptor.ConnectionType.datagram.rawValue == WinSDK.SOCK_DGRAM)
    #expect(SocketDescriptor.ConnectionType.raw.rawValue == WinSDK.SOCK_RAW)
    #expect(SocketDescriptor.ConnectionType.reliablyDeliveredMessage.rawValue == WinSDK.SOCK_RDM)
    #expect(SocketDescriptor.ConnectionType.sequencedPacketStream.rawValue == WinSDK.SOCK_SEQPACKET)
  }

  @available(System 199, *)
  @Test func protocolsMatchTheSDK() {
    // IPPROTO_IP is a macro; the rest are enumerators of IPPROTO.
    #expect(SocketDescriptor.ProtocolID.ip.rawValue == WinSDK.IPPROTO_IP)
    #expect(SocketDescriptor.ProtocolID.tcp.rawValue == WinSDK.IPPROTO_TCP.rawValue)
    #expect(SocketDescriptor.ProtocolID.udp.rawValue == WinSDK.IPPROTO_UDP.rawValue)
    #expect(SocketDescriptor.ProtocolID.ipv4.rawValue == WinSDK.IPPROTO_IPV4.rawValue)
    #expect(SocketDescriptor.ProtocolID.ipv6.rawValue == WinSDK.IPPROTO_IPV6.rawValue)
    #expect(SocketDescriptor.ProtocolID.raw.rawValue == WinSDK.IPPROTO_RAW.rawValue)
  }

  @available(System 199, *)
  @Test func messageFlagsMatchTheSDK() {
    #expect(SocketDescriptor.MessageFlags.outOfBand.rawValue == WinSDK.MSG_OOB)
    #expect(SocketDescriptor.MessageFlags.peek.rawValue == WinSDK.MSG_PEEK)
    #expect(SocketDescriptor.MessageFlags.doNotRoute.rawValue == WinSDK.MSG_DONTROUTE)
    #expect(SocketDescriptor.MessageFlags.waitForAll.rawValue == WinSDK.MSG_WAITALL)
    #expect(SocketDescriptor.MessageFlags.dataTruncated.rawValue == WinSDK.MSG_TRUNC)
    #expect(SocketDescriptor.MessageFlags.controlTruncated.rawValue == WinSDK.MSG_CTRUNC)
  }

  @available(System 199, *)
  @Test func shutdownKindsMatchTheSDK() {
    #expect(SocketDescriptor.ShutdownKind.read.rawValue == WinSDK.SD_RECEIVE)
    #expect(SocketDescriptor.ShutdownKind.write.rawValue == WinSDK.SD_SEND)
    #expect(SocketDescriptor.ShutdownKind.readWrite.rawValue == WinSDK.SD_BOTH)
  }

  @available(System 199, *)
  @Test func descriptions() {
    #expect(SocketDescriptor.Domain.ipv6.description == "ipv6")
    #expect(SocketDescriptor.Domain(rawValue: 99).description == "Domain(99)")
    #expect(SocketDescriptor.ConnectionType.datagram.description == "datagram")
    #expect(SocketDescriptor.ProtocolID.tcp.description == "6")
    let flags: SocketDescriptor.MessageFlags = [.peek, .outOfBand]
    #expect(flags.description == "[.outOfBand, .peek]")
    #expect(SocketDescriptor.ShutdownKind.write.description == "write")
  }
}

#endif // os(Windows)
