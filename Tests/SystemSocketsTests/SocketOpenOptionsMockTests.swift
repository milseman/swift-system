/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && ENABLE_MOCKING

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

// What open, pair, and accept call for their options: the flags of socket,
// socketpair, and accept4 on Linux, and fcntl after the call on Darwin.
@Suite("Socket open options mocks")
private struct SocketOpenOptionsMockTests {
  @available(System 199, *)
  @Test func openPassesOrSetsTheOptions() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try SocketDescriptor.open(.local, .stream, options: [.closeOnExec, .nonBlocking])
      let calls = drain(mocking)
      #if os(Linux) && canImport(Glibc)
      let stream = CInt(SOCK_STREAM.rawValue)
      #else
      let stream = SOCK_STREAM
      #endif
      #if SYSTEM_PACKAGE_DARWIN
      #expect(calls.map(\.name) == ["socket", "fcntl", "fcntl", "fcntl"])
      // A mocked socket is descriptor 0, whose mocked status flags are 0.
      #expect(calls.map(\.arguments) == [
        [PF_LOCAL, stream, 0], [0, F_SETFD, FD_CLOEXEC], [0, F_GETFL], [0, F_SETFL, O_NONBLOCK],
      ])
      #else
      let flags = SocketDescriptor.OpenOptions([.closeOnExec, .nonBlocking]).rawValue
      #expect(calls.map(\.name) == ["socket"])
      #expect(calls.first?.arguments == [PF_LOCAL, stream | flags, 0])
      #endif
    }
  }

  @available(System 199, *)
  @Test func noOptionsCallOnlySocket() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try SocketDescriptor.open(.local, .datagram, options: [])
      #expect(drain(mocking).map(\.name) == ["socket"])
    }
  }

  @available(System 199, *)
  @Test func pairSetsTheOptionsOnBoth() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try SocketDescriptor.pair(.local, .stream, options: .closeOnExec)
      #if SYSTEM_PACKAGE_DARWIN
      #expect(drain(mocking).map(\.name) == ["socketpair", "fcntl", "fcntl"])
      #else
      #expect(drain(mocking).map(\.name) == ["socketpair"])
      #endif
    }
  }

  @available(System 199, *)
  @Test func acceptPassesOrSetsTheOptions() throws {
    let listener = SocketDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      _ = try listener.accept(options: .nonBlocking)
      let calls = drain(mocking)
      #if SYSTEM_PACKAGE_DARWIN
      #expect(calls.map(\.name) == ["accept", "fcntl", "fcntl"])
      #expect(calls.dropFirst().map(\.arguments) == [[0, F_GETFL], [0, F_SETFL, O_NONBLOCK]])
      #else
      #expect(calls.map(\.name) == ["accept4"])
      #expect(calls.first?.arguments.first == AnyHashable(CInt(42)))
      #expect(calls.first?.arguments.last == AnyHashable(SocketDescriptor.OpenOptions.nonBlocking.rawValue))
      #endif

      // Without .nonBlocking, Darwin checks that the socket isn't
      // nonblocking, since accept passes on the listener's mode.
      _ = try listener.accept(options: [])
      #if SYSTEM_PACKAGE_DARWIN
      #expect(drain(mocking).map(\.name) == ["accept", "fcntl"])
      #else
      #expect(drain(mocking).map(\.name) == ["accept4"])
      #endif
    }
  }

  @available(System 199, *)
  @Test func acceptRetriesOnInterrupt() throws {
    let listener = SocketDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 2)
      var client = SocketAddress()
      _ = try listener.accept(client: &client, options: [])
      #if SYSTEM_PACKAGE_DARWIN
      #expect(drain(mocking).map(\.name) == ["accept", "accept", "accept", "fcntl"])
      #else
      #expect(drain(mocking).map(\.name) == ["accept4", "accept4", "accept4"])
      #endif

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try listener.accept(options: [], retryOnInterrupt: false)
      }
    }
  }

  /// A failed call sets no options.
  @available(System 199, *)
  @Test func aFailedCallStops() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EMFILE, count: 1)
      #expect(throws: Errno.tooManyOpenFiles) {
        try SocketDescriptor.open(.local, .stream, options: .closeOnExec)
      }
      #expect(drain(mocking).map(\.name) == ["socket"])
    }
  }
}

private func drain(_ mocking: MockingDriver) -> [Trace.Entry] {
  var calls: [Trace.Entry] = []
  while let entry = mocking.trace.dequeue() {
    calls.append(entry)
  }
  return calls
}

#endif // !os(Windows) && ENABLE_MOCKING
