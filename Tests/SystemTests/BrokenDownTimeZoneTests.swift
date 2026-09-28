/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

// These tests set TZ, which belongs to the whole process, so they're
// XCTests, which run one at a time in a process of their own.
@available(System 199, *)
final class BrokenDownTimeZoneTests: XCTestCase {
  /// Runs `body` with TZ set to `zone`, then restores it.
  private func withTimeZone(_ zone: String, _ body: () throws -> Void) throws {
    let saved = ProcessEnvironment.value(of: "TZ")
    try ProcessEnvironment.set("TZ", to: zone)
    defer {
      if let saved {
        try? ProcessEnvironment.set("TZ", to: saved)
      } else {
        try? ProcessEnvironment.remove("TZ")
      }
      tzset()
    }
    try body()
  }

  private func fields(_ time: BrokenDownTime) -> [Int] {
    [time.year, time.month, time.day, time.hour, time.minute, time.second]
  }

  func testLocalTime() throws {
    try withTimeZone("America/Los_Angeles") {
      let summer = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      XCTAssertEqual(fields(summer), [2026, 9, 21, 7, 13, 20])
      XCTAssertEqual(summer.weekday, .monday)
      XCTAssertEqual(summer.isDaylightSavingTime, true)
      XCTAssertEqual(summer.utcOffset, -25_200)
      XCTAssertEqual(summer.timeZoneAbbreviation, "PDT")
      XCTAssertEqual(try summer.secondsSinceEpoch(in: .local), 1_790_000_000)
      XCTAssertEqual(summer.formatted("%Y-%m-%d %H:%M:%S %z %Z %s"),
                     "2026-09-21 07:13:20 -0700 PDT 1790000000")

      let winter = try BrokenDownTime(secondsSinceEpoch: 1_800_000_000, in: .local)
      XCTAssertEqual(fields(winter), [2027, 1, 15, 0, 0, 0])
      XCTAssertEqual(winter.isDaylightSavingTime, false)
      XCTAssertEqual(winter.utcOffset, -28_800)
      XCTAssertEqual(winter.timeZoneAbbreviation, "PST")
      XCTAssertEqual(try winter.secondsSinceEpoch(in: .local), 1_800_000_000)

      // The same fields, read as UTC, are a different time.
      XCTAssertEqual(try winter.secondsSinceEpoch(in: .utc), 1_800_000_000 - 28_800)
    }
  }

  /// glibc's localtime_r reads TZ only once unless tzset is called, which
  /// breaking down a local time does.
  func testChangesToTZTakeEffect() throws {
    try withTimeZone("Asia/Tokyo") {
      let tokyo = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      XCTAssertEqual(tokyo.hour, 23)
      XCTAssertEqual(tokyo.utcOffset, 32_400)
      XCTAssertEqual(tokyo.timeZoneAbbreviation, "JST")
    }
    try withTimeZone("Europe/London") {
      let london = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      XCTAssertEqual(london.hour, 15)
      XCTAssertEqual(london.utcOffset, 3_600)
      XCTAssertEqual(london.timeZoneAbbreviation, "BST")
    }
    try withTimeZone("UTC0") {
      let utc = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      XCTAssertEqual(utc.hour, 14)
      XCTAssertEqual(utc.utcOffset, 0)
    }
  }

  /// When the clocks go back, 1:30 happens twice.
  func testTheRepeatedHour() throws {
    try withTimeZone("America/Los_Angeles") {
      var time = BrokenDownTime(year: 2026, month: 11, day: 1, hour: 1, minute: 30)
      time.isDaylightSavingTime = true
      XCTAssertEqual(try time.secondsSinceEpoch(in: .local), 1_793_521_800)
      let first = try time.normalized(in: .local)
      XCTAssertEqual(first.timeZoneAbbreviation, "PDT")
      XCTAssertEqual(first.utcOffset, -25_200)

      time.isDaylightSavingTime = false
      XCTAssertEqual(try time.secondsSinceEpoch(in: .local), 1_793_525_400)
      let second = try time.normalized(in: .local)
      XCTAssertEqual(second.timeZoneAbbreviation, "PST")
      XCTAssertEqual(second.utcOffset, -28_800)
      XCTAssertEqual(fields(first), fields(second))

      // Left to the system, it's one of the two.
      time.isDaylightSavingTime = nil
      XCTAssert([1_793_521_800, 1_793_525_400].contains(try time.secondsSinceEpoch(in: .local)))

      // Breaking either down and converting back finds the same time.
      for seconds in [1_793_521_800, 1_793_525_400] {
        let local = try BrokenDownTime(secondsSinceEpoch: seconds, in: .local)
        XCTAssertEqual(try local.secondsSinceEpoch(in: .local), seconds)
      }
    }
  }

