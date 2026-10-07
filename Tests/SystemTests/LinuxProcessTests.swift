/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: process descriptors (pidfd), signal descriptors (signalfd), and
// close_range, on Linux. Nothing here has run: this Mac builds none of it.
// These are XCTest tests, since they spawn children and block signals.

#if os(Linux) || os(Android)

import XCTest

#if canImport(Glibc)
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
final class LinuxProcessTests: XCTestCase {
  #if !os(Android)
  func testAProcessDescriptorSignalsAndWaitsForItsChild() throws {
    // Swift 6.2's move checker rejects a noncopyable let that a do-catch
    // initializes, so check for pidfds on this process first.
    do {
      try ProcessDescriptor(ProcessID.current).close()
    } catch {
      // A test rather than `catch Errno.noFunction`: Swift 6.2 crashes in
      // IRGen on a pattern catch in a function that then gets an owner from
      // an owner, as openDescriptor() does below.
      guard error == .noFunction else { throw error }
      throw XCTSkip("This kernel has no pidfd_open")
    }
    let child = ChildProcess(taking: try spawnWaitingChild())
    let descriptor = try child.openDescriptor()
    XCTAssertEqual(descriptor.processID, child.id)
    try descriptor.sendSignal(nil)
    try descriptor.sendSignal(.terminate)
    do {
      let status = try descriptor.wait()
      XCTAssertEqual(status, .signaled(.terminate, coreDumped: false))
    } catch Errno.invalidArgument {
      throw XCTSkip("This kernel has no waitid(P_PIDFD)")
    }
    // The process is gone, and the descriptor still refers to it alone.
    XCTAssertThrowsError(try descriptor.sendSignal(.kill)) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    // The child is reaped, so the owner's deinit finds nothing to do.
    _ = child.relinquish()
    try descriptor.close()
  }
  #endif

  #if os(Linux)
  // The child gets a pipe's read end, which isn't close-on-exec, and
  // closeAll(from:) closes it there: the child's shell finds it in
  // /proc/self/fd only without the action. The pipe and the children are
  // the test's own.
  func testClosingTheRestOfAChildsDescriptors() throws {
    // glibc 2.34 or later, as every image build.sh runs has.
    XCTAssertTrue(SpawnFileAction.supportsCloseAll)
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    defer {
      try? readEnd.close()
      try? writeEnd.close()
    }
    let check = ["sh", "-c", "test -e /proc/self/fd/\(readEnd.rawValue)"]
    let inherits = try ChildProcess.spawn(shell, arguments: check)
    let inherited = try inherits.wait()
    XCTAssertEqual(inherited, .exited(0))
    let closes = try ChildProcess.spawn(
      shell, arguments: check, fileActions: [.closeAll(from: readEnd)])
    let closed = try closes.wait()
    XCTAssertEqual(closed, .exited(1))
  }
  #endif

  func testASignalDescriptorReceivesBlockedSignals() throws {
    let previous = PThread.blockSignals([.userDefined1])
    defer { PThread.setCurrentSignalMask(previous) }
    let receiver = try SignalDescriptor(
      signals: [.userDefined1], options: [.closeOnExec, .nonBlocking])
    XCTAssertThrowsError(try receiver.read()) {
      XCTAssertEqual($0 as? Errno, .resourceTemporarilyUnavailable)
    }
    try Signal.userDefined1.raise()
    let information = try receiver.read()
    XCTAssertEqual(information.signal, .userDefined1)
    XCTAssertEqual(information.processID, ProcessID.current)
    XCTAssertFalse(PThread.pendingSignals().contains(.userDefined1))
    try receiver.close()
  }

  #if ENABLE_MOCKING
  func testLinuxCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "pidfd_open", .noInterrupt, 4242 as pid_t, 0 as CUnsignedInt) { _ in
        _ = try ProcessDescriptor(ProcessID(rawValue: 4242)).relinquish()
      },
      MockTestCase(
        name: "pidfd_send_signal", .noInterrupt, 7 as CInt, SIGTERM, 0 as CUnsignedInt
      ) { _ in
        // defer can't consume the owner, so relinquish it on both paths.
        let descriptor = ProcessDescriptor(
          taking: FileDescriptor(rawValue: 7), processID: ProcessID(rawValue: 4242))
        let result = descriptor._sendSignal(.terminate)
        _ = descriptor.relinquish()
        try result.get()
      },
      MockTestCase(name: "signalfd", .noInterrupt, -1 as CInt, [SIGUSR1], 0 as CInt) { _ in
        _ = try SignalDescriptor(signals: [.userDefined1]).relinquish()
      },
      MockTestCase(
        name: "close_range", .noInterrupt, 3 as CUnsignedInt, CUnsignedInt.max,
        0 as CUnsignedInt
      ) { _ in
        try FileDescriptor.closeAll(from: FileDescriptor(rawValue: 3))
      },
      MockTestCase(
        name: "close_range", .noInterrupt, 3 as CUnsignedInt, 9 as CUnsignedInt,
        _CLOSE_RANGE_CLOEXEC
      ) { _ in
        try FileDescriptor.setCloseOnExecForAll(
          from: FileDescriptor(rawValue: 3), through: FileDescriptor(rawValue: 9))
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
  #endif
}

#endif // os(Linux) || os(Android)
