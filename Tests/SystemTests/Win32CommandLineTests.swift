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

/// The arguments that `CommandLineToArgvW`, which follows the C runtime's
/// rules, splits a command line into.
private func win32RawSplit(_ line: String) -> [String]? {
  line.withCString(encodedAs: UTF16.self) { line -> [String]? in
    var count: CInt = 0
    guard let arguments = CommandLineToArgvW(line, &count) else { return nil }
    defer { LocalFree(arguments) }
    return (0..<Int(count)).map { String(decodingCString: arguments[$0]!, as: UTF16.self) }
  }
}

// Win32.commandLine(program:arguments:), against CommandLineToArgvW and a
// child process.
@available(System 199, *)
final class Win32CommandLineTests: XCTestCase {
  func testQuoting() {
    XCTAssertEqual(
      Win32.commandLine(program: "C:\\Tools\\tool.exe", arguments: ["--name", "two words", ""]),
      "\"C:\\Tools\\tool.exe\" --name \"two words\" \"\"")
    XCTAssertEqual(
      Win32.commandLine(program: "x", arguments: ["a\\b", "a\\", "a\\\"b", "\"", "c:\\dir\\"]),
      "\"x\" a\\b a\\ \"a\\\\\\\"b\" \"\\\"\" c:\\dir\\")
    XCTAssertEqual(
      Win32.commandLine(program: "x", arguments: ["dir with space\\"]), "\"x\" \"dir with space\\\\\"")
  }

  func testCommandLineToArgvWSplitsItBack() throws {
    let cases: [[String]] = [
      [],
      [""],
      ["", ""],
      ["plain", "two words", "tab\there", "line\nfeed", "vertical\u{0B}tab"],
      ["\"", "\"\"", "a\"b", "\\\"", "\\\\\"", "trailing\\", "trailing space\\", "\\\\server\\share"],
      ["café", "日本語 テキスト", "emoji 🙂"],
    ]
    for arguments in cases {
      let line = Win32.commandLine(program: "C:\\Program Files\\tool.exe", arguments: arguments)
      let split = try XCTUnwrap(win32RawSplit(line), line)
      XCTAssertEqual(split, ["C:\\Program Files\\tool.exe"] + arguments, line)
    }
  }

  func testAChildReceivesTheArguments() throws {
    // A quoted program name, which CreateProcessW reads from the command
    // line when it isn't given the program, runs. cmd.exe splits the rest
    // by its own rules, which these arguments don't test.
    let root = try XCTUnwrap(win32RawEnvironmentValue("SystemRoot"))
    let program = root + "\\System32\\cmd.exe"
    let line = Win32.commandLine(program: program, arguments: ["/c", "exit", "7"])
    let child = try Win32.ProcessHandle.create(commandLine: line, flags: .noWindow)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 7)
  }
}

#endif // os(Windows)
