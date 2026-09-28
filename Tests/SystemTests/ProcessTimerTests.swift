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

// The timers belong to the whole process, and their signals end it, so
// these tests are XCTests, which run one at a time in a process of their
// own. None lets a timer expire unless its signal is ignored.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class ProcessTimerTests: XCTestCase {
  typealias Schedule = ProcessTimer.Schedule

  override func tearDown() {
    for timer in [ProcessTimer.real, .virtual, .profiling] {
      _ = try? timer.setSchedule(.disarmed)
    }
  }

  func testSettingAndReadingEachTimer() throws {
    for timer in [ProcessTimer.real, .virtual, .profiling] {
      XCTAssertEqual(try timer.schedule(), .disarmed)
      let previous = try timer.setSchedule(
        Schedule(nextExpiration: .seconds(100), interval: .seconds(1)))
      XCTAssertEqual(previous, .disarmed)

      let schedule = try timer.schedule()
      XCTAssertLessThanOrEqual(schedule.nextExpiration, .seconds(100))
      XCTAssertGreaterThan(schedule.nextExpiration, .seconds(99))
      XCTAssertEqual(schedule.interval, .seconds(1))

      let running = try timer.setSchedule(.disarmed)
      XCTAssertGreaterThan(running.nextExpiration, .seconds(99))
      XCTAssertEqual(try timer.schedule(), .disarmed)
    }
  }

  func testTimesRoundUpToMicroseconds() {
    var schedule = Schedule(nextExpiration: .nanoseconds(1), interval: .nanoseconds(1500))
    XCTAssertEqual(schedule.rawValue.it_value.tv_sec, 0)
    XCTAssertEqual(schedule.rawValue.it_value.tv_usec, 1, "a positive time doesn't stop the timer")
    XCTAssertEqual(schedule.interval, .microseconds(2))
    schedule.nextExpiration = .seconds(-5)
    XCTAssertEqual(schedule, Schedule(nextExpiration: .zero, interval: .microseconds(2)))
    schedule.nextExpiration = Duration(secondsComponent: 1, attosecondsComponent: 999_999_999_999_999_999)
    XCTAssertEqual(schedule.nextExpiration, .seconds(2))
    XCTAssertEqual(Schedule.disarmed, Schedule(nextExpiration: .zero))
  }

  /// A one-shot timer is disarmed once it expires. SIGALRM is ignored, so
  /// that it doesn't end the test process.
  func testAnExpiredOneShotTimerIsDisarmed() throws {
    let previous = signal(SIGALRM, SIG_IGN)
    defer { signal(SIGALRM, previous) }
    try ProcessTimer.real.setSchedule(Schedule(nextExpiration: .milliseconds(10)))
    usleep(100_000)
    XCTAssertEqual(try ProcessTimer.real.schedule(), .disarmed)
  }

  func testAlarmSetsTheRealTimer() throws {
    XCTAssertEqual(ProcessTimer.setAlarm(seconds: 100), 0)
    let schedule = try ProcessTimer.real.schedule()
    XCTAssertGreaterThan(schedule.nextExpiration, .seconds(99))
    XCTAssertEqual(schedule.interval, .zero)

    // The time left rounds up.
    try ProcessTimer.real.setSchedule(Schedule(nextExpiration: .milliseconds(2400)))
    XCTAssertEqual(ProcessTimer.setAlarm(seconds: 0), 3)
    XCTAssertEqual(try ProcessTimer.real.schedule(), .disarmed)
    XCTAssertEqual(ProcessTimer.setAlarm(seconds: 0), 0)
  }

  func testAnUnknownTimer() {
    XCTAssertThrowsError(try ProcessTimer(rawValue: 99).schedule()) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
