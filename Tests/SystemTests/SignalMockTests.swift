/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the signal and process-group wrappers, checked against the calls
// they make. None of these calls fail with EINTR, so the cases are
// .noInterrupt: a forced EINTR is thrown, never retried. The mask calls can't
// fail, so their wrappers don't throw, and those cases are .noError.

#if ENABLE_MOCKING && !os(Windows) && !os(WASI)

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

@available(System 199, *)
final class SignalMockTests: XCTestCase {
  func testSendingSignals() {
    let process = ProcessID(rawValue: 4242)
    let thread = PThread.ID.current
    let cases: [MockTestCase] = [
      MockTestCase(name: "kill", .noInterrupt, 4242 as pid_t, SIGTERM) { _ in
        try process.sendSignal(.terminate)
      },
      MockTestCase(name: "kill", .noInterrupt, 4242 as pid_t, 0 as CInt) { _ in
        try process.sendSignal(nil)
      },
      MockTestCase(name: "killpg", .noInterrupt, 4242 as pid_t, SIGINT) { _ in
        try process.sendSignalToProcessGroup(.interrupt)
      },
      MockTestCase(name: "kill", .noInterrupt, -1 as pid_t, SIGHUP) { _ in
        try ProcessID.sendSignalToAllProcesses(.hangup)
      },
      MockTestCase(name: "raise", .noInterrupt, SIGUSR1) { _ in
        try Signal.userDefined1.raise()
      },
      MockTestCase(name: "pthread_kill", .noInterrupt, thread.rawValue, SIGUSR2) { _ in
        try thread.sendSignal(.userDefined2)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }

  // kill and killpg give IDs below 1 and 2 other meanings, which the
  // wrappers leave to their own methods.
  func testSignalsNeverReachSpecialIDs() throws {
    try MockingDriver.withMockingEnabled { mocking in
      for id: pid_t in [0, -1, -4242] {
        XCTAssertThrowsError(try ProcessID(rawValue: id).sendSignal(.kill)) {
          XCTAssertEqual($0 as? Errno, .invalidArgument)
        }
      }
      for id: pid_t in [1, 0, -1] {
        XCTAssertThrowsError(try ProcessID(rawValue: id).sendSignalToProcessGroup(.kill)) {
          XCTAssertEqual($0 as? Errno, .invalidArgument)
        }
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testActions() {
    let handler: @convention(c) (CInt) -> Void = { _ in }
    let bits = unsafeBitCast(handler, to: Int.self)
    let cases: [MockTestCase] = [
      // No new action: the handler and flags are recorded as -1.
      MockTestCase(name: "sigaction", .noInterrupt, SIGUSR1, -1, -1) { _ in
        _ = try Signal.userDefined1.action()
      },
      MockTestCase(name: "sigaction", .noInterrupt, SIGPIPE, 1, 0) { _ in
        try Signal.brokenPipe.setAction(.ignore)
      },
      MockTestCase(name: "sigaction", .noInterrupt, SIGPIPE, 0, 0) { _ in
        try Signal.brokenPipe.setAction(.default)
      },
      MockTestCase(name: "sigaction", .noInterrupt, SIGUSR2, bits, Int(SA_RESTART)) { _ in
        try Signal.userDefined2.setAction(
          Signal.Action(handler: .function(handler), flags: [.restart]))
      },
    ]
    cases.forEach { $0.runAllTests() }
  }

  func testMasks() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "pthread_sigmask", .noError, SIG_BLOCK, [SIGUSR1]) { _ in
        PThread.blockSignals([.userDefined1])
      },
      MockTestCase(name: "pthread_sigmask", .noError, SIG_UNBLOCK, [SIGUSR1, SIGUSR2]) { _ in
        PThread.unblockSignals([.userDefined1, .userDefined2])
      },
      MockTestCase(name: "pthread_sigmask", .noError, SIG_SETMASK, [CInt]()) { _ in
        PThread.setCurrentSignalMask([])
      },
      MockTestCase(name: "pthread_sigmask", .noError, SIG_BLOCK, [CInt]?.none) { _ in
        _ = PThread.currentSignalMask()
      },
      MockTestCase(name: "sigsuspend", .noError, [SIGINT]) { _ in
        PThread.suspendUntilSignal(mask: [.interrupt])
      },
      MockTestCase(name: "sigwait", .noInterrupt, [SIGINT, SIGTERM]) { _ in
        let signal = try PThread.waitForSignal(in: [.interrupt, .terminate])
        XCTAssertEqual(signal, .interrupt)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }

  func testProcessGroupsAndSessions() {
    let process = ProcessID(rawValue: 4242)
    let cases: [MockTestCase] = [
      MockTestCase(name: "getpgid", .noInterrupt, 4242 as pid_t) { _ in
        _ = try process.processGroup()
      },
      MockTestCase(name: "setpgid", .noInterrupt, 4242 as pid_t, 4242 as pid_t) { _ in
        try process.setProcessGroup(process)
      },
      MockTestCase(name: "getsid", .noInterrupt, 4242 as pid_t) { _ in
        _ = try process.sessionID()
      },
      MockTestCase(name: "setsid", .noInterrupt) { _ in
        try ProcessID.createSession()
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
}

#endif // ENABLE_MOCKING && !os(Windows) && !os(WASI)
