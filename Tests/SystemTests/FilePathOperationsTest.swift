//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
#if canImport(Android)
import Android
#elseif os(WASI)
import CSystem
#endif

final class FilePathOperationsTest: XCTestCase {
  #if ENABLE_MOCKING && !os(WASI) // Would need to use _getConst funcs from CSystem
  @available(System 199, *)
  func testSyscalls() {
    let dir = FileDescriptor(rawValue: 42)
    let path: FilePath = "a path"

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mkdir", .interruptable, "a path", 0o755) {
        retryOnInterrupt in
        try path.makeDirectory(
          permissions: [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute],
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "mkdir", .interruptable, "a path", 0o700) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.makeDirectory(
            $0, permissions: .ownerReadWriteExecute, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "mkdirat", .interruptable, 42, "a path", 0o700) {
        retryOnInterrupt in
        try path.makeDirectory(
          relativeTo: dir, permissions: .ownerReadWriteExecute,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "mkdirat", .interruptable, 42, "a path", 0o700) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.makeDirectory(
            $0, relativeTo: dir, permissions: .ownerReadWriteExecute,
            retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]

    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  @available(System 199, *)
  func testMakeDirectory() throws {
    try withTemporaryFilePath(basename: "testMakeDirectory") { path in
      let sub = path.appending("sub")
      try sub.makeDirectory(permissions: .ownerReadWriteExecute)
      XCTAssertEqual(try sub.stat().type, .directory)
      #if !os(WASI) // WASI has no permissions
      XCTAssertEqual(try sub.stat().permissions, .ownerReadWriteExecute)
      #endif
      XCTAssertThrowsError(try sub.makeDirectory(permissions: .ownerReadWriteExecute)) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }

      try path.appending("c string").withCString {
        try FilePath.makeDirectory($0, permissions: .ownerReadWriteExecute)
      }
      XCTAssertEqual(try path.appending("c string").stat().type, .directory)

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("relative").makeDirectory(
          relativeTo: dir, permissions: .ownerReadWriteExecute)
        XCTAssertEqual(try path.appending("relative").stat().type, .directory)

        try "relative c string".withCString {
          try FilePath.makeDirectory(
            $0, relativeTo: dir, permissions: .ownerReadWriteExecute)
        }
        XCTAssertEqual(try path.appending("relative c string").stat().type, .directory)

        XCTAssertThrowsError(
          try FilePath("missing/sub").makeDirectory(
            relativeTo: dir, permissions: .ownerReadWriteExecute)
        ) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }
}

#endif // !os(Windows)
