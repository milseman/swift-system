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
final class TimersAndPriorityMockTests: XCTestCase {
  func testCalls() {
    let child = ProcessID(rawValue: 1234)
    let cases: [MockTestCase] = [
      MockTestCase(name: "getitimer", .noInterrupt, _ITIMER_VIRTUAL) { _ in
        _ = try ProcessTimer.virtual.schedule()
      },
      MockTestCase(
        name: "setitimer", .noInterrupt, _ITIMER_REAL,
        Int64(2), Int64(500_000), Int64(0), Int64(1)
      ) { _ in
        try ProcessTimer.real.setSchedule(ProcessTimer.Schedule(
          nextExpiration: .milliseconds(2500), interval: .nanoseconds(1)))
      },
      MockTestCase(name: "getpriority", .noInterrupt, _PRIO_PROCESS, id_t(1234)) { _ in
        _ = try ProcessPriority.current(for: .process(child))
      },
      MockTestCase(name: "getpriority", .noInterrupt, _PRIO_USER, id_t(501)) { _ in
        _ = try ProcessPriority.current(for: .user(UserID(rawValue: 501)))
      },
      MockTestCase(name: "setpriority", .noInterrupt, _PRIO_PGRP, id_t(1234), CInt(7)) { _ in
        try ProcessPriority.setCurrent(7, for: .processGroup(child))
      },
      MockTestCase(name: "nice", .noInterrupt, CInt(2)) { _ in
        try ProcessPriority.adjust(by: 2)
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// -1 is a nice value: only errno says whether getpriority and nice
  /// failed.
  func testMinusOneIsANiceValue() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: 0)
      XCTAssertEqual(try ProcessPriority.current(for: .process(.current)), -1)
      XCTAssertEqual(try ProcessPriority.adjust(by: -1), -1)
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
