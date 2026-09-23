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

      MockTestCase(name: "link", .interruptable, "existing", "a path") {
        retryOnInterrupt in
        try path.makeHardLink(to: "existing", retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "link", .interruptable, "existing", "a path") {
        retryOnInterrupt in
        try "a path".withCString { new in
          try "existing".withCString { existing in
            try FilePath.makeHardLink(new, to: existing, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(
        name: "linkat", .interruptable, 43, "existing", 42, "a path", AT_SYMLINK_FOLLOW
      ) { retryOnInterrupt in
        try path.makeHardLink(
          relativeTo: dir, to: "existing", relativeTo: FileDescriptor(rawValue: 43),
          flags: .symlinkFollow, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "linkat", .interruptable, 43, "existing", 42, "a path", 0) {
        retryOnInterrupt in
        try "a path".withCString { new in
          try "existing".withCString { existing in
            try FilePath.makeHardLink(
              new, relativeTo: dir, to: existing, relativeTo: FileDescriptor(rawValue: 43),
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(name: "symlink", .interruptable, "target", "a path") {
        retryOnInterrupt in
        try path.makeSymbolicLink(to: "target", retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "symlink", .interruptable, "target", "a path") {
        retryOnInterrupt in
        try "a path".withCString { link in
          try "target".withCString { target in
            try FilePath.makeSymbolicLink(link, to: target, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(name: "symlinkat", .interruptable, "target", 42, "a path") {
        retryOnInterrupt in
        try path.makeSymbolicLink(
          relativeTo: dir, to: "target", retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "symlinkat", .interruptable, "target", 42, "a path") {
        retryOnInterrupt in
        try "a path".withCString { link in
          try "target".withCString { target in
            try FilePath.makeSymbolicLink(
              link, relativeTo: dir, to: target, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(
        name: "readlink", .interruptable,
        "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try path.readSymbolicLink(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "readlink", .interruptable,
        "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.readSymbolicLink($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "readlinkat", .interruptable,
        42, "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try path.readSymbolicLink(relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "readlinkat", .interruptable,
        42, "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.readSymbolicLink(
            $0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "truncate", .interruptable, "a path", 6) { retryOnInterrupt in
        try path.resize(to: 6, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "truncate", .interruptable, "a path", 6) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.resize($0, to: 6, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "chmod", .interruptable, "a path", 0o644) { retryOnInterrupt in
        try path.setPermissions(
          [.ownerReadWrite, .groupRead, .otherRead], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "chmod", .interruptable, "a path", 0o644) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setPermissions(
            $0, [.ownerReadWrite, .groupRead, .otherRead],
            retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "lchmod", .interruptable, "a path", 0o600) { retryOnInterrupt in
        try path.setPermissions(
          .ownerReadWrite, followTargetSymlink: false, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "lchmod", .interruptable, "a path", 0o600) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setPermissions(
            $0, .ownerReadWrite, followTargetSymlink: false,
            retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "fchmodat", .interruptable, 42, "a path", 0o600, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try path.setPermissions(
          .ownerReadWrite, relativeTo: dir, flags: .symlinkNoFollow,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fchmodat", .interruptable, 42, "a path", 0o600, 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setPermissions(
            $0, .ownerReadWrite, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "chown", .interruptable, "a path", 501, 20) { retryOnInterrupt in
        try path.setOwner(
          user: UserID(501), group: GroupID(20), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "chown", .interruptable, "a path", uid_t(truncatingIfNeeded: -1), 20
      ) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setOwner($0, group: GroupID(20), retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "lchown", .interruptable, "a path", 501, gid_t(truncatingIfNeeded: -1)
      ) { retryOnInterrupt in
        try path.setOwner(
          user: UserID(501), followTargetSymlink: false, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "lchown", .interruptable, "a path", 501, 20) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setOwner(
            $0, user: UserID(501), group: GroupID(20), followTargetSymlink: false,
            retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "fchownat", .interruptable, 42, "a path", 501, 20, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try path.setOwner(
          relativeTo: dir, user: UserID(501), group: GroupID(20), flags: .symlinkNoFollow,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fchownat", .interruptable,
        42, "a path", uid_t(truncatingIfNeeded: -1), gid_t(truncatingIfNeeded: -1), 0
      ) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setOwner($0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
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

  @available(System 199, *)
  func testMakeHardLink() throws {
    try withTemporaryFilePath(basename: "testMakeHardLink") { path in
      let a = path.appending("a")
      let fd = try FileDescriptor.open(
        a, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()

      try path.appending("b").makeHardLink(to: a)
      XCTAssertEqual(try path.appending("b").stat().inode, try a.stat().inode)
      XCTAssertEqual(try a.stat().linkCount, 2)

      try path.appending("c").withCString { new in
        try a.withCString { existing in
          try FilePath.makeHardLink(new, to: existing)
        }
      }
      XCTAssertEqual(try path.appending("c").stat().inode, try a.stat().inode)
      XCTAssertEqual(try a.stat().linkCount, 3)

      XCTAssertThrowsError(try path.appending("b").makeHardLink(to: a)) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertThrowsError(try path.appending("d").makeHardLink(to: path.appending("x"))) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("e").makeHardLink(relativeTo: dir, to: "a", relativeTo: dir)
        XCTAssertEqual(try path.appending("e").stat().inode, try a.stat().inode)

        // With .symlinkFollow, a symbolic link is resolved to its target.
        "a".withCString { target in
          path.appending("symlink").withCString { link in
            XCTAssertEqual(symlink(target, link), 0)
          }
        }
        try "f".withCString { new in
          try "symlink".withCString { existing in
            try FilePath.makeHardLink(
              new, relativeTo: dir, to: existing, relativeTo: dir, flags: .symlinkFollow)
          }
        }
        let f = try path.appending("f").stat(followTargetSymlink: false)
        XCTAssertEqual(f.type, .regular)
        XCTAssertEqual(f.inode, try a.stat().inode)
      }
    }
  }

  @available(System 199, *)
  func testMakeSymbolicLink() throws {
    try withTemporaryFilePath(basename: "testMakeSymbolicLink") { path in
      // The target doesn't need to exist.
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "target")
      XCTAssertEqual(try link.stat(followTargetSymlink: false).type, .symbolicLink)
      XCTAssertThrowsError(try link.stat()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      // A relative target resolves against the link's directory.
      let fd = try FileDescriptor.open(
        path.appending("target"), .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      XCTAssertEqual(try link.stat().inode, try path.appending("target").stat().inode)

      XCTAssertThrowsError(try link.makeSymbolicLink(to: "elsewhere")) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }

      try path.appending("c string").withCString { link in
        try "target".withCString { target in
          try FilePath.makeSymbolicLink(link, to: target)
        }
      }
      XCTAssertEqual(
        try path.appending("c string").stat(followTargetSymlink: false).type,
        .symbolicLink)

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("relative").makeSymbolicLink(relativeTo: dir, to: "target")
        XCTAssertEqual(
          try path.appending("relative").stat().inode,
          try path.appending("target").stat().inode)

        try "relative c string".withCString { link in
          try "target".withCString { target in
            try FilePath.makeSymbolicLink(link, relativeTo: dir, to: target)
          }
        }
        XCTAssertEqual(
          try path.appending("relative c string").stat().inode,
          try path.appending("target").stat().inode)

        XCTAssertThrowsError(
          try FilePath("missing/link").makeSymbolicLink(relativeTo: dir, to: "target")
        ) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }

  @available(System 199, *)
  func testReadSymbolicLink() throws {
    try withTemporaryFilePath(basename: "testReadSymbolicLink") { path in
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "target")
      XCTAssertEqual(try link.readSymbolicLink(), "target")
      XCTAssertEqual(try link.withCString { try FilePath.readSymbolicLink($0) }, "target")

      // A target longer than the first buffer is read in full.
      let long = FilePath(
        repeatElement("component", count: 60).joined(separator: "/"))
      XCTAssertGreaterThan(long.length, FilePath._initialSymbolicLinkCapacity)
      try path.appending("long").makeSymbolicLink(to: long)
      XCTAssertEqual(try path.appending("long").readSymbolicLink(), long)

      try path.appending("absolute").makeSymbolicLink(to: path)
      XCTAssertEqual(try path.appending("absolute").readSymbolicLink(), path)

      XCTAssertThrowsError(try path.readSymbolicLink()) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try path.appending("missing").readSymbolicLink()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        XCTAssertEqual(try FilePath("link").readSymbolicLink(relativeTo: dir), "target")
        XCTAssertEqual(
          try "long".withCString { try FilePath.readSymbolicLink($0, relativeTo: dir) },
          long)
        XCTAssertThrowsError(try FilePath("missing").readSymbolicLink(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }

  @available(System 199, *)
  func testResize() throws {
    try withTemporaryFilePath(basename: "testResize") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)

        try file.resize(to: 6)
        XCTAssertEqual(try fd.stat().size, 6)
        let extended = try Array<UInt8>(unsafeUninitializedCapacity: 8) { buf, count in
          count = try fd.read(fromAbsoluteOffset: 0, into: UnsafeMutableRawBufferPointer(buf))
        }
        XCTAssertEqual(extended, Array("abc".utf8) + [0, 0, 0])

        try file.withCString { try FilePath.resize($0, to: 2) }
        XCTAssertEqual(try fd.stat().size, 2)
        let truncated = try Array<UInt8>(unsafeUninitializedCapacity: 8) { buf, count in
          count = try fd.read(fromAbsoluteOffset: 0, into: UnsafeMutableRawBufferPointer(buf))
        }
        XCTAssertEqual(truncated, Array("ab".utf8))
      }

      XCTAssertThrowsError(try path.appending("missing").resize(to: 0)) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      XCTAssertThrowsError(try path.resize(to: 0)) {
        XCTAssertEqual($0 as? Errno, .isDirectory)
      }
    }
  }

  #if !os(WASI)
  @available(System 199, *)
  func testSetPermissions() throws {
    try withTemporaryFilePath(basename: "testSetPermissions") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()

      try file.setPermissions([.ownerRead, .groupRead])
      XCTAssertEqual(try file.stat().permissions, [.ownerRead, .groupRead])

      try file.withCString { try FilePath.setPermissions($0, .ownerReadWrite) }
      XCTAssertEqual(try file.stat().permissions, .ownerReadWrite)

      // By default, a symbolic link's target changes.
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "file")
      let linkPermissions = try link.stat(followTargetSymlink: false).permissions
      try link.setPermissions([.ownerReadWrite, .groupRead])
      XCTAssertEqual(try file.stat().permissions, [.ownerReadWrite, .groupRead])
      XCTAssertEqual(try link.stat(followTargetSymlink: false).permissions, linkPermissions)

      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
      // Only some platforms can change a symbolic link's own permissions.
      try link.setPermissions(.ownerReadWriteExecute, followTargetSymlink: false)
      XCTAssertEqual(
        try link.stat(followTargetSymlink: false).permissions, .ownerReadWriteExecute)
      XCTAssertEqual(try file.stat().permissions, [.ownerReadWrite, .groupRead])
      #endif

      XCTAssertThrowsError(try path.appending("missing").setPermissions(.ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("file").setPermissions(.ownerRead, relativeTo: dir)
        XCTAssertEqual(try file.stat().permissions, .ownerRead)

        try "link".withCString {
          try FilePath.setPermissions($0, .ownerReadWrite, relativeTo: dir)
        }
        XCTAssertEqual(try file.stat().permissions, .ownerReadWrite)

        #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
        try FilePath("link").setPermissions(
          .ownerRead, relativeTo: dir, flags: .symlinkNoFollow)
        XCTAssertEqual(try link.stat(followTargetSymlink: false).permissions, .ownerRead)
        XCTAssertEqual(try file.stat().permissions, .ownerReadWrite)
        #endif

        XCTAssertThrowsError(
          try FilePath("missing").setPermissions(.ownerRead, relativeTo: dir)
        ) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }

  @available(System 199, *)
  func testSetOwner() throws {
    try withTemporaryFilePath(basename: "testSetOwner") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "file")
      let original = try file.stat()

      // The owner can always pass the file's current IDs, or nil.
      try file.setOwner()
      try file.setOwner(user: original.userID, group: original.groupID)
      try link.setOwner(
        user: original.userID, group: original.groupID, followTargetSymlink: false)
      try file.withCString {
        try FilePath.setOwner($0, user: original.userID, group: original.groupID)
      }
      XCTAssertEqual(try file.stat().userID, original.userID)
      XCTAssertEqual(try file.stat().groupID, original.groupID)

      // The owner can change the group to another group they belong to.
      let count = getgroups(0, nil)
      var groups = [gid_t](repeating: 0, count: Int(max(count, 0)))
      let filled = Int(max(getgroups(count, &groups), 0))
      let other = groups.prefix(filled).first { $0 != original.groupID.rawValue }
      if let other {
        // By default, a symbolic link's target changes.
        try link.setOwner(group: GroupID(other))
        XCTAssertEqual(try file.stat().groupID, GroupID(other))
        XCTAssertEqual(try file.stat().userID, original.userID)
        try file.setOwner(group: original.groupID)
      }

      // Only a privileged process can give the file to another user.
      if geteuid() != 0 {
        XCTAssertThrowsError(try file.setOwner(user: UserID(0))) {
          XCTAssertEqual($0 as? Errno, .notPermitted)
        }
      }
      XCTAssertThrowsError(try path.appending("missing").setOwner()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("file").setOwner(relativeTo: dir, group: original.groupID)
        try "link".withCString {
          try FilePath.setOwner(
            $0, relativeTo: dir, user: original.userID, flags: .symlinkNoFollow)
        }
        if let other {
          try FilePath("link").setOwner(relativeTo: dir, group: GroupID(other))
          XCTAssertEqual(try file.stat().groupID, GroupID(other))
        }
        XCTAssertThrowsError(try FilePath("missing").setOwner(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }
  #endif // !os(WASI)
}

#endif // !os(Windows)
