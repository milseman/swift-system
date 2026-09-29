/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux)

import XCTest

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The provisional C locales on Linux, where the categories' values differ
// from Darwin's, the POSIX and global locales are passed differently (see
// Syscalls+ProvisionalLocale.swift), and a container may have no locales
// but C, POSIX and C.UTF-8. XCTest, since setting the global locale changes
// the whole process. ProvisionalLocaleTest has Darwin's.
@available(System 199, *)
final class ProvisionalLocaleLinuxTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let locale = CLocale(rawValue: _mockLocale)
    #if canImport(Glibc)
    // glibc's twelve categories: bits 0 through 12, but for LC_ALL's, 6.
    let all: CInt = 0x1FBF
    #else
    let all: CInt = 0x7FFF_FFFF
    #endif
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "newlocale", .noInterrupt, all, "C.UTF-8", 0) { _ in
        _ = try CLocale.named("C.UTF-8")
      },
      MockTestCase(name: "newlocale", .noInterrupt, CInt(LC_NUMERIC_MASK), "C", 0) { _ in
        _ = try CLocale.named("C", categories: .numeric)
      },
      MockTestCase(name: "freelocale", .noError, Int(bitPattern: _mockLocale)) { _ in
        locale.free()
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  /// glibc's and Musl's values, which aren't Darwin's.
  func testTheCategories() {
    XCTAssertEqual(CLocale.Category.characterTypes.rawValue, 0)
    XCTAssertEqual(CLocale.Category.numeric.rawValue, 1)
    XCTAssertEqual(CLocale.Category.time.rawValue, 2)
    XCTAssertEqual(CLocale.Category.collation.rawValue, 3)
    XCTAssertEqual(CLocale.Category.monetary.rawValue, 4)
    XCTAssertEqual(CLocale.Category.messages.rawValue, 5)
    XCTAssertEqual(CLocale.Category.all.rawValue, 6)
    XCTAssertEqual(CLocale.Categories.numeric.rawValue, 1 << 1)
    XCTAssertTrue(CLocale.Categories.all.isSuperset(
      of: [.collation, .characterTypes, .messages, .monetary, .numeric, .time]))
  }

  /// The POSIX locale, which Linux passes as one that newlocale made.
  func testParsingInThePOSIXLocale() {
    func parse(_ text: String) -> (Double, Int) {
      text.withCString { CLocale.posix.parseDouble($0) }
    }
    XCTAssertTrue(parse("3.25xyz") == (3.25, 4))
    XCTAssertTrue(parse("  42") == (42, 4))
    XCTAssertTrue(parse("0x1.8p3") == (12, 7))
    XCTAssertTrue(parse("abc") == (0, 0))
    XCTAssertTrue(parse("3,25") == (3, 1))
    XCTAssertEqual(parse("-INF").0, -.infinity)
    XCTAssertEqual(parse("1e999").0, .infinity)
    let float = "2.5f".withCString { CLocale.posix.parseFloat($0) }
    XCTAssertTrue(float == (2.5, 3))
  }

  func testComparingIgnoringCase() {
    XCTAssertEqual(CLocale.posix.compareIgnoringCase("HELLO", "hello!", maxByteCount: 5), 0)
    XCTAssertLessThan(CLocale.posix.compareIgnoringCase("a", "B", maxByteCount: 1), 0)
    XCTAssertGreaterThan(CLocale.posix.compareIgnoringCase("hello!", "HELLO", maxByteCount: 10), 0)
    XCTAssertEqual(CLocale.global.compareIgnoringCase("HELLO", "hello", maxByteCount: 5), 0)
  }

  /// C.UTF-8 is built into glibc from 2.35, and into Musl. French, whose
  /// decimal separator is a comma, is checked where it's installed, and
  /// only in glibc: Musl's numbers don't follow the locale.
  func testANamedLocale() throws {
    let utf8 = try CLocale.named("C.UTF-8")
    defer { utf8.free() }
    XCTAssertTrue("3.25".withCString { utf8.parseDouble($0) } == (3.25, 4))
    #if canImport(Glibc)
    // Musl accepts any name, keeping it for messages.
    XCTAssertThrowsError(try CLocale.named("no_SUCH.locale")) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    guard let french = try? CLocale.named("fr_FR.UTF-8") else {
      throw XCTSkip("fr_FR.UTF-8 isn't installed")
    }
    defer { french.free() }
    XCTAssertTrue("3,25".withCString { french.parseDouble($0) } == (3.25, 4))
    let numeric = try CLocale.named("fr_FR.UTF-8", categories: .numeric)
    defer { numeric.free() }
    XCTAssertTrue("3,25".withCString { numeric.parseDouble($0) } == (3.25, 4))
    #endif
  }

  /// The global locale's calls follow the thread's locale, which is the
  /// global one here.
  func testTheGlobalLocale() throws {
    let original = CLocale.globalName(for: .numeric)
    defer { CLocale.setGlobal(original, for: .numeric) }
    XCTAssertTrue("3.25".withCString { CLocale.global.parseDouble($0) } == (3.25, 4))
    #if canImport(Glibc)
    // Musl accepts any name, keeping it for messages.
    XCTAssertNil(CLocale.setGlobal("no_SUCH.locale", for: .numeric))
    guard CLocale.setGlobal("fr_FR.UTF-8", for: .numeric) != nil else {
      throw XCTSkip("fr_FR.UTF-8 isn't installed")
    }
    XCTAssertEqual(CLocale.globalName(for: .numeric), "fr_FR.UTF-8")
    XCTAssertTrue("3,25".withCString { CLocale.global.parseDouble($0) } == (3.25, 4))
    // The POSIX locale's rules don't follow it.
    XCTAssertTrue("3,25".withCString { CLocale.posix.parseDouble($0) } == (3, 1))
    #endif
  }
}

#endif // os(Linux)
