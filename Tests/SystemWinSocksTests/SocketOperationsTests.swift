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

// Each test binds only loopback addresses (127.0.0.1 and ::1) to ports the
// system picks, and connects only to its own sockets, which it closes:
// nothing here reaches beyond this host, or listens where the firewall
// would ask about it.
@Suite("Socket Operations (Winsock)")
private struct SocketOperationsTests {
  /// A listening TCP socket on a loopback port the system picks, its
  /// address, and a client connected to it.
  @available(System 199, *)
  private static func connectedPair(
    ipv6: Bool = false
  ) throws(Win32.Error) -> (listener: SocketDescriptor, address: SocketAddress, client: SocketDescriptor) {
    let listener = try SocketDescriptor.open(ipv6 ? .ipv6 : .ipv4, .stream)
    var succeeded = false
    defer { if !succeeded { try? listener.close() } }
    try listener.bind(to: ipv6
      ? SocketAddress(ipv6: .loopback(port: 0)) : SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    let client = try SocketDescriptor.open(ipv6 ? .ipv6 : .ipv4, .stream)
    defer { if !succeeded { try? client.close() } }
    try client.connect(to: address)
    succeeded = true
    return (listener, address, client)
  }

  @available(System 199, *)
  @Test func tcpRoundTrip() throws {
    let (listener, address, client) = try Self.connectedPair()
    defer {
      try? client.close()
      try? listener.close()
    }
    #expect(address.ipv4?.host == .loopback)
    #expect(address.ipv4?.port != 0)

    var clientAddress = SocketAddress()
    let server = try listener.accept(client: &clientAddress)
    defer { try? server.close() }
    #expect(clientAddress.ipv4?.host == .loopback)

    var peer = SocketAddress()
    try client.getPeerAddress(into: &peer)
    #expect(peer == address)

    let message: [UInt8] = Array("hello".utf8)
    let sent = try message.withUnsafeBytes { bytes throws(Win32.Error) in
      try client.send(bytes)
    }
    #expect(sent == message.count)
    // With waitForAll, the receive waits for the whole buffer, which the
    // message fills.
    var received = [UInt8](repeating: 0, count: message.count)
    let count = try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
      try server.receive(into: buffer, flags: .waitForAll)
    }
    #expect(count == message.count && received == message)

    // The client's shutdown is the server's end of the stream.
    try client.shutdown(.write)
    let end = try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
      try server.receive(into: buffer)
    }
    #expect(end == 0)
  }

  @available(System 199, *)
  @Test func tcpRoundTripOverIPv6() throws {
    let (listener, address, client) = try Self.connectedPair(ipv6: true)
    defer {
      try? client.close()
      try? listener.close()
    }
    #expect(address.ipv6?.host == .loopback)
    let server = try listener.accept()
    defer { try? server.close() }

    let sent = try [UInt8(42)].withUnsafeBytes { bytes throws(Win32.Error) in
      try server.send(bytes)
    }
    #expect(sent == 1)
    var byte: UInt8 = 0
    let count = try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
      try client.receive(into: buffer)
    }
    #expect(count == 1 && byte == 42)
  }

  // accept's socket isn't inherited, as open's aren't.
  @available(System 199, *)
  @Test func acceptedSocketsAreNotInherited() throws {
    let (listener, _, client) = try Self.connectedPair()
    defer {
      try? client.close()
      try? listener.close()
    }
    let server = try listener.accept()
    defer { try? server.close() }
    let handle = try #require(HANDLE(bitPattern: UInt(server.rawValue)))
    var flags: DWORD = 0
    #expect(WinSDK.GetHandleInformation(handle, &flags))
    #expect(flags & WinSDK.HANDLE_FLAG_INHERIT == 0)
  }

  // A connected stream's data has no sender: the address comes back empty,
  // as on POSIX, though Winsock leaves it untouched.
  @available(System 199, *)
  @Test func streamReceivesHaveNoSender() throws {
    let (listener, _, client) = try Self.connectedPair()
    defer {
      try? client.close()
      try? listener.close()
    }
    let server = try listener.accept()
    defer { try? server.close() }
    _ = try [UInt8(7)].withUnsafeBytes { bytes throws(Win32.Error) in try client.send(bytes) }
    var sender = SocketAddress(ipv4: .loopback(port: 1))
    var byte: UInt8 = 0
    let count = try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
      try server.receive(into: buffer, sender: &sender)
    }
    #expect(count == 1)
    #expect(sender.isEmpty)
  }

  @available(System 199, *)
  @Test func udpRoundTrip() throws {
    let first = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? first.close() }
    let second = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? second.close() }
    try first.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try second.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var firstAddress = SocketAddress()
    try first.getLocalAddress(into: &firstAddress)
    var secondAddress = SocketAddress()
    try second.getLocalAddress(into: &secondAddress)

    let message: [UInt8] = [1, 2, 3, 4]
    let sent = try message.withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    #expect(sent == 4)
    var received = [UInt8](repeating: 0, count: 8)
    var sender = SocketAddress()
    let count = try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
      try second.receive(into: buffer, sender: &sender)
    }
    #expect(Array(received.prefix(count)) == message)
    #expect(sender == firstAddress)
  }

  // Unlike POSIX's, Winsock's receive of a datagram that doesn't fit
  // fails, after filling the buffer.
  @available(System 199, *)
  @Test func datagramsThatDontFitThrow() throws {
    let first = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? first.close() }
    let second = try SocketDescriptor.open(.ipv4, .datagram)
    defer { try? second.close() }
    try second.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var secondAddress = SocketAddress()
    try second.getLocalAddress(into: &secondAddress)

    _ = try [UInt8](1...8).withUnsafeBytes { bytes throws(Win32.Error) in
      try first.send(bytes, to: secondAddress)
    }
    var received = [UInt8](repeating: 0, count: 4)
    #expect(throws: Win32.Error.messageTooLong) {
      try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
        try second.receive(into: buffer)
      }
    }
    #expect(received == [1, 2, 3, 4])
  }

  // A loopback port that a socket holds without listening refuses
  // connections.
  @available(System 199, *)
  @Test func connectingToAPortNoOneListensOnIsRefused() throws {
    let holder = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? holder.close() }
    try holder.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var address = SocketAddress()
    try holder.getLocalAddress(into: &address)

    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? client.close() }
    #expect(throws: Win32.Error.connectionRefused) {
      try client.connect(to: address)
    }
  }

  @available(System 199, *)
  @Test func namesOfUnboundAndUnconnectedSockets() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    var address = SocketAddress()
    #expect(throws: Win32.Error.invalidArgument) {
      try socket.getLocalAddress(into: &address)
    }
    #expect(throws: Win32.Error.socketNotConnected) {
      try socket.getPeerAddress(into: &address)
    }
  }

  @available(System 199, *)
  @Test func writeAllAndCloseAfter() throws {
    let (listener, _, client) = try Self.connectedPair()
    defer { try? listener.close() }
    let server = try listener.accept()
    defer { try? server.close() }

    // Sixteen KiB, which loopback's buffers hold without a reader.
    let message = (0 ..< 16384).map { UInt8(truncatingIfNeeded: $0) }
    let written = try client.closeAfter {
      try client.writeAll(message)
    }
    #expect(written == message.count)
    var received = [UInt8](repeating: 0, count: message.count)
    let count = try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
      try server.receive(into: buffer, flags: .waitForAll)
    }
    #expect(count == message.count && received == message)
    // closeAfter closed the client, which ends the stream. (Closing it
    // again would close whatever socket another test has since been given
    // the same handle.)
    let end = try received.withUnsafeMutableBytes { buffer throws(Win32.Error) in
      try server.receive(into: buffer)
    }
    #expect(end == 0)
  }

  @available(System 199, *)
  @Test func bindingAnAddressInUseFails() throws {
    let first = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? first.close() }
    try first.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var address = SocketAddress()
    try first.getLocalAddress(into: &address)

    let second = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? second.close() }
    #expect(throws: Win32.Error.addressInUse) {
      try second.bind(to: address)
    }
  }
}

#endif // os(Windows)
