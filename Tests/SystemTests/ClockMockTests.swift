/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && ENABLE_MOCKING

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class ClockMockTests: XCTestCase {
  func testClockCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "clock_gettime", .noInterrupt, CLOCK_MONOTONIC, Wildcard()) { _ in
        _ = try ClockID.monotonic.currentTime()
      },
      MockTestCase(name: "clock_getres", .noInterrupt, CLOCK_REALTIME, Wildcard()) { _ in
        _ = try ClockID.realtime.resolution()
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// The mock doesn't fill in the time that's left, which stays zero,
  /// so a sleep that restarted from the beginning would ask for 1.5 s again.
  func testSleepResumesWithTheTimeLeft() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      try PThread.sleep(for: .milliseconds(1500))
      XCTAssertEqual(requests(mocking), [[1, 500_000_000], [0, 0]])

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try PThread.sleep(for: .seconds(2), retryOnInterrupt: false)) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(requests(mocking), [[2, 0]])

      // Other errors aren't retried.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertThrowsError(try PThread.sleep(for: .seconds(1))) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(requests(mocking), [[1, 0]])
    }
  }

  func testSleepRounding() throws {
    try MockingDriver.withMockingEnabled { mocking in
      try PThread.sleep(for: .nanoseconds(1) + Duration(secondsComponent: 0, attosecondsComponent: 1))
      try PThread.sleep(for: Duration(secondsComponent: 0, attosecondsComponent: 1))
      try PThread.sleep(for: .zero)
      try PThread.sleep(for: .seconds(-1))
      XCTAssertEqual(requests(mocking), [[0, 2], [0, 1], [0, 0], [0, 0]])
    }
  }

  private func requests(_ mocking: MockingDriver) -> [[Int64]] {
    var result: [[Int64]] = []
    while let entry = mocking.trace.dequeue() {
      XCTAssertEqual(entry.name, "nanosleep")
      result.append(entry.arguments.map { $0 as! Int64 })
    }
    return result
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
