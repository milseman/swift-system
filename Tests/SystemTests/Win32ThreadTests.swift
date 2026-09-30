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

// Win32.ThreadID and Win32.ThreadHandle. The suspended children are started
// with raw Win32 calls (win32RawSpawn).
@available(System 199, *)
final class Win32ThreadTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let rights: [(Win32.ThreadAccess, DWORD)] = [
      (.terminate, DWORD(WinSDK.THREAD_TERMINATE)),
      (.suspendResume, DWORD(WinSDK.THREAD_SUSPEND_RESUME)),
      (.getContext, DWORD(WinSDK.THREAD_GET_CONTEXT)),
      (.setContext, DWORD(WinSDK.THREAD_SET_CONTEXT)),
      (.setInformation, DWORD(WinSDK.THREAD_SET_INFORMATION)),
      (.queryInformation, DWORD(WinSDK.THREAD_QUERY_INFORMATION)),
      (.setThreadToken, DWORD(WinSDK.THREAD_SET_THREAD_TOKEN)),
      (.impersonate, DWORD(WinSDK.THREAD_IMPERSONATE)),
      (.directImpersonation, DWORD(WinSDK.THREAD_DIRECT_IMPERSONATION)),
      (.setLimitedInformation, DWORD(WinSDK.THREAD_SET_LIMITED_INFORMATION)),
      (.queryLimitedInformation, DWORD(WinSDK.THREAD_QUERY_LIMITED_INFORMATION)),
      (.resume, DWORD(WinSDK.THREAD_RESUME)),
      (.delete, DWORD(WinSDK.DELETE)),
      (.readControl, DWORD(WinSDK.READ_CONTROL)),
      (.writeDAC, DWORD(WinSDK.WRITE_DAC)),
      (.writeOwner, DWORD(WinSDK.WRITE_OWNER)),
      (.synchronize, DWORD(WinSDK.SYNCHRONIZE)),
      // THREAD_ALL_ACCESS, spelled from its parts.
      (.all, DWORD(WinSDK.STANDARD_RIGHTS_REQUIRED) | DWORD(WinSDK.SYNCHRONIZE) | 0xFFFF),
      (.maximumAllowed, DWORD(WinSDK.MAXIMUM_ALLOWED)),
    ]
    for (right, value) in rights {
      XCTAssertEqual(right.rawValue, value, "\(right)")
    }
  }

  func testCurrentThreadID() {
    XCTAssertEqual(Win32.ThreadID.current.rawValue, GetCurrentThreadId())
    XCTAssertEqual(Win32.ThreadID.current, Win32.ThreadID(GetCurrentThreadId()))
  }

  func testCurrentThreadHandle() throws {
    let thread = try Win32.ThreadHandle.current()
    // A real handle, not GetCurrentThread's pseudo handle.
    XCTAssertNotEqual(thread.unsafeRawHandle, GetCurrentThread())
    let id = try thread.threadID()
    XCTAssertEqual(id, .current)
    let code = try thread.exitCode()
    XCTAssertNil(code)
    let exited = try thread.waitForExit(timeout: .zero)
    XCTAssertFalse(exited)
    let inheritable = try thread.isInheritable()
    XCTAssertFalse(inheritable)
    try thread.close()

    let narrow = try Win32.ThreadHandle.current(access: .synchronize, inheritable: true)
    XCTAssertThrowsWin32Error(.accessDenied) { try narrow.threadID() }
    let narrowInheritable = try narrow.isInheritable()
    XCTAssertTrue(narrowInheritable)
    try narrow.close()
  }

  func testOpeningByID() throws {
    let thread = try Win32.ThreadHandle.open(.current, access: .queryLimitedInformation)
    let id = try thread.threadID()
    XCTAssertEqual(id, .current)
    try thread.close()

    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ThreadHandle.open(Win32.ThreadID(0xFFFF_FFFC), access: .queryLimitedInformation)
    }
  }

  func testSuspendAndResume() throws {
    let child = try win32RawSpawn("cmd.exe /c exit 3", suspended: true).get()
    let process = Win32.ProcessHandle(unsafelyAdopting: child.process)!
    let thread = Win32.ThreadHandle(unsafelyAdopting: child.thread)!
    let id = try thread.threadID()
    XCTAssertNotEqual(id.rawValue, 0)

    let suspendedAtStart = try process.waitForExit(timeout: .milliseconds(100))
    XCTAssertFalse(suspendedAtStart)
    // The suspend count starts at 1.
    let beforeSuspend = try thread.suspend()
    XCTAssertEqual(beforeSuspend, 1)
    let beforeFirstResume = try thread.resume()
    XCTAssertEqual(beforeFirstResume, 2)
    let stillSuspended = try process.waitForExit(timeout: .milliseconds(50))
    XCTAssertFalse(stillSuspended)
    let beforeLastResume = try thread.resume()
    XCTAssertEqual(beforeLastResume, 1)

    try thread.waitForExit()
    try process.waitForExit()
    // The first thread reports the code the process exited with.
    let threadCode = try thread.exitCode()
    XCTAssertEqual(threadCode, 3)
    let processCode = try process.exitCode()
    XCTAssertEqual(processCode, 3)
    try thread.close()
    try process.close()
  }

  func testAdoptionRejectsSentinels() throws {
    let fromNull = Win32.ThreadHandle(unsafelyAdopting: nil)
    XCTAssertTrue(fromNull == nil)
    // INVALID_HANDLE_VALUE's value is the calling process's pseudo handle.
    let fromInvalid = Win32.ThreadHandle(unsafelyAdopting: INVALID_HANDLE_VALUE)
    XCTAssertTrue(fromInvalid == nil)

    let thread = try Win32.ThreadHandle.current()
    let raw = thread.relinquish()
    XCTAssertEqual(GetThreadId(raw), GetCurrentThreadId())
    XCTAssertTrue(CloseHandle(raw))
  }
}

#endif // os(Windows)
