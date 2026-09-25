/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Helpers for the event notification tests: kqueue, epoll, and poll.

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

/// Asserts that `body` throws `expected`.
internal func assertThrows(
  _ expected: Errno, _ message: String = "",
  file: StaticString = #filePath, line: UInt = #line,
  _ body: () throws -> Void
) {
  do {
    try body()
    XCTFail("expected \(expected) \(message)", file: file, line: line)
  } catch {
    XCTAssertEqual(error as? Errno, expected, message, file: file, line: line)
  }
}
#endif // !os(Windows) && !os(WASI)
