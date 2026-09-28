/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class ExtendedAttributesMockTests: XCTestCase {
  func testCalls() {
    let path: FilePath = "a path"
    let fd = FileDescriptor(rawValue: 3)
    let create = ExtendedAttributeOptions.create.rawValue
    // A read asks for the size first, and the mocked size is zero,
    // so a mocked read makes that one call and then one of size zero.
    let cases: [MockTestCase] = [
      MockTestCase(name: "setxattr", .interruptable, "a path", "user.a", 2, create, true) {
        retryOnInterrupt in
        try path.setExtendedAttribute(
          "user.a", to: [1, 2], options: .create, followTargetSymlink: false,
          retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "removexattr", .interruptable, "a path", "user.a", false) {
        retryOnInterrupt in
        try path.removeExtendedAttribute("user.a", retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "fsetxattr", .interruptable, 3, "user.a", 1, 0) { retryOnInterrupt in
        try fd.setExtendedAttribute("user.a", to: [9], retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "fremovexattr", .interruptable, 3, "user.a") { retryOnInterrupt in
        try fd.removeExtendedAttribute("user.a", retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in cases { test.runAllTests() }
  }

  func testReadsAskForTheSizeFirst() throws {
    let path: FilePath = "a path"
    try MockingDriver.withMockingEnabled { mocking in
      mocking.byteCounts = [3, 3]
      XCTAssertEqual(try path.extendedAttribute("user.a", followTargetSymlink: false), [0, 0, 0])
      var calls: [[AnyHashable]] = []
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "getxattr")
        calls.append(entry.arguments)
      }
      XCTAssertEqual(calls, [["a path", "user.a", 0, true], ["a path", "user.a", 3, true]])

    }
  }

  /// A value that grows between asking its size and reading it fails the
  /// read with ERANGE, which asks again.
  func testAValueThatGrowsIsReadAgain() throws {
    var value: [UInt8] = [1, 2]
    var calls = 0
    let result = _readAttributeValue(retryOnInterrupt: true) { buffer, size in
      calls += 1
      if calls == 2 { value.append(3) }  // It grows after the first size.
      guard let buffer else { return value.count }
      guard size >= value.count else {
        Errno.current = .outOfRange
        return -1
      }
      value.withUnsafeBytes { buffer.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
      return value.count
    }
    XCTAssertEqual(try result.get(), [1, 2, 3])
    XCTAssertEqual(calls, 4)
  }
}

#endif // (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)) && ENABLE_MOCKING
