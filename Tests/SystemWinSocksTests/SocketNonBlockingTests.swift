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

// Nonblocking sockets, over loopback addresses and ports the system picks,
// each socket the test's own. Winsock can't report a socket's mode, so the
// tests tell the modes apart by what a receive with nothing to read throws:
// a nonblocking socket throws wouldBlock at once, and a blocking one with a
// short receive time-out throws timedOut.
@Suite("Nonblocking sockets (Winsock)")
private struct SocketNonBlockingTests {
  @available(System 199, *)
  @Test func constantsMatchTheSDK() {
    #expect(_FIONBIO == WinSDK.FIONBIO)
    #expect(SocketDescriptor.OpenOptions.nonBlocking.description == "[.nonBlocking]")
    #expect(SocketDescriptor.OpenOptions().description == "[]")
  }

  /// A listening socket on a loopback port the system picks, and its address.
  @available(System 199, *)
  private static func listener(
    options: SocketDescriptor.OpenOptions = []
  ) throws(Win32.Error) -> (SocketDescriptor, SocketAddress) {
    let listener = try SocketDescriptor.open(.ipv4, .stream, options: options)
    var succeeded = false
    defer { if !succeeded { try? listener.close() } }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    succeeded = true
    return (listener, address)
  }

  /// Receives a byte, or throws.
  @available(System 199, *)
  private static func receiveByte(_ socket: SocketDescriptor) throws(Win32.Error) -> Int {
    var byte: UInt8 = 0
    return try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
      try socket.receive(into: buffer)
    }
  }

  @available(System 199, *)
  @Test func acceptingWithNoConnectionWouldBlock() throws {
    let (listener, _) = try Self.listener(options: .nonBlocking)
    defer { try? listener.close() }
    #expect(throws: Win32.Error.wouldBlock) {
      try listener.accept()
    }
  }

  @available(System 199, *)
  @Test func receivingWithNothingToReadWouldBlock() throws {
    let (listener, address) = try Self.listener()
    defer { try? listener.close() }
    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? client.close() }
    try client.connect(to: address)
    let server = try listener.accept()
    defer { try? server.close() }

    try server.setNonBlocking()
    #expect(throws: Win32.Error.wouldBlock) {
      try Self.receiveByte(server)
    }
    // Blocking again, the receive waits for the byte.
    try server.setNonBlocking(false)
    _ = try [UInt8(1)].withUnsafeBytes { bytes throws(Win32.Error) in try client.send(bytes) }
    #expect(try Self.receiveByte(server) == 1)
  }

  // The accepted socket's mode is the options', not the listener's.
  @available(System 199, *)
  @Test func acceptOptionsSetTheModeExactly() throws {
    let (listener, address) = try Self.listener(options: .nonBlocking)
    defer { try? listener.close() }
    let first = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? first.close() }
    try first.connect(to: address)
    let second = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? second.close() }
    try second.connect(to: address)

    let blocking = try listener.accept(options: [])
    defer { try? blocking.close() }
    try blocking.setReceiveTimeout(.milliseconds(50))
    #expect(throws: Win32.Error.timedOut) {
      try Self.receiveByte(blocking)
    }

    var client = SocketAddress()
    let nonBlocking = try listener.accept(client: &client, options: .nonBlocking)
    defer { try? nonBlocking.close() }
    #expect(client.ipv4?.host == .loopback)
    #expect(throws: Win32.Error.wouldBlock) {
      try Self.receiveByte(nonBlocking)
    }
  }

  // A nonblocking connect throws wouldBlock where POSIX throws EINPROGRESS,
  // unless it finishes at once; either way the blocking accept finishes it.
  @available(System 199, *)
  @Test func connectingWithoutBlocking() throws {
    let (listener, address) = try Self.listener()
    defer { try? listener.close() }
    let client = try SocketDescriptor.open(.ipv4, .stream, options: .nonBlocking)
    defer { try? client.close() }
    do throws(Win32.Error) {
      try client.connect(to: address)
    } catch {
      #expect(error == .wouldBlock)
    }
    let server = try listener.accept()
    defer { try? server.close() }
    #expect(try client.getSocketOption(.error) == 0)
  }
}

#endif // os(Windows)
