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
// own. None lets a timer expire unless its signal is handled or ignored.
//
// A timer's time left falls while the test waits for a processor, so a test
// that reads it back allows for a delay as long as the hang guard.

/// Set by the SIGALRM handler.
nonisolated(unsafe) private var alarmArrived: CInt = 0

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
    // The virtual and profiling timers count the process's processor time,
    // which runs no faster than the real timer's while one thread works.
    let expiration = Duration.seconds(100_000)
    let least = expiration - .seconds(hangGuardSeconds)
    for timer in [ProcessTimer.real, .virtual, .profiling] {
      XCTAssertEqual(try timer.schedule(), .disarmed)
      let previous = try timer.setSchedule(
        Schedule(nextExpiration: expiration, interval: .seconds(1)))
      XCTAssertEqual(previous, .disarmed)

      // Linux adds a scheduler tick, 1 to 10 ms, to a processor-time
      // timer's expiration, so that it can't expire early.
      #if os(Linux) || os(Android)
      let most = timer == .real ? expiration : expiration + .milliseconds(10)
      #else
      let most = expiration
      #endif
      let schedule = try timer.schedule()
      XCTAssertLessThanOrEqual(schedule.nextExpiration, most)
      XCTAssertGreaterThan(schedule.nextExpiration, least)
      XCTAssertEqual(schedule.interval, .seconds(1))

      let running = try timer.setSchedule(.disarmed)
      XCTAssertGreaterThan(running.nextExpiration, least)
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

  /// A one-shot timer is disarmed once it expires, which its signal shows.
  /// A handler takes the signal, so that it doesn't end the test process.
  func testAnExpiredOneShotTimerIsDisarmed() throws {
    alarmArrived = 0
    let previous = try Signal.alarm.setAction(
      Signal.Action(handler: .function({ _ in alarmArrived = 1 })))
    defer { _ = try? Signal.alarm.setAction(previous) }
    try ProcessTimer.real.setSchedule(Schedule(nextExpiration: .milliseconds(10)))
    // The signal goes to whichever thread doesn't block it, so this waits
    // for the handler rather than for the signal.
    let deadline = ContinuousClock.now + .seconds(hangGuardSeconds)
    while alarmArrived == 0 && ContinuousClock.now < deadline { usleep(1_000) }
    XCTAssertEqual(alarmArrived, 1, "the timer expired")
    XCTAssertEqual(try ProcessTimer.real.schedule(), .disarmed)
  }

  func testAlarmSetsTheRealTimer() throws {
    // SIGALRM is ignored, in case a delay lets the short timer below expire.
    let previous = try Signal.alarm.setAction(.ignore)
    defer { _ = try? Signal.alarm.setAction(previous) }

    XCTAssertEqual(ProcessTimer.setAlarm(seconds: 100_000), 0)
    let schedule = try ProcessTimer.real.schedule()
    XCTAssertGreaterThan(schedule.nextExpiration, .seconds(100_000 - hangGuardSeconds))
    XCTAssertEqual(schedule.interval, .zero)

    // The seconds left are rounded. They're 2.4, less the delay before the
    // call, which the clock around both calls bounds; a delay of less than
    // 0.4 s leaves one answer.
    let clock = ContinuousClock()
    let start = clock.now
    try ProcessTimer.real.setSchedule(Schedule(nextExpiration: .milliseconds(2400)))
    let left = ProcessTimer.setAlarm(seconds: 0)
    let delay = clock.now - start
    XCTAssertGreaterThanOrEqual(left, roundedAlarmSeconds(.milliseconds(2400) - delay))
    XCTAssertLessThanOrEqual(left, roundedAlarmSeconds(.milliseconds(2400)))
    XCTAssertEqual(try ProcessTimer.real.schedule(), .disarmed)
    XCTAssertEqual(ProcessTimer.setAlarm(seconds: 0), 0)
  }

  /// The seconds that `alarm` reports for a timer with `left` to run:
  /// rounded up, but by glibc and the Linux kernel to the nearest second,
  /// and zero for a timer that has expired.
  private func roundedAlarmSeconds(_ left: Duration) -> Int {
    guard left > .zero else { return 0 }
    let (seconds, attoseconds) = left.components
    #if canImport(Glibc)
    let half: Int64 = 500_000_000_000_000_000
    return max(1, Int(seconds) + (attoseconds >= half ? 1 : 0))
    #else
    return Int(seconds) + (attoseconds > 0 ? 1 : 0)
    #endif
  }

  func testAnUnknownTimer() {
    XCTAssertThrowsError(try ProcessTimer(rawValue: 99).schedule()) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
