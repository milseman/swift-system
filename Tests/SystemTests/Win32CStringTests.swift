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

// CString on Windows: strlen, strnlen, wcslen, _strdup, strcmp and strncmp,
// on literals and the test's own buffers.
@available(System 199, *)
final class Win32CStringTests: XCTestCase {
  func testLengths() {
    XCTAssertEqual(CString.length(of: "hello"), 5)
    XCTAssertEqual(CString.length(of: ""), 0)
    XCTAssertEqual(CString.length(of: "hello", maxLength: 3), 3)
    XCTAssertEqual(CString.length(of: "hi", maxLength: 8), 2)
    let fixed: [CChar] = [0x61, 0x62, 0x63]
    fixed.withUnsafeBufferPointer {
      XCTAssertEqual(CString.length(of: $0.baseAddress!, maxLength: $0.count), 3)
    }
  }

  func testWideLengths() {
    "C:\\Windows".withCString(encodedAs: UTF16.self) {
      XCTAssertEqual(CString.length(of: $0), 10)
    }
    // A code point outside the BMP is two UTF-16 code units.
    "\u{1F600}".withCString(encodedAs: UTF16.self) {
      XCTAssertEqual(CString.length(of: $0), 2)
    }
  }

  func testDuplicates() throws {
    let copy = try CString.duplicate("NAME=value")
    defer { Memory.free(copy) }
    XCTAssertEqual(String(cString: copy), "NAME=value")
  }

  func testComparisons() {
    XCTAssertEqual(CString.compare("abc", "abc"), 0)
    XCTAssertLessThan(CString.compare("abc", "abd"), 0)
    XCTAssertGreaterThan(CString.compare("b", "abc"), 0)
    // Bytes compare as unsigned values.
    XCTAssertGreaterThan(CString.compare("\u{E9}", "z"), 0)
    XCTAssertEqual(CString.compare("<?xml version", "<?xml", maxLength: 5), 0)
    XCTAssertNotEqual(CString.compare("<?xmL", "<?xml", maxLength: 5), 0)
  }

  #if ENABLE_MOCKING
  func testDuplicatesThrowTheirError() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: 12)
      XCTAssertThrowsError(try CString.duplicate("x")) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
    }
  }
  #endif
}

#endif // os(Windows)
