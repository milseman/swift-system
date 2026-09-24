/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// libproc is only in the macOS SDK.
#if os(macOS)

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
@available(macOS 13.0, *)
final class ProcessResourceTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let pid = ProcessID(42)
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "proc_pid_rusage", .noInterrupt, 42, RUSAGE_INFO_V6, Wildcard()) {
        _ in
        _ = try pid.resourceUsageInfo()
      },

      MockTestCase(
        name: "proc_pidinfo", .noInterrupt, 42, PROC_PIDTASKINFO, 0, Wildcard(),
        CInt(MemoryLayout<proc_taskinfo>.size)
      ) { _ in
        _ = try pid.taskInfo()
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  // The user time the system reports through getrusage, which is in
  // microseconds, brackets the time from each call, which is in Mach
  // absolute time units. Those aren't nanoseconds on Apple silicon,
  // so this checks the conversion.
  func testProcessorTimes() throws {
    // Spend some user time.
    var sum = 0.0
    for i in 0..<5_000_000 { sum += Double(i).squareRoot() }
    XCTAssertGreaterThan(sum, 0)

    let before = userTime()
    let usage = try ProcessID.current.resourceUsageInfo()
    let task = try ProcessID.current.taskInfo()
    let after = userTime()

    // getrusage truncates to microseconds.
    let slack = Duration.microseconds(1)
    XCTAssertGreaterThan(usage.userTime, .zero)
    XCTAssertGreaterThanOrEqual(usage.userTime + slack, before)
    XCTAssertLessThanOrEqual(usage.userTime, after + slack)
    XCTAssertGreaterThanOrEqual(task.totalUserTime + slack, before)
    XCTAssertLessThanOrEqual(task.totalUserTime, after + slack)
    XCTAssertLessThanOrEqual(task.existingThreadsUserTime, task.totalUserTime)
    XCTAssertLessThanOrEqual(usage.performanceCoreUserTime, usage.userTime)
    XCTAssertGreaterThan(usage.systemTime, .zero)
    XCTAssertGreaterThan(task.totalSystemTime, .zero)
  }

  func testResourceUsageInfo() throws {
    let info = try ProcessID.current.resourceUsageInfo()
    XCTAssertGreaterThan(info.residentSize, 0)
    XCTAssertGreaterThan(info.physicalFootprint, 0)
    XCTAssertGreaterThanOrEqual(info.lifetimeMaxPhysicalFootprint, info.physicalFootprint)
    XCTAssertGreaterThan(info.instructions, 0)
    XCTAssertGreaterThan(info.cycles, 0)
    // The process started in the past, and hasn't exited.
    XCTAssertGreaterThan(info.startAbsoluteTime, 0)
    XCTAssertLessThan(info.startAbsoluteTime, mach_absolute_time())
    XCTAssertEqual(info.exitAbsoluteTime, 0)
    // The test runner is an executable with a UUID.
    XCTAssertFalse(withUnsafeBytes(of: info.executableUUID) { $0.allSatisfy { $0 == 0 } })

    // A process of the same user, such as the parent, is visible.
    XCTAssertGreaterThan(try ProcessID.parent.resourceUsageInfo().residentSize, 0)
  }

  func testTaskInfo() throws {
    let info = try ProcessID.current.taskInfo()
    XCTAssertGreaterThan(info.residentSize, 0)
    XCTAssertGreaterThan(info.virtualSize, info.residentSize)
    XCTAssertGreaterThanOrEqual(info.threadCount, 1)
    XCTAssertGreaterThanOrEqual(info.runningThreadCount, 1)
    XCTAssertGreaterThan(info.unixSystemCalls, 0)
    XCTAssertGreaterThan(info.contextSwitches, 0)

    XCTAssertGreaterThanOrEqual(try ProcessID.parent.taskInfo().threadCount, 1)
  }

  func testErrors() throws {
    // PIDs don't get this large.
    let missing = ProcessID(.max)
    XCTAssertThrowsError(try missing.resourceUsageInfo()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    XCTAssertThrowsError(try missing.taskInfo()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }

    // launchd belongs to root.
    guard geteuid() != 0 else { throw XCTSkip("The test runs with privileges") }
    XCTAssertThrowsError(try ProcessID(1).resourceUsageInfo()) {
      XCTAssertEqual($0 as? Errno, .notPermitted)
    }
    XCTAssertThrowsError(try ProcessID(1).taskInfo()) {
      XCTAssertEqual($0 as? Errno, .notPermitted)
    }
  }

  func testMachAbsoluteTimeConversion() {
    var timebase = mach_timebase_info_data_t()
    _ = mach_timebase_info(&timebase)
    let ticks = UInt64(1_000_000_000) * UInt64(timebase.denom)
    XCTAssertEqual(
      _duration(machAbsoluteTime: ticks), .nanoseconds(1_000_000_000 * Int64(timebase.numer)))
    XCTAssertEqual(_duration(machAbsoluteTime: 0), .zero)
    // Too many ticks for nanoseconds to fit saturates, rather than trapping.
    if timebase.numer > timebase.denom {
      XCTAssertEqual(_duration(machAbsoluteTime: .max), .nanoseconds(UInt64.max))
    }
  }

  private func userTime() -> Duration {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return .seconds(usage.ru_utime.tv_sec) + .microseconds(usage.ru_utime.tv_usec)
  }
}

#endif // os(macOS)
