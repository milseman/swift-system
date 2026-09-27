/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && !os(Android) && ENABLE_MOCKING

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
#endif

@available(System 199, *)
final class SystemIdentityMockTests: XCTestCase {
  func testCalls() {
    // The buffers leave room for a terminator the call might not write.
    let cases: [MockTestCase] = [
      MockTestCase(name: "uname", .noInterrupt, Wildcard()) { _ in
        _ = try SystemIdentity.current()
      },
      MockTestCase(name: "gethostname", .noInterrupt, Wildcard(), 255) { _ in
        _ = try SystemIdentity.hostName()
      },
      MockTestCase(name: "getlogin_r", .noInterrupt, Wildcard(), 255) { _ in
        _ = try SystemIdentity.loginName()
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// getlogin_r returns ERANGE for a buffer too small for the name.
  func testLoginNameGrowsItsBuffer() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: ERANGE, count: 2)
      _ = try SystemIdentity.loginName()
      var lengths: [Int] = []
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "getlogin_r")
        lengths.append(entry.arguments[1] as! Int)
      }
      XCTAssertEqual(lengths, [255, 511, 1023])
    }
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android) && ENABLE_MOCKING
