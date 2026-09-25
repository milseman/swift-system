/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The termios wrappers, checked against the calls they make. The mocks record
// the termios and winsize arguments as pointers, which the tests don't check;
// TerminalTests checks the values on a pseudoterminal.
#if ENABLE_MOCKING
@available(System 199, *)
final class TerminalMockTests: XCTestCase {
  func testSyscalls() {
    let terminal = TerminalDescriptor(rawValue: 42)
    let attributes = TerminalAttributes()
    let size = TerminalDescriptor.WindowSize(rows: 24, columns: 80)

    var syscallTestCases: [MockTestCase] = [
      // tcgetattr can't be interrupted, so it has no retryOnInterrupt.
      MockTestCase(name: "tcgetattr", .noInterrupt, 42, Wildcard()) { _ in
        _ = try terminal.attributes()
      },

      MockTestCase(name: "tcsetattr", .interruptable, 42, TCSANOW, Wildcard()) {
        retryOnInterrupt in
        try terminal.setAttributes(
          attributes, when: .now, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcsetattr", .interruptable, 42, TCSADRAIN, Wildcard()) {
        retryOnInterrupt in
        try terminal.setAttributes(
          attributes, when: .afterDrain, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcsetattr", .interruptable, 42, TCSAFLUSH, Wildcard()) {
        retryOnInterrupt in
        try terminal.setAttributes(
          attributes, when: .afterFlush, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcdrain", .interruptable, 42) { retryOnInterrupt in
        try terminal.drain(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflush", .interruptable, 42, TCIFLUSH) { retryOnInterrupt in
        try terminal.flush(.input, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflush", .interruptable, 42, TCOFLUSH) { retryOnInterrupt in
        try terminal.flush(.output, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflush", .interruptable, 42, TCIOFLUSH) { retryOnInterrupt in
        try terminal.flush(.both, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflow", .interruptable, 42, TCOOFF) { retryOnInterrupt in
        try terminal.flow(.suspendOutput, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflow", .interruptable, 42, TCOON) { retryOnInterrupt in
        try terminal.flow(.resumeOutput, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflow", .interruptable, 42, TCIOFF) { retryOnInterrupt in
        try terminal.flow(.sendStop, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcflow", .interruptable, 42, TCION) { retryOnInterrupt in
        try terminal.flow(.sendStart, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcsendbreak", .interruptable, 42, 0) { retryOnInterrupt in
        try terminal.sendBreak(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcsendbreak", .interruptable, 42, 3) { retryOnInterrupt in
        try terminal.sendBreak(duration: 3, retryOnInterrupt: retryOnInterrupt)
      },

      // Getting the window size can't be interrupted; setting it can.
      MockTestCase(name: "tiocgwinsz", .noInterrupt, 42, Wildcard()) { _ in
        _ = try terminal.windowSize()
      },

      MockTestCase(name: "tiocswinsz", .interruptable, 42, Wildcard()) { retryOnInterrupt in
        try terminal.setWindowSize(size, retryOnInterrupt: retryOnInterrupt)
      },

      // setSpeed changes only the attributes value, so it can't be
      // interrupted, and doesn't throw.
      MockTestCase(name: "cfsetspeed", .noError, Wildcard(), B9600) { _ in
        var attributes = TerminalAttributes()
        attributes.setSpeed(.b9600)
      },
    ]

    #if SYSTEM_PACKAGE_DARWIN
    syscallTestCases.append(
      MockTestCase(name: "tcsetattr", .interruptable, 42, TCSASOFT, Wildcard()) {
        retryOnInterrupt in
        try terminal.setAttributes(
          attributes, when: .soft, retryOnInterrupt: retryOnInterrupt)
      })
    #endif

    for test in syscallTestCases { test.runAllTests() }
  }

  func testWrappersReportTheCallsErrors() throws {
    // Each wrapper throws the error its call fails with, without retrying.
    let terminal = TerminalDescriptor(rawValue: 42)
    let calls: [(name: String, call: () throws -> Void)] = [
      ("tcgetattr", { _ = try terminal.attributes() }),
      ("tcsetattr", { try terminal.setAttributes(TerminalAttributes(), when: .now) }),
      ("tcdrain", { try terminal.drain() }),
      ("tcflush", { try terminal.flush(.both) }),
      ("tcflow", { try terminal.flow(.resumeOutput) }),
      ("tcsendbreak", { try terminal.sendBreak() }),
      ("tiocgwinsz", { _ = try terminal.windowSize() }),
      ("tiocswinsz", { try terminal.setWindowSize(.init(rows: 1, columns: 1)) }),
    ]
    try MockingDriver.withMockingEnabled { mocking in
      for (name, call) in calls {
        mocking.forceErrno = .always(errno: ENOTTY)
        XCTAssertThrowsError(try call(), name) {
          XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice, name)
        }
        XCTAssertEqual(mocking.trace.dequeue()?.name, name)
        XCTAssertTrue(mocking.trace.isEmpty, name)
      }
    }
  }

  func testWithAttributesRestoresTheOriginalAttributes() throws {
    let terminal = TerminalDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      // The changed attributes apply after a flush, as `when`
      // defaults to, and the original ones immediately afterward.
      let result = try terminal.withAttributes({ $0.localFlags.remove(.echo) }) {
        expectCall(mocking, "tcgetattr", 42, Wildcard())
        expectCall(mocking, "tcsetattr", 42, TCSAFLUSH, Wildcard())
        return 7
      }
      XCTAssertEqual(result, 7)
      expectCall(mocking, "tcsetattr", 42, TCSANOW, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)

      try terminal.withAttributes(when: .afterDrain, { _ in }) {}
      expectCall(mocking, "tcgetattr", 42, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSADRAIN, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSANOW, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)

      try terminal.withRawMode {}
      expectCall(mocking, "tcgetattr", 42, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSAFLUSH, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSANOW, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testWithAttributesRestoresWhenTheBodyThrows() throws {
    struct BodyError: Error {}
    let terminal = TerminalDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertThrowsError(
        try terminal.withAttributes({ $0.localFlags.remove(.echo) }) {
          throw BodyError()
        }
      ) {
        XCTAssertTrue($0 is BodyError)
      }
      expectCall(mocking, "tcgetattr", 42, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSAFLUSH, Wildcard())
      expectCall(mocking, "tcsetattr", 42, TCSANOW, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testWithAttributesChangesNothingWhenItCantStart() throws {
    struct ModifyError: Error {}
    let terminal = TerminalDescriptor(rawValue: 42)
    try MockingDriver.withMockingEnabled { mocking in
      // If the attributes can't be read, neither closure runs.
      mocking.forceErrno = .counted(errno: EBADF, count: 1)
      XCTAssertThrowsError(
        try terminal.withAttributes({ _ in XCTFail("modify ran") }) {
          XCTFail("body ran")
        }
      ) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      expectCall(mocking, "tcgetattr", 42, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)

      // If `modify` throws, the attributes don't change.
      XCTAssertThrowsError(
        try terminal.withAttributes({ _ in throw ModifyError() }) {
          XCTFail("body ran")
        }
      ) {
        XCTAssertTrue($0 is ModifyError)
      }
      expectCall(mocking, "tcgetattr", 42, Wildcard())
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
}

/// Checks that the next call in the trace is `name`, with `arguments`.
private func expectCall(
  _ mocking: MockingDriver, _ name: String, _ arguments: AnyHashable...,
  file: StaticString = #filePath, line: UInt = #line
) {
  let expected = Trace.Entry(name: name, arguments)
  guard let actual = mocking.trace.dequeue() else {
    XCTFail("expected \(expected), but the trace is empty", file: file, line: line)
    return
  }
  XCTAssertTrue(
    expected.matches(actual), "expected \(expected), got \(actual)", file: file, line: line)
}
#endif // ENABLE_MOCKING

#endif // !os(Windows) && !os(WASI)
