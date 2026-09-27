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
final class NetworkInterfaceMockTests: XCTestCase {
  func testCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "getifaddrs", .noInterrupt, Wildcard()) { _ in
        let addresses = try NetworkInterface.Addresses()
        XCTAssertEqual(addresses.count, 0)
      },
      MockTestCase(name: "if_indextoname", .noInterrupt, 7) { _ in
        _ = try NetworkInterface.Index(rawValue: 7).name()
      },
    ]
    for test in cases { test.runAllTests() }
  }

  /// A failure other than "no such interface" throws, and that one is nil.
  func testNameToIndex() throws {
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertEqual(try NetworkInterface.Index(name: "en0")?.rawValue, 1)
      mocking.forceErrno = .counted(errno: ENXIO, count: 1)
      XCTAssertNil(try NetworkInterface.Index(name: "en0"))
      mocking.forceErrno = .counted(errno: ENODEV, count: 1)
      XCTAssertNil(try NetworkInterface.Index(name: "en0"))
      mocking.forceErrno = .counted(errno: EMFILE, count: 1)
      XCTAssertThrowsError(try NetworkInterface.Index(name: "en0")) {
        XCTAssertEqual($0 as? Errno, .tooManyOpenFiles)
      }
      var names: [AnyHashable] = []
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "if_nametoindex")
        names.append(entry.arguments[0])
      }
      XCTAssertEqual(names, Array(repeating: "en0", count: 4))
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
