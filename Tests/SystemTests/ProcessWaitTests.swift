/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: waiting for children, and ChildProcess, with real children.
// These are XCTest tests; see ProcessTestSupport.swift.

#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The children's output goes to /dev/null: a child that a failing test
// leaves running would otherwise hold the test runner's output open.
@available(System 199, *)
private let quiet: [SpawnFileAction] = [
  .open("/dev/null", .writeOnly, as: .standardOutput),
  .open("/dev/null", .writeOnly, as: .standardError),
]

@available(System 199, *)
private func spawnSleep(_ seconds: Int = 10) throws -> ProcessID {
  try ProcessID.spawn("/bin/sleep", arguments: ["sleep", "\(seconds)"], fileActions: quiet)
}

@available(System 199, *)
private func spawnExit(_ status: Int) throws -> ProcessID {
  try ProcessID.spawn(shell, arguments: ["sh", "-c", "exit \(status)"], fileActions: quiet)
}

@available(System 199, *)
final class ProcessWaitTests: XCTestCase {
  func testWaitingReapsTheChild() throws {
    let child = try spawnExit(2)
    XCTAssertEqual(try child.wait(), .exited(2))
    // Reaped: the ID no longer names a child.
    XCTAssertThrowsError(try child.wait()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testTryWait() throws {
    let child = try spawnSleep()
    XCTAssertNil(try child.tryWait())
    try child.sendSignal(.kill)
    var status: ExitStatus?
    while status == nil {
      status = try child.tryWait()
      usleep(1_000)
    }
    XCTAssertEqual(status, .signaled(.kill, coreDumped: false))
  }

  func testStoppedAndContinued() throws {
    let child = try spawnSleep()
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    try child.sendSignal(.stop)
    XCTAssertEqual(try child.wait(for: .stopped), .stopped(.stop))
    try child.sendSignal(.continue)
    XCTAssertEqual(try child.wait(for: .continued), .continued)
    XCTAssertNil(try child.wait(for: [.stopped, .continued, .exited, .noHang]))
    try child.sendSignal(.kill)
    XCTAssertEqual(
      try child.wait(for: .exited), .terminated(.signaled(.kill, coreDumped: false)))
  }

  func testKeepWaitableLeavesTheChildToReap() throws {
    let child = try spawnExit(5)
    XCTAssertEqual(try child.wait(for: [.exited, .keepWaitable]), .terminated(.exited(5)))
    // Still a zombie, so its ID is still reserved.
    try child.sendSignal(nil)
    XCTAssertEqual(try child.wait(), .exited(5))
  }

  func testNoHangReportsNothingForARunningChild() throws {
    let child = try spawnSleep()
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    XCTAssertNil(try child.wait(for: [.exited, .noHang]))
    XCTAssertNil(try child.wait(for: [.exited, .noHang, .keepWaitable]))
  }

  func testWaitingForAnyChild() throws {
    let first = try spawnExit(1)
    let second = try spawnExit(2)
    var reaped: [ProcessID: ExitStatus] = [:]
    for _ in 0..<2 {
      let (id, status) = try ProcessID.waitForAnyChild()
      reaped[id] = status
    }
    XCTAssertEqual(reaped, [first: .exited(1), second: .exited(2)])
    XCTAssertThrowsError(try ProcessID.tryWaitForAnyChild()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testTryWaitingForAnyChild() throws {
    let child = try spawnSleep()
    XCTAssertNil(try ProcessID.tryWaitForAnyChild())
    try child.sendSignal(.terminate)
    var reaped: (id: ProcessID, status: ExitStatus)?
    while reaped == nil {
      reaped = try ProcessID.tryWaitForAnyChild()
      usleep(1_000)
    }
    XCTAssertEqual(reaped?.id, child)
    XCTAssertEqual(reaped?.status, .signaled(.terminate, coreDumped: false))
  }

  func testWaitingForAnyChildInAProcessGroup() throws {
    let leader = try ProcessID.spawn(
      shell, arguments: ["sh", "-c", "exit 3"],
      attributes: SpawnAttributes(processGroup: .new))
    let outsider = try spawnSleep()
    defer {
      try? outsider.sendSignal(.kill)
      _ = try? outsider.wait()
    }
    let reported = try ProcessID.waitForAnyChild(inProcessGroup: leader, for: .exited)
    XCTAssertEqual(reported?.id, leader)
    XCTAssertEqual(reported?.change, .terminated(.exited(3)))
    XCTAssertNil(try ProcessID.waitForAnyChild(for: [.exited, .noHang]))
  }
}

@available(System 199, *)
final class ChildProcessTests: XCTestCase {
  func testSpawnAndWait() throws {
    let child = try ChildProcess.spawn(shell, arguments: ["sh", "-c", "exit 4"])
    // An assertion's autoclosure can't consume a noncopyable value.
    let status = try child.wait()
    XCTAssertEqual(status, .exited(4))
  }

  func testSignalingTheChild() throws {
    let child = try ChildProcess.spawn(searchingPathFor: "sleep", arguments: ["sleep", "10"])
    try child.sendSignal(nil)
    try child.sendSignal(.terminate)
    let status = try child.wait()
    XCTAssertEqual(status, .signaled(.terminate, coreDumped: false))
  }

  func testDestroyingARunningChildEndsAndReapsIt() throws {
    let start = time(nil)
    let id: ProcessID
    do {
      let child = ChildProcess(taking: try spawnSleep(60))
      id = child.id
    }
    XCTAssertLessThan(time(nil) - start, 10)
    XCTAssertThrowsError(try id.tryWait()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testDestroyingAnEndedChildReapsIt() throws {
    let id: ProcessID
    do {
      let child = ChildProcess(taking: try spawnExit(0))
      id = child.id
      // Let it end, so that the deinit only reaps it.
      _ = try id.wait(for: [.exited, .keepWaitable])
    }
    XCTAssertThrowsError(try id.tryWait()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testDestroyingAChildEndsItWhenAnErrorEndsTheScope() throws {
    struct Stop: Error {}
    var id: ProcessID?
    do {
      let child = ChildProcess(taking: try spawnSleep(60))
      id = child.id
      throw Stop()
    } catch is Stop {}
    XCTAssertThrowsError(try id!.tryWait()) {
      XCTAssertEqual($0 as? Errno, .noChildProcess)
    }
  }

  func testTryWaitRemembersTheStatus() throws {
    var child = ChildProcess(taking: try spawnExit(3))
    var status: ExitStatus?
    while status == nil {
      status = try child.tryWait()
      usleep(1_000)
    }
    XCTAssertEqual(status, .exited(3))
    let again = try child.tryWait()
    XCTAssertEqual(again, .exited(3))
    // The ID may name another process now, so nothing is sent.
    XCTAssertThrowsError(try child.sendSignal(.kill)) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    let final = try child.wait()
    XCTAssertEqual(final, .exited(3))
  }

  func testRelinquishLeavesTheChildRunning() throws {
    let child = ChildProcess(taking: try spawnSleep())
    let id = child.relinquish()
    try id.sendSignal(nil)
    XCTAssertNil(try id.tryWait())
    try id.sendSignal(.kill)
    XCTAssertEqual(try id.wait(), .signaled(.kill, coreDumped: false))
  }

  #if ENABLE_MOCKING
  func testDestroyingSignalsOnlyAnUnreapedChild() throws {
    let id = ProcessID(rawValue: 4242)
    try MockingDriver.withMockingEnabled { mocking in
      // The peek reports a running child: kill it, then reap it.
      do { _ = ChildProcess(taking: id) }
      let expected = [
        Trace.Entry(name: "waitid", [_idTypeValue(P_PID), 4242, Wildcard()]),
        Trace.Entry(name: "kill", [4242 as pid_t, SIGKILL]),
        Trace.Entry(name: "waitpid", [4242 as pid_t, 0 as CInt]),
      ]
      for entry in expected {
        XCTAssertEqual(mocking.trace.dequeue()?.matches(entry), true, "\(entry)")
      }
      XCTAssertTrue(mocking.trace.isEmpty)

      // Something else reaped it, and its ID may name another process.
      mocking.forceErrno = .always(errno: ECHILD)
      do { _ = ChildProcess(taking: id) }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "waitid")
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#endif
