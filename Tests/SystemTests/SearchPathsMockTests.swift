/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN && ENABLE_MOCKING

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
final class SearchPathsMockTests: XCTestCase {
  func testEnumerationCalls() {
    // The mocked start ends the enumeration, so there's no second call.
    MockTestCase(
      name: "sysdir_start_search_path_enumeration", .noError,
      CUnsignedInt(13), CUnsignedInt(3)
    ) { _ in
      XCTAssertEqual(Array(SearchPaths(.caches, in: [.user, .local])), [])
    }.runAllTests()

    MockTestCase(
      name: "sysdir_get_next_search_path_enumeration", .noError, CUnsignedInt(42)
    ) { _ in
      var iterator = SearchPaths.Iterator(_state: 42)
      XCTAssertNil(iterator.next())
    }.runAllTests()
  }
}

#endif // SYSTEM_PACKAGE_DARWIN && ENABLE_MOCKING
