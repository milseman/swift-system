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
    let child = try ChildProcess.spawn("/bin/sleep", arguments: ["sleep", "10"])
    let descriptor: ProcessDescriptor
    do {
      descriptor = try child.openDescriptor()
    } catch Errno.noFunction {
      throw XCTSkip("This kernel has no pidfd_open")
    }
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
