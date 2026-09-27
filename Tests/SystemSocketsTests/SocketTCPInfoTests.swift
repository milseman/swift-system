/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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
#if ENABLE_MOCKING
@testable import SystemSockets
#else
import SystemSockets
#endif

@Suite("TCP connection information")
private struct SocketTCPInfoTests {
  @available(System 199, *)
  private func state(of socket: SocketDescriptor) throws -> SocketDescriptor.TCPState {
    #if SYSTEM_PACKAGE_DARWIN
    return try socket.tcpConnectionInfo().state
    #else
    return try socket.tcpInfo().state
    #endif
  }

  @available(System 199, *)
  @Test func aNewSocketIsClosed() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
    defer { try? socket.close() }
    #expect(try state(of: socket) == .closed)
    #expect(SocketDescriptor.TCPState.established.description == "established")
  }

  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test(.requiresSocketBinding) func aConnectionsLife() throws {
    let listener = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(ipv4: IPv4Address(host: .loopback, port: 0)))
    try listener.listen(backlog: 1)
    #expect(try state(of: listener) == .listen)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)

    let client = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
    defer { try? client.close() }
    try client.connect(to: address)
    let server = try listener.accept(options: .closeOnExec)
    defer { try? server.close() }
    #expect(try state(of: client) == .established)
    #expect(try state(of: server) == .established)

    let payload = [UInt8](repeating: 7, count: 1000)
    #expect(try payload.withUnsafeBytes { try client.send($0) } == 1000)
    var received = [UInt8](repeating: 0, count: 1000)
    var count = 0
    while count < 1000 {
      count += try received.withUnsafeMutableBytes {
        try server.receive(into: UnsafeMutableRawBufferPointer(rebasing: $0[count...]))
      }
    }

    #if SYSTEM_PACKAGE_DARWIN
    let info = try client.tcpConnectionInfo()
    #expect(info.bytesSent >= 1000)
    #expect(info.packetsSent > 0)
    #expect(info.maximumSegmentSize > 0)
    #expect(info.sendCongestionWindow > 0)
    // Darwin reports 0 for an idle connection.
    #expect(info.retransmitTimeout >= .zero)
    #expect(try server.tcpConnectionInfo().bytesReceived >= 1000)
    #else
    let info = try client.tcpInfo()
    #expect(info.sendMaximumSegmentSize > 0)
    #expect(info.sendCongestionWindow > 0)
    #expect(info.retransmitTimeout > .zero)
    // Linux 4.19 and later report these.
    #expect(try #require(info.bytesSent) >= 1000)
    // It can count the SYN's sequence number too.
    #expect(try #require(info.bytesAcknowledged) >= 1000)
    #expect(try #require(info.segmentsSent) > 0)
    #expect(try #require(info.minimumRoundTripTime) >= .zero)
    #expect(try #require(server.tcpInfo().bytesReceived) >= 1000)
    #endif
    // Loopback connections negotiate these on both.
    #expect(info.options.contains([.selectiveAcknowledgments, .windowScaling]))

    // The client closes, and the server's side waits for it to close too.
    try client.shutdown(.write)
    var byte: UInt8 = 0
    #expect(try withUnsafeMutableBytes(of: &byte) { try server.receive(into: $0) } == 0)
    #expect(try state(of: server) == .closeWait)
    // Once the server's acknowledgment arrives, which can take a moment.
    #expect(try [.finWait1, .finWait2].contains(state(of: client)))
  }

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func theCallsLevelNameAndSize() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let socket = SocketDescriptor(rawValue: 3)
      #if SYSTEM_PACKAGE_DARWIN
      _ = try socket.tcpConnectionInfo()
      let name = TCP_CONNECTION_INFO
      #else
      _ = try socket.tcpInfo()
      let name = TCP_INFO
      #endif
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "getsockopt")
      #expect(entry.map { Array($0.arguments.prefix(3)) } == [CInt(3), CInt(IPPROTO_TCP), name])
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