  /// When the clocks go forward, 2:30 doesn't happen.
  func testTheSkippedHour() throws {
    try withTimeZone("America/Los_Angeles") {
      let skipped = BrokenDownTime(year: 2026, month: 3, day: 8, hour: 2, minute: 30)
      let normalized = try skipped.normalized(in: .local)
      XCTAssertEqual(fields(normalized), [2026, 3, 8, 3, 30, 0])
      XCTAssertEqual(normalized.isDaylightSavingTime, true)
      XCTAssertEqual(try skipped.secondsSinceEpoch(in: .local), 1_772_965_800)
    }
  }

  /// The hazard that isDaylightSavingTime's documentation warns about:
  /// a value left over from another date moves the time.
  func testAStaleDaylightSavingFlagMovesTheTime() throws {
    try withTimeZone("America/Los_Angeles") {
      var time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      XCTAssertEqual(time.isDaylightSavingTime, true)
      time.month = 1
      XCTAssertEqual(try time.normalized(in: .local).hour, 6)
      time.isDaylightSavingTime = nil
      XCTAssertEqual(try time.normalized(in: .local).hour, 7)
    }
  }

  /// Calendar arithmetic across a change of offset keeps the clock time.
  func testAddingDaysAcrossTheChange() throws {
    try withTimeZone("America/Los_Angeles") {
      var time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .local)
      time.day += 60
      time.isDaylightSavingTime = nil
      let later = try time.normalized(in: .local)
      XCTAssertEqual(fields(later), [2026, 11, 20, 7, 13, 20])
      XCTAssertEqual(later.timeZoneAbbreviation, "PST")
      XCTAssertEqual(try time.secondsSinceEpoch(in: .local), 1_790_000_000 + 60 * 86_400 + 3_600)
    }
  }

  /// Darwin's mktime fails for times before 1900, which its localtime_r
  /// breaks down, with the zone's local mean time before 1883.
  func testLocalTimesBefore1900() throws {
    try withTimeZone("America/Los_Angeles") {
      let old = try BrokenDownTime(secondsSinceEpoch: -2_800_000_000, in: .local)
      XCTAssertEqual(fields(old), [1881, 4, 9, 6, 20, 22])
      XCTAssertEqual(old.utcOffset, -28_378)
      XCTAssertEqual(old.timeZoneAbbreviation, "LMT")
      #if SYSTEM_PACKAGE_DARWIN
      XCTAssertThrowsError(try old.secondsSinceEpoch(in: .local)) {
        XCTAssertEqual($0 as? Errno, .overflow)
      }
      #else
      XCTAssertEqual(try old.secondsSinceEpoch(in: .local), -2_800_000_000)
      #endif
    }
  }

  /// A UTC time formats as UTC whatever the local zone is. C's strftime
  /// prints the local zone's offset for %z on Darwin, and reads %s as local
  /// time everywhere.
  func testFormattingUTCIgnoresTheLocalZone() throws {
    try withTimeZone("America/Denver") {
      let utc = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
      XCTAssertEqual(utc.formatted("%H:%M %z %s"), "14:13 +0000 1790000000")

      var c = utc._cFields!
      var buffer = [CChar](repeating: 0, count: 64)
      // mktime reads the fields as mountain standard time, since the
      // UTC time isn't in daylight saving time.
      XCTAssertGreaterThan(strftime(&buffer, buffer.count, "%s", &c), 0)
      XCTAssertEqual(String(cString: buffer), "1790025200", "strftime reads the fields as local time")
      #if SYSTEM_PACKAGE_DARWIN
      XCTAssertGreaterThan(strftime(&buffer, buffer.count, "%z", &c), 0)
      XCTAssertEqual(String(cString: buffer), "-0700", "Darwin's %z is the local zone's")
      #endif
    }
  }
}

#endif // !os(Windows) && !os(WASI)
