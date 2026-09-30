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

// Helpers for the Win32 namespace's tests. They check results with raw
// Win32 calls where the API under test can't check itself.

// MARK: - Errors

/// Asserts that `body` throws `expected`.
///
/// `body` throws untyped errors: Swift 6.2 doesn't infer a closure's thrown
/// type, so a `throws(Win32.Error)` parameter would need every closure
/// annotated. It catches with a catch-all rather than a pattern, which
/// Swift 6.2 can crash on in a function that handles owners.
@available(System 199, *)
internal func XCTAssertThrowsWin32Error<R: ~Copyable>(
  _ expected: Win32.Error,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  _ body: () throws -> R
) {
  do {
    _ = try body()
    XCTFail(
      "didn't throw \(expected.debugDescription). \(message())", file: file, line: line)
  } catch {
    guard let error = error as? Win32.Error else {
      XCTFail("threw \(error), not a Win32.Error. \(message())", file: file, line: line)
      return
    }
    XCTAssertEqual(
      error, expected, "threw \(error.debugDescription). \(message())",
      file: file, line: line)
  }
}

#endif // os(Windows)
