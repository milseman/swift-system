/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

final class TemporaryPathTest: XCTestCase {
  #if SYSTEM_PACKAGE_DARWIN
  func testNotInSlashTmp() throws {
    try withTemporaryFilePath(basename: "NotInSlashTmp") { path in
      // We shouldn't be using "/tmp" on Darwin
      XCTAssertNotEqual(path.components.first!, "tmp")
    }
  }
  #endif

  func testUnique() throws {
    try withTemporaryFilePath(basename: "test") { path in
      let strPath = String(decoding: path)
      XCTAssert(strPath.contains("test"))
      try withTemporaryFilePath(basename: "test") { path2 in
        let strPath2 = String(decoding: path2)
        XCTAssertNotEqual(strPath, strPath2)
      }
    }
  }

  func testCleanup() throws {
    var thePath: FilePath? = nil

    try withTemporaryFilePath(basename: "test") { path in
      thePath = path.appending("foo.txt")
      let fd = try FileDescriptor.open(thePath!, .readWrite,
                                       options: [.create, .truncate],
                                       permissions: .ownerReadWrite)
      _ = try fd.closeAfter {
        try fd.writeAll("Hello World".utf8)
      }
    }

    XCTAssertThrowsError(try FileDescriptor.open(thePath!, .readOnly)) {
      error in

      XCTAssertEqual(error as! Errno, Errno.noSuchFileOrDirectory)
    }
  }

  #if !os(Windows)
  @available(System 199, *)
  func testCleanupNested() throws {
    var thePath: FilePath? = nil

    try withTemporaryFilePath(basename: "testCleanupNested") { path in
      thePath = path
      try makeNestedTree(in: path)
    }

    XCTAssertThrowsError(try FileDescriptor.open(thePath!, .readOnly)) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
  }

  // withTemporaryFilePath ignores an error from removing the directory,
  // so call _recursiveRemove directly to see one.
  @available(System 199, *)
  func testRecursiveRemove() throws {
    try withTemporaryFilePath(basename: "testRecursiveRemove") { path in
      let outside = path.appending("outside")
      try outside.makeDirectory(permissions: .ownerReadWriteExecute)
      try makeFile(at: outside.appending("keep"))

      let top = path.appending("top")
      try top.makeDirectory(permissions: .ownerReadWriteExecute)
      try makeNestedTree(in: top)
      try top.appending("a/b/outside").makeSymbolicLink(to: outside)

      try _recursiveRemove(at: top)

      XCTAssertThrowsError(try FileDescriptor.open(top, .readOnly)) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      // The link to a directory outside was removed, not followed.
      XCTAssertNoThrow(try FileDescriptor.open(outside.appending("keep"), .readOnly).close())
    }
  }
  #endif // !os(Windows)
}

#if !os(Windows)
/// Fills a directory with files and directories at several depths.
///
/// The same name appears at every depth, so an entry resolved against
/// the wrong directory removes the wrong file, or none.
@available(System 199, *)
private func makeNestedTree(in directory: FilePath) throws {
  for subdirectory in ["a", "a/b", "a/b/c", "a/empty", ".hidden"] {
    try directory.appending(subdirectory).makeDirectory(permissions: .ownerReadWriteExecute)
  }
  for file in ["same", "a/same", "a/b/same", "a/b/c/same", ".hidden/..dots"] {
    try makeFile(at: directory.appending(file))
  }
  try directory.appending("a/b/c/link").makeSymbolicLink(to: "../../same")
}

private func makeFile(at path: FilePath) throws {
  let fd = try FileDescriptor.open(
    path, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
  try fd.close()
}
#endif // !os(Windows)
