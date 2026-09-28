/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && ENABLE_MOCKING

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

@available(System 199, *)
final class ProcessCredentialsMockTests: XCTestCase {
  func testGroupListCall() {
    MockTestCase(name: "getgrouplist", .noError, "someone", CInterop.GroupID(20)) { _ in
      XCTAssertEqual(try GroupID.supplementary(forUser: "someone", including: GroupID(rawValue: 20)), [])
    }.runAllTests()
  }

  /// getgrouplist's -1 means that the groups don't fit, so the list grows,
  /// up to 2^17 groups.
  func testGroupListGrows() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: 0)
      XCTAssertThrowsError(try GroupID.supplementary(forUser: "someone", including: GroupID(rawValue: 20))) {
        XCTAssertEqual($0 as? Errno, .outOfRange)
      }
      var calls = 0
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "getgrouplist")
        calls += 1
      }
      XCTAssertEqual(calls, 6, "64, 256, 1024, 4096, 16384 and 65536 groups")
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testThreadCredentialsCall() throws {
    MockTestCase(name: "pthread_getugid_np", .noInterrupt) { _ in
      _ = try PThread.credentials()
    }.runAllTests()

    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: ESRCH)
      XCTAssertNil(try PThread.credentials())
      mocking.forceErrno = .always(errno: EPERM)
      XCTAssertThrowsError(try PThread.credentials()) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
    }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
