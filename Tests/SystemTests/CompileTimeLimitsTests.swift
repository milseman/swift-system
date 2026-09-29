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

// The C library's compile-time limits on names, paths, symbolic links and
// arguments.
@available(System 199, *)
final class CompileTimeLimitsTest: XCTestCase {
  func testLimitsAreTheHeaders() {
    XCTAssertEqual(SystemConfig.maxFileNameBytes, Int(NAME_MAX))
    XCTAssertEqual(SystemConfig.maxPathBytes, Int(PATH_MAX))
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertEqual(SystemConfig.maxFileNameBytes, 255)
    XCTAssertEqual(SystemConfig.maxPathBytes, 1024)
    XCTAssertEqual(SystemConfig.maxSymbolicLinks, Int(MAXSYMLINKS))
    #endif
  }

  /// POSIX's least limit on a program's arguments is 4096 bytes,
  /// and the system's own is no less.
  func testGuaranteedArgumentBytes() throws {
    XCTAssertEqual(SystemConfig.guaranteedArgumentBytes, Int(_POSIX_ARG_MAX))
    XCTAssertEqual(SystemConfig.guaranteedArgumentBytes, 4096)
    if let system = try SystemConfig.value(.maxArgumentBytes) {
      XCTAssertGreaterThanOrEqual(system, SystemConfig.guaranteedArgumentBytes)
    }
  }

  /// A file system's own limit is no more than the headers'.
  func testFileSystemLimitsAreNoMore() throws {
    try withTemporaryFilePath(basename: "testFileSystemLimitsAreNoMore") { dir in
      if let name = try SystemConfig.value(.maxFileNameBytes, for: dir) {
        XCTAssertLessThanOrEqual(name, SystemConfig.maxFileNameBytes)
      }
      if let path = try SystemConfig.value(.maxPathBytes, for: dir) {
        XCTAssertLessThanOrEqual(path, SystemConfig.maxPathBytes)
      }
    }
  }

  /// A name of maxFileNameBytes bytes can be created, and one byte more
  /// can't.
  func testFileNameLimit() throws {
    try withTemporaryFilePath(basename: "testFileNameLimit") { dir in
      let longest = dir.appending(String(repeating: "n", count: SystemConfig.maxFileNameBytes))
      try FileDescriptor.open(longest, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      let tooLong = dir.appending(String(repeating: "n", count: SystemConfig.maxFileNameBytes + 1))
      XCTAssertThrowsError(
        try FileDescriptor.open(tooLong, .writeOnly, options: .create, permissions: .ownerReadWrite)
      ) { XCTAssertEqual($0 as? Errno, .fileNameTooLong) }
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// An extended attribute's name can be maxExtendedAttributeNameBytes
  /// bytes long, and no longer.
  func testExtendedAttributeNameLimit() throws {
    XCTAssertEqual(SystemConfig.maxExtendedAttributeNameBytes, Int(XATTR_MAXNAMELEN))
    try withTemporaryFilePath(basename: "testExtendedAttributeNameLimit") { dir in
      let file = dir.appending("file")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      let longest = String(repeating: "a", count: SystemConfig.maxExtendedAttributeNameBytes)
      try file.setExtendedAttribute(longest, to: [1])
      XCTAssertThrowsError(try file.setExtendedAttribute(longest + "a", to: [1])) {
        XCTAssertEqual($0 as? Errno, .fileNameTooLong)
      }
    }
  }

  /// Opening a path through a chain of maxSymbolicLinks links succeeds,
  /// and through one more fails. The chains are opened relative to the
  /// directory's descriptor, since the temporary directory's own path goes
  /// through a link (/var), and every link counts.
  func testSymbolicLinkLimit() throws {
    try withTemporaryFilePath(basename: "testSymbolicLinkLimit") { dir in
      let target = dir.appending("target")
      try FileDescriptor.open(target, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      // link0 -> link1 -> ... -> link(n-1) -> target: opening link0 follows n links.
      func chain(_ n: Int, _ prefix: String) throws -> FilePath {
        for k in 0..<n {
          let next = k == n - 1 ? "target" : "\(prefix)\(k + 1)"
          try dir.appending("\(prefix)\(k)").makeSymbolicLink(to: FilePath(next))
        }
        return FilePath("\(prefix)0")
      }
      let fd = try FileDescriptor.open(dir, .readOnly)
      defer { try? fd.close() }
      let limit = SystemConfig.maxSymbolicLinks
      try FileDescriptor.open(try chain(limit, "a"), relativeTo: fd, .readOnly).close()
      XCTAssertThrowsError(try FileDescriptor.open(try chain(limit + 1, "b"), relativeTo: fd, .readOnly)) {
        XCTAssertEqual($0 as? Errno, .tooManySymbolicLinkLevels)
      }
    }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
