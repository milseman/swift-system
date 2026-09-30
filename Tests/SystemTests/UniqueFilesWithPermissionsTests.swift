/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unique files with permissions of the caller's choosing (mktemp, then
// open or openat with O_EXCL). XCTest, since they set the process's
// creation mask.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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
final class UniqueFilesWithPermissionsTest: XCTestCase {
  func testTheCreationMaskApplies() throws {
    try withTemporaryFilePath(basename: "testTheCreationMaskApplies") { dir in
      let (path, fd) = try FilePermissions.withCreationMask([.groupWrite, .otherWrite]) {
        try dir.appending("shared-XXXXXX").makeUniqueFile(
          options: .closeOnExec, permissions: [.ownerReadWrite, .groupReadWrite, .otherRead])
      }
      defer { try? fd.close() }
      let name = try XCTUnwrap(path.lastComponent?.string)
      XCTAssertTrue(name.hasPrefix("shared-"))
      XCTAssertEqual(name.count, "shared-XXXXXX".count)
      XCTAssertFalse(name.hasSuffix("XXXXXX"))
      XCTAssertEqual(try fd.stat().mode.permissions, [.ownerReadWrite, .groupRead, .otherRead])
      XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))
      // Open for reading and writing.
      XCTAssertEqual(try fd.writeAll("abc".utf8), 3)
      XCTAssertEqual(try fd.seek(offset: 0, from: .start), 0)
      var bytes = [UInt8](repeating: 0, count: 3)
      XCTAssertEqual(try bytes.withUnsafeMutableBytes { try fd.read(into: $0) }, 3)
      XCTAssertEqual(bytes, Array("abc".utf8))
    }
  }

  func testEachNameIsNew() throws {
    try withTemporaryFilePath(basename: "testEachNameIsNew") { dir in
      var names: Set<String> = []
      for _ in 0..<20 {
        let (path, fd) = try dir.appending("XXXXXX").makeUniqueFile(permissions: .ownerReadWrite)
        try fd.close()
        names.insert(path.string)
      }
      XCTAssertEqual(names.count, 20)
    }
  }

  func testRelativeToADirectory() throws {
    try withTemporaryFilePath(basename: "testRelativeToADirectory") { dir in
      // A subdirectory that the working directory doesn't have.
      try dir.appending("sub").makeDirectory(permissions: .ownerReadWriteExecute)
      let directory = try FileDescriptor.open(dir, .readOnly)
      defer { try? directory.close() }
      let (path, fd) = try FilePermissions.withCreationMask([.otherWrite]) {
        try FilePath("sub/data-XXXXXX").makeUniqueFile(
          relativeTo: directory, permissions: [.ownerReadWrite, .groupRead])
      }
      defer { try? fd.close() }
      XCTAssertFalse(path.isAbsolute)
      XCTAssertTrue(path.string.hasPrefix("sub/data-"))
      XCTAssertEqual(try dir.appending(path.components).stat().type, .regular)
      XCTAssertEqual(try fd.stat().mode.permissions, [.ownerReadWrite, .groupRead])
    }
  }

  func testTemplates() throws {
    try withTemporaryFilePath(basename: "testTemplates") { dir in
      // Six X's must end the template.
      XCTAssertThrowsError(try dir.appending("XXXXX").makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try dir.appending("XXXXXX.txt").makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      // A directory that doesn't exist.
      XCTAssertThrowsError(
        try dir.appending("missing/XXXXXX").makeUniqueFile(permissions: .ownerReadWrite)
      ) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
    }
  }

  #if ENABLE_MOCKING && SYSTEM_PACKAGE_DARWIN
  private func entries(_ mocking: MockingDriver) -> [(String, [AnyHashable])] {
    var result: [(String, [AnyHashable])] = []
    while let entry = mocking.trace.dequeue() { result.append((entry.name, entry.arguments)) }
    return result
  }

  func testCalls() throws {
    let flags = O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC
    let mode = FilePermissions([.ownerReadWrite, .groupRead]).rawValue
    try MockingDriver.withMockingEnabled { mocking in
      _ = try FilePath("a/b-XXXXXX").makeUniqueFile(
        options: .closeOnExec, permissions: [.ownerReadWrite, .groupRead])
      // Relative to a directory, mktemp makes only the last component.
      _ = try FilePath("a/b-XXXXXX").makeUniqueFile(
        relativeTo: FileDescriptor(rawValue: 42), options: .closeOnExec,
        permissions: [.ownerReadWrite, .groupRead])
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), ["mktemp", "open", "mktemp", "openat"])
      XCTAssertEqual(calls.map(\.1), [
        ["a/b-XXXXXX"], ["a/b-XXXXXX", flags, mode],
        ["b-XXXXXX"], [42, "a/b-XXXXXX", flags, mode],
      ] as [[AnyHashable]])
    }
  }

  func testRetries() throws {
    let template = FilePath("XXXXXX")
    try MockingDriver.withMockingEnabled { mocking in
      // A taken name is tried again, with the template restored.
      mocking.forceErrno = .counted(errno: EEXIST, count: 1)
      _ = try template.makeUniqueFile(permissions: .ownerReadWrite)
      XCTAssertEqual(entries(mocking).map(\.0), ["mktemp", "mktemp", "open"])

      // Up to a limit.
      mocking.forceErrno = .always(errno: EEXIST)
      XCTAssertThrowsError(try template.makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertEqual(entries(mocking).count, FilePath._uniqueNameAttempts)

      // An interruption is retried only when asked.
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      _ = try template.makeUniqueFile(permissions: .ownerReadWrite)
      XCTAssertEqual(entries(mocking).map(\.0), ["mktemp", "mktemp", "open"])
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(
        try template.makeUniqueFile(permissions: .ownerReadWrite, retryOnInterrupt: false)
      ) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["mktemp"])

      // Other errors aren't retried.
      mocking.forceErrno = .counted(errno: EACCES, count: 1)
      XCTAssertThrowsError(try template.makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["mktemp"])

      // A bad template makes no call.
      XCTAssertThrowsError(try FilePath("XXXXX").makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
