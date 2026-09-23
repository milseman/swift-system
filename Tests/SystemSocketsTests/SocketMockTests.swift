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

// Mock tests for SocketDescriptor.pair and the checked conversion from
// FileDescriptor, using SystemSockets' own syscall mocking. A mocked call
// records its name and arguments and returns 0, unless an errno is forced.
@Suite("Socket syscall mocks")
private struct SocketMockTests {

  @available(System 199, *)
  @Test func checkedConversionCallsGetsockoptForTheSocketType() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let socket = try SocketDescriptor(FileDescriptor(rawValue: 42))
      #expect(socket.rawValue == 42)
      let calls = drain(mocking)
      #expect(calls.map(\.name) == ["getsockopt"])
      #expect(calls.first.map { Array($0.arguments.prefix(3)) } == [42, SOL_SOCKET, SO_TYPE])
    }
  }

  @available(System 199, *)
  @Test func checkedConversionDoesNotRetryOnInterrupt() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try SocketDescriptor(FileDescriptor(rawValue: 42))
      }
      #expect(drain(mocking).map(\.name) == ["getsockopt"])
    }
  }

  @available(System 199, *)
  @Test func checkedConversionReportsTheError() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: ENOTSOCK)
      #expect(throws: Errno.notSocket) {
        try SocketDescriptor(FileDescriptor(rawValue: 42))
      }
      #expect(drain(mocking).map(\.name) == ["getsockopt"])
    }
  }

  @available(System 199, *)
  @Test func pairPassesDomainTypeAndProtocol() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try SocketDescriptor.pair(.local, .datagram)
      _ = try SocketDescriptor.pair(.local, .stream, protocol: .tcp)
      let calls = drain(mocking)
      #expect(calls.map(\.name) == ["socketpair", "socketpair"])
      #expect(calls.map { Array($0.arguments.prefix(3)) } == [
        [PF_LOCAL, SOCK_DGRAM, 0],
        [PF_LOCAL, SOCK_STREAM, CInt(IPPROTO_TCP)],
      ])
    }
  }

  @available(System 199, *)
  @Test func pairRetriesOnInterruptByDefault() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 3)
      _ = try SocketDescriptor.pair(.local, .stream)
      // Three interrupted calls, then one that succeeds.
      #expect(drain(mocking).map(\.name) == Array(repeating: "socketpair", count: 4))
    }
  }

  @available(System 199, *)
  @Test func pairThrowsOnInterruptWhenNotRetrying() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try SocketDescriptor.pair(.local, .stream, retryOnInterrupt: false)
      }
      #expect(drain(mocking).map(\.name) == ["socketpair"])
    }
  }

  @available(System 199, *)
  @Test func pairReportsOtherErrorsWithoutRetrying() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EMFILE)
      #expect(throws: Errno.tooManyOpenFiles) {
        try SocketDescriptor.pair(.local, .stream)
      }
      #expect(drain(mocking).map(\.name) == ["socketpair"])
    }
  }
}

/// Removes and returns the calls that the mocking driver recorded.
private func drain(_ mocking: MockingDriver) -> [Trace.Entry] {
  var calls: [Trace.Entry] = []
  while let entry = mocking.trace.dequeue() {
    calls.append(entry)
  }
  return calls
}

#endif // !os(Windows) && ENABLE_MOCKING
