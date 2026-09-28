/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING

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

@available(System 199, *)
final class PseudoterminalMockTests: XCTestCase {
  func testCalls() {
    MockTestCase(name: "ptsname_r", .noInterrupt, 7, 127) { _ in
      _ = try FileDescriptor(rawValue: 7).pseudoterminalPath()
    }.runAllTests()
  }

  /// openPseudoterminal opens the controller, grants access to its
  /// terminal, unlocks it, finds its path, and opens it,
  /// with the same flags as the controller.
  func testOpeningASequence() throws {
    try MockingDriver.withMockingEnabled { mocking in
      // A mocked posix_openpt returns descriptor 0, and a mocked ptsname_r
      // leaves the path empty.
      _ = try TerminalDescriptor.openPseudoterminal()
      let flags = O_RDWR | O_NOCTTY | O_CLOEXEC
      let expected: [(String, [AnyHashable])] = [
        ("posix_openpt", [flags]),
        ("grantpt", [CInt(0)]),
        ("unlockpt", [CInt(0)]),
        ("ptsname_r", [CInt(0), 127]),
        ("open", ["", flags]),
      ]
      for (name, arguments) in expected {
        let entry = mocking.trace.dequeue()
        XCTAssertEqual(entry?.name, name)
        XCTAssertEqual(entry?.arguments, arguments, name)
      }
      XCTAssertNil(mocking.trace.dequeue())

      _ = try TerminalDescriptor.openPseudoterminal(closeOnExec: false)
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [O_RDWR | O_NOCTTY])
    }
  }

  /// The attributes and the window size apply to the terminal.
  func testConfiguringTheTerminal() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try TerminalDescriptor.openPseudoterminal(
        attributes: TerminalAttributes(), windowSize: .init(rows: 24, columns: 80))
      var names: [String] = []
      while let entry = mocking.trace.dequeue() { names.append(entry.name) }
      XCTAssertEqual(
        names, ["posix_openpt", "grantpt", "unlockpt", "ptsname_r", "open", "tcsetattr", "tiocswinsz"])
    }
  }

  /// A failure to open the controller makes no other call.
  func testAFailedOpenStops() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EAGAIN, count: 1)
      XCTAssertThrowsError(try TerminalDescriptor.openPseudoterminal()) { error in
        XCTAssertEqual(error as? Errno, .resourceTemporarilyUnavailable)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "posix_openpt")
      XCTAssertNil(mocking.trace.dequeue())
    }
  }

  /// An interrupted open of the controller is retried.
  func testAnInterruptedOpenIsRetried() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      _ = try TerminalDescriptor.openPseudoterminal()
      XCTAssertEqual(mocking.trace.dequeue()?.name, "posix_openpt")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "posix_openpt")
      XCTAssertEqual(mocking.trace.dequeue()?.name, "grantpt")
    }
  }
}

#endif // (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING
