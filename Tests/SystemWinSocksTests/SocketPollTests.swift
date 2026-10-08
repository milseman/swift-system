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

// WSAPoll over loopback connections of the test's own, on ports the system
// picks. Every wait has a time-out, so a test that's wrong fails rather
// than hangs.
@Suite("Polling (Winsock)")
private struct SocketPollTests {
  @available(System 199, *)
  @Test func eventsMatchTheSDK() {
    typealias Events = SocketDescriptor.PollEvents
    #expect(Events.readable.rawValue == CShort(WinSDK.POLLIN))
    #expect(Events.writable.rawValue == CShort(WinSDK.POLLOUT))
    #expect(Events.readableNormalData.rawValue == CShort(WinSDK.POLLRDNORM))
    #expect(Events.readablePriorityData.rawValue == CShort(WinSDK.POLLRDBAND))
    #expect(Events.writableNormalData.rawValue == CShort(WinSDK.POLLWRNORM))
    #expect(Events.writablePriorityData.rawValue == CShort(WinSDK.POLLWRBAND))
    #expect(Events.error.rawValue == CShort(WinSDK.POLLERR))
    #expect(Events.hangUp.rawValue == CShort(WinSDK.POLLHUP))
    #expect(Events.invalidDescriptor.rawValue == CShort(WinSDK.POLLNVAL))
    #expect(Events.readableNormalData.description == "[.readableNormalData]")
    #expect(Events([.readable, .hangUp]).description == "[.readable, .hangUp]")
  }

  @available(System 199, *)
  @Test func millisecondsRoundUp() {
    #expect(SocketDescriptor._pollMilliseconds(timeout: nil) == -1)
    #expect(SocketDescriptor._pollMilliseconds(timeout: .zero) == 0)
    #expect(SocketDescriptor._pollMilliseconds(timeout: .seconds(-1)) == 0)
    #expect(SocketDescriptor._pollMilliseconds(timeout: .microseconds(1)) == 1)
    #expect(SocketDescriptor._pollMilliseconds(timeout: .milliseconds(1500)) == 1500)
    #expect(SocketDescriptor._pollMilliseconds(timeout: .seconds(Int64.max)) == CInt.max)
  }

  /// A connected loopback pair: the listener, the client, and the accepted
  /// server end.
  @available(System 199, *)
  private static func connection() throws(Win32.Error)
    -> (listener: SocketDescriptor, client: SocketDescriptor, server: SocketDescriptor)
  {
    let listener = try SocketDescriptor.open(.ipv4, .stream)
    var succeeded = false
    defer { if !succeeded { try? listener.close() } }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { if !succeeded { try? client.close() } }
    try client.connect(to: address)
    let server = try listener.accept()
    succeeded = true
    return (listener, client, server)
  }

  @available(System 199, *)
  @Test func readinessOfAConnection() throws {
    let (listener, client, server) = try Self.connection()
    // The client is closed once, below or here: a second close could close
    // a socket that another test has since been given the same handle.
    var clientIsOpen = true
    defer {
      try? server.close()
      if clientIsOpen { try? client.close() }
      try? listener.close()
    }
    #expect(try client.poll(for: .writable, timeout: .seconds(5)).contains(.writable))
    #expect(try server.poll(for: .readableNormalData, timeout: .zero) == [])

    _ = try [UInt8(5)].withUnsafeBytes { bytes throws(Win32.Error) in try client.send(bytes) }
    #expect(try server.poll(for: .readableNormalData, timeout: .seconds(5)) == .readableNormalData)

    // A closed peer: hung up, or readable with the end of the stream.
    var byte: UInt8 = 0
    _ = try withUnsafeMutableBytes(of: &byte) { buffer throws(Win32.Error) in
      try server.receive(into: buffer)
    }
    clientIsOpen = false
    try client.close()
    let events = try server.poll(for: .readableNormalData, timeout: .seconds(5))
    #expect(!events.isDisjoint(with: [.hangUp, .readableNormalData]))
  }

  // A listening socket is readable while a connection waits to be accepted.
  @available(System 199, *)
  @Test func pendingConnectionsAreReadable() throws {
    let listener = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    #expect(try listener.poll(for: .readableNormalData, timeout: .zero) == [])

    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? client.close() }
    try client.connect(to: address)
    #expect(try listener.poll(for: .readableNormalData, timeout: .seconds(5)) == .readableNormalData)
  }

  @available(System 199, *)
  @Test func pollingSeveralSockets() throws {
    let (listener, client, server) = try Self.connection()
    defer {
      try? server.close()
      try? client.close()
      try? listener.close()
    }
    _ = try [UInt8(1)].withUnsafeBytes { bytes throws(Win32.Error) in try client.send(bytes) }
    var entries = [
      SocketDescriptor.PollEntry(client, events: .readableNormalData),
      SocketDescriptor.PollEntry(server, events: .readableNormalData),
    ]
    var span = entries.mutableSpan
    let ready = try SocketDescriptor.poll(&span, timeout: .seconds(5))
    #expect(ready == 1)
    #expect(entries[0].returnedEvents == [])
    #expect(entries[1].returnedEvents == .readableNormalData)
    #expect(entries[1].socket == server)
  }
}

#endif // os(Windows)
