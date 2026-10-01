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

// Win32.ProcessHandle.create: CreateProcessW, with the handle list.
@available(System 199, *)
final class Win32ProcessCreationTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let flags: [(Win32.ProcessCreationFlags, DWORD)] = [
      (.suspended, DWORD(WinSDK.CREATE_SUSPENDED)),
      (.detached, DWORD(WinSDK.DETACHED_PROCESS)),
      (.newConsole, DWORD(WinSDK.CREATE_NEW_CONSOLE)),
      (.newProcessGroup, DWORD(WinSDK.CREATE_NEW_PROCESS_GROUP)),
      (.breakawayFromJob, DWORD(WinSDK.CREATE_BREAKAWAY_FROM_JOB)),
      (.defaultErrorMode, DWORD(WinSDK.CREATE_DEFAULT_ERROR_MODE)),
      (.noWindow, DWORD(WinSDK.CREATE_NO_WINDOW)),
    ]
    for (flag, value) in flags {
      XCTAssertEqual(flag.rawValue, value, "\(flag)")
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_CREATE_UNICODE_ENVIRONMENT, DWORD(WinSDK.CREATE_UNICODE_ENVIRONMENT))
    XCTAssertEqual(_EXTENDED_STARTUPINFO_PRESENT, DWORD(WinSDK.EXTENDED_STARTUPINFO_PRESENT))
    XCTAssertEqual(_STARTF_USESTDHANDLES, DWORD(WinSDK.STARTF_USESTDHANDLES))
    // Negative values cast to DWORD in the SDK, so they may import either way.
    XCTAssertEqual(_STD_INPUT_HANDLE, DWORD(truncatingIfNeeded: WinSDK.STD_INPUT_HANDLE))
    XCTAssertEqual(_STD_OUTPUT_HANDLE, DWORD(truncatingIfNeeded: WinSDK.STD_OUTPUT_HANDLE))
    XCTAssertEqual(_STD_ERROR_HANDLE, DWORD(truncatingIfNeeded: WinSDK.STD_ERROR_HANDLE))
    XCTAssertEqual(_CSTR_LESS_THAN, CInt(WinSDK.CSTR_LESS_THAN))
    XCTAssertEqual(_CSTR_EQUAL, CInt(WinSDK.CSTR_EQUAL))
    XCTAssertEqual(_CSTR_GREATER_THAN, CInt(WinSDK.CSTR_GREATER_THAN))
    // PROC_THREAD_ATTRIBUTE_HANDLE_LIST is a function-like macro, which
    // doesn't import; testOnlyStandardHandlesAreInherited checks it in use.
  }

  func testExitCodeAndIDs() throws {
    let child = try Win32.ProcessHandle.create(commandLine: "cmd.exe /c exit 7", flags: .noWindow)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 7)
    let processID = try child.process.processID()
    XCTAssertEqual(processID, child.processID)
    let threadID = try child.thread.threadID()
    XCTAssertEqual(threadID, child.threadID)
    let processInheritable = try child.process.isInheritable()
    XCTAssertFalse(processInheritable)
  }

  func testSuspended() throws {
    let child = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c exit 3", flags: [.suspended, .noWindow])
    let early = try child.process.waitForExit(timeout: .milliseconds(100))
    XCTAssertFalse(early)
    let count = try child.thread.resume()
    XCTAssertEqual(count, 1)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 3)
  }

  // A standard handle is passed through a binding of optional type, which
  // the call borrows; assigning nil to it closes it.
  func testStandardOutput() throws {
    let pipe = try Win32TestPipe()
    var writeEnd: Win32.FileHandle? = pipe.writeEnd
    let child = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c echo hello", standardOutput: writeEnd, flags: .noWindow)
    // The child got a duplicate: the caller's handle is still open.
    let raw: HANDLE?
    switch writeEnd {
    case .some(let handle): raw = handle.unsafeRawHandle
    case .none: raw = nil
    }
    let written = try win32RawWrite(try XCTUnwrap(raw), Array("!".utf8)).get()
    XCTAssertEqual(written, 1)
    writeEnd = nil
    let output = try win32ReadToEnd(pipe.readEnd)
    // The caller's byte and the child's line, in whichever order they came.
    XCTAssertEqual(output.sorted(), Array("hello\r\n!".utf8).sorted())
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 0)
  }

  func testStandardInputAndError() throws {
    let input = try Win32TestPipe()
    let output = try Win32TestPipe()
    var inputReadEnd: Win32.FileHandle? = input.readEnd
    let inputWriteEnd = input.writeEnd
    var outputWriteEnd: Win32.FileHandle? = output.writeEnd
    let child = try Win32.ProcessHandle.create(
      commandLine: "sort.exe", standardInput: inputReadEnd, standardOutput: outputWriteEnd,
      flags: .noWindow)
    inputReadEnd = nil
    outputWriteEnd = nil
    try withRawSpan(Array("b\r\na\r\n".utf8)) { try inputWriteEnd.write($0) }
    try inputWriteEnd.close()
    let sorted = try win32ReadToEnd(output.readEnd)
    XCTAssertEqual(String(decoding: sorted, as: UTF8.self), "a\r\nb\r\n")
    try child.process.waitForExit()

    let errors = try Win32TestPipe()
    var errorsWriteEnd: Win32.FileHandle? = errors.writeEnd
    let failing = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c \"(echo oops) 1>&2\"", standardError: errorsWriteEnd,
      flags: .noWindow)
    errorsWriteEnd = nil
    let message = try win32ReadToEnd(errors.readEnd)
    XCTAssertEqual(String(decoding: message, as: UTF8.self), "oops\r\n")
    try failing.process.waitForExit()
  }

  func testOnlyStandardHandlesAreInherited() throws {
    // An inheritable handle that isn't a standard handle doesn't reach the
    // child: once the caller closes its write end, the pipe has no writer,
    // though the child is still running.
    let pipe = try Win32TestPipe()
    try pipe.writeEnd.setInheritable(true)
    let null: Win32.FileHandle? = try Win32.FileHandle.open("NUL", access: .genericWrite)
    let child = try Win32.ProcessHandle.create(
      commandLine: "ping.exe -n 5 127.0.0.1", standardOutput: null, flags: .noWindow)
    try pipe.writeEnd.close()
    let output = try win32ReadToEnd(pipe.readEnd)
    XCTAssertEqual(output, [])
    let running = try child.process.exitCode()
    XCTAssertNil(running, "the read waited for the child, which inherited the pipe")
    try child.process.terminate(exitCode: 1)
    try child.process.waitForExit()
  }

  func testUnspecifiedHandlesAreTheCallers() throws {
    // With only standard input given, the child's standard output is the
    // caller's, which this test points at a pipe.
    let pipe = try Win32TestPipe()
    let previous = GetStdHandle(DWORD(truncatingIfNeeded: STD_OUTPUT_HANDLE))
    XCTAssertTrue(
      SetStdHandle(DWORD(truncatingIfNeeded: STD_OUTPUT_HANDLE), pipe.writeEnd.unsafeRawHandle))
    let null: Win32.FileHandle? = try Win32.FileHandle.open("NUL", access: .genericRead)
    let created = Result { () throws(Win32.Error) -> ProcessID in
      let child = try Win32.ProcessHandle.create(
        commandLine: "cmd.exe /c echo inherited", standardInput: null, flags: .noWindow)
      try child.process.waitForExit()
      return child.processID
    }
    XCTAssertTrue(SetStdHandle(DWORD(truncatingIfNeeded: STD_OUTPUT_HANDLE), previous))
    _ = try created.get()
    try pipe.writeEnd.close()
    let output = try win32ReadToEnd(pipe.readEnd)
    XCTAssertEqual(String(decoding: output, as: UTF8.self), "inherited\r\n")
  }

  func testEnvironment() throws {
    let root = try XCTUnwrap(win32RawEnvironmentValue("SystemRoot"))
    let child = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c exit %SYSTEM_TEST_CODE%",
      environment: ["SYSTEM_TEST_CODE=37", "SystemRoot=" + root], flags: .noWindow)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 37)
  }

  func testEnvironmentBlock() throws {
    // Sorted by name, ignoring case, with ties in order. "=" sorts before
    // letters, and a drive's variable is named up to its second "=".
    let block = try Win32._environmentBlock(["b=2", "A=1", "=C:=C:\\dir", "a=3", "B=4"]).get()
    XCTAssertEqual(block, Array("=C:=C:\\dir\u{0}A=1\u{0}a=3\u{0}b=2\u{0}B=4\u{0}\u{0}".utf16))
    let empty = try Win32._environmentBlock([]).get()
    XCTAssertEqual(empty, [0, 0])
    XCTAssertThrowsWin32Error(.invalidParameter) { try Win32._environmentBlock([""]).get() }
    XCTAssertThrowsWin32Error(.invalidParameter) { try Win32._environmentBlock(["A=\u{0}"]).get() }
  }

  func testCurrentDirectory() throws {
    try withTemporaryFilePath(basename: "testCurrentDirectory") { directory in
      let marker = try Win32.FileHandle.open(
        directory.appending("marker.txt"), access: .genericWrite, disposition: .createNew)
      try marker.close()
      let child = try Win32.ProcessHandle.create(
        commandLine: "cmd.exe /c if exist marker.txt (exit 5) else (exit 6)",
        currentDirectory: directory, flags: .noWindow)
      try child.process.waitForExit()
      let code = try child.process.exitCode()
      XCTAssertEqual(code, 5)
    }
  }

  func testApplication() throws {
    let root = try XCTUnwrap(win32RawEnvironmentValue("SystemRoot"))
    let child = try Win32.ProcessHandle.create(
      commandLine: "cmd /c exit 9", application: FilePath(root + "\\System32\\cmd.exe"),
      flags: .noWindow)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 9)
    // Windows neither searches for an application nor adds an extension.
    XCTAssertThrowsWin32Error(.fileNotFound) {
      try Win32.ProcessHandle.create(
        commandLine: "cmd /c exit 9", application: "cmd", flags: .noWindow)
    }
  }

  func testFailures() {
    XCTAssertThrowsWin32Error(.fileNotFound) {
      try Win32.ProcessHandle.create(commandLine: "system-test-no-such-program.exe")
    }
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ProcessHandle.create(commandLine: "cmd.exe\u{0} /c exit 1")
    }
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.ProcessHandle.create(commandLine: "cmd.exe /c exit 1", environment: [""])
    }
  }
}

#endif // os(Windows)
