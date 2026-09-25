/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The kqueue wrappers, checked against the calls they make. The mock records
// kevent's descriptor, the numbers of changes and of events, and the
// timeout's seconds and nanoseconds, or -1 and -1 for no timeout.
// KernelQueueTests checks the same wrappers on real queues.
#if ENABLE_MOCKING
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class KernelQueueMockTests: XCTestCase {
  let change = KernelEvent(identifier: 1, filter: .user, flags: .add)

  func testSyscalls() {
    let syscallTestCases: [MockTestCase] = [
      // kqueue can't be interrupted. The queue gives up the mock's
      // descriptor, so that it isn't closed.
      MockTestCase(name: "kqueue", .noInterrupt) { _ in
        _ = try KernelQueue().relinquish()
      },

      // A signal can't interrupt registering, so it never throws EINTR.
      MockTestCase(name: "kevent", .noError, 42, 1, 0, 0, 0) { _ in
        try withQueue { try $0.register(self.change) }
      },

      MockTestCase(name: "kevent", .noError, 42, 2, 0, 0, 0) { _ in
        try withQueue { queue in
          try [self.change, self.change].withUnsafeBufferPointer {
            try queue.register(Span(_unsafeElements: $0))
          }
        }
      },

      MockTestCase(name: "kevent", .interruptable, 42, 0, 4, -1, -1) { retryOnInterrupt in
        try withQueue {
          try poll($0, timeout: nil, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "kevent", .interruptable, 42, 0, 4, 1, 500_000_000) {
        retryOnInterrupt in
        try withQueue {
          try poll($0, timeout: .milliseconds(1500), retryOnInterrupt: retryOnInterrupt)
        }
      },

      // With no changes, a retried registerAndPoll is the same call.
      MockTestCase(name: "kevent", .interruptable, 42, 0, 4, 0, 0) { retryOnInterrupt in
        try withQueue {
          try registerAndPoll(
            $0, [], timeout: .zero, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }

  func testRegisterTreatsInterruptionAsSuccess() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EINTR)
      try withQueue { try $0.register(self.change) }
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [42, 1, 0, 0, 0] as [AnyHashable])
      XCTAssertNil(mocking.trace.dequeue(), "registering isn't retried")
    }
  }

  func testRegisterThrowsOtherErrors() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EBADF)
      assertThrows(.badFileDescriptor) {
        try withQueue { try $0.register(self.change) }
      }
    }
  }

  func testRetriedWaitDoesNotReapplyChanges() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 2)
      try withQueue {
        try registerAndPoll(
          $0, [change, change], timeout: .milliseconds(5), retryOnInterrupt: true)
      }
      let calls = [
        mocking.trace.dequeue(), mocking.trace.dequeue(), mocking.trace.dequeue(),
      ]
      XCTAssertEqual(calls.map { $0?.name }, ["kevent", "kevent", "kevent"])
      XCTAssertEqual(
        calls.map { $0?.arguments[1] }, [2, 0, 0] as [AnyHashable?],
        "the first call applies both changes, and the retries apply none")
      XCTAssertNil(mocking.trace.dequeue())
    }
  }

  func testInterruptedWaitThrowsWithoutRetry() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EINTR)
      assertThrows(.interrupted) {
        try withQueue {
          try registerAndPoll(
            $0, [change, change], timeout: .zero, retryOnInterrupt: false)
        }
      }
      XCTAssertEqual(mocking.trace.dequeue()?.arguments[1], AnyHashable(2))
      XCTAssertNil(mocking.trace.dequeue())
    }
  }

  func testTimeouts() throws {
    let cases: [(Duration?, seconds: Int, nanoseconds: Int)] = [
      (nil, -1, -1),
      (.zero, 0, 0),
      (.seconds(-5), 0, 0),
      (.nanoseconds(1), 0, 1),
      // Parts of a nanosecond round up, so a positive timeout waits.
      (Duration(secondsComponent: 0, attosecondsComponent: 1), 0, 1),
      (Duration(secondsComponent: 2, attosecondsComponent: 999_999_999_999_999_999), 3, 0),
      (.microseconds(1_500_001), 1, 500_001_000),
      (.seconds(100_000_000), 100_000_000, 0),
      // Darwin rejects longer timeouts, so they wait about three years.
      (.seconds(100_000_001), 100_000_000, 0),
      (.seconds(Int64.max), 100_000_000, 0),
    ]
    for (timeout, seconds, nanoseconds) in cases {
      try MockingDriver.withMockingEnabled { mocking in
        try withQueue { try poll($0, timeout: timeout, retryOnInterrupt: true) }
        let arguments = mocking.trace.dequeue()?.arguments
        XCTAssertEqual(
          arguments.map { Array($0.suffix(2)) }, [seconds, nanoseconds] as [AnyHashable],
          "timeout \(String(describing: timeout))")
      }
    }
  }
}

/// Calls `body` with a queue for the mock's descriptor, 42,
/// which the queue gives up afterward so that it isn't closed.
@available(System 199, *)
private func withQueue(_ body: (borrowing KernelQueue) throws -> Void) throws {
  // A defer block can't consume the queue, so each path gives it up.
  let queue = KernelQueue(taking: FileDescriptor(rawValue: 42))
  do {
    try body(queue)
  } catch {
    _ = queue.relinquish()
    throw error
  }
  _ = queue.relinquish()
}

/// Polls `queue` with room for four events.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func poll(
  _ queue: borrowing KernelQueue, timeout: Duration?, retryOnInterrupt: Bool
) throws {
  try withUnsafeTemporaryAllocation(of: KernelEvent.self, capacity: 4) { buffer in
    var events = OutputSpan(buffer: buffer, initializedCount: 0)
    try queue.poll(into: &events, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
    _ = events.finalize(for: buffer)
  }
}

/// Registers `changes` with `queue` and polls it with room for four events.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func registerAndPoll(
  _ queue: borrowing KernelQueue, _ changes: [KernelEvent],
  timeout: Duration?, retryOnInterrupt: Bool
) throws {
  try changes.withUnsafeBufferPointer { changes in
    try withUnsafeTemporaryAllocation(of: KernelEvent.self, capacity: 4) { buffer in
      var events = OutputSpan(buffer: buffer, initializedCount: 0)
      try queue.registerAndPoll(
        Span(_unsafeElements: changes), into: &events,
        timeout: timeout, retryOnInterrupt: retryOnInterrupt)
      _ = events.finalize(for: buffer)
    }
  }
}
#endif // ENABLE_MOCKING
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
