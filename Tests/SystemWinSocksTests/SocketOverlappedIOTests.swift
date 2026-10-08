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

// Overlapped sends and receives on a loopback connection of the test's own,
// reported through a completion port of its own. Each OVERLAPPED and buffer
// is deallocated only once its operation's packet has been dequeued, and
// every dequeue has a time-out.
@Suite("Overlapped sockets (Winsock)")
private struct SocketOverlappedIOTests {
  @available(System 199, *)
  @Test func constantsMatchTheSDK() {
    #expect(_WSA_IO_INCOMPLETE == DWORD(WinSDK.WSA_IO_INCOMPLETE))
    #expect(_ERROR_NOT_FOUND == DWORD(WinSDK.ERROR_NOT_FOUND))
    #expect(Win32.Error.ioPending.rawValue == DWORD(WinSDK.WSA_IO_PENDING))
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

  /// A zeroed OVERLAPPED of its own, freed after `body`.
  private static func withOverlapped<R>(
    _ body: (UnsafeMutablePointer<OVERLAPPED>) throws -> R
  ) rethrows -> R {
    let overlapped = UnsafeMutablePointer<OVERLAPPED>.allocate(capacity: 1)
    overlapped.initialize(to: OVERLAPPED())
    defer { overlapped.deallocate() }
    return try body(overlapped)
  }

  @available(System 199, *)
  @Test func receivingThroughACompletionPort() throws {
    let (listener, client, server) = try Self.connection()
    defer {
      try? server.close()
      try? client.close()
      try? listener.close()
    }
    let port = try Win32.CompletionPort.create()
    try port.associate(server, key: 7)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    try Self.withOverlapped { overlapped in
      // Nothing has been sent, so the receive is pending.
      #expect(try server.receive(into: buffer, overlapped: overlapped) == nil)
      #expect(try server.result(of: overlapped, wait: false) == nil)

      _ = try [UInt8(1), 2, 3].withUnsafeBytes { bytes in try client.send(bytes) }
      let completion = try #require(try port.dequeue(timeout: .seconds(5)))
      #expect(completion.key == 7)
      #expect(completion.overlapped == overlapped)
      #expect(completion.error == nil)
      #expect(completion.bytesTransferred == 3)
      #expect(Array(buffer.prefix(3)) == [1, 2, 3])
      #expect(try server.result(of: overlapped, wait: false) == 3)
    }
  }

  // A send that finishes at once still queues a packet.
  @available(System 199, *)
  @Test func sendingThroughACompletionPort() throws {
    let (listener, client, server) = try Self.connection()
    defer {
      try? server.close()
      try? client.close()
      try? listener.close()
    }
    let port = try Win32.CompletionPort.create()
    try port.associate(client, key: 9)
    let message: [UInt8] = [4, 5, 6, 7]

    try message.withUnsafeBytes { bytes in
      try Self.withOverlapped { overlapped in
        let sent = try client.send(bytes, overlapped: overlapped)
        #expect(sent == nil || sent == 4)
        let completion = try #require(try port.dequeue(timeout: .seconds(5)))
        #expect(completion.key == 9 && completion.overlapped == overlapped)
        #expect(completion.bytesTransferred == 4)
      }
    }
    var received = [UInt8](repeating: 0, count: 4)
    let count = try received.withUnsafeMutableBytes { buffer in
      try server.receive(into: buffer, flags: .waitForAll)
    }
    #expect(count == 4 && received == message)
  }

  @available(System 199, *)
  @Test func cancelingAPendingReceive() throws {
    let (listener, client, server) = try Self.connection()
    defer {
      try? server.close()
      try? client.close()
      try? listener.close()
    }
    let port = try Win32.CompletionPort.create()
    try port.associate(server, key: 1)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    try Self.withOverlapped { overlapped in
      #expect(try server.receive(into: buffer, overlapped: overlapped) == nil)
      #expect(try server.cancel(overlapped))
      let completion = try #require(try port.dequeue(timeout: .seconds(5)))
      #expect(completion.overlapped == overlapped)
      #expect(completion.error == .operationAborted)
      #expect(throws: Win32.Error.operationAborted) {
        try server.result(of: overlapped, wait: false)
      }
    }
    #expect(try !server.cancelAll())
  }

  @available(System 199, *)
  @Test func associatingTwiceFails() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    let first = try Win32.CompletionPort.create()
    let second = try Win32.CompletionPort.create()
    try first.associate(socket, key: 0)
    #expect(throws: Win32.Error.invalidParameter) {
      try second.associate(socket, key: 0)
    }
  }
}

#endif // os(Windows)
