/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// The environment belongs to the whole process, so these tests are XCTests,
// which run one at a time in a process of their own. Each uses a variable
// name that no other test uses.
@available(System 199, *)
final class ProcessEnvironmentTests: XCTestCase {
  private func name(_ suffix: String) -> String {
    "SYSTEM_TESTS_\(suffix)_\(ProcessID.current.rawValue)"
  }

  func testSetValueAndRemove() throws {
    let variable = name("SET")
    defer { try? ProcessEnvironment.remove(variable) }
    XCTAssertNil(ProcessEnvironment.value(of: variable))

    try ProcessEnvironment.set(variable, to: "first")
    XCTAssertEqual(ProcessEnvironment.value(of: variable), "first")
    XCTAssertEqual(getenv(variable).map { String(cString: $0) }, "first")

    try ProcessEnvironment.set(variable, to: "second", overwrite: false)
    XCTAssertEqual(ProcessEnvironment.value(of: variable), "first")
    try ProcessEnvironment.set(variable, to: "second")
    XCTAssertEqual(ProcessEnvironment.value(of: variable), "second")

    try ProcessEnvironment.set(variable, to: "")
    XCTAssertEqual(ProcessEnvironment.value(of: variable), "")

    try ProcessEnvironment.remove(variable)
    XCTAssertNil(ProcessEnvironment.value(of: variable))
    // Removing a missing variable succeeds.
    try ProcessEnvironment.remove(variable)
  }

  func testInvalidNamesAndValues() {
    for bad in ["", "A=B", "=", "A\0B"] {
      XCTAssertNil(ProcessEnvironment.value(of: bad), bad.debugDescription)
      XCTAssertThrowsError(try ProcessEnvironment.set(bad, to: "x")) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try ProcessEnvironment.remove(bad)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
    // A null character would cut the C string short.
    let variable = name("NULL")
    XCTAssertThrowsError(try ProcessEnvironment.set(variable, to: "a\0b")) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
    XCTAssertNil(ProcessEnvironment.value(of: variable))
  }

  func testEntries() throws {
    let variable = name("ENTRIES")
    // The value's first character is "=" and a combining mark.
    let value = "=\u{301}a=b"
    try ProcessEnvironment.set(variable, to: value)
    defer { try? ProcessEnvironment.remove(variable) }

    let matches = ProcessEnvironment.entries().filter { $0.name == variable }
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches.first?.value, value)

    // Every entry of the C array is there, in order, except for any without "=".
    let names = ProcessEnvironment.withUnsafeEntries { entries in
      var names: [String] = []
      var entry = entries
      while let pointer = entry.pointee {
        let text = String(cString: pointer)
        if let equals = text.utf8.firstIndex(of: UInt8(ascii: "=")) {
          names.append(String(decoding: text.utf8[..<equals], as: UTF8.self))
        }
        entry += 1
      }
      return names
    }
    XCTAssertEqual(ProcessEnvironment.entries().map(\.name), names)
    XCTAssertTrue(names.contains(variable))
  }

  func testValuesThatArentUTF8() throws {
    let variable = name("BYTES")
    // setenv from C, since a Swift string can't hold these bytes.
    let bytes: [CChar] = [CChar(bitPattern: 0x61), CChar(bitPattern: 0xFF), 0]
    XCTAssertEqual(setenv(variable, bytes, 1), 0)
    defer { try? ProcessEnvironment.remove(variable) }

    XCTAssertEqual(ProcessEnvironment.value(of: variable), "a\u{FFFD}")
    XCTAssertEqual(
      ProcessEnvironment.entries().first { $0.name == variable }?.value, "a\u{FFFD}")
    let raw = ProcessEnvironment.withUnsafeEntries { entries -> [UInt8]? in
      let prefix = Array("\(variable)=".utf8)
      var entry = entries
      while let pointer = entry.pointee {
        let entryBytes = Array(UnsafeRawBufferPointer(start: pointer, count: strlen(pointer)))
        if entryBytes.starts(with: prefix) { return Array(entryBytes.dropFirst(prefix.count)) }
        entry += 1
      }
      return nil
    }
    XCTAssertEqual(raw, [0x61, 0xFF])
  }

  #if ENABLE_MOCKING
  func testMockedCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "setenv", .noInterrupt, "NAME", "value", 1) { _ in
        try ProcessEnvironment.set("NAME", to: "value")
      },
      MockTestCase(name: "setenv", .noInterrupt, "NAME", "", 0) { _ in
        try ProcessEnvironment.set("NAME", to: "", overwrite: false)
      },
      MockTestCase(name: "unsetenv", .noInterrupt, "NAME") { _ in
        try ProcessEnvironment.remove("NAME")
      },
    ]
    for test in cases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING
}

#endif // !os(Windows) && !os(WASI)
