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

import WinSDK

// Job objects. The test process may be in a job of its runner's already;
// Windows 8 and later nest jobs, so the tests' jobs nest in it.
@available(System 199, *)
final class Win32JobsTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let options: [(Win32.JobOptions, DWORD)] = [
      (.dieOnUnhandledException, DWORD(WinSDK.JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION)),
      (.breakawayAllowed, DWORD(WinSDK.JOB_OBJECT_LIMIT_BREAKAWAY_OK)),
      (.silentBreakaway, DWORD(WinSDK.JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK)),
      (.killOnClose, DWORD(WinSDK.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE)),
    ]
    for (option, value) in options {
      XCTAssertEqual(option.rawValue, value, "\(option)")
    }
    let kinds: [(Win32.JobNotification.Kind, DWORD)] = [
      (.endOfJobTime, DWORD(WinSDK.JOB_OBJECT_MSG_END_OF_JOB_TIME)),
      (.endOfProcessTime, DWORD(WinSDK.JOB_OBJECT_MSG_END_OF_PROCESS_TIME)),
      (.activeProcessLimit, DWORD(WinSDK.JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT)),
      (.noActiveProcesses, DWORD(WinSDK.JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO)),
      (.newProcess, DWORD(WinSDK.JOB_OBJECT_MSG_NEW_PROCESS)),
      (.processExited, DWORD(WinSDK.JOB_OBJECT_MSG_EXIT_PROCESS)),
      (.processExitedAbnormally, DWORD(WinSDK.JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS)),
      (.processMemoryLimit, DWORD(WinSDK.JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT)),
      (.jobMemoryLimit, DWORD(WinSDK.JOB_OBJECT_MSG_JOB_MEMORY_LIMIT)),
      (.notificationLimit, DWORD(WinSDK.JOB_OBJECT_MSG_NOTIFICATION_LIMIT)),
    ]
    for (kind, value) in kinds {
      XCTAssertEqual(kind.rawValue, value, "\(kind)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    let all = DWORD(WinSDK.JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION)
      | DWORD(WinSDK.JOB_OBJECT_LIMIT_BREAKAWAY_OK)
      | DWORD(WinSDK.JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK)
      | DWORD(WinSDK.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE)
    XCTAssertEqual(_JOB_OBJECT_OPTION_FLAGS, all)
  }

  func testAssigningAndTerminating() throws {
    let job = try Win32.JobHandle.create()
    let created = try Win32.ProcessHandle.create(
      commandLine: win32LongRunningCommand, flags: [.suspended, .noWindow])
    let before = try job.contains(created.process)
    XCTAssertFalse(before)
    try job.assign(created.process)
    let after = try job.contains(created.process)
    XCTAssertTrue(after)
    let inAJob = try created.process.isInJob()
    XCTAssertTrue(inAJob)
    _ = try created.thread.resume()

    try job.terminate(exitCode: 42)
    let exited = try created.process.waitForExit(timeout: .seconds(30))
    XCTAssertTrue(exited)
    let code = try created.process.exitCode()
    XCTAssertEqual(code, 42)
    try job.close()
  }

  func testOptions() throws {
    let job = try Win32.JobHandle.create()
    let initial = try job.options()
    XCTAssertEqual(initial, [])
    try job.setOptions([.killOnClose, .silentBreakaway])
    let set = try job.options()
    XCTAssertEqual(set, [.killOnClose, .silentBreakaway])
    try job.setOptions([.dieOnUnhandledException])
    let replaced = try job.options()
    XCTAssertEqual(replaced, [.dieOnUnhandledException])
    try job.close()
  }

  func testClosingAKillOnCloseJobEndsItsProcesses() throws {
    let job = try Win32.JobHandle.create()
    try job.setOptions(.killOnClose)
    let created = try Win32.ProcessHandle.create(
      commandLine: win32LongRunningCommand, flags: [.suspended, .noWindow])
    try job.assign(created.process)
    _ = try created.thread.resume()
    let running = try created.process.waitForExit(timeout: .milliseconds(100))
    XCTAssertFalse(running)
    try job.close()
    let exited = try created.process.waitForExit(timeout: .seconds(30))
    XCTAssertTrue(exited)
  }

  func testNotifications() throws {
    let job = try Win32.JobHandle.create()
    let port = try Win32.CompletionPort.create()
    try job.associate(with: port, key: 7)
    let created = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c exit 3", flags: [.suspended, .noWindow])
    try job.assign(created.process)
    _ = try created.thread.resume()

    // The process joins, exits, and leaves the job empty. Windows doesn't
    // promise every packet, but delivers these in a quiet test. A console
    // host the process starts can join the job too.
    var notifications: [Win32.JobNotification] = []
    while let completion = try port.dequeue(timeout: .seconds(30)) {
      let notification = Win32.JobNotification(completion)
      notifications.append(notification)
      if notification.kind == .noActiveProcesses { break }
    }
    let id = created.processID
    let joined = notifications.firstIndex { $0.kind == .newProcess && $0.processID == id }
    let exited = notifications.firstIndex { $0.kind == .processExited && $0.processID == id }
    XCTAssertNotNil(joined, "\(notifications)")
    XCTAssertNotNil(exited, "\(notifications)")
    if let joined, let exited { XCTAssertLessThan(joined, exited) }
    XCTAssertEqual(notifications.last?.kind, .noActiveProcesses)
    XCTAssertEqual(notifications.last?.processID, nil)
    XCTAssertTrue(notifications.allSatisfy { $0.key == 7 })
    try port.close()
    try job.close()
  }

  func testAssigningNeedsTheRights() throws {
    let job = try Win32.JobHandle.create()
    let created = try Win32.ProcessHandle.create(
      commandLine: win32LongRunningCommand, flags: [.suspended, .noWindow])
    let limited = try Win32.ProcessHandle.open(created.processID, access: .synchronize)
    XCTAssertThrowsWin32Error(.accessDenied) { try job.assign(limited) }
    try created.process.terminate(exitCode: 1)
    try job.close()
  }
}

#endif // os(Windows)
