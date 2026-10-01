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

import WinSDK

// Clocks and sleeping: Win32.FileTime, the system time, the monotonic
// clocks, and Win32.sleep(for:). Elapsed times are checked against lower
// bounds only, which a loaded machine can't break.
@available(System 199, *)
final class Win32TimeTests: XCTestCase {
  /// 2000-01-01T00:00:00Z: 946,684,800 seconds after the Unix epoch.
  private let y2k = Win32.FileTime(rawValue: 125_911_584_000_000_000)

  func testFileTimeHalves() {
    let raw = FILETIME(dwLowDateTime: 0x89AB_CDEF, dwHighDateTime: 0x0123_4567)
    let time = Win32.FileTime(raw)
    XCTAssertEqual(time.rawValue, 0x0123_4567_89AB_CDEF)
    XCTAssertEqual(time.fileTime.dwLowDateTime, 0x89AB_CDEF)
    XCTAssertEqual(time.fileTime.dwHighDateTime, 0x0123_4567)
    XCTAssertLessThan(Win32.FileTime(rawValue: 1), Win32.FileTime(rawValue: 2))
  }

  func testUnixEpochConversions() {
    let epoch = Win32.FileTime(rawValue: 116_444_736_000_000_000)
    XCTAssertEqual(epoch.durationSinceUnixEpoch, .zero)
    XCTAssertEqual(Win32.FileTime(durationSinceUnixEpoch: .zero), epoch)
    XCTAssertEqual(y2k.durationSinceUnixEpoch, .seconds(946_684_800))
    XCTAssertEqual(Win32.FileTime(durationSinceUnixEpoch: .seconds(946_684_800)), y2k)
    // The start of 1601, and an interval past it.
    XCTAssertEqual(Win32.FileTime(rawValue: 0).durationSinceUnixEpoch, .seconds(-11_644_473_600))
    XCTAssertEqual(
      Win32.FileTime(rawValue: 1).durationSinceUnixEpoch,
      .seconds(-11_644_473_600) + .nanoseconds(100))
    // Rounding down to 100 nanoseconds, before and after the epoch.
    XCTAssertEqual(
      Win32.FileTime(durationSinceUnixEpoch: .nanoseconds(150))?.rawValue, epoch.rawValue + 1)
    XCTAssertEqual(
      Win32.FileTime(durationSinceUnixEpoch: .nanoseconds(-1))?.rawValue, epoch.rawValue - 1)
    XCTAssertEqual(
      Win32.FileTime(durationSinceUnixEpoch: .nanoseconds(-100))?.rawValue, epoch.rawValue - 1)
    // Out of range.
    XCTAssertNil(Win32.FileTime(durationSinceUnixEpoch: .seconds(Int64.max)))
    XCTAssertNil(Win32.FileTime(durationSinceUnixEpoch: .seconds(Int64.min)))
  }

  func testSystemTime() {
    let precise = Win32.FileTime.now
    let coarse = Win32.FileTime.coarseNow
    // After 2026, and within a timer period or two of each other.
    XCTAssertGreaterThan(precise.durationSinceUnixEpoch, .seconds(1_767_225_600))
    XCTAssertLessThan(abs(precise.rawValue - coarse.rawValue), 10_000_000)
    // The C runtime's clock agrees, to the second.
    let seconds = Int64(_time64(nil))
    let fromFileTime = Win32.FileTime.now.durationSinceUnixEpoch.components.seconds
    XCTAssertLessThanOrEqual(abs(fromFileTime - seconds), 2)
  }

  func testMonotonicClocks() {
    let ticks = Win32.tickCount()
    let unbiased = Win32.unbiasedInterruptTime()
    let interrupt = Win32.interruptTime()
    let counter = Win32.performanceCounter()
    Win32.sleep(for: .milliseconds(50))
    let laterTicks = Win32.tickCount()
    let laterUnbiased = Win32.unbiasedInterruptTime()
    let laterInterrupt = Win32.interruptTime()
    let laterCounter = Win32.performanceCounter()

    // A sleep of 50 milliseconds can end early by less than a timer period.
    XCTAssertGreaterThanOrEqual(laterTicks - ticks, .milliseconds(20))
    XCTAssertGreaterThanOrEqual(laterUnbiased - unbiased, .milliseconds(20))
    XCTAssertGreaterThanOrEqual(laterInterrupt - interrupt, .milliseconds(20))
    let frequency = Win32.performanceFrequency()
    XCTAssertGreaterThan(frequency, 0)
    XCTAssertGreaterThanOrEqual(laterCounter - counter, frequency / 50)
    // Time asleep or hibernating counts only in the biased clock.
    XCTAssertLessThanOrEqual(unbiased, Win32.interruptTime())
  }

  func testIntervalsAsDurations() {
    XCTAssertEqual(Win32._duration(intervals: 0), .zero)
    XCTAssertEqual(Win32._duration(intervals: 1), .nanoseconds(100))
    XCTAssertEqual(Win32._duration(intervals: 10_000_000), .seconds(1))
    XCTAssertEqual(Win32._duration(intervals: 25_000_001), .seconds(2.5) + .nanoseconds(100))
  }

  func testSleepYieldsForNonpositiveDurations() {
    let start = Win32.unbiasedInterruptTime()
    Win32.sleep(for: .zero)
    Win32.sleep(for: .seconds(-5))
    XCTAssertLessThan(Win32.unbiasedInterruptTime() - start, .seconds(5))
  }
}

#endif // os(Windows)
