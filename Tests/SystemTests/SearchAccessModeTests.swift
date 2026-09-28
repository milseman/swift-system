/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

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

// The access modes that open a directory for searching and a file for
// executing, which Darwin keeps as one mode.
@available(System 199, *)
final class SearchAccessModeTest: XCTestCase {
  func testSearchAccessMode() throws {
    try withTemporaryFilePath(basename: "testSearchAccessMode") { dir in
      let fd = try FileDescriptor.open(dir, .search)
      defer { try? fd.close() }
      // It's a directory to resolve relative paths against...
      let file = try FileDescriptor.open(
        "file", relativeTo: fd, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try file.close()
      XCTAssertNoThrow(try FileDescriptor.open("file", relativeTo: fd, .readOnly).close())
      // ...but not one to read.
      var byte: UInt8 = 0
      XCTAssertThrowsError(try withUnsafeMutableBytes(of: &byte) { try fd.read(into: $0) }) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      // The system keeps one mode for searching and executing.
      XCTAssertEqual(try fd.accessMode(), .execute)
      XCTAssertEqual(try fd.statusFlags().rawValue & O_EXEC, 0)
      // Only a directory opens for searching.
      XCTAssertThrowsError(try FileDescriptor.open(dir.appending("file"), .search)) {
        XCTAssertEqual($0 as? Errno, .notDirectory)
      }
    }
  }

  func testExecuteAccessMode() throws {
    try withTemporaryFilePath(basename: "testExecuteAccessMode") { dir in
      let plain = dir.appending("plain")
      try FileDescriptor.open(plain, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      XCTAssertThrowsError(try FileDescriptor.open(plain, .execute)) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
      let tool = dir.appending("tool")
      try FileDescriptor.open(tool, .writeOnly, options: .create, permissions: .ownerReadWriteExecute).close()
      let fd = try FileDescriptor.open(tool, .execute)
      defer { try? fd.close() }
      XCTAssertEqual(try fd.accessMode(), .execute)
      var byte: UInt8 = 0
      XCTAssertThrowsError(try withUnsafeMutableBytes(of: &byte) { try fd.read(into: $0) }) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
    }
  }

  func testAccessModeDescriptions() {
    XCTAssertEqual(FileDescriptor.AccessMode.search.description, "search")
    XCTAssertEqual(FileDescriptor.AccessMode.execute.description, "execute")
    XCTAssertEqual(FileDescriptor.AccessMode.readOnly.description, "readOnly")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
