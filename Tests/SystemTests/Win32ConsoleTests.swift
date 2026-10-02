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

// Consoles and standard handles. The tests that need a console open
// CONOUT$ and CONIN$, and skip without one.
@available(System 199, *)
final class Win32ConsoleTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let modes: [(Win32.ConsoleMode, DWORD)] = [
      (.processedInput, DWORD(WinSDK.ENABLE_PROCESSED_INPUT)),
      (.lineInput, DWORD(WinSDK.ENABLE_LINE_INPUT)),
      (.echoInput, DWORD(WinSDK.ENABLE_ECHO_INPUT)),
      (.windowInput, DWORD(WinSDK.ENABLE_WINDOW_INPUT)),
      (.mouseInput, DWORD(WinSDK.ENABLE_MOUSE_INPUT)),
      (.insertMode, DWORD(WinSDK.ENABLE_INSERT_MODE)),
      (.quickEditMode, DWORD(WinSDK.ENABLE_QUICK_EDIT_MODE)),
      (.extendedFlags, DWORD(WinSDK.ENABLE_EXTENDED_FLAGS)),
      (.autoPosition, DWORD(WinSDK.ENABLE_AUTO_POSITION)),
      (.virtualTerminalInput, DWORD(WinSDK.ENABLE_VIRTUAL_TERMINAL_INPUT)),
      (.processedOutput, DWORD(WinSDK.ENABLE_PROCESSED_OUTPUT)),
      (.wrapAtEndOfLine, DWORD(WinSDK.ENABLE_WRAP_AT_EOL_OUTPUT)),
      (.virtualTerminalProcessing, DWORD(WinSDK.ENABLE_VIRTUAL_TERMINAL_PROCESSING)),
      (.disableNewlineAutoReturn, DWORD(WinSDK.DISABLE_NEWLINE_AUTO_RETURN)),
      (.lvbGridWorldwide, DWORD(WinSDK.ENABLE_LVB_GRID_WORLDWIDE)),
    ]
    for (mode, value) in modes {
      XCTAssertEqual(mode.rawValue, value, "\(mode)")
    }
    // Negative values cast to DWORD in the SDK, so they may import either way.
    XCTAssertEqual(
      Win32.StandardHandle.input.rawValue, DWORD(truncatingIfNeeded: WinSDK.STD_INPUT_HANDLE))
    XCTAssertEqual(
      Win32.StandardHandle.output.rawValue, DWORD(truncatingIfNeeded: WinSDK.STD_OUTPUT_HANDLE))
    XCTAssertEqual(
      Win32.StandardHandle.error.rawValue, DWORD(truncatingIfNeeded: WinSDK.STD_ERROR_HANDLE))
    let events: [(Win32.ConsoleControlEvent, DWORD)] = [
      (.controlC, DWORD(WinSDK.CTRL_C_EVENT)),
      (.controlBreak, DWORD(WinSDK.CTRL_BREAK_EVENT)),
      (.close, DWORD(WinSDK.CTRL_CLOSE_EVENT)),
      (.logoff, DWORD(WinSDK.CTRL_LOGOFF_EVENT)),
      (.shutdown, DWORD(WinSDK.CTRL_SHUTDOWN_EVENT)),
    ]
    for (event, value) in events {
      XCTAssertEqual(event.rawValue, value, "\(event)")
    }
  }

  func testLendingAStandardHandle() throws {
    // Point standard output at a pipe, lend it, and write through it.
    let pipe = try Win32TestPipe()
    let output = DWORD(truncatingIfNeeded: STD_OUTPUT_HANDLE)
    let previousOutput = GetStdHandle(output)
    XCTAssertTrue(SetStdHandle(output, pipe.writeEnd.unsafeRawHandle))
    let written = Win32.FileHandle.withStandardHandle(.output) { handle in
      win32RawWrite(handle.unsafeRawHandle, Array("lent".utf8))
    }
    XCTAssertTrue(SetStdHandle(output, previousOutput))
    let count = try XCTUnwrap(written).get()
    XCTAssertEqual(count, 4)
    try pipe.writeEnd.close()
    let contents = try win32ReadToEnd(pipe.readEnd)
    XCTAssertEqual(contents, Array("lent".utf8))

    // Without a handle, the body isn't called.
    let error = DWORD(truncatingIfNeeded: STD_ERROR_HANDLE)
    let previousError = GetStdHandle(error)
    XCTAssertTrue(SetStdHandle(error, nil))
    let called = Win32.FileHandle.withStandardHandle(.error) { _ in true }
    XCTAssertTrue(SetStdHandle(error, previousError))
    XCTAssertNil(called)
  }

  func testOtherCharacterDevicesAreNotConsoles() throws {
    let null = try Win32.FileHandle.open("NUL", access: .genericWrite)
    XCTAssertFalse(null.isConsole)
    try null.close()
    let pipe = try Win32TestPipe()
    XCTAssertFalse(pipe.readEnd.isConsole)
    try withTemporaryFilePath(basename: "testOtherCharacterDevicesAreNotConsoles") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: .genericWrite, disposition: .createNew)
      XCTAssertFalse(file.isConsole)
      XCTAssertThrowsWin32Error(.invalidHandle) { try file.consoleMode() }
      try file.close()
    }

    // The C runtime's _isatty calls NUL a terminal; isTerminal doesn't.
    let descriptor = try FileDescriptor.open("NUL", .writeOnly)
    XCTAssertFalse(descriptor.isTerminal)
    XCTAssertNotEqual(_isatty(descriptor.rawValue), 0)
    try descriptor.close()
  }

  func testConsoleOutput() throws {
    guard let output = try? Win32.FileHandle.open("CONOUT$", access: [.genericRead, .genericWrite])
    else {
      throw XCTSkip("This process has no console.")
    }
    XCTAssertTrue(output.isConsole)
    let mode = try output.consoleMode()
    XCTAssertTrue(mode.contains(.processedOutput))

    // Set and restored, whether the body returns or throws.
    let toggled = mode.symmetricDifference(.wrapAtEndOfLine)
    let inside = try output.withConsoleMode(toggled) { () throws(Win32.Error) in
      try output.consoleMode()
    }
    XCTAssertEqual(inside, toggled)
    let after = try output.consoleMode()
    XCTAssertEqual(after, mode)
    XCTAssertThrowsWin32Error(.accessDenied) {
      try output.withConsoleMode(toggled) { () throws(Win32.Error) in throw .accessDenied }
    }
    let afterThrow = try output.consoleMode()
    XCTAssertEqual(afterThrow, mode)

    let info = try output.consoleScreenBufferInfo()
    XCTAssertGreaterThan(info.columns, 0)
    XCTAssertGreaterThan(info.rows, 0)
    XCTAssertGreaterThan(info.windowColumns, 0)
    XCTAssertLessThanOrEqual(info.windowColumns, info.columns)
    XCTAssertLessThanOrEqual(info.windowRows, info.rows)
    XCTAssertLessThan(info.cursorColumn, info.columns)
    try output.close()
  }

  func testConsoleInput() throws {
    guard let input = try? Win32.FileHandle.open("CONIN$", access: [.genericRead, .genericWrite])
    else {
      throw XCTSkip("This process has no console.")
    }
    XCTAssertTrue(input.isConsole)
    let mode = try input.consoleMode()
    // A password prompt's mode: whole lines, not echoed.
    let quiet = try input.withConsoleMode(mode.subtracting(.echoInput)) { () throws(Win32.Error) in
      try input.consoleMode()
    }
    XCTAssertFalse(quiet.contains(.echoInput))
    let after = try input.consoleMode()
    XCTAssertEqual(after, mode)
    try input.close()
  }

  func testSettingAStandardHandle() throws {
    let pipe = try Win32TestPipe()
    let readEnd = pipe.readEnd
    let error = DWORD(truncatingIfNeeded: STD_ERROR_HANDLE)
    let previous = GetStdHandle(error)
    let raw = pipe.writeEnd.unsafeRawHandle
    try Win32.FileHandle.setStandardHandle(.error, to: pipe.writeEnd)
    XCTAssertEqual(GetStdHandle(error), raw)
    let written = Win32.FileHandle.withStandardHandle(.error) { handle in
      win32RawWrite(handle.unsafeRawHandle, Array("set".utf8))
    }
    // The process kept the handle; the test takes it back to close it.
    XCTAssertTrue(SetStdHandle(error, previous))
    XCTAssertTrue(CloseHandle(raw))
    let count = try XCTUnwrap(written).get()
    XCTAssertEqual(count, 3)
    let contents = try win32ReadToEnd(readEnd)
    XCTAssertEqual(contents, Array("set".utf8))
  }

  func testAllocatingAndAttachingConsoles() throws {
    if let output = try? Win32.FileHandle.open("CONOUT$", access: .genericWrite) {
      try output.close()
      // A process has one console at most.
      XCTAssertThrowsWin32Error(.accessDenied) { try Win32.allocateConsole() }
      XCTAssertThrowsWin32Error(.accessDenied) { try Win32.attachParentConsole() }
      // Only Ctrl+C and Ctrl+Break can be generated.
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try Win32.generateConsoleControlEvent(.close)
      }
      return
    }
    // A console of its own, which sets the standard handles, so they're put
    // back after.
    let handles = [STD_INPUT_HANDLE, STD_OUTPUT_HANDLE, STD_ERROR_HANDLE].map {
      DWORD(truncatingIfNeeded: $0)
    }
    let previous = handles.map { GetStdHandle($0) }
    defer {
      for (which, handle) in zip(handles, previous) { SetStdHandle(which, handle) }
    }
    try Win32.allocateConsole()
    let output = try Win32.FileHandle.open("CONOUT$", access: .genericWrite)
    XCTAssertTrue(output.isConsole)
    try output.close()
    try Win32.freeConsole()
    let reopened = try? Win32.FileHandle.open("CONOUT$", access: .genericWrite)
    XCTAssertTrue(reopened == nil)
    XCTAssertThrowsWin32Error(.invalidParameter) {
      try Win32.attachConsole(of: ProcessID(0xFFFF_FFFC))
    }
  }

  func testCtrlBreakEndsAProcessGroup() throws {
    // The child reads the console, so this needs a console for input.
    let input = DWORD(truncatingIfNeeded: STD_INPUT_HANDLE)
    var mode: DWORD = 0
    guard let handle = GetStdHandle(input), GetConsoleMode(handle, &mode) else {
      throw XCTSkip("This process's standard input isn't a console.")
    }
    // sort.exe waits for input, and has no handler of its own, so Ctrl+Break
    // ends it.
    let child = try Win32.ProcessHandle.create(
      commandLine: "sort.exe", flags: .newProcessGroup)
    defer { _ = try? child.process.terminate(exitCode: 1) }
    let exitedEarly = try child.process.waitForExit(timeout: .milliseconds(200))
    XCTAssertFalse(exitedEarly)
    try Win32.generateConsoleControlEvent(.controlBreak, toProcessGroup: child.processID)
    let exited = try child.process.waitForExit(timeout: .seconds(30))
    XCTAssertTrue(exited)
  }

  func testControlHandlers() throws {
    let handler: PHANDLER_ROUTINE = { _ in false }
    try Win32.addConsoleControlHandler(handler)
    try Win32.removeConsoleControlHandler(handler)
    // This leaves Ctrl+C handled, even if the test runner started with it
    // ignored, as a process created in a new process group does.
    try Win32.setIgnoresConsoleInterrupt(true)
    try Win32.setIgnoresConsoleInterrupt(false)
  }
}

#endif // os(Windows)
