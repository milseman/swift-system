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

// Processes: ProcessID on Windows, and Win32.ProcessHandle. The children
// are started with raw Win32 calls (win32RawSpawn), so these tests don't
// depend on System's own process creation.
@available(System 199, *)
final class Win32ProcessTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let rights: [(Win32.ProcessAccess, DWORD)] = [
      (.terminate, DWORD(WinSDK.PROCESS_TERMINATE)),
      (.createThread, DWORD(WinSDK.PROCESS_CREATE_THREAD)),
      (.virtualMemoryOperation, DWORD(WinSDK.PROCESS_VM_OPERATION)),
      (.virtualMemoryRead, DWORD(WinSDK.PROCESS_VM_READ)),
      (.virtualMemoryWrite, DWORD(WinSDK.PROCESS_VM_WRITE)),
      (.duplicateHandle, DWORD(WinSDK.PROCESS_DUP_HANDLE)),
      (.createProcess, DWORD(WinSDK.PROCESS_CREATE_PROCESS)),
      (.setQuota, DWORD(WinSDK.PROCESS_SET_QUOTA)),
      (.setInformation, DWORD(WinSDK.PROCESS_SET_INFORMATION)),
      (.queryInformation, DWORD(WinSDK.PROCESS_QUERY_INFORMATION)),
      (.suspendResume, DWORD(WinSDK.PROCESS_SUSPEND_RESUME)),
      (.queryLimitedInformation, DWORD(WinSDK.PROCESS_QUERY_LIMITED_INFORMATION)),
      (.setLimitedInformation, DWORD(WinSDK.PROCESS_SET_LIMITED_INFORMATION)),
      (.delete, DWORD(WinSDK.DELETE)),
      (.readControl, DWORD(WinSDK.READ_CONTROL)),
      (.writeDAC, DWORD(WinSDK.WRITE_DAC)),
      (.writeOwner, DWORD(WinSDK.WRITE_OWNER)),
      (.synchronize, DWORD(WinSDK.SYNCHRONIZE)),
      // PROCESS_ALL_ACCESS, spelled as winnt.h defines it for Windows Vista
      // and later, in case the compound macro doesn't import.
      (.all, DWORD(WinSDK.STANDARD_RIGHTS_REQUIRED) | DWORD(WinSDK.SYNCHRONIZE) | 0xFFFF),
      (.maximumAllowed, DWORD(WinSDK.MAXIMUM_ALLOWED)),
    ]
    for (right, value) in rights {
      XCTAssertEqual(right.rawValue, value, "\(right)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_INFINITE, DWORD(WinSDK.INFINITE))
    XCTAssertEqual(_WAIT_OBJECT_0, DWORD(WinSDK.WAIT_OBJECT_0))
    XCTAssertEqual(_WAIT_TIMEOUT, DWORD(WinSDK.WAIT_TIMEOUT))
    XCTAssertEqual(_WAIT_FAILED, DWORD(WinSDK.WAIT_FAILED))
  }

  func testMillisecondRounding() {
    XCTAssertEqual(_win32Milliseconds(roundingUp: .zero), 0)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .seconds(-1)), 0)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .nanoseconds(-1)), 0)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .nanoseconds(1)), 1)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .milliseconds(1)), 1)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .microseconds(1_001)), 2)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .seconds(3)), 3_000)
    XCTAssertEqual(_win32Milliseconds(roundingUp: .seconds(Int64.max)), .max)
  }

  func testCurrentProcessID() {
    XCTAssertEqual(ProcessID.current.rawValue, GetCurrentProcessId())
    XCTAssertEqual(ProcessID.current, ProcessID(GetCurrentProcessId()))
  }

  func testCurrentProcessHandle() throws {
    let id = try Win32.ProcessHandle.current.processID()
    XCTAssertEqual(id, .current)
    let code = try Win32.ProcessHandle.current.exitCode()
    XCTAssertNil(code)
    let exited = try Win32.ProcessHandle.current.waitForExit(timeout: .milliseconds(1))
    XCTAssertFalse(exited)
    // The pseudo handle is a constant, and closing it does nothing.
    let current = Win32.ProcessHandle.current
    XCTAssertEqual(current.unsafeRawHandle, GetCurrentProcess())
    try current.close()
    let idAfterClose = try Win32.ProcessHandle.current.processID()
    XCTAssertEqual(idAfterClose, .current)
  }

  func testDuplicatingTheCurrentProcess() throws {
    let real = try Win32.ProcessHandle.current.duplicate()
    XCTAssertNotEqual(real.unsafeRawHandle, GetCurrentProcess())
    let id = try real.processID()
    XCTAssertEqual(id, .current)
    let inheritable = try real.isInheritable()
    XCTAssertFalse(inheritable)
    try real.close()

    let narrow = try Win32.ProcessHandle.current.duplicate(access: .synchronize)
    XCTAssertThrowsWin32Error(.accessDenied) { try narrow.processID() }
    try narrow.close()
  }

  func testOpeningByID() throws {
    let process = try Win32.ProcessHandle.open(
      .current, access: [.queryLimitedInformation, .synchronize])
    let id = try process.processID()
    XCTAssertEqual(id, .current)
    let code = try process.exitCode()
    XCTAssertNil(code)
    try process.close()
  }

  func testOpenFailures() {
    // The System Idle Process.
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ProcessHandle.open(ProcessID(0), access: .queryLimitedInformation)
    }
    // Process IDs are multiples of 4, and this one is far above any in use.
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ProcessHandle.open(ProcessID(0xFFFF_FFFC), access: .queryLimitedInformation)
    }
  }

  func testExitCodeOfAChild() throws {
    let child = try win32RawSpawn("cmd.exe /c exit 42").get()
    XCTAssertTrue(CloseHandle(child.thread))
    let process = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    try process.waitForExit()
    let code = try process.exitCode()
    XCTAssertEqual(code, 42)
    let id = try process.processID()
    XCTAssertEqual(id, ProcessID(child.id))

    // While a handle is open, the exited process's ID still opens it.
    let reopened = try Win32.ProcessHandle.open(
      id, access: [.synchronize, .queryLimitedInformation])
    let reopenedCode = try reopened.exitCode()
    XCTAssertEqual(reopenedCode, 42)
    try reopened.close()
    try process.close()
  }

  func testExitCodeKeepsAll32Bits() throws {
    // cmd.exe's `exit` takes a signed 32-bit code.
    let child = try win32RawSpawn("cmd.exe /c exit -1073741510").get()
    XCTAssertTrue(CloseHandle(child.thread))
    let process = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    try process.waitForExit()
    let code = try process.exitCode()
    XCTAssertEqual(code, 0xC000_013A)  // STATUS_CONTROL_C_EXIT
    try process.close()
  }

  func testTerminate() throws {
    let child = try win32RawSpawn(win32LongRunningCommand).get()
    XCTAssertTrue(CloseHandle(child.thread))
    let owner = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    let process = try Win32.ProcessHandle.open(
      ProcessID(child.id), access: [.terminate, .synchronize, .queryLimitedInformation])

    let exitedEarly = try process.waitForExit(timeout: .milliseconds(50))
    XCTAssertFalse(exitedEarly)
    let running = try process.exitCode()
    XCTAssertNil(running)

    try process.terminate(exitCode: 99)
    let exited = try process.waitForExit(timeout: .seconds(30))
    XCTAssertTrue(exited)
    let code = try process.exitCode()
    XCTAssertEqual(code, 99)
    // Every handle sees the same process.
    let ownerCode = try owner.exitCode()
    XCTAssertEqual(ownerCode, 99)
    // An exited process can't be ended again.
    XCTAssertThrowsWin32Error(.accessDenied) { try process.terminate(exitCode: 1) }
    try process.close()
    try owner.close()
  }

  func testAccessRightsAreChecked() throws {
    let child = try win32RawSpawn(win32LongRunningCommand).get()
    XCTAssertTrue(CloseHandle(child.thread))
    let owner = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    let waiter = try Win32.ProcessHandle.open(ProcessID(child.id), access: .synchronize)
    let querier = try Win32.ProcessHandle.open(
      ProcessID(child.id), access: .queryLimitedInformation)

    XCTAssertThrowsWin32Error(.accessDenied) { try waiter.processID() }
    XCTAssertThrowsWin32Error(.accessDenied) { try waiter.terminate(exitCode: 1) }
    XCTAssertThrowsWin32Error(.accessDenied) { try querier.waitForExit(timeout: .zero) }
    let id = try querier.processID()
    XCTAssertEqual(id, ProcessID(child.id))

    try owner.terminate(exitCode: 7)
    try waiter.waitForExit()
    // Reading the exit code needs both rights: the wait, and the query.
    XCTAssertThrowsWin32Error(.accessDenied) { try waiter.exitCode() }
    XCTAssertThrowsWin32Error(.accessDenied) { try querier.exitCode() }
    let code = try owner.exitCode()
    XCTAssertEqual(code, 7)
    try waiter.close()
    try querier.close()
    try owner.close()
  }

  func testNonpositiveTimeoutsCheckWithoutWaiting() throws {
    let child = try win32RawSpawn(win32LongRunningCommand).get()
    XCTAssertTrue(CloseHandle(child.thread))
    let process = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    let zero = try process.waitForExit(timeout: .zero)
    XCTAssertFalse(zero)
    let negative = try process.waitForExit(timeout: .seconds(-1))
    XCTAssertFalse(negative)
    try process.terminate(exitCode: 1)
    try process.waitForExit()
    let afterExit = try process.waitForExit(timeout: .zero)
    XCTAssertTrue(afterExit)
    try process.close()
  }

  func testInheritance() throws {
    let process = try Win32.ProcessHandle.open(.current, access: .queryLimitedInformation)
    let before = try process.isInheritable()
    XCTAssertFalse(before)
    try process.setInheritable(true)
    let after = try process.isInheritable()
    XCTAssertTrue(after)
    try process.close()

    let inheritable = try Win32.ProcessHandle.open(
      .current, access: .queryLimitedInformation, inheritable: true)
    let opened = try inheritable.isInheritable()
    XCTAssertTrue(opened)
    let duplicate = try inheritable.duplicate()
    let duplicated = try duplicate.isInheritable()
    XCTAssertFalse(duplicated)
    try duplicate.close()
    try inheritable.close()
  }

  func testAdoption() throws {
    let fromNull = Win32.ProcessHandle(unsafelyAdopting: nil)
    XCTAssertTrue(fromNull == nil)
    // The pseudo handle, whose value is INVALID_HANDLE_VALUE's, is adopted.
    let pseudo = Win32.ProcessHandle(unsafelyAdopting: GetCurrentProcess())!
    let id = try pseudo.processID()
    XCTAssertEqual(id, .current)
    try pseudo.close()

    let opened = try Win32.ProcessHandle.open(.current, access: .queryLimitedInformation)
    let raw = opened.relinquish()
    XCTAssertEqual(GetProcessId(raw), GetCurrentProcessId())
    XCTAssertTrue(CloseHandle(raw))
  }
}

#endif // os(Windows)
