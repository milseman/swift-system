/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
#if canImport(Android)
import Android
#endif

// Error paths and edge cases for FilePath operations: the buffer that
// currentWorkingDirectory grows, each rename(options:) overload, and changing
// a symbolic link's own permissions on Linux, which can't be done.
//
// These are XCTest tests, which run one at a time, since one of them changes
// the working directory, which belongs to the whole process.

@available(System 199, *)
final class FilePathOperationsErrorTest: XCTestCase {
  #if ENABLE_MOCKING && !os(WASI) // Would need to use _getConst funcs from CSystem
  func testCurrentWorkingDirectoryGrowsItsBuffer() throws {
    let capacity = FilePath._initialWorkingDirectoryCapacity
    try MockingDriver.withMockingEnabled { mocking in
      // While getcwd reports that the buffer is too small, each attempt
      // doubles it. (The mock returns an empty path.)
      mocking.forceErrno = .counted(errno: ERANGE, count: 2)
      XCTAssertEqual(try FilePath.currentWorkingDirectory(), "")
      for size in [capacity, 2 * capacity, 4 * capacity] {
        let call = mocking.trace.dequeue()
        XCTAssertEqual(call?.name, "getcwd")
        XCTAssertEqual(call?.arguments.last, AnyHashable(size))
      }
      XCTAssertTrue(mocking.trace.isEmpty)

      // Any other error is thrown after one attempt.
      mocking.forceErrno = .counted(errno: EACCES, count: 1)
      XCTAssertThrowsError(try FilePath.currentWorkingDirectory()) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.arguments.last, AnyHashable(capacity))
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  #if !os(WASI) // WASI has no fchdir
  func testCurrentWorkingDirectoryLongerThanTheBuffer() throws {
    let original = try FileDescriptor.open(".", .readOnly)
    defer { try? original.close() }

    try withTemporaryFilePath(basename: "testLongWorkingDirectory") { path in
      try FilePath.setCurrentWorkingDirectory(path)
      defer { try? FilePath.setCurrentWorkingDirectory(original) }
      // getcwd resolves symbolic links, such as Darwin's /var to /private/var.
      var expected = try FilePath.currentWorkingDirectory()

      // Descend until the path needs the buffer to double twice. Darwin
      // allows a working directory longer than PATH_MAX, 1024 there, as long
      // as each path given to chdir is shorter.
      let name = String(repeating: "d", count: 200)
      var depth = 0
      defer {
        // A path this long can be too long to remove by absolute path.
        while depth > 0 {
          try? FilePath.setCurrentWorkingDirectory(FilePath(".."))
          try? FilePath(name).removeDirectory()
          depth -= 1
        }
      }
      while expected.length <= 2 * FilePath._initialWorkingDirectoryCapacity {
        try FilePath(name).makeDirectory(permissions: .ownerReadWriteExecute)
        try FilePath.setCurrentWorkingDirectory(FilePath(name))
        depth += 1
        expected = expected.appending(name)
      }
      XCTAssertEqual(try FilePath.currentWorkingDirectory(), expected)
    }
  }
  #endif // !os(WASI)

  #if ENABLE_MOCKING && (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android))
  func testRenameWithOptionsSyscalls() throws {
    // Each overload passes its options to the call, which fails with the
    // call's error: an existing file for .exclusive, or an option the file
    // system doesn't support.
    let path: FilePath = "a path"
    let dir = FileDescriptor(rawValue: 42)
    let other = FileDescriptor(rawValue: 43)
    #if SYSTEM_PACKAGE_DARWIN
    let exclusive = UInt32(RENAME_EXCL)
    let swap = UInt32(RENAME_SWAP)
    let (name, nameAt) = ("renamex_np", "renameatx_np")
    let cwdArguments: [AnyHashable] = []
    #else
    // The kernel's RENAME_NOREPLACE and RENAME_EXCHANGE.
    let exclusive = UInt32(1 << 0)
    let swap = UInt32(1 << 1)
    let (name, nameAt) = ("renameat2", "renameat2")
    let cwdArguments: [AnyHashable] = [AT_FDCWD]
    #endif

    let calls: [(String, [AnyHashable], (Bool) throws -> Void)] = [
      (name, cwdArguments + ["a path"] + cwdArguments + ["new path", UInt32(0)], {
        try path.rename(to: "new path", options: [], retryOnInterrupt: $0)
      }),
      (name, cwdArguments + ["a path"] + cwdArguments + ["new path", exclusive], {
        retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(
              old, to: new, options: .exclusive, retryOnInterrupt: retryOnInterrupt)
          }
        }
      }),
      (nameAt, [42, "a path", 43, "new path", swap], {
        try path.rename(
          relativeTo: dir, to: "new path", relativeTo: other, options: .swap,
          retryOnInterrupt: $0)
      }),
      (nameAt, [42, "a path", 43, "new path", exclusive], { retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(
              old, relativeTo: dir, to: new, relativeTo: other, options: .exclusive,
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      }),
    ]

    for (name, arguments, body) in calls {
      var test = MockTestCase(name: name, .interruptable) { try body($0) }
      test.expected = Trace.Entry(name: name, arguments)
      test.runAllTests()

      try MockingDriver.withMockingEnabled { mocking in
        for (code, expected) in [(EEXIST, Errno.fileExists), (EINVAL, .invalidArgument)] {
          mocking.forceErrno = .counted(errno: code, count: 1)
          XCTAssertThrowsError(try body(true), name) {
            XCTAssertEqual($0 as? Errno, expected, name)
          }
          XCTAssertEqual(mocking.trace.dequeue()?.name, name)
          XCTAssertTrue(mocking.trace.isEmpty, name)
        }
      }
    }
  }
  #endif // ENABLE_MOCKING && (SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android))

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
  func testRenameWithConflictingOptions() throws {
    // A rename can't both refuse to replace a file and exchange two.
    try withTemporaryFilePath(basename: "testRenameWithConflictingOptions") { path in
      for name in ["a", "b"] {
        try FileDescriptor.open(
          path.appending(name), .writeOnly, options: .create, permissions: .ownerReadWrite
        ).close()
      }
      XCTAssertThrowsError(
        try path.appending("a").rename(to: path.appending("b"), options: [.exclusive, .swap])
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertNoThrow(try path.appending("a").stat())
      XCTAssertNoThrow(try path.appending("b").stat())
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

  #if os(Linux)
  func testSetPermissionsOfASymbolicLinkOnLinux() throws {
    try withTemporaryFilePath(basename: "testSymbolicLinkPermissions") { path in
      let file = path.appending("file")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "file")
      let linkPermissions = try link.stat(followTargetSymlink: false).permissions

      // Linux can't change a symbolic link's own permissions: lchmod and
      // fchmodat with AT_SYMLINK_NOFOLLOW fail with EOPNOTSUPP (which is
      // ENOTSUP there), or before glibc 2.32, which has no lchmod, ENOSYS.
      func checkUnsupported(
        _ what: String, line: UInt = #line, _ body: () throws -> Void
      ) {
        XCTAssertThrowsError(try body(), what, line: line) {
          let error = $0 as? Errno
          XCTAssertTrue(
            error == .notSupported || error == .noFunction, "\(what): \(String(describing: error))",
            line: line)
        }
      }
      checkUnsupported("lchmod") {
        try link.setPermissions(.ownerRead, followTargetSymlink: false)
      }
      checkUnsupported("lchmod, C string") {
        try link.withCString {
          try FilePath.setPermissions($0, .ownerRead, followTargetSymlink: false)
        }
      }
      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        checkUnsupported("fchmodat") {
          try FilePath("link").setPermissions(
            .ownerRead, relativeTo: dir, flags: .symlinkNoFollow)
        }
      }

      // Neither the link nor its target changed.
      XCTAssertEqual(try link.stat(followTargetSymlink: false).permissions, linkPermissions)
      XCTAssertEqual(try file.stat().permissions, .ownerReadWrite)

      // A path that isn't a symbolic link changes, where lchmod exists.
      do {
        try file.setPermissions(.ownerRead, followTargetSymlink: false)
        XCTAssertEqual(try file.stat().permissions, .ownerRead)
      } catch Errno.noFunction {
        // glibc before 2.32
      }
    }
  }
  #endif // os(Linux)
}

#endif // !os(Windows)
