/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The provisional C string functions and character classes
// (Provisional+StringH.swift, Provisional+CType.swift).

#if !os(Windows)

import Testing
import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

/// Calls `body` with a copy of `bytes` that has no null byte after them.
private func withBytes<R>(_ bytes: [UInt8], _ body: (UnsafePointer<CChar>) throws -> R) rethrows -> R {
  try bytes.withUnsafeBufferPointer { buffer in
    try buffer.withMemoryRebound(to: CChar.self) { try body($0.baseAddress!) }
  }
}

@Suite("CString")
private struct ProvisionalStringTests {
  @available(System 199, *)
  @Test func lengths() {
    #expect(CString.length(of: "") == 0)
    #expect(CString.length(of: "hello") == 5)
    #expect(CString.length(of: "héllo") == 6)
    #expect(CString.length(of: "hello", maxLength: 3) == 3)
    #expect(CString.length(of: "hi", maxLength: 10) == 2)
    #expect(CString.length(of: "hi", maxLength: 0) == 0)
    // A full fixed-size field has no null byte; the length stops at the field.
    withBytes(Array("abcdef".utf8)) { #expect(CString.length(of: $0, maxLength: 6) == 6) }
  }

  @available(System 199, *)
  @Test func duplicates() throws {
    let copy = try CString.duplicate("NAME=value")
    defer { Memory.free(copy) }
    #expect(String(cString: copy) == "NAME=value")

    let empty = try CString.duplicate("")
    defer { Memory.free(empty) }
    #expect(empty.pointee == 0)

    // strndup reads no further than its limit, so the bytes needn't end.
    let part = try withBytes(Array("abc".utf8)) { try CString.duplicate($0, maxLength: 2) }
    defer { Memory.free(part) }
    #expect(String(cString: part) == "ab")
    let whole = try CString.duplicate("xy", maxLength: 10)
    defer { Memory.free(whole) }
    #expect(String(cString: whole) == "xy")
  }

  @available(System 199, *)
  @Test func comparisons() {
    #expect(CString.compare("abc", "abc") == 0)
    #expect(CString.compare("abc", "abd") < 0)
    #expect(CString.compare("b", "a") > 0)
    #expect(CString.compare("ab", "abc") < 0)
    #expect(CString.compare("", "") == 0)
    // Bytes compare as unsigned: é's first UTF-8 byte, 0xC3, orders after z.
    #expect(CString.compare("é", "z") > 0)

    #expect(CString.compare("<?xml version", "<?xml", maxLength: 5) == 0)
    #expect(CString.compare("abc", "abd", maxLength: 2) == 0)
    #expect(CString.compare("abc", "abd", maxLength: 3) < 0)
    #expect(CString.compare("abc", "xyz", maxLength: 0) == 0)
    // The comparison stops at a null byte, whatever the limit.
    #expect(CString.compare("ab", "ab", maxLength: 100) == 0)
    withBytes(Array("abcd".utf8)) { unterminated in
      #expect(CString.compare(unterminated, "abcz", maxLength: 3) == 0)
    }
  }

  // The test process doesn't call setlocale, so case is the POSIX locale's:
  // only the ASCII letters have it.
  @available(System 199, *)
  @Test func comparisonsIgnoringCase() {
    #expect(CString.compareIgnoringCase("UTF-8", "utf-8") == 0)
    #expect(CString.compareIgnoringCase("abc", "ABD") < 0)
    #expect(CString.compareIgnoringCase("B", "a") > 0)
    #expect(CString.compareIgnoringCase("ab", "ABC") < 0)
    #expect(CString.compareIgnoringCase("", "") == 0)
    // Case is folded before comparing: "_" (0x5F) orders after "A" (0x41)
    // but before "a" (0x61), which "A" becomes.
    #expect(CString.compareIgnoringCase("_", "A") < 0)
    // Bytes outside ASCII have no case here.
    #expect(CString.compareIgnoringCase("É", "é") != 0)

    #expect(CString.compareIgnoringCase("+INFINITY", "+infinity", maxLength: 9) == 0)
    #expect(CString.compareIgnoringCase("0X1F", "0x", maxLength: 2) == 0)
    #expect(CString.compareIgnoringCase("abc", "ABD", maxLength: 2) == 0)
    #expect(CString.compareIgnoringCase("abc", "ABD", maxLength: 3) < 0)
    #expect(CString.compareIgnoringCase("abc", "xyz", maxLength: 0) == 0)
    // The comparison stops at a null byte, whatever the limit.
    #expect(CString.compareIgnoringCase("Ab", "aB", maxLength: 100) == 0)
    withBytes(Array("ABCD".utf8)) { unterminated in
      #expect(CString.compareIgnoringCase(unterminated, "abcz", maxLength: 3) == 0)
    }
  }

  @available(System 199, *)
  @Test func copies() {
    var buffer = [CChar](repeating: 0x7f, count: 4)
    // A string that doesn't fit is truncated, and the copy still ends.
    let length = buffer.withUnsafeMutableBufferPointer { CString.copy("hello", into: $0) }
    #expect(length == 5)
    #expect(buffer == [0x68, 0x65, 0x6c, 0])

    let short = buffer.withUnsafeMutableBufferPointer { CString.copy("ab", into: $0) }
    #expect(short == 2)
    #expect(Array(buffer[..<3]) == [0x61, 0x62, 0])

    let exact = buffer.withUnsafeMutableBufferPointer { CString.copy("abc", into: $0) }
    #expect(exact == 3)
    #expect(buffer == [0x61, 0x62, 0x63, 0])

    // An empty buffer takes nothing; the length says how much it needed.
    #expect(CString.copy("abc", into: UnsafeMutableBufferPointer(start: nil, count: 0)) == 3)
    var one: [CChar] = [0x7f]
    let none = one.withUnsafeMutableBufferPointer { CString.copy("abc", into: $0) }
    #expect(none == 3 && one == [0])
  }
}

@Suite("CType")
private struct ProvisionalCTypeTests {
  /// The ASCII bytes in each class, in the C locale.
  static let spaces: Set<UInt8> = [0x20, 0x09, 0x0a, 0x0b, 0x0c, 0x0d]
  static let digits = Set(UInt8(ascii: "0")...UInt8(ascii: "9"))
  static let uppercase = Set(UInt8(ascii: "A")...UInt8(ascii: "Z"))
  static let lowercase = Set(UInt8(ascii: "a")...UInt8(ascii: "z"))
  static let hexDigits = digits.union(UInt8(ascii: "a")...UInt8(ascii: "f"))
    .union(UInt8(ascii: "A")...UInt8(ascii: "F"))
  static let controls = Set(UInt8(0)...0x1f).union([0x7f])
  static let graphic = Set(UInt8(0x21)...0x7e)

