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

      MockTestCase(name: "rmdir", .interruptable, "a path") { retryOnInterrupt in
        try path.removeDirectory(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "rmdir", .interruptable, "a path") { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.removeDirectory($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "unlinkat", .interruptable, 42, "a path", AT_REMOVEDIR) {
        retryOnInterrupt in
        try path.removeDirectory(relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "unlinkat", .interruptable, 42, "a path", AT_REMOVEDIR) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.removeDirectory(
            $0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "unlink", .interruptable, "a path") { retryOnInterrupt in
        try path.unlink(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "unlink", .interruptable, "a path") { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.unlink($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "unlinkat", .interruptable, 42, "a path", 0) {
        retryOnInterrupt in
        try path.unlink(relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "unlinkat", .interruptable, 42, "a path", 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.unlink($0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "rename", .interruptable, "a path", "new path") {
        retryOnInterrupt in
        try path.rename(to: "new path", retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "rename", .interruptable, "a path", "new path") {
        retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(old, to: new, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(name: "renameat", .interruptable, 42, "a path", 43, "new path") {
        retryOnInterrupt in
        try path.rename(
          relativeTo: dir, to: "new path", relativeTo: FileDescriptor(rawValue: 43),
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "renameat", .interruptable, 42, "a path", 43, "new path") {
        retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(
              old, relativeTo: dir, to: new, relativeTo: FileDescriptor(rawValue: 43),
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      },
    ]

    for test in syscallTestCases { test.runAllTests() }

    #if SYSTEM_PACKAGE_DARWIN
    let resolutionFlagsTestCases: Array<MockTestCase> = [
      MockTestCase(
        name: "unlinkat", .interruptable, 42, "a path", AT_SYMLINK_NOFOLLOW_ANY
      ) { retryOnInterrupt in
        try path.unlink(
          relativeTo: dir, flags: .symlinkNoFollowAny, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "unlinkat", .interruptable, 42, "a path",
        AT_REMOVEDIR | AT_SYMLINK_NOFOLLOW_ANY
      ) { retryOnInterrupt in
        try path.removeDirectory(
          relativeTo: dir, flags: .symlinkNoFollowAny, retryOnInterrupt: retryOnInterrupt)
      },
    ]

    for test in resolutionFlagsTestCases { test.runAllTests() }
    #endif // SYSTEM_PACKAGE_DARWIN
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  @available(System 199, *)
  func testResolutionFlags() {
    XCTAssertEqual(FilePath.ResolutionFlags.symlinkNoFollow.rawValue, AT_SYMLINK_NOFOLLOW)
    XCTAssertEqual(FilePath.ResolutionFlags.symlinkFollow.rawValue, AT_SYMLINK_FOLLOW)
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertEqual(
      FilePath.ResolutionFlags.symlinkNoFollowAny.rawValue, AT_SYMLINK_NOFOLLOW_ANY)
    #endif
    #if canImport(Darwin, _version: 346) || os(FreeBSD)
    XCTAssertEqual(FilePath.ResolutionFlags.resolveBeneath.rawValue, AT_RESOLVE_BENEATH)
    #endif
  }

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

  @available(System 199, *)
  func testRemove() throws {
    try withTemporaryFilePath(basename: "testRemove") { path in
      func makeFile(_ name: String) throws {
        let fd = try FileDescriptor.open(
          path.appending(name), .writeOnly, options: .create, permissions: .ownerReadWrite)
        try fd.close()
      }
      func exists(_ name: String) -> Bool {
        (try? path.appending(name).stat(followTargetSymlink: false)) != nil
      }

      try makeFile("file")
      try path.appending("file").unlink()
      XCTAssertFalse(exists("file"))
      XCTAssertThrowsError(try path.appending("file").unlink()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      try makeFile("c string")
      try path.appending("c string").withCString { try FilePath.unlink($0) }
      XCTAssertFalse(exists("c string"))

      try path.appending("dir").makeDirectory(permissions: .ownerReadWriteExecute)
      // POSIX allows either error for unlinking a directory.
      XCTAssertThrowsError(try path.appending("dir").unlink()) {
        XCTAssert([Errno.notPermitted, .isDirectory].contains($0 as? Errno))
      }
      try makeFile("dir/file")
      XCTAssertThrowsError(try path.appending("dir").removeDirectory()) {
        XCTAssert([Errno.directoryNotEmpty, .fileExists].contains($0 as? Errno))
      }
      try path.appending("dir/file").unlink()
      try path.appending("dir").removeDirectory()
      XCTAssertFalse(exists("dir"))

      try path.appending("c string dir").makeDirectory(permissions: .ownerReadWriteExecute)
      try path.appending("c string dir").withCString { try FilePath.removeDirectory($0) }
      XCTAssertFalse(exists("c string dir"))

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try makeFile("relative")
        try FilePath("relative").unlink(relativeTo: dir)
        XCTAssertFalse(exists("relative"))

        try makeFile("relative c string")
        try "relative c string".withCString { try FilePath.unlink($0, relativeTo: dir) }
        XCTAssertFalse(exists("relative c string"))

        try path.appending("relative dir").makeDirectory(permissions: .ownerReadWriteExecute)
        XCTAssertThrowsError(try FilePath("relative dir").unlink(relativeTo: dir)) {
          XCTAssert([Errno.notPermitted, .isDirectory].contains($0 as? Errno))
        }
        try FilePath("relative dir").removeDirectory(relativeTo: dir)
        XCTAssertFalse(exists("relative dir"))

        try path.appending("relative c string dir").makeDirectory(
          permissions: .ownerReadWriteExecute)
        try "relative c string dir".withCString {
          try FilePath.removeDirectory($0, relativeTo: dir)
        }
        XCTAssertFalse(exists("relative c string dir"))

        try makeFile("not a dir")
        XCTAssertThrowsError(try FilePath("not a dir").removeDirectory(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .notDirectory)
        }

        #if canImport(Darwin, _version: 346) || os(FreeBSD)
        XCTAssertThrowsError(
          try FilePath("../elsewhere").unlink(relativeTo: dir, flags: .resolveBeneath)
        ) {
          XCTAssertEqual($0 as? Errno, Errno(rawValue: ENOTCAPABLE))
        }
        #endif
      }
    }
  }

  @available(System 199, *)
  func testRename() throws {
    try withTemporaryFilePath(basename: "testRename") { path in
      func write(_ contents: String, to name: String) throws {
        let fd = try FileDescriptor.open(
          path.appending(name), .writeOnly, options: [.create, .truncate],
          permissions: .ownerReadWrite)
        try fd.closeAfter { _ = try fd.writeAll(contents.utf8) }
      }
      func contents(of name: String) throws -> String {
        let fd = try FileDescriptor.open(path.appending(name), .readOnly)
        return try fd.closeAfter {
          let bytes = try Array<UInt8>(unsafeUninitializedCapacity: 16) { buf, count in
            count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
          }
          return String(decoding: bytes, as: UTF8.self)
        }
      }
      func exists(_ name: String) -> Bool {
        (try? path.appending(name).stat(followTargetSymlink: false)) != nil
      }

      try write("a", to: "a")
      try path.appending("a").rename(to: path.appending("b"))
      XCTAssertFalse(exists("a"))
      XCTAssertEqual(try contents(of: "b"), "a")

      // Renaming replaces an existing file.
      try write("c", to: "c")
      try path.appending("c").withCString { old in
        try path.appending("b").withCString { new in
          try FilePath.rename(old, to: new)
        }
      }
      XCTAssertFalse(exists("c"))
      XCTAssertEqual(try contents(of: "b"), "c")

      XCTAssertThrowsError(try path.appending("a").rename(to: path.appending("d"))) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      try path.appending("one").makeDirectory(permissions: .ownerReadWriteExecute)
      try path.appending("two").makeDirectory(permissions: .ownerReadWriteExecute)
      let one = try FileDescriptor.open(path.appending("one"), .readOnly, options: .directory)
      try one.closeAfter {
        let two = try FileDescriptor.open(path.appending("two"), .readOnly, options: .directory)
        try two.closeAfter {
          try write("e", to: "one/e")
          try FilePath("e").rename(relativeTo: one, to: "f", relativeTo: two)
          XCTAssertFalse(exists("one/e"))
          XCTAssertEqual(try contents(of: "two/f"), "e")

          try "f".withCString { old in
            try "g".withCString { new in
              try FilePath.rename(old, relativeTo: two, to: new, relativeTo: one)
            }
          }
          XCTAssertFalse(exists("two/f"))
          XCTAssertEqual(try contents(of: "one/g"), "e")

          XCTAssertThrowsError(
            try FilePath("f").rename(relativeTo: two, to: "h", relativeTo: one)
          ) {
            XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
          }
        }
      }
    }
  }
}

#endif // !os(Windows)
