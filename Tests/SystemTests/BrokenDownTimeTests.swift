/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The tests' times need a 64-bit Int, which wasm32 and 32-bit ARM don't have.
#if !os(Windows) && !os(WASI) && _pointerBitWidth(_64)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#endif

// UTC only: these tests don't depend on the local time zone, and don't
// change TZ, which BrokenDownTimeZoneTests does in a process of its own.
@Suite("Broken-down time")
private struct BrokenDownTimeTests {
  @available(System 199, *)
  typealias Weekday = BrokenDownTime.Weekday

  @available(System 199, *)
  @Test func knownTimesInUTC() throws {
    let known: [(Int, [Int], Weekday, Int)] = [
      (0, [1970, 1, 1, 0, 0, 0], .thursday, 1),
      (-1, [1969, 12, 31, 23, 59, 59], .wednesday, 365),
      (951_782_400, [2000, 2, 29, 0, 0, 0], .tuesday, 60),
      (1_790_000_000, [2026, 9, 21, 14, 13, 20], .monday, 264),
      (-62_135_596_800, [1, 1, 1, 0, 0, 0], .monday, 1),
      (-62_167_219_200, [0, 1, 1, 0, 0, 0], .saturday, 1),
      (253_402_300_799, [9999, 12, 31, 23, 59, 59], .friday, 365),
      (-2_208_988_800, [1900, 1, 1, 0, 0, 0], .monday, 1),
    ]
    for (seconds, fields, weekday, dayOfYear) in known {
      let time = try BrokenDownTime(secondsSinceEpoch: seconds, in: .utc)
      #expect(
        [time.year, time.month, time.day, time.hour, time.minute, time.second] == fields,
        "\(seconds)")
      #expect(time.weekday == weekday, "\(seconds)")
      #expect(time.dayOfYear == dayOfYear, "\(seconds)")
      #expect(time.isDaylightSavingTime == false)
      #expect(time.utcOffset == 0)
      #if SYSTEM_PACKAGE_DARWIN
      #expect(time.timeZoneAbbreviation == "UTC")
      #endif
      #expect(try time.secondsSinceEpoch(in: .utc) == seconds, "\(seconds)")
    }
  }

  /// Seconds across ±5,000 years, and the edges of the days around the epoch.
  static var spreadOfTimes: [Int] {
    var generator = SplitMix(seed: 0x5EED)
    var times = (0..<2_000).map { _ in Int(generator.next() % 315_569_520_000) - 157_784_760_000 }
    times += [0, -1, 1, 86_399, 86_400, -86_400, -86_401, Int(Int32.max), Int(Int32.min)]
    return times
  }

  @available(System 199, *)
  @Test func breakingDownMatchesTheCLibrary() throws {
    for seconds in Self.spreadOfTimes {
      let time = try BrokenDownTime(secondsSinceEpoch: seconds, in: .utc)
      var t = time_t(seconds)
      var c = tm()
      #expect(gmtime_r(&t, &c) != nil)
      #expect(time.year == Int(c.tm_year) + 1900)
      #expect(time.month == Int(c.tm_mon) + 1)
      #expect(time.day == Int(c.tm_mday))
      #expect([time.hour, time.minute, time.second] == [c.tm_hour, c.tm_min, c.tm_sec].map { Int($0) })
      #expect(time.weekday.rawValue == Int(c.tm_wday), "\(seconds)")
      #expect(time.dayOfYear == Int(c.tm_yday) + 1, "\(seconds)")
      #expect(try time.secondsSinceEpoch(in: .utc) == seconds)
    }
  }

  /// Fields out of their ranges carry as timegm carries them, and the
  /// weekday and day of the year, which BrokenDownTime computes, are those
  /// of the date the fields carry to. From 1905, since Darwin's timegm
  /// fails before 1900.
  @available(System 199, *)
  @Test func fieldsOutOfRangeCarryAsTimegmCarriesThem() throws {
    var generator = SplitMix(seed: 0xCA221)
    func field(_ range: ClosedRange<Int>) -> Int {
      range.lowerBound + Int(generator.next() % UInt64(range.count))
    }
    for _ in 0..<2_000 {
      let time = BrokenDownTime(
        year: field(1905...3000), month: field(-30...30), day: field(-400...400),
        hour: field(-50...50), minute: field(-200...200), second: field(-5000...5000))
      var c = time._cFields!
      let seconds = timegm(&c)
      #expect(try time.secondsSinceEpoch(in: .utc) == seconds, "\(time)")
      #expect(time.weekday.rawValue == Int(c.tm_wday), "\(time)")
      #expect(time.dayOfYear == Int(c.tm_yday) + 1, "\(time)")

      let normalized = try time.normalized(in: .utc)
      #expect(normalized == (try BrokenDownTime(secondsSinceEpoch: seconds, in: .utc)))
      #expect(normalized.weekday == time.weekday)
      #expect(normalized.dayOfYear == time.dayOfYear)
    }
  }

  @available(System 199, *)
  @Test func normalizing() throws {
    func normalized(_ fields: [Int]) throws -> [Int] {
      let time = try BrokenDownTime(
        year: fields[0], month: fields[1], day: fields[2],
        hour: fields[3], minute: fields[4], second: fields[5]
      ).normalized(in: .utc)
      return [time.year, time.month, time.day, time.hour, time.minute, time.second]
    }
    #expect(try normalized([2026, 1, 32, 0, 0, 0]) == [2026, 2, 1, 0, 0, 0])
    #expect(try normalized([2026, 3, 0, 0, 0, 0]) == [2026, 2, 28, 0, 0, 0])
    #expect(try normalized([2024, 3, 0, 0, 0, 0]) == [2024, 2, 29, 0, 0, 0])
    #expect(try normalized([2026, 2, 29, 0, 0, 0]) == [2026, 3, 1, 0, 0, 0])
    #expect(try normalized([2026, 13, 1, 0, 0, 0]) == [2027, 1, 1, 0, 0, 0])
    #expect(try normalized([2026, 0, 1, 0, 0, 0]) == [2025, 12, 1, 0, 0, 0])
    #expect(try normalized([2026, -11, 1, 0, 0, 0]) == [2025, 1, 1, 0, 0, 0])
    #expect(try normalized([2026, 12, 31, 24, 0, 0]) == [2027, 1, 1, 0, 0, 0])
    #expect(try normalized([2026, 1, 1, 0, 0, -1]) == [2025, 12, 31, 23, 59, 59])
    #expect(try normalized([2026, 6, 30, 23, 59, 60]) == [2026, 7, 1, 0, 0, 0])
    #expect(try normalized([1900, 1, 1, 0, 0, 0]) == [1900, 1, 1, 0, 0, 0])
    #expect(try normalized([2000, 1, 366, 0, 0, 0]) == [2000, 12, 31, 0, 0, 0])
  }

  @available(System 199, *)
  @Test func minusOneIsATimeNotAnError() throws {
    let lastSecondOf1969 = BrokenDownTime(
      year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59)
    #expect(try lastSecondOf1969.secondsSinceEpoch(in: .utc) == -1)
    #expect(try lastSecondOf1969.normalized(in: .utc).year == 1969)

    // The same time, carried from other fields.
    let carried = BrokenDownTime(year: 1970, month: 1, day: 1, second: -1)
    #expect(try carried.secondsSinceEpoch(in: .utc) == -1)
    #expect(try carried.normalized(in: .utc) == (try BrokenDownTime(secondsSinceEpoch: -1, in: .utc)))
  }

  /// Darwin's timegm returns -1 for any time before 1900, without setting
  /// errno; BrokenDownTime computes the time instead.
  @available(System 199, *)
  @Test func timesBefore1900InUTC() throws {
    let lastSecondOf1899 = BrokenDownTime(
      year: 1899, month: 12, day: 31, hour: 23, minute: 59, second: 59)
    #expect(try lastSecondOf1899.secondsSinceEpoch(in: .utc) == -2_208_988_801)
    #if SYSTEM_PACKAGE_DARWIN
    var c = lastSecondOf1899._cFields!
    #expect(timegm(&c) == -1)
    #endif

    let firstOfTheEra = BrokenDownTime(year: 1, month: 1, day: 1)
    #expect(try firstOfTheEra.secondsSinceEpoch(in: .utc) == -62_135_596_800)
    let carried = try BrokenDownTime(year: 1, month: 0, day: 1).normalized(in: .utc)
    #expect([carried.year, carried.month, carried.day] == [0, 12, 1])
    #expect(carried.weekday == .friday)
    #expect(carried.timeZoneAbbreviation == (try BrokenDownTime(secondsSinceEpoch: 0, in: .utc)).timeZoneAbbreviation)
  }

  @available(System 199, *)
  @Test func timesThatDontFitThrow() throws {
    #expect(throws: Errno.overflow) { try BrokenDownTime(secondsSinceEpoch: .max, in: .utc) }
    #expect(throws: Errno.overflow) { try BrokenDownTime(secondsSinceEpoch: .min, in: .utc) }

    // The year fits, and carrying the months into it overflows.
    let lastYear = Int(Int32.max) + 1900
    let pastTheLastYear = BrokenDownTime(year: lastYear, month: 13, day: 1)
    #expect(throws: Errno.overflow) { try pastTheLastYear.secondsSinceEpoch(in: .utc) }
    #expect(throws: Errno.overflow) { try pastTheLastYear.normalized(in: .utc) }

    // A field that doesn't fit an int fails before the call.
    let tooLate = BrokenDownTime(year: lastYear + 1, month: 1, day: 1)
    #expect(throws: Errno.overflow) { try tooLate.secondsSinceEpoch(in: .utc) }
    let tooManyDays = BrokenDownTime(year: 2026, month: 1, day: Int(Int32.max) + 1)
    #expect(throws: Errno.overflow) { try tooManyDays.secondsSinceEpoch(in: .utc) }
    let tooEarlyMonth = BrokenDownTime(year: 2026, month: Int(Int32.min), day: 1)
    #expect(throws: Errno.overflow) { try tooEarlyMonth.normalized(in: .utc) }
  }

  @available(System 199, *)
  @Test func weekdays() {
    #expect(Weekday.allCases.map(\.rawValue) == Array(0...6))
    #expect(Weekday.sunday.rawValue == 0)
    #expect(Weekday.saturday.rawValue == 6)
    // A time made from its fields has the right weekday without converting.
    #expect(BrokenDownTime(year: 2026, month: 9, day: 28).weekday == .monday)
    #expect(BrokenDownTime(year: 2026, month: 9, day: 28 + 7 * 1000).weekday == .monday)
    #expect(BrokenDownTime(year: 2026, month: 9, day: 27, hour: 24).weekday == .monday)
    #expect(BrokenDownTime(year: 1, month: 1, day: 1).weekday == .monday)
    #expect(BrokenDownTime(year: -1, month: 12, day: 31).weekday == .friday)
    #expect(BrokenDownTime(year: 2024, month: 12, day: 31).dayOfYear == 366)
    #expect(BrokenDownTime(year: 2100, month: 12, day: 31).dayOfYear == 365)
    #expect(BrokenDownTime(year: 2026, month: 13, day: 1).dayOfYear == 1)
  }

  @available(System 199, *)
  @Test func formatting() throws {
    let time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
    #expect(time.formatted("%Y-%m-%d %H:%M:%S") == "2026-09-21 14:13:20")
    #expect(time.formatted("%A %B %j %u %w %a %b %e %y %C") == "Monday September 264 1 1 Mon Sep 21 26 20")
    #expect(time.formatted("%A, %B %d, %Y at %H:%M %Z") == "Monday, September 21, 2026 at 14:13 \(time.timeZoneAbbreviation!)")
    #expect(time.formatted("") == "")
    #expect(time.formatted("%%") == "%")
    #expect(time.formatted("%%z %%Z %%s") == "%z %Z %s")
    #expect(time.formatted("100%% %Y") == "100% 2026")
    #expect(time.formatted("Zeit: %H Uhr ⏰") == "Zeit: 14 Uhr ⏰")

    // Longer than the first buffer.
    let long = String(repeating: "%Y", count: 300)
    #expect(time.formatted(long) == String(repeating: "2026", count: 300))

    // Weekday and day of the year are the fields', without converting.
    let madeUp = BrokenDownTime(year: 2026, month: 9, day: 28)
    #expect(madeUp.formatted("%a %j") == "Mon 271")
  }

  /// strftime's %z, %Z and %s can describe the local zone rather than the
  /// time's; BrokenDownTime replaces them with the time's own fields.
  @available(System 199, *)
  @Test func zoneConversionsDescribeTheTime() throws {
    let utc = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
    #expect(utc.formatted("%z") == "+0000")
    #expect(utc.formatted("%s") == "1790000000")

    var pacific = BrokenDownTime(
      year: 2026, month: 9, day: 21, hour: 7, minute: 13, second: 20,
      isDaylightSavingTime: true, utcOffset: -25_200, timeZoneAbbreviation: "PDT")
    #expect(pacific.formatted("%z %Z %s") == "-0700 PDT 1790000000")

    pacific.timeZoneAbbreviation = nil
    #expect(pacific.formatted("[%Z]") == "[]")
    pacific.timeZoneAbbreviation = "50%"
    #expect(pacific.formatted("%Z") == "50%")

    func offset(_ seconds: Int) -> String {
      BrokenDownTime(year: 2026, month: 1, day: 1, utcOffset: seconds).formatted("%z")
    }
    #expect(offset(19_800) == "+0530")
    #expect(offset(-17_762) == "-0456")  // New York's local mean time, -4:56:02.
    #expect(offset(30) == "+0000")
    #expect(offset(-30) == "-0000")
    #expect(offset(50_400) == "+1400")
    #expect(offset(360_000) == "+10000")
  }

  @available(System 199, *)
  @Test func fieldsThatDontFitTrap() async {
    await #expect(processExitsWith: .failure) {
      _ = BrokenDownTime(year: .max, month: 1, day: 1).weekday
    }
    await #expect(processExitsWith: .failure) {
      _ = BrokenDownTime(year: 2026, month: 1, day: 1, hour: .min).formatted("%H")
    }
  }
}

/// A small, seedable generator, so that failures reproduce.
private struct SplitMix {
  var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

#endif // !os(Windows) && !os(WASI) && _pointerBitWidth(_64)
