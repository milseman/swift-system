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
final class BrokenDownTimeMockTests: XCTestCase {
  func testConversionCalls() {
    let noon = BrokenDownTime(year: 2026, month: 9, day: 28, hour: 12)
    // timegm and mktime record the fields as C's struct tm holds them.
    let fields: [AnyHashable] = [CInt(126), CInt(8), CInt(28), CInt(12), CInt(0), CInt(0)]
    let cases: [MockTestCase] = [
      MockTestCase(name: "gmtime_r", .noInterrupt, 1_790_000_000) { _ in
        _ = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
      },
      MockTestCase(name: "localtime_r", .noInterrupt, -1) { _ in
        _ = try BrokenDownTime(secondsSinceEpoch: -1, in: .local)
      },
      MockTestCase(name: "timegm", .noInterrupt, fields[0], fields[1], fields[2],
                   fields[3], fields[4], fields[5], CInt(-1)) { _ in
        _ = try noon.secondsSinceEpoch(in: .utc)
      },
      MockTestCase(name: "mktime", .noInterrupt, fields[0], fields[1], fields[2],
                   fields[3], fields[4], fields[5], CInt(1)) { _ in
        var summer = noon
        summer.isDaylightSavingTime = true
        _ = try summer.normalized(in: .local)
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// A failed timegm or mktime returns -1, which is also a time: the error
  /// is the one the call set, or overflow if it set none, as Darwin's don't.
  func testFailuresAreTheErrorOrOverflow() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let noon = BrokenDownTime(year: 2026, month: 9, day: 28, hour: 12)
      mocking.forceErrno = .always(errno: EINVAL)
      XCTAssertThrowsError(try noon.secondsSinceEpoch(in: .utc)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "timegm")

      mocking.forceErrno = .always(errno: 0)
      XCTAssertThrowsError(try noon.secondsSinceEpoch(in: .local)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "mktime")
      XCTAssertThrowsError(try BrokenDownTime(secondsSinceEpoch: 0, in: .utc)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "gmtime_r")

      // A timegm that fails without an error, as Darwin's does before 1900,
      // is computed instead, and the result broken down to check it.
      XCTAssertThrowsError(try noon.secondsSinceEpoch(in: .utc)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "timegm")
      let check = mocking.trace.dequeue()
      XCTAssertEqual(check?.name, "gmtime_r")
      XCTAssertEqual(check?.arguments, [1_790_596_800])

      // The last second of 1969 is -1 without an error, whatever errno says.
      let lastSecond = BrokenDownTime(
        year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59)
      mocking.forceErrno = .always(errno: EOVERFLOW)
      XCTAssertEqual(try lastSecond.secondsSinceEpoch(in: .utc), -1)
      XCTAssertEqual(mocking.trace.dequeue()?.name, "timegm")
      XCTAssert(mocking.trace.isEmpty)
    }
  }

  /// Fields that don't fit C's ints fail without a call.
  func testFieldsThatDontFitMakeNoCall() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let time = BrokenDownTime(year: 2026, month: 1, day: .max)
      XCTAssertThrowsError(try time.secondsSinceEpoch(in: .utc)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      XCTAssertThrowsError(try time.normalized(in: .local)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      XCTAssert(mocking.trace.isEmpty)
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
