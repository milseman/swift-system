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

// Tests for the foreground process group and session of a terminal.
//
// These are XCTest tests, which run one at a time, because setting the
// foreground process group changes the controlling terminal, which the
// whole process shares. Most of what these methods do requires a
// controlling terminal. A test run from a terminal has one, and so does one
// run with `script -q /dev/null swift test`, but one run in CI may not, and
// then those tests skip.
@available(System 199, *)
final class TerminalJobControlTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let terminal = TerminalDescriptor(rawValue: 1)
    let rawFD = terminal.rawValue

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "tcgetpgrp", .noInterrupt, rawFD) { _ in
        _ = try terminal.foregroundProcessGroup()
      },

      MockTestCase(name: "tcsetpgrp", .interruptable, rawFD, 42) { retryOnInterrupt in
        try terminal.setForegroundProcessGroup(
          ProcessID(42), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "tcgetsid", .noInterrupt, rawFD) { _ in
        _ = try terminal.sessionID()
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  func testControllingTerminal() throws {
    // /dev/tty is the process's controlling terminal, if it has one.
    let tty: FileDescriptor
    do {
      tty = try FileDescriptor.open("/dev/tty", .readWrite)
    } catch {
      throw XCTSkip("The process has no controlling terminal: \(error)")
    }
    defer { try? tty.close() }
    let terminal = try TerminalDescriptor(tty)

    XCTAssertEqual(try terminal.sessionID(), ProcessID(getsid(0)))
    let original = try terminal.foregroundProcessGroup()
    XCTAssertGreaterThan(original.rawValue, 0)

    // `swift test` runs tests in a process group of their own, which isn't
    // in the foreground. Changing the foreground process group from the
    // background sends SIGTTOU, which stops the process, unless the calling
    // thread blocks it.
    var stopSignal = sigset_t()
    sigemptyset(&stopSignal)
    sigaddset(&stopSignal, SIGTTOU)
    var previousMask = sigset_t()
    pthread_sigmask(SIG_BLOCK, &stopSignal, &previousMask)
    defer { pthread_sigmask(SIG_SETMASK, &previousMask, nil) }

    // Bring this process's group to the foreground, then hand the terminal
    // back to the group that had it.
    let own = ProcessID(getpgrp())
    defer { try? terminal.setForegroundProcessGroup(original) }
    try terminal.setForegroundProcessGroup(own)
    XCTAssertEqual(try terminal.foregroundProcessGroup(), own)
    try terminal.setForegroundProcessGroup(original)
    XCTAssertEqual(try terminal.foregroundProcessGroup(), original)

    // A process group that doesn't exist can't have the terminal.
    // Darwin reports EINVAL; Linux reports ESRCH.
    XCTAssertThrowsError(try terminal.setForegroundProcessGroup(ProcessID(.max)))
    XCTAssertEqual(try terminal.foregroundProcessGroup(), original)
  }

  // glibc declares posix_openpt(3) and friends only under _XOPEN_SOURCE,
  // which Swift's Glibc module doesn't define.
  #if !(os(Linux) && canImport(Glibc))
  func testNotTheControllingTerminal() throws {
    // A pseudoterminal opened with O_NOCTTY is a terminal,
    // but not this process's controlling terminal.
    let controller = FileDescriptor(rawValue: posix_openpt(O_RDWR | O_NOCTTY))
    guard controller.rawValue != -1 else { throw Errno.current }
    defer { try? controller.close() }
    guard grantpt(controller.rawValue) == 0,
          unlockpt(controller.rawValue) == 0,
          let path = ptsname(controller.rawValue)
    else { throw Errno.current }
    let fd = try FileDescriptor.open(
      path, .readWrite, options: FileDescriptor.OpenOptions(rawValue: O_NOCTTY))
    defer { try? fd.close() }
    let terminal = try TerminalDescriptor(fd)

    XCTAssertThrowsError(try terminal.foregroundProcessGroup()) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
    XCTAssertThrowsError(try terminal.sessionID()) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
    XCTAssertThrowsError(try terminal.setForegroundProcessGroup(ProcessID(getpgrp()))) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
  }
  #endif

  func testNotATerminal() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let notATerminal = TerminalDescriptor(unchecked: pipe.readEnd)
    XCTAssertThrowsError(try notATerminal.foregroundProcessGroup()) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
    XCTAssertThrowsError(try notATerminal.sessionID()) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
    XCTAssertThrowsError(
      try notATerminal.setForegroundProcessGroup(ProcessID(getpgrp()))
    ) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }

    let closed = TerminalDescriptor(rawValue: -1)
    XCTAssertThrowsError(try closed.foregroundProcessGroup()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    XCTAssertThrowsError(try closed.sessionID()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    XCTAssertThrowsError(try closed.setForegroundProcessGroup(ProcessID(getpgrp()))) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
