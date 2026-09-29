/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class RootAndSyncTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "chroot", .interruptable, "a path") { retryOnInterrupt in
        try FilePath.setRootDirectory("a path", retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "chroot", .interruptable, "a path") { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setRootDirectory($0, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  /// The tests don't run with privileges, so changing the root fails,
  /// leaving it as it was.
  func testChangingTheRootNeedsPrivileges() throws {
    try XCTSkipIf(getuid() == 0, "running as root, which may change the root")
    try withTemporaryFilePath(basename: "testChangingTheRootNeedsPrivileges") { dir in
      XCTAssertThrowsError(try FilePath.setRootDirectory(dir)) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
    }
    XCTAssertThrowsError(try FilePath.setRootDirectory("/", retryOnInterrupt: false)) {
      XCTAssertEqual($0 as? Errno, .notPermitted)
    }
  }

  func testSynchronizingAllFileSystems() {
    FileDescriptor.synchronizeAllFileSystems()
  }
}

#endif // !os(Windows) && !os(WASI)
