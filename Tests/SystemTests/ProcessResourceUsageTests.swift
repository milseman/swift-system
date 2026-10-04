/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// getrusage. The children's usage counts only children that have ended and
// been waited for, which other tests' children can be at any time, so these
// check its shape, not its values.

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class ProcessResourceUsageTest: XCTestCase {
  func testTheCallingProcess() throws {
    let usage = try ProcessID.resourceUsage()
    // A process that's running holds some memory.
    XCTAssertGreaterThan(usage.maxResidentSetSize, 0)
    for time in [usage.userTime, usage.systemTime] {
      XCTAssertGreaterThanOrEqual(time.seconds, 0)
      XCTAssertTrue((0..<1_000_000).contains(time.microseconds))
    }
    for count in [
      usage.minorPageFaults, usage.majorPageFaults, usage.swaps,
      usage.blockInputs, usage.blockOutputs, usage.messagesSent,
      usage.messagesReceived, usage.signalsReceived,
      usage.voluntaryContextSwitches, usage.involuntaryContextSwitches,
    ] {
      XCTAssertGreaterThanOrEqual(count, 0)
    }
  }

  func testTheChildren() throws {
    let usage = try ProcessID.resourceUsage(of: .children)
    XCTAssertGreaterThanOrEqual(usage.maxResidentSetSize, 0)
    XCTAssertTrue((0..<1_000_000).contains(usage.userTime.microseconds))
  }

  #if ENABLE_MOCKING
  func testSyscalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "getrusage", .noInterrupt, _RUSAGE_SELF) { _ in
        _ = try ProcessID.resourceUsage(of: .current)
      },
      MockTestCase(name: "getrusage", .noInterrupt, _RUSAGE_CHILDREN) { _ in
        _ = try ProcessID.resourceUsage(of: .children)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
