/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING

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

// A mocked sendfile sends the next of the driver's byte counts: on Darwin,
// the count it reports with an error, too.
@Suite("sendfile mocks")
private struct SocketSendFileMockTests {
  let socket = SocketDescriptor(rawValue: 7)
  let file = FileDescriptor(rawValue: 9)

  @available(System 199, *)
  @Test func passesTheDescriptorsOffsetAndCount() throws {
    try MockingDriver.withMockingEnabled { mocking throws in
      mocking.byteCounts = [100]
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 30, count: 100) == 100)
      let calls = drain(mocking)
      #expect(calls.map(\.name) == ["sendfile"])
      #if SYSTEM_PACKAGE_DARWIN
      // sendfile(fd, s, offset, len, ...): the file comes first.
      #expect(calls.first?.arguments == [CInt(9), CInt(7), off_t(30), off_t(100)])
      #else
      // sendfile(out_fd, in_fd, offset, count): the socket comes first.
      #expect(calls.first?.arguments == [CInt(7), CInt(9), off_t(30), 100])
      #endif
    }
  }

  @available(System 199, *)
  @Test func aZeroCountMakesNoCall() throws {
    try MockingDriver.withMockingEnabled { mocking throws in
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 0, count: 0) == 0)
      #expect(drain(mocking).isEmpty)
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Darwin reports what it sent before EAGAIN or EINTR; that's a result.
  @available(System 199, *)
  @Test func bytesSentBeforeAnErrorAreTheResult() throws {
    try MockingDriver.withMockingEnabled { mocking throws in
      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      mocking.byteCounts = [8092]
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 0, count: 1 << 20) == 8092)

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      mocking.byteCounts = [10]
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 0, count: 100) == 10)
      #expect(drain(mocking).count == 2)
    }
  }
  #endif

  @available(System 199, *)
  @Test func wouldBlockWithNothingSentThrows() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      #expect(throws: Errno.wouldBlock) {
        try socket.sendFile(file, fromAbsoluteOffset: 0, count: 100)
      }
      #expect(drain(mocking).count == 1)
    }
  }

  @available(System 199, *)
  @Test func anInterruptionBeforeAnythingIsSentIsRetried() throws {
    try MockingDriver.withMockingEnabled { mocking throws in
      mocking.forceErrno = .counted(errno: EINTR, count: 2)
      mocking.byteCounts = [0, 0, 100]
      #if SYSTEM_PACKAGE_DARWIN
      // The failed calls report 0 bytes, then the third sends them all.
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 0, count: 100) == 100)
      #else
      // A failed call uses no byte count on Linux.
      mocking.byteCounts = [100]
      #expect(try socket.sendFile(file, fromAbsoluteOffset: 0, count: 100) == 100)
      #endif
      #expect(drain(mocking).count == 3)

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      #expect(throws: Errno.interrupted) {
        try socket.sendFile(file, fromAbsoluteOffset: 0, count: 100, retryOnInterrupt: false)
      }
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

#endif // (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING
