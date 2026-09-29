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

@Suite("Socket open options")
private struct SocketOpenOptionsTests {
  @available(System 199, *)
  private func flags(of socket: SocketDescriptor) throws -> (closeOnExec: Bool, nonBlocking: Bool) {
    (
      try socket.fileDescriptor.descriptorFlags().contains(.closeOnExec),
      try socket.fileDescriptor.statusFlags().contains(.nonBlocking)
    )
  }

  @available(System 199, *)
  @Test func openSetsTheOptions() throws {
    for options: SocketDescriptor.OpenOptions in [[], .closeOnExec, .nonBlocking, [.closeOnExec, .nonBlocking]] {
      let socket = try SocketDescriptor.open(.local, .stream, options: options)
      defer { try? socket.close() }
      let set = try flags(of: socket)
      #expect(set.closeOnExec == options.contains(.closeOnExec), "\(options)")
      #expect(set.nonBlocking == options.contains(.nonBlocking), "\(options)")
    }
  }

  @available(System 199, *)
  @Test func pairSetsTheOptionsOnBoth() throws {
    let (first, second) = try SocketDescriptor.pair(
      .local, .stream, options: [.closeOnExec, .nonBlocking])
    defer {
      try? first.close()
      try? second.close()
    }
    #expect(try flags(of: first) == (true, true))
    #expect(try flags(of: second) == (true, true))
    let (plain, other) = try SocketDescriptor.pair(.local, .datagram, options: [])
    defer {
      try? plain.close()
      try? other.close()
    }
    #expect(try flags(of: plain) == (false, false))
  }

  /// The accepted socket gets exactly the options asked for, even from a
  /// nonblocking listener, whose mode Darwin's accept passes on.
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test(.requiresSocketBinding) func acceptSetsExactlyTheOptions() throws {
    let listener = try SocketDescriptor.open(.ipv4, .stream, options: [.closeOnExec, .nonBlocking])
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var bound = SocketAddress()
    try listener.getLocalAddress(into: &bound)
    let port = try #require(bound.ipv4?.port)

    func connect() throws -> SocketDescriptor {
      let client = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
      try client.connect(to: SocketAddress(ipv4: .loopback(port: port)))
      return client
    }

    // A connection can reach the listener's queue a moment after connect()
    // returns, and the nonblocking listener doesn't wait for it. The
    // listener is readable while a connection is queued, so accept waits
    // for that.
    func accepting<T>(_ accept: () throws -> T) throws -> T {
      #expect(
        try listener.fileDescriptor.poll(for: .readable, timeout: .seconds(hangGuardSeconds))
          .contains(.readable))
      return try accept()
    }

    let first = try connect()
    defer { try? first.close() }
    let blocking = try accepting { try listener.accept(options: []) }
    defer { try? blocking.close() }
    #expect(try flags(of: blocking) == (false, false))

    let second = try connect()
    defer { try? second.close() }
    var client = SocketAddress()
    let nonBlocking = try accepting {
      try listener.accept(client: &client, options: [.closeOnExec, .nonBlocking])
    }
    defer { try? nonBlocking.close() }
    #expect(try flags(of: nonBlocking) == (true, true))
    #expect(client.ipv4?.addressString == "127.0.0.1")

    // With no connection waiting, the nonblocking listener doesn't wait.
    #expect(throws: Errno.wouldBlock) { try listener.accept(options: .closeOnExec) }
  }

  @available(System 199, *)
  @Test func description() {
    #expect(SocketDescriptor.OpenOptions([.closeOnExec, .nonBlocking]).description
      == "[.nonBlocking, .closeOnExec]")
  }
}

#endif // !os(Windows)
