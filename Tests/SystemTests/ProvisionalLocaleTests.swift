/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The provisional C locales (Provisional+Locale.swift). XCTest, since
// setting the global locale changes the whole process.
@available(System 199, *)
final class ProvisionalLocaleTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let locale = CLocale(rawValue: _mockLocale)
    let all = CInt(LC_COLLATE_MASK | LC_CTYPE_MASK | LC_MESSAGES_MASK | LC_MONETARY_MASK | LC_NUMERIC_MASK | LC_TIME_MASK)
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "newlocale", .noInterrupt, all, "fr_FR.UTF-8", 0) { _ in
        _ = try CLocale.named("fr_FR.UTF-8")
      },
      MockTestCase(name: "newlocale", .noInterrupt, CInt(LC_NUMERIC_MASK), "de_DE", 0) { _ in
        _ = try CLocale.named("de_DE", categories: .numeric)
      },
      MockTestCase(name: "freelocale", .noError, Int(bitPattern: _mockLocale)) { _ in
        locale.free()
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

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
  }

  func testANamedLocale() throws {
    let french = try CLocale.named("fr_FR.UTF-8")
    defer { french.free() }
    let parsed = "3,25".withCString { french.parseDouble($0) }
    XCTAssertTrue(parsed == (3.25, 4))
    // Only the numeric rules, from French, and the rest from POSIX.
    let numeric = try CLocale.named("fr_FR.UTF-8", categories: .numeric)
    defer { numeric.free() }
    XCTAssertTrue("3,25".withCString { numeric.parseDouble($0) } == (3.25, 4))
    XCTAssertThrowsError(try CLocale.named("no_SUCH.locale")) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
  }

  func testTheGlobalLocale() throws {
    let original = CLocale.globalName(for: .numeric)
    defer { CLocale.setGlobal(original, for: .numeric) }
    XCTAssertEqual(CLocale.setGlobal("fr_FR.UTF-8", for: .numeric), "fr_FR.UTF-8")
    XCTAssertEqual(CLocale.globalName(for: .numeric), "fr_FR.UTF-8")
    // The global locale's rules, through LC_GLOBAL_LOCALE.
    XCTAssertTrue("3,25".withCString { CLocale.global.parseDouble($0) } == (3.25, 4))
    XCTAssertNil(CLocale.setGlobal("no_SUCH.locale", for: .numeric))
    XCTAssertEqual(CLocale.globalName(for: .numeric), "fr_FR.UTF-8")
  }

  /// The POSIX locale's information, and a French one's, whose dates put
  /// the day first.
  func testInformation() throws {
    let posix = CLocale.posix
    XCTAssertEqual(posix.information(.characterEncoding), "US-ASCII")
    XCTAssertEqual(posix.information(.dateFormat), "%m/%d/%y")
    XCTAssertEqual(posix.information(.timeFormat), "%H:%M:%S")
    XCTAssertEqual(posix.information(.amSymbol), "AM")
    XCTAssertEqual(posix.information(.dayName(1)), "Sunday")
    XCTAssertEqual(posix.information(.abbreviatedDayName(7)), "Sat")
    XCTAssertEqual(posix.information(.monthName(1)), "January")
    XCTAssertEqual(posix.information(.abbreviatedMonthName(12)), "Dec")
    XCTAssertEqual(posix.information(.decimalSeparator), ".")
    XCTAssertEqual(posix.information(.monthDayOrder), "md")
    let french = try CLocale.named("fr_FR.UTF-8")
    defer { french.free() }
    XCTAssertEqual(french.information(.characterEncoding), "UTF-8")
    XCTAssertEqual(french.information(.decimalSeparator), ",")
    XCTAssertEqual(french.information(.monthDayOrder), "dm")
    // The global locale's, through LC_GLOBAL_LOCALE.
    XCTAssertFalse(CLocale.global.information(.monthDayOrder).isEmpty)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
