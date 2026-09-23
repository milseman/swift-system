/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
#if canImport(Android)
import Android
#endif

// Error paths and edge cases for synchronize, synchronizeData,
// setPermissions, setOwner, setFileFlags, and open(_:relativeTo:...).
// These are XCTest tests, which run one at a time, so a test can use a
// descriptor after closing it without racing another test's open.

#if !os(Windows)
@available(System 199, *)
final class FileOperationsErrorTest: XCTestCase {
  /// Checks that `body` throws `expected`.
  private func check(
    _ expected: Errno, file: StaticString = #filePath, line: UInt = #line,
    _ body: () throws -> Void
  ) {
    XCTAssertThrowsError(try body(), file: file, line: line) {
      XCTAssertEqual($0 as? Errno, expected, file: file, line: line)
    }
  }

  func testInvalidDescriptor() {
    let fd = FileDescriptor(rawValue: -1)
    check(.badFileDescriptor) { try fd.synchronize() }
    #if !SYSTEM_PACKAGE_DARWIN
    check(.badFileDescriptor) { try fd.synchronizeData() }
    #endif
    #if !os(WASI)
    check(.badFileDescriptor) { try fd.setPermissions(.ownerReadWrite) }
    check(.badFileDescriptor) { try fd.setOwner() }
    #endif
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    check(.badFileDescriptor) { try fd.setFileFlags([]) }
    #endif
  }

  func testClosedDescriptor() throws {
    try withTemporaryFilePath(basename: "testClosedDescriptor") { path in
      let fd = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      check(.badFileDescriptor) { try fd.synchronize() }
      #if !SYSTEM_PACKAGE_DARWIN
      check(.badFileDescriptor) { try fd.synchronizeData() }
      #endif
      #if !os(WASI)
      check(.badFileDescriptor) { try fd.setPermissions(.ownerReadWrite) }
      check(.badFileDescriptor) { try fd.setOwner() }
      #endif
      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
      check(.badFileDescriptor) { try fd.setFileFlags([]) }
      #endif
    }
  }

  func testMetadataChangesThroughAReadOnlyDescriptor() throws {
    // These calls need ownership of the file, not write access to it.
    try withTemporaryFilePath(basename: "testReadOnlyDescriptor") { path in
      let file = path.appending("file.txt")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let fd = try FileDescriptor.open(file, .readOnly)
      try fd.closeAfter {
        try fd.synchronize()
        #if !os(WASI)
        try fd.setPermissions([.ownerRead, .groupRead])
        XCTAssertEqual(try file.stat().permissions, [.ownerRead, .groupRead])
        try fd.setOwner()
        #endif
        #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
        try fd.setFileFlags(.noDump)
        XCTAssertTrue(try file.stat().flags.contains(.noDump))
        #endif
      }
    }
  }

