/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import ucrt

/// EOVERFLOW, which Errno names only on other platforms.
private var overflow: Errno { Errno(rawValue: 132) }

// BrokenDownTime on Windows, over the C runtime's 64-bit time functions.
// The local-time tests set TZ, and restore it, which XCTest allows, since it
// runs one test at a time.
@available(System 199, *)
final class Win32BrokenDownTimeTests: XCTestCase {
  /// Runs `body` with `TZ` set to `zone`, and restores it.
  private func withTimeZone(_ zone: String, _ body: () throws -> Void) throws {
    let original = ProcessEnvironment.value(of: "TZ")
    try ProcessEnvironment.set("TZ", to: zone)
    defer {
      if let original {
        try? ProcessEnvironment.set("TZ", to: original)
      } else {
        try? ProcessEnvironment.remove("TZ")
      }
      _tzset()
    }
    try body()
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(BrokenDownTime._overflow.rawValue, ucrt.EOVERFLOW)
    XCTAssertEqual(overflow.rawValue, ucrt.EOVERFLOW)
  }

  func testUTC() throws {
    let time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
    XCTAssertEqual(
      time,
      BrokenDownTime(
        year: 2026, month: 9, day: 21, hour: 14, minute: 13, second: 20,
        isDaylightSavingTime: false, utcOffset: 0, timeZoneAbbreviation: "UTC"))
    XCTAssertEqual(time.weekday, .monday)
    XCTAssertEqual(time.dayOfYear, 264)
    let seconds = try time.secondsSinceEpoch(in: .utc)
    XCTAssertEqual(seconds, 1_790_000_000)
  }

  func testUTCOutsideTheCRuntimesRange() throws {
    // The C runtime converts 1970 through 3000; System computes the rest.
    let before = try BrokenDownTime(secondsSinceEpoch: -1, in: .utc)
    XCTAssertEqual(
      before,
      BrokenDownTime(
        year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59,
        isDaylightSavingTime: false, utcOffset: 0, timeZoneAbbreviation: "UTC"))
    XCTAssertEqual(before.weekday, .wednesday)
    let beforeSeconds = try before.secondsSinceEpoch(in: .utc)
    XCTAssertEqual(beforeSeconds, -1)

    let after = try BrokenDownTime(secondsSinceEpoch: 32_535_216_000, in: .utc)
    XCTAssertEqual(after.year, 3001)
    XCTAssertEqual(after.month, 1)
    XCTAssertEqual(after.day, 1)
    let afterSeconds = try after.secondsSinceEpoch(in: .utc)
    XCTAssertEqual(afterSeconds, 32_535_216_000)

    let ancient = try BrokenDownTime(secondsSinceEpoch: -62_135_596_800, in: .utc)
    XCTAssertEqual(ancient.year, 1)
    XCTAssertEqual(ancient.month, 1)
    XCTAssertEqual(ancient.day, 1)

    XCTAssertThrowsError(try BrokenDownTime(secondsSinceEpoch: .max, in: .utc)) { error in
      XCTAssertEqual(error as? Errno, overflow)
    }
  }

  func testNormalizing() throws {
    let carried = try BrokenDownTime(year: 2026, month: 1, day: 32).normalized(in: .utc)
    XCTAssertEqual(carried.month, 2)
    XCTAssertEqual(carried.day, 1)
    XCTAssertEqual(carried.timeZoneAbbreviation, "UTC")
    // Outside the C runtime's range too.
    let early = try BrokenDownTime(year: 1960, month: 13, day: 1).normalized(in: .utc)
    XCTAssertEqual(early.year, 1961)
    XCTAssertEqual(early.month, 1)
  }

  func testLocalTimes() throws {
    try withTimeZone("PST8PDT") {
      let summer = try BrokenDownTime(secondsSinceEpoch: 1_784_000_000, in: .local)
      XCTAssertEqual(summer.isDaylightSavingTime, true)
      XCTAssertEqual(summer.utcOffset, -7 * 3_600)
      XCTAssertEqual(summer.timeZoneAbbreviation, "PDT")
      // The local fields are the UTC fields of the time moved by the offset.
      var shifted = try BrokenDownTime(secondsSinceEpoch: 1_784_000_000 - 7 * 3_600, in: .utc)
      XCTAssertEqual(summer.year, shifted.year)
      XCTAssertEqual(summer.day, shifted.day)
      XCTAssertEqual(summer.hour, shifted.hour)
      let summerSeconds = try summer.secondsSinceEpoch(in: .local)
      XCTAssertEqual(summerSeconds, 1_784_000_000)

      let winter = try BrokenDownTime(secondsSinceEpoch: 1_768_000_000, in: .local)
      XCTAssertEqual(winter.isDaylightSavingTime, false)
      XCTAssertEqual(winter.utcOffset, -8 * 3_600)
      XCTAssertEqual(winter.timeZoneAbbreviation, "PST")
      shifted = try BrokenDownTime(secondsSinceEpoch: 1_768_000_000 - 8 * 3_600, in: .utc)
      XCTAssertEqual(winter.hour, shifted.hour)
      XCTAssertEqual(winter.formatted("%z %Z"), "-0800 PST")

      // A week later, letting the system choose the offset.
      var nextWeek = winter
      nextWeek.day += 7
      nextWeek.isDaylightSavingTime = nil
      let nextWeekSeconds = try nextWeek.secondsSinceEpoch(in: .local)
      XCTAssertEqual(nextWeekSeconds, 1_768_000_000 + 7 * 86_400)
    }
  }

  func testLocalTimesOutsideTheCRuntimesRange() throws {
    try withTimeZone("PST8PDT") {
      XCTAssertThrowsError(try BrokenDownTime(secondsSinceEpoch: -86_400, in: .local)) { error in
        XCTAssertEqual(error as? Errno, overflow)
      }
      XCTAssertThrowsError(
        try BrokenDownTime(year: 3001, month: 6, day: 1).secondsSinceEpoch(in: .local)
      ) { error in
        XCTAssertEqual(error as? Errno, overflow)
      }
    }
  }

  func testFormatting() throws {
    let time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
    XCTAssertEqual(time.formatted("%Y-%m-%d %H:%M:%S"), "2026-09-21 14:13:20")
    XCTAssertEqual(time.formatted("%A, %B %d, %Y at %H:%M %Z"), "Monday, September 21, 2026 at 14:13 UTC")
    XCTAssertEqual(time.formatted("%z %Z %s"), "+0000 UTC 1790000000")
    XCTAssertEqual(time.formatted("100%%"), "100%")
    XCTAssertEqual(time.formatted("%F %T %j %u %e"), "2026-09-21 14:13:20 264 1 21")
    // The C runtime's # flag and E and O modifiers.
    XCTAssertEqual(time.formatted("%#m/%#d %Ey %Od"), "9/21 26 21")
    // What the C runtime rejects prints as it's written.
    XCTAssertEqual(time.formatted("%k %-d %q %"), "%k %-d %q %")
    XCTAssertEqual(time.formatted(""), "")

    var odd = time
    odd.timeZoneAbbreviation = "A%B"
    XCTAssertEqual(odd.formatted("%Z"), "A%B")
  }

  func testFormattingFieldsOutsideTheirRanges() throws {
    // The C runtime rejects them, so the time they carry to is formatted.
    let carried = BrokenDownTime(year: 2026, month: 1, day: 32)
    XCTAssertEqual(carried.formatted("%Y-%m-%d"), "2026-02-01")
    // A year the C runtime can't print at all.
    let distant = BrokenDownTime(year: 12_000, month: 1, day: 1)
    XCTAssertEqual(distant.formatted("%Y"), "")
    // A conversion that doesn't read the year still works.
    XCTAssertEqual(distant.formatted("%m"), "01")
  }

  #if ENABLE_MOCKING
  func testTheCRuntimeCalls() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
      let breakDown = mocking.trace.dequeue()
      XCTAssertEqual(breakDown?.name, "_gmtime64_s")
      XCTAssertEqual(breakDown?.arguments, [1_790_000_000] as [AnyHashable])

      _ = try BrokenDownTime(year: 2026, month: 9, day: 21, isDaylightSavingTime: true)
        .secondsSinceEpoch(in: .local)
      let convert = mocking.trace.dequeue()
      XCTAssertEqual(convert?.name, "_mktime64")
      let fields: [AnyHashable] = [CInt(126), CInt(8), CInt(21), CInt(0), CInt(0), CInt(0), CInt(1)]
      XCTAssertEqual(convert?.arguments, fields)
    }
  }
  #endif
}

#endif // os(Windows)
