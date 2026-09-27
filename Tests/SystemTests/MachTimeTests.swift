/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class MachTimeTest: XCTestCase {
  func testTimebase() {
    var info = mach_timebase_info_data_t()
    XCTAssertEqual(mach_timebase_info(&info), KERN_SUCCESS)
    XCTAssertEqual(
      Mach.Timebase.current, Mach.Timebase(numerator: info.numer, denominator: info.denom))
    #if arch(arm64)
    XCTAssertEqual(Mach.Timebase.current, Mach.Timebase(numerator: 125, denominator: 3))
    #endif
  }

  func testConversions() {
    let silicon = Mach.Timebase(numerator: 125, denominator: 3)
    XCTAssertEqual(silicon.nanoseconds(ofTicks: 3), 125)
    XCTAssertEqual(silicon.nanoseconds(ofTicks: 1), 41)
    XCTAssertEqual(silicon.nanoseconds(ofTicks: 0), 0)
    XCTAssertEqual(silicon.ticks(inNanoseconds: 125), 3)
    XCTAssertEqual(silicon.ticks(inNanoseconds: 1_000_000_000), 24_000_000)
    XCTAssertEqual(silicon.ticks(in: .seconds(1)), 24_000_000)
    XCTAssertEqual(silicon.ticks(in: .milliseconds(1)), 24_000)
    XCTAssertEqual(silicon.duration(ofTicks: 24_000_000), .seconds(1))
    XCTAssertEqual(silicon.duration(ofTicks: 3), .nanoseconds(125))

    // Results too large for a UInt64 saturate.
    XCTAssertEqual(silicon.nanoseconds(ofTicks: .max), .max)
    XCTAssertEqual(silicon.ticks(inNanoseconds: .max), UInt64.max / 125 * 3 + 2)
    XCTAssertEqual(silicon.ticks(in: .seconds(Int64.max)), .max)
    XCTAssertEqual(silicon.duration(ofTicks: .max), .nanoseconds(UInt64.max))

    let intel = Mach.Timebase(numerator: 1, denominator: 1)
    XCTAssertEqual(intel.nanoseconds(ofTicks: 12345), 12345)
    XCTAssertEqual(intel.ticks(inNanoseconds: .max), .max)
    XCTAssertEqual(intel.ticks(in: .nanoseconds(7)), 7)
    // Parts of a nanosecond round down.
    XCTAssertEqual(intel.ticks(in: .nanoseconds(7) + .seconds(0.5e-9)), 7)
  }

  func testClocks() throws {
    let timebase = Mach.Timebase.current

    // The absolute clock is CLOCK_UPTIME_RAW, in other units.
    let before = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    let absolute = Mach.AbsoluteTime.now
    let after = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    let nanoseconds = timebase.nanoseconds(ofTicks: absolute.rawValue)
    XCTAssertGreaterThanOrEqual(nanoseconds + 1_000, before)
    XCTAssertLessThanOrEqual(nanoseconds, after + 1_000)

    // The continuous clock is CLOCK_MONOTONIC_RAW, which counts sleep too.
    let continuousBefore = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let continuous = Mach.ContinuousTime.now
    let continuousAfter = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let continuousNanoseconds = timebase.nanoseconds(ofTicks: continuous.rawValue)
    XCTAssertGreaterThanOrEqual(continuousNanoseconds + 1_000, continuousBefore)
    XCTAssertLessThanOrEqual(continuousNanoseconds, continuousAfter + 1_000)
    XCTAssertGreaterThanOrEqual(continuous.rawValue, absolute.rawValue)

    // The approximate times trail the precise ones.
    XCTAssertLessThanOrEqual(Mach.AbsoluteTime.approximateNow, Mach.AbsoluteTime.now)
    XCTAssertLessThanOrEqual(Mach.ContinuousTime.approximateNow, Mach.ContinuousTime.now)
    XCTAssertLessThan(absolute, Mach.AbsoluteTime.now)
  }

  func testInstants() throws {
    let start = Mach.AbsoluteTime.now
    let clockStart = SuspendingClock.now
    usleep(20_000)
    let elapsed = start.duration(to: .now)
    let clockElapsed = clockStart.duration(to: .now)
    XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(20))
    XCTAssertLessThanOrEqual(elapsed, clockElapsed + .microseconds(1))

    // Durations run both ways, to the nearest tick.
    let tick = Mach.Timebase.current.duration(ofTicks: 1) + .nanoseconds(1)
    let later = start.advanced(by: .seconds(1))
    XCTAssertGreaterThan(later, start)
    XCTAssertLessThanOrEqual(abs(start.duration(to: later) - .seconds(1)), tick)
    XCTAssertLessThanOrEqual(abs(later.duration(to: start) + .seconds(1)), tick)
    XCTAssertEqual(later.advanced(by: .seconds(-1)), start)
    XCTAssertEqual(start.advanced(by: .zero), start)

    let continuous = Mach.ContinuousTime.now
    XCTAssertEqual(continuous.advanced(by: .seconds(5)).advanced(by: .seconds(-5)), continuous)
    XCTAssertGreaterThan(continuous.duration(to: .now), .zero)
  }

  #if os(macOS)
  func testKernelTimes() throws {
    // The kernel reports a process's start in absolute time.
    let info = try ProcessID.current.resourceUsageInfo()
    let started = Mach.AbsoluteTime(rawValue: info.startAbsoluteTime)
    XCTAssertGreaterThan(started.duration(to: .now), .zero)
    XCTAssertEqual(
      _duration(machAbsoluteTime: info.startAbsoluteTime),
      Mach.Timebase.current.duration(ofTicks: info.startAbsoluteTime))
  }
  #endif

  private func abs(_ duration: Duration) -> Duration {
    duration < .zero ? .zero - duration : duration
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
