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

import ucrt
import WinSDK

/// The C runtime's copy of an environment variable, or `nil`.
private func crtValue(_ name: String) -> String? {
  name.withCString(encodedAs: UTF16.self) { name in
    _wgetenv(name).map { String(decodingCString: $0, as: UTF16.self) }
  }
}

// ProcessEnvironment on Windows. Each test uses variables of its own, and
// removes them, since the environment belongs to the whole process.
@available(System 199, *)
final class Win32EnvironmentTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_ERROR_ENVVAR_NOT_FOUND, DWORD(WinSDK.ERROR_ENVVAR_NOT_FOUND))
  }

  func testSetReadAndRemove() throws {
    let name = "SYSTEM_TESTS_ENVIRONMENT"
    XCTAssertNil(ProcessEnvironment.value(of: name))
    try ProcessEnvironment.set(name, to: "first")
    defer { try? ProcessEnvironment.remove(name) }
    XCTAssertEqual(ProcessEnvironment.value(of: name), "first")
    // Names compare without regard to case.
    XCTAssertEqual(ProcessEnvironment.value(of: name.lowercased()), "first")
    // Both copies changed.
    XCTAssertEqual(win32RawEnvironmentValue(name), "first")
    XCTAssertEqual(crtValue(name), "first")

    try ProcessEnvironment.set(name, to: "second", overwrite: false)
    XCTAssertEqual(ProcessEnvironment.value(of: name), "first")
    try ProcessEnvironment.set(name, to: "second")
    XCTAssertEqual(ProcessEnvironment.value(of: name), "second")

    try ProcessEnvironment.remove(name)
    XCTAssertNil(ProcessEnvironment.value(of: name))
    XCTAssertNil(win32RawEnvironmentValue(name))
    XCTAssertNil(crtValue(name))
    // Removing a missing variable succeeds.
    try ProcessEnvironment.remove(name)
  }

  func testEmptyValues() throws {
    let name = "SYSTEM_TESTS_EMPTY"
    try ProcessEnvironment.set(name, to: "")
    defer { try? ProcessEnvironment.remove(name) }
    // The system's copy holds an empty value, and the C runtime's can't.
    XCTAssertEqual(ProcessEnvironment.value(of: name), "")
    XCTAssertNil(crtValue(name))
    let listed = ProcessEnvironment.entries().contains { $0.name == name && $0.value.isEmpty }
    XCTAssertTrue(listed)
  }

  func testLongValues() throws {
    let name = "SYSTEM_TESTS_LONG"
    let value = String(repeating: "x", count: 5_000)
    try ProcessEnvironment.set(name, to: value)
    defer { try? ProcessEnvironment.remove(name) }
    XCTAssertEqual(ProcessEnvironment.value(of: name), value)
  }

  func testInvalidNamesAndValues() {
    for name in ["", "A=B", "A\u{0}B"] {
      XCTAssertThrowsError(try ProcessEnvironment.set(name, to: "x")) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try ProcessEnvironment.remove(name)) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      XCTAssertNil(ProcessEnvironment.value(of: name))
    }
    XCTAssertThrowsError(try ProcessEnvironment.set("SYSTEM_TESTS_NUL", to: "a\u{0}b")) { error in
      XCTAssertEqual(error as? Errno, .invalidArgument)
    }
  }

  func testEntriesAndTheBlock() throws {
    let name = "SYSTEM_TESTS_ENTRY"
    try ProcessEnvironment.set(name, to: "a=b")
    defer { try? ProcessEnvironment.remove(name) }
    // The name ends at the first "=".
    let entry = ProcessEnvironment.entries().first { $0.name == name }
    XCTAssertEqual(entry?.value, "a=b")
    let root = ProcessEnvironment.entries().first { $0.name.lowercased() == "systemroot" }
    XCTAssertNotNil(root)

    let strings = ProcessEnvironment.withUnsafeEntries { block -> [String] in
      var strings: [String] = []
      var entry = block
      while entry.pointee != 0 {
        let string = String(decodingCString: entry, as: UTF16.self)
        strings.append(string)
        entry += string.utf16.count + 1
      }
      return strings
    }
    XCTAssertTrue(strings.contains(name + "=a=b"))
  }

  func testChildrenInherit() throws {
    let name = "SYSTEM_TESTS_INHERITED"
    try ProcessEnvironment.set(name, to: "23")
    defer { try? ProcessEnvironment.remove(name) }
    let child = try Win32.ProcessHandle.create(
      commandLine: "cmd.exe /c exit %\(name)%", flags: .noWindow)
    try child.process.waitForExit()
    let code = try child.process.exitCode()
    XCTAssertEqual(code, 23)
  }
}

#endif // os(Windows)
