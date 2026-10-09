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

import ucrt

/// How many times the test's SIGINT handler ran.
nonisolated(unsafe) private var interruptsHandled = 0

// Signal on Windows: the C runtime's numbers, names, and raise. Signal
// handlers are process-wide, which is why these are XCTest's: one test at a
// time. The one test that raises a real signal installs a handler first,
// and restores the previous one.
@available(System 199, *)
final class Win32SignalTests: XCTestCase {
  func testNumbersMatchTheCRuntime() {
    let signals: [(Signal, CInt)] = [
      (.interrupt, ucrt.SIGINT),
      (.illegalInstruction, ucrt.SIGILL),
      (.floatingPointException, ucrt.SIGFPE),
      (.segmentationViolation, ucrt.SIGSEGV),
      (.terminate, ucrt.SIGTERM),
      (.controlBreak, ucrt.SIGBREAK),
      (.abort, ucrt.SIGABRT),
    ]
    for (signal, number) in signals {
      XCTAssertEqual(signal.rawValue, number, signal.description)
    }
  }

  func testNames() {
    XCTAssertEqual(Signal.interrupt.description, "SIGINT")
    XCTAssertEqual(Signal.abort.name, "SIGABRT")
    XCTAssertEqual(Signal.controlBreak.name, "SIGBREAK")
    XCTAssertNil(Signal(rawValue: 9).name)
    XCTAssertEqual(Signal(rawValue: 9).description, "Signal(rawValue: 9)")
  }

  func testRaisingANumberThatIsntASignalThrows() {
    // The C runtime reports it to the invalid parameter handler, which
    // raise(), unlike a direct call, keeps from ending the process.
    XCTAssertThrowsError(try Signal(rawValue: 99).raise()) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }

  func testRaisingASignalRunsItsHandler() throws {
    let handler: _crt_signal_t = { _ in interruptsHandled += 1 }
    let previous = ucrt.signal(ucrt.SIGINT, handler)
    // SIG_ERR is -1 as a function pointer; without the handler, raising
    // SIGINT would end the test process.
    guard unsafeBitCast(previous, to: Int.self) != -1 else {
      throw XCTSkip("signal(SIGINT) failed")
    }
    defer { _ = ucrt.signal(ucrt.SIGINT, previous) }
    let before = interruptsHandled
    try Signal.interrupt.raise()
    XCTAssertEqual(interruptsHandled, before + 1)
  }

  #if ENABLE_MOCKING
  func testRaiseCallsTheCRuntime() throws {
    try MockingDriver.withMockingEnabled { mocking in
      try Signal.terminate.raise()
      let entry = mocking.trace.dequeue()
      XCTAssertEqual(entry?.name, "raise")
      XCTAssertEqual(entry?.arguments, [ucrt.SIGTERM])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#endif // os(Windows)