  #if !os(WASI) // WASI has no pipe, and no permissions or process credentials
  func testSynchronizeRejectsAPipe() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    // A pipe has no storage to flush to.
    #if SYSTEM_PACKAGE_DARWIN
    check(.notSupported) { try pipe.writeEnd.synchronize() }
    #elseif os(Linux) || os(Android)
    check(.invalidArgument) { try pipe.writeEnd.synchronize() }
    check(.invalidArgument) { try pipe.writeEnd.synchronizeData() }
    #endif
  }

  func testChangesToAnotherUsersFileAreNotPermitted() throws {
    guard geteuid() != 0 else {
      throw XCTSkip("A privileged process can change any file")
    }
    // /tmp is owned by root, on a writable file system. (On a read-only
    // file system, Linux reports EROFS before checking permissions.)
    let tmp: FileDescriptor
    do {
      tmp = try FileDescriptor.open("/tmp", .readOnly)
    } catch Errno.noSuchFileOrDirectory {
      throw XCTSkip("This system has no /tmp")
    }
    try tmp.closeAfter {
      let status = try tmp.stat()
      guard status.userID.rawValue != geteuid() else {
        throw XCTSkip("The current user owns /tmp")
      }
      // Even setting the current values requires owning the file.
      check(.notPermitted) { try tmp.setPermissions(status.permissions) }
      check(.notPermitted) { try tmp.setOwner(group: GroupID(getegid())) }
      check(.notPermitted) { try tmp.setOwner(user: UserID(geteuid())) }
      // Other processes change /tmp's times, so compare only what the calls
      // would have changed.
      let after = try tmp.stat()
      XCTAssertEqual(after.permissions, status.permissions)
      XCTAssertEqual(after.userID, status.userID)
      XCTAssertEqual(after.groupID, status.groupID)
    }
  }
  #endif // !os(WASI)

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  func testImmutableFlagBlocksChanges() throws {
    try withTemporaryFilePath(basename: "testImmutableFlag") { path in
      let file = path.appending("file.txt")
      let fd = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      try fd.closeAfter {
        let original = try fd.stat().flags
        try fd.setFileFlags(original.union(.userImmutable))
        // Clear the flag even if a check fails, so that the directory can
        // be removed.
        defer { try? fd.setFileFlags(original) }
        XCTAssertTrue(try fd.stat().flags.contains(.userImmutable))

        check(.notPermitted) { try FileDescriptor.open(file, .writeOnly).close() }
        check(.notPermitted) { try fd.setPermissions(.ownerRead) }

        try fd.setFileFlags(original)
        try FileDescriptor.open(file, .writeOnly).close()
        try fd.setPermissions(.ownerRead)
      }
    }
  }

  func testAppendOnlyFlagBlocksOverwriting() throws {
    try withTemporaryFilePath(basename: "testAppendOnlyFlag") { path in
      let file = path.appending("file.txt")
      let fd = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)
        let original = try fd.stat().flags
        try fd.setFileFlags(original.union(.userAppend))
        defer { try? fd.setFileFlags(original) }

        check(.notPermitted) { try fd.writeAll(toAbsoluteOffset: 0, "x".utf8) }
        check(.notPermitted) { try FileDescriptor.open(file, .writeOnly).close() }
        let appender = try FileDescriptor.open(file, .writeOnly, options: .append)
        try appender.closeAfter { try appender.writeAll("def".utf8) }
        XCTAssertEqual(try fd.stat().size, 6)

        try fd.setFileFlags(original)
        try fd.writeAll(toAbsoluteOffset: 0, "x".utf8)
      }
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

  func testOpenRelativeToAnInvalidDirectory() throws {
    try withTemporaryFilePath(basename: "testOpenRelativeToInvalid") { path in
      let file = path.appending("file.txt")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let invalid = FileDescriptor(rawValue: -1)

      #if !os(WASI) // WASI resolves paths only beneath the directory
      // An absolute path ignores the directory, even an invalid one.
      try FileDescriptor.open(file, relativeTo: invalid, .readOnly).close()
      #endif

      // A relative path needs an open directory.
      check(.badFileDescriptor) {
        try FileDescriptor.open("file.txt", relativeTo: invalid, .readOnly).close()
      }
      let directory = try FileDescriptor.open(path, .readOnly, options: .directory)
      try directory.close()
      check(.badFileDescriptor) {
        try FileDescriptor.open("file.txt", relativeTo: directory, .readOnly).close()
      }
    }
  }

  #if !os(WASI) // WASI has no AT_FDCWD, and resolves paths only beneath a directory
  func testOpenRelativeToTheCurrentDirectory() throws {
    // AT_FDCWD stands for the current directory.
    let current = try FileDescriptor.open(
      ".", relativeTo: FileDescriptor(rawValue: AT_FDCWD), .readOnly, options: .directory)
    try current.closeAfter {
      let expected = try FilePath(".").stat()
      let actual = try current.stat()
      XCTAssertEqual(actual.deviceID, expected.deviceID)
      XCTAssertEqual(actual.inode, expected.inode)
    }
  }

  func testOpenRelativeToNestedAndParentPaths() throws {
    try withTemporaryFilePath(basename: "testOpenRelativeNested") { path in
      XCTAssertEqual(path.appending("sub").withPlatformString { mkdir($0, 0o700) }, 0)
      let directory = try FileDescriptor.open(path, .readOnly, options: .directory)
      try directory.closeAfter {
        let created = try FileDescriptor.open(
          "sub/file.txt", relativeTo: directory, .writeOnly,
          options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
        try created.closeAfter { try created.writeAll("nested".utf8) }
        XCTAssertEqual(try path.appending("sub/file.txt").stat().size, 6)

        // ".." can lead out of the directory.
        let sub = try FileDescriptor.open("sub", relativeTo: directory, .readOnly)
        try sub.closeAfter {
          try FileDescriptor.open("../sub/file.txt", relativeTo: sub, .readOnly).close()
        }

        // The pointer overload resolves the same way.
        try "sub/file.txt".withCString {
          try FileDescriptor.open($0, relativeTo: directory, .readOnly).close()
        }

        check(.fileExists) {
          try FileDescriptor.open(
            "sub/file.txt", relativeTo: directory, .writeOnly,
            options: [.create, .exclusiveCreate], permissions: .ownerReadWrite
          ).close()
        }
        check(.notDirectory) {
          try FileDescriptor.open(
            "sub/file.txt", relativeTo: directory, .readOnly, options: .directory
          ).close()
        }
        check(.noSuchFileOrDirectory) {
          try FileDescriptor.open("sub/missing.txt", relativeTo: directory, .readOnly).close()
        }
      }
    }
  }
  #endif // !os(WASI)
}
#endif // !os(Windows)
