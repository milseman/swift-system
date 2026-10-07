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
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// confstr exists where SystemConfig.string does.
#if !os(Windows) && !os(WASI) && !os(Android)
@available(System 199, *)
final class ConfigurationStringTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() throws {
    let path = CInt(_CS_PATH)
    try MockingDriver.withMockingEnabled { mocking in
      // A mocked confstr returns 0, which means the name has no value.
      XCTAssertNil(try SystemConfig.string(.defaultSearchPath))
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [path, 0])
      XCTAssertTrue(mocking.trace.isEmpty)

      // The first call reads the size, and a value that has grown since is
      // read again.
      mocking.byteCounts = [4, 8, 8]
      XCTAssertEqual(try SystemConfig.string(.defaultSearchPath)?.utf8.count, 7)
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [path, 0])
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [path, 4])
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [path, 8])
      XCTAssertTrue(mocking.trace.isEmpty)

      mocking.forceErrno = .always(errno: EINVAL)
      XCTAssertThrowsError(try SystemConfig.string(.defaultSearchPath)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [path, 0])
    }
  }
  #endif // ENABLE_MOCKING

  func testDefaultSearchPath() throws {
    let value = try XCTUnwrap(try SystemConfig.string(.defaultSearchPath))
    XCTAssertTrue(value.split(separator: ":").contains("/usr/bin"))
    // It matches what confstr returns.
    let size = confstr(CInt(_CS_PATH), nil, 0)
    var buffer = [CChar](repeating: 0, count: size)
    XCTAssertEqual(confstr(CInt(_CS_PATH), &buffer, size), size)
    XCTAssertEqual(value, String(decoding: buffer.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self))
  }

  func testInvalidName() {
    XCTAssertThrowsError(try SystemConfig.string(SystemConfig.StringName(rawValue: 12345))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }

  #if os(Linux) && canImport(Glibc)
  func testTheCLibrarysVersion() throws {
    // "glibc 2.39": the name, then what gnu_get_libc_version returns
    // (which Glibc's Swift module doesn't import).
    let value = try XCTUnwrap(try SystemConfig.string(.gnuLibraryVersion))
    XCTAssertTrue(value.hasPrefix("glibc "), value)
    let numbers = value.dropFirst("glibc ".count).split(separator: ".").map { Int($0) }
    XCTAssertGreaterThanOrEqual(numbers.count, 2, value)
    XCTAssertTrue(numbers.allSatisfy { $0 != nil }, value)
    // At least the version System was built with.
    XCTAssertGreaterThanOrEqual(numbers[0]! * 1000 + numbers[1]!, Int(__GLIBC__) * 1000 + Int(__GLIBC_MINOR__))
  }
  #endif

  #if SYSTEM_PACKAGE_DARWIN
  func testUserDirectories() throws {
    let user = try XCTUnwrap(try SystemConfig.string(.userDirectory))
    let temporary = try XCTUnwrap(try SystemConfig.string(.userTemporaryDirectory))
    let cache = try XCTUnwrap(try SystemConfig.string(.userCacheDirectory))
    for directory in [user, temporary, cache] {
      XCTAssertTrue(directory.hasPrefix("/"), directory)
      XCTAssertTrue(directory.hasSuffix("/"), directory)
      XCTAssertEqual(try FilePath(directory).stat().type, .directory, directory)
    }
    // The temporary and cache directories are in the user's directory.
    XCTAssertTrue(temporary.hasPrefix(user.dropLast(2)))
    XCTAssertTrue(cache.hasPrefix(user.dropLast(2)))
    XCTAssertNotEqual(temporary, cache)
  }
  #endif
}
#endif // !os(Windows) && !os(WASI) && !os(Android)

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
final class MakePathTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() throws {
    let path: FilePath = "a/path"
    let dir = FileDescriptor(rawValue: 42)
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mkpath_np", .interruptable, "a/path", 0o755) { retryOnInterrupt in
        try path.makeDirectories(
          permissions: [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute],
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "mkpath_np", .interruptable, "a/path", 0o700) { retryOnInterrupt in
        _ = try "a/path".withCString {
          try FilePath.makeDirectories(
            $0, permissions: .ownerReadWriteExecute, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "mkpathat_np", .interruptable, 42, "a/path", 0o700) {
        retryOnInterrupt in
        try path.makeDirectories(
          relativeTo: dir, permissions: .ownerReadWriteExecute,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "mkpathat_np", .interruptable, 42, "a/path", 0o700) {
        retryOnInterrupt in
        _ = try "a/path".withCString {
          try FilePath.makeDirectories(
            $0, relativeTo: dir, permissions: .ownerReadWriteExecute,
            retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    for test in syscallTestCases { test.runAllTests() }

    // mkpath_np returns EEXIST only if the directory is already there.
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EEXIST)
      XCTAssertEqual(try path.makeDirectories(permissions: .ownerReadWriteExecute), false)
      mocking.forceErrno = .always(errno: EACCES)
      XCTAssertThrowsError(try path.makeDirectories(permissions: .ownerReadWriteExecute)) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
    }
  }
  #endif // ENABLE_MOCKING

  func testMakeDirectories() throws {
    try withTemporaryFilePath(basename: "testMakeDirectories") { path in
      let leaf = path.appending("a/b/c")
      XCTAssertTrue(try leaf.makeDirectories(permissions: .ownerReadWriteExecute))
      XCTAssertEqual(try leaf.stat().type, .directory)
      XCTAssertEqual(try leaf.stat().permissions, .ownerReadWriteExecute)
      // Making it again finds it there.
      XCTAssertFalse(try leaf.makeDirectories(permissions: .ownerReadWriteExecute))
      XCTAssertFalse(
        try path.appending("a").withCString {
          try FilePath.makeDirectories($0, permissions: .ownerReadWriteExecute)
        })

      // The directories before the last get the default permissions, with
      // the file creation mask applied, and write and search for the owner.
      let mask = umask(0o022)
      defer { umask(mask) }
      XCTAssertTrue(try path.appending("d/e").makeDirectories(permissions: .ownerReadWriteExecute))
      XCTAssertEqual(
        try path.appending("d").stat().permissions,
        [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])

      // A file in the way isn't a directory.
      let fd = try FileDescriptor.open(
        path.appending("file"), .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      XCTAssertThrowsError(try path.appending("file").makeDirectories(permissions: .ownerReadWriteExecute)) {
        XCTAssertEqual($0 as? Errno, .notDirectory)
      }
      XCTAssertThrowsError(try path.appending("file/f").makeDirectories(permissions: .ownerReadWriteExecute)) {
        XCTAssertEqual($0 as? Errno, .notDirectory)
      }

      // A relative path is resolved against a directory.
      let directory = try FileDescriptor.open(path.appending("a"), .readOnly, options: .directory)
      try directory.closeAfter {
        XCTAssertTrue(try FilePath("x/y").makeDirectories(
          relativeTo: directory, permissions: .ownerReadWriteExecute))
        XCTAssertFalse(try "x/y".withCString {
          try FilePath.makeDirectories($0, relativeTo: directory, permissions: .ownerReadWriteExecute)
        })
      }
      XCTAssertEqual(try path.appending("a/x/y").stat().type, .directory)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN
