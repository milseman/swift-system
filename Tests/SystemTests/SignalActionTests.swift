/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: signal actions, masks, and delivery, with real signals. These
// are XCTest tests, which run one at a time in a process of their own: each
// changes a signal's action or the thread's mask, which the whole process
// shares, and restores it.

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

// What the handlers saw. They're plain stores, which is safe in a handler;
// each test reads them before installing a handler, so that no handler
// initializes them.
nonisolated(unsafe) private var handledSignal: CInt = 0
nonisolated(unsafe) private var handledSender: CInt = 0
nonisolated(unsafe) private var handledCode: CInt = 0

@available(System 199, *)
final class SignalActionTests: XCTestCase {
  override func setUp() {
    handledSignal = 0
    handledSender = 0
    handledCode = 0
  }

  func testIgnoringBrokenPipeMakesWritesFail() throws {
    let previous = try Signal.brokenPipe.setAction(.ignore)
    defer { _ = try? Signal.brokenPipe.setAction(previous) }
    XCTAssertEqual(try Signal.brokenPipe.action().handler, .ignore)

    let pipe = try FileDescriptor.pipe()
    defer { try? pipe.writeEnd.close() }
    try pipe.readEnd.close()
    XCTAssertThrowsError(try pipe.writeEnd.writeAll([1])) {
      XCTAssertEqual($0 as? Errno, .brokenPipe)
    }
  }

  func testSetActionReturnsThePreviousAction() throws {
    let original = try Signal.userDefined1.action()
    defer { _ = try? Signal.userDefined1.setAction(original) }
    try Signal.userDefined1.setAction(.ignore)
    let previous = try Signal.userDefined1.setAction(.default)
    XCTAssertEqual(previous.handler, .ignore)
    XCTAssertEqual(try Signal.userDefined1.action().handler, .default)
  }

  func testAFunctionRunsWhenTheSignalArrives() throws {
    let action = Signal.Action(
      handler: .function({ handledSignal = $0 }), mask: [.userDefined2], flags: [.restart])
    let previous = try Signal.userDefined1.setAction(action)
    defer { _ = try? Signal.userDefined1.setAction(previous) }

    let installed = try Signal.userDefined1.action()
    XCTAssertEqual(installed.handler, action.handler)
    XCTAssertEqual(installed.mask, [.userDefined2])
    XCTAssertTrue(installed.flags.contains(.restart))

    // raise delivers the signal to this thread before it returns.
    try Signal.userDefined1.raise()
    XCTAssertEqual(handledSignal, SIGUSR1)
  }

  func testAFunctionWithInfoLearnsTheSender() throws {
    let action = Signal.Action(handler: .functionWithInfo({ signal, info, _ in
      guard let info else { return }
      let information = Signal.Information(rawValue: info.pointee)
      handledSignal = information.signal.rawValue
      handledSender = information.processID.rawValue
      handledCode = information.code
    }))
    let previous = try Signal.userDefined1.setAction(action)
    defer { _ = try? Signal.userDefined1.setAction(previous) }

    try Signal.userDefined1.raise()
    XCTAssertEqual(handledSignal, SIGUSR1)
    XCTAssertEqual(handledSender, getpid())
    #if os(Linux) || os(Android)
    XCTAssertTrue([SI_USER, SI_TKILL].contains(handledCode), "si_code \(handledCode)")
    #else
    // Darwin reports 0, rather than SI_USER, for a signal that pthread_kill
    // sent, which raise does (macOS 26.3).
    XCTAssertTrue([0, SI_USER].contains(handledCode), "si_code \(handledCode)")
    #endif
  }

  func testResetHandlerRunsTheHandlerOnce() throws {
    let previous = try Signal.userDefined1.setAction(
      Signal.Action(handler: .function({ handledSignal = $0 }), flags: [.resetHandler]))
    defer { _ = try? Signal.userDefined1.setAction(previous) }
    try Signal.userDefined1.raise()
    XCTAssertEqual(handledSignal, SIGUSR1)
    XCTAssertEqual(try Signal.userDefined1.action().handler, .default)
  }

  func testKillAndStopKeepTheirActions() {
    for signal in [Signal.kill, .stop] {
      XCTAssertThrowsError(try signal.setAction(.ignore)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  func testBlockedSignalsWaitToBeTaken() throws {
    let previous = PThread.blockSignals([.userDefined2])
    defer { PThread.setCurrentSignalMask(previous) }
    XCTAssertTrue(PThread.currentSignalMask().contains(.userDefined2))
    XCTAssertFalse(previous.contains(.userDefined2))

    try Signal.userDefined2.raise()
    XCTAssertTrue(PThread.pendingSignals().contains(.userDefined2))
    XCTAssertEqual(try PThread.waitForSignal(in: [.userDefined2]), .userDefined2)
    XCTAssertFalse(PThread.pendingSignals().contains(.userDefined2))
  }

  func testUnblockingDeliversAPendingSignal() throws {
    let action = Signal.Action(handler: .function({ handledSignal = $0 }))
    let previousAction = try Signal.userDefined2.setAction(action)
    defer { _ = try? Signal.userDefined2.setAction(previousAction) }
    let previousMask = PThread.blockSignals([.userDefined2])
    defer { PThread.setCurrentSignalMask(previousMask) }

    try Signal.userDefined2.raise()
    XCTAssertEqual(handledSignal, 0)
    let blocked = PThread.unblockSignals([.userDefined2])
    XCTAssertTrue(blocked.contains(.userDefined2))
    XCTAssertEqual(handledSignal, SIGUSR2)
  }

  func testSuspendingUntilASignalRunsItsHandler() throws {
    let action = Signal.Action(handler: .function({ handledSignal = $0 }))
    let previousAction = try Signal.userDefined1.setAction(action)
    defer { _ = try? Signal.userDefined1.setAction(previousAction) }
    let previousMask = PThread.blockSignals([.userDefined1])
    defer { PThread.setCurrentSignalMask(previousMask) }

    let waiter = PThread.ID.current
    let sender = try PThread {
      usleep(20_000)
      try? waiter.sendSignal(.userDefined1)
    }
    // The signal is blocked except while suspended, so it can't arrive
    // between the check and the suspension.
    while handledSignal == 0 {
      PThread.suspendUntilSignal(mask: previousMask)
    }
    try sender.join()
    XCTAssertEqual(handledSignal, SIGUSR1)
    // The mask is restored after the suspension.
    XCTAssertTrue(PThread.currentSignalMask().contains(.userDefined1))
  }

  func testAThreadCanBeSignaled() throws {
    let previousAction = try Signal.userDefined2.setAction(
      Signal.Action(handler: .function({ handledSignal = $0 })))
    defer { _ = try? Signal.userDefined2.setAction(previousAction) }
    try PThread.ID.current.sendSignal(.userDefined2)
    XCTAssertEqual(handledSignal, SIGUSR2)
  }

  func testTheNullSignalChecksForAProcess() throws {
    try ProcessID.current.sendSignal(nil)
    try ProcessID.currentProcessGroup.sendSignalToProcessGroup(nil)
  }
}

#endif // !os(Windows) && !os(WASI)