  @available(System 199, *)
  @Test func asciiClasses() {
    let letters = Self.uppercase.union(Self.lowercase)
    for byte in UInt8(0)...0x7f {
      #expect(CType.isSpace(byte) == Self.spaces.contains(byte), "\(byte)")
      #expect(CType.isBlank(byte) == (byte == 0x20 || byte == 0x09), "\(byte)")
      #expect(CType.isDigit(byte) == Self.digits.contains(byte), "\(byte)")
      #expect(CType.isHexDigit(byte) == Self.hexDigits.contains(byte), "\(byte)")
      #expect(CType.isLetter(byte) == letters.contains(byte), "\(byte)")
      #expect(CType.isLetterOrDigit(byte) == letters.union(Self.digits).contains(byte), "\(byte)")
      #expect(CType.isUppercase(byte) == Self.uppercase.contains(byte), "\(byte)")
      #expect(CType.isLowercase(byte) == Self.lowercase.contains(byte), "\(byte)")
      #expect(CType.isControl(byte) == Self.controls.contains(byte), "\(byte)")
      #expect(CType.isGraphic(byte) == Self.graphic.contains(byte), "\(byte)")
      #expect(CType.isPrintable(byte) == (Self.graphic.contains(byte) || byte == 0x20), "\(byte)")
      #expect(
        CType.isPunctuation(byte)
          == (Self.graphic.contains(byte) && !letters.union(Self.digits).contains(byte)), "\(byte)")
    }
  }

  @available(System 199, *)
  @Test func caseConversions() {
    #expect(CType.lowercased(UInt8(ascii: "A")) == UInt8(ascii: "a"))
    #expect(CType.lowercased(UInt8(ascii: "a")) == UInt8(ascii: "a"))
    #expect(CType.lowercased(UInt8(ascii: "1")) == UInt8(ascii: "1"))
    #expect(CType.uppercased(UInt8(ascii: "z")) == UInt8(ascii: "Z"))
    #expect(CType.uppercased(UInt8(ascii: "Z")) == UInt8(ascii: "Z"))
    for byte in UInt8(0)...0x7f {
      let expected = Self.uppercase.contains(byte) ? byte + 0x20 : byte
      #expect(CType.lowercased(byte) == expected, "\(byte)")
    }
  }

  /// A byte above 127 is what the C library's current locale says;
  /// the wrappers agree with the C functions for every byte.
  @available(System 199, *)
  @Test func everyByteAgreesWithC() {
    for byte in UInt8.min...UInt8.max {
      let c = CInt(byte)
      #expect(CType.isSpace(byte) == (isspace(c) != 0))
      #expect(CType.isLetter(byte) == (isalpha(c) != 0))
      #expect(CType.isPunctuation(byte) == (ispunct(c) != 0))
      #expect(CType.lowercased(byte) == UInt8(truncatingIfNeeded: tolower(c)))
      #expect(CType.uppercased(byte) == UInt8(truncatingIfNeeded: toupper(c)))
    }
  }
}

#if ENABLE_MOCKING
@available(System 199, *)
final class ProvisionalStringMockTest: XCTestCase {
  /// strdup and strndup allocate, so their only error is ENOMEM,
  /// which they don't retry.
  func testDuplicatesThrowTheirError() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let copy = try CString.duplicate("abc")
      Memory.free(copy)
      let part = try CString.duplicate("abcdef", maxLength: 3)
      XCTAssertEqual(String(cString: part), "abc")
      Memory.free(part)
      mocking.forceErrno = .always(errno: ENOMEM)
      XCTAssertThrowsError(try CString.duplicate("abc")) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      XCTAssertThrowsError(try CString.duplicate("abc", maxLength: 1)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      var calls: [(String, [AnyHashable])] = []
      while let entry = mocking.trace.dequeue() { calls.append((entry.name, entry.arguments)) }
      XCTAssertEqual(calls.map(\.0), ["strdup", "strndup", "strdup", "strndup"])
      XCTAssertEqual(calls.map(\.1), [["abc"], ["abc", 3], ["abc"], ["a", 1]] as [[AnyHashable]])
    }
  }
}
#endif // ENABLE_MOCKING

#endif // !os(Windows)
