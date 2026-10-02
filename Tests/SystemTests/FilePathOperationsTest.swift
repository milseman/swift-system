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

      MockTestCase(
        name: "readlink", .interruptable,
        "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try path.readSymbolicLinkPlatformString(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "readlink", .interruptable,
        "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.readSymbolicLinkPlatformString($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "readlinkat", .interruptable,
        42, "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try path.readSymbolicLinkPlatformString(
          relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "readlinkat", .interruptable,
        42, "a path", Wildcard(), FilePath._initialSymbolicLinkCapacity
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.readSymbolicLinkPlatformString(
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

      MockTestCase(name: "access", .interruptable, "a path", R_OK | W_OK) {
        retryOnInterrupt in
        try path.checkAccess([.read, .write], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "access", .interruptable, "a path", F_OK) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.checkAccess($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "faccessat", .interruptable,
        42, "a path", X_OK, AT_EACCESS | AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try path.checkAccess(
          .execute, relativeTo: dir, flags: .symlinkNoFollow, useEffectiveIDs: true,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "faccessat", .interruptable, 42, "a path", R_OK, 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.checkAccess(
            $0, .read, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "getcwd", .noInterrupt, Wildcard(), FilePath._initialWorkingDirectoryCapacity
      ) { _ in
        _ = try FilePath.currentWorkingDirectory()
      },

      MockTestCase(name: "chdir", .interruptable, "a path") { retryOnInterrupt in
        try FilePath.setCurrentWorkingDirectory(path, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "chdir", .interruptable, "a path") { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setCurrentWorkingDirectory($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "fchdir", .interruptable, 42) { retryOnInterrupt in
        try FilePath.setCurrentWorkingDirectory(dir, retryOnInterrupt: retryOnInterrupt)
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

    let mkfifo = [
      MockTestCase(name: "mkfifo", .interruptable, "a path", 0o600) { retryOnInterrupt in
        try path.makeFIFO(permissions: .ownerReadWrite, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "mkfifo", .interruptable, "a path", 0o600) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.makeFIFO(
            $0, permissions: .ownerReadWrite, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    for test in mkfifo { test.runAllTests() }

    if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
      let mkfifoat = [
        MockTestCase(name: "mkfifoat", .interruptable, 42, "a path", 0o600) {
          retryOnInterrupt in
          try path.makeFIFO(
            relativeTo: dir, permissions: .ownerReadWrite,
            retryOnInterrupt: retryOnInterrupt)
        },

        MockTestCase(name: "mkfifoat", .interruptable, 42, "a path", 0o600) {
          retryOnInterrupt in
          try "a path".withCString {
            try FilePath.makeFIFO(
              $0, relativeTo: dir, permissions: .ownerReadWrite,
              retryOnInterrupt: retryOnInterrupt)
          }
        },
      ]
      for test in mkfifoat { test.runAllTests() }
    }

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

    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    let fileFlags = UInt32(bitPattern: UF_NODUMP | UF_APPEND)
    var fileFlagsTestCases: Array<MockTestCase> = [
      MockTestCase(name: "chflags", .interruptable, "a path", fileFlags) {
        retryOnInterrupt in
        try path.setFileFlags([.noDump, .userAppend], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "chflags", .interruptable, "a path", fileFlags) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setFileFlags(
            $0, [.noDump, .userAppend], retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "lchflags", .interruptable, "a path", fileFlags) {
        retryOnInterrupt in
        try path.setFileFlags(
          [.noDump, .userAppend], followTargetSymlink: false,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "lchflags", .interruptable, "a path", fileFlags) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setFileFlags(
            $0, [.noDump, .userAppend], followTargetSymlink: false,
            retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    #if os(FreeBSD) || os(OpenBSD)
    fileFlagsTestCases += [
      MockTestCase(
        name: "chflagsat", .interruptable, 42, "a path", fileFlags, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try path.setFileFlags(
          [.noDump, .userAppend], relativeTo: dir, flags: .symlinkNoFollow,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "chflagsat", .interruptable, 42, "a path", fileFlags, 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setFileFlags(
            $0, [.noDump, .userAppend], relativeTo: dir,
            retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    #endif // os(FreeBSD) || os(OpenBSD)

    for test in fileFlagsTestCases { test.runAllTests() }
    #endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
    let other = FileDescriptor(rawValue: 43)
    #if SYSTEM_PACKAGE_DARWIN
    let renameTestCases: Array<MockTestCase> = [
      MockTestCase(
        name: "renamex_np", .interruptable, "a path", "new path", UInt32(RENAME_EXCL)
      ) { retryOnInterrupt in
        try path.rename(to: "new path", options: .exclusive, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "renamex_np", .interruptable, "a path", "new path", UInt32(RENAME_SWAP)
      ) { retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(
              old, to: new, options: .swap, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(
        name: "renameatx_np", .interruptable,
        42, "a path", 43, "new path", UInt32(RENAME_EXCL | RENAME_SWAP)
      ) { retryOnInterrupt in
        try path.rename(
          relativeTo: dir, to: "new path", relativeTo: other, options: [.exclusive, .swap],
          retryOnInterrupt: retryOnInterrupt)
      },
    ]
    #else
    let renameTestCases: Array<MockTestCase> = [
      // The kernel's RENAME_NOREPLACE and RENAME_EXCHANGE.
      MockTestCase(
        name: "renameat2", .interruptable, AT_FDCWD, "a path", AT_FDCWD, "new path",
        UInt32(1 << 0)
      ) { retryOnInterrupt in
        try path.rename(to: "new path", options: .exclusive, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "renameat2", .interruptable, 42, "a path", 43, "new path",
        UInt32(1 << 1)
      ) { retryOnInterrupt in
        try "a path".withCString { old in
          try "new path".withCString { new in
            try FilePath.rename(
              old, relativeTo: dir, to: new, relativeTo: other, options: .swap,
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      },
    ]
    #endif
    for test in renameTestCases { test.runAllTests() }
    #endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
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
    #if SYSTEM_PACKAGE_DARWIN && canImport(Darwin, _version: 346) || os(FreeBSD)
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

        #if SYSTEM_PACKAGE_DARWIN && canImport(Darwin, _version: 346) || os(FreeBSD)
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

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
  @available(System 199, *)
  func testRenameWithOptions() throws {
    try withTemporaryFilePath(basename: "testRenameWithOptions") { path in
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

      try write("a", to: "a")
      try write("b", to: "b")
      do {
        try path.appending("a").rename(to: path.appending("c"), options: .exclusive)
      } catch Errno.invalidArgument {
        throw XCTSkip("The file system doesn't support exclusive renames")
      }
      XCTAssertEqual(try contents(of: "c"), "a")

      // An exclusive rename doesn't replace an existing file.
      XCTAssertThrowsError(
        try path.appending("c").rename(to: path.appending("b"), options: .exclusive)
      ) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertEqual(try contents(of: "b"), "b")

      // A swap exchanges two files, which must both exist.
      try path.appending("c").withCString { old in
        try path.appending("b").withCString { new in
          try FilePath.rename(old, to: new, options: .swap)
        }
      }
      XCTAssertEqual(try contents(of: "c"), "b")
      XCTAssertEqual(try contents(of: "b"), "a")
      XCTAssertThrowsError(
        try path.appending("c").rename(to: path.appending("missing"), options: .swap)
      ) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("b").rename(relativeTo: dir, to: "c", relativeTo: dir, options: .swap)
        XCTAssertEqual(try contents(of: "c"), "a")
        XCTAssertEqual(try contents(of: "b"), "b")

        try "c".withCString { old in
          try "d".withCString { new in
            try FilePath.rename(
              old, relativeTo: dir, to: new, relativeTo: dir, options: .exclusive)
          }
        }
        XCTAssertEqual(try contents(of: "d"), "a")
        XCTAssertThrowsError(
          try FilePath("d").rename(
            relativeTo: dir, to: "b", relativeTo: dir, options: .exclusive)
        ) {
          XCTAssertEqual($0 as? Errno, .fileExists)
        }
      }
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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

  /// The contents, unlike the FilePath, keep the stored target's redundant
  /// and trailing separators, so a copy made with them is the same link.
  @available(System 199, *)
  func testReadSymbolicLinkPlatformString() throws {
    try withTemporaryFilePath(basename: "testReadSymbolicLinkPlatformString") { path in
      // A FilePath target would be "a/b" already.
      let link = path.appending("link")
      try link.withCString { try FilePath.makeSymbolicLink($0, to: "a//b/") }
      XCTAssertEqual(try link.readSymbolicLink(), "a/b")
      let contents = try link.readSymbolicLinkPlatformString()
      XCTAssertEqual(contents, Array("a//b/".utf8CString))
      XCTAssertEqual(try link.withCString { try FilePath.readSymbolicLinkPlatformString($0) }, contents)
      XCTAssertEqual(FilePath(platformString: contents), try link.readSymbolicLink())

      let copy = path.appending("copy")
      try copy.withCString { try FilePath.makeSymbolicLink($0, to: contents) }
      XCTAssertEqual(try copy.readSymbolicLinkPlatformString(), contents)

      // A target longer than the first buffer is read in full.
      let long = repeatElement("component", count: 60).joined(separator: "//")
      XCTAssertGreaterThan(long.utf8.count, FilePath._initialSymbolicLinkCapacity)
      try long.withCString { target in
        try path.appending("long").withCString { try FilePath.makeSymbolicLink($0, to: target) }
      }
      XCTAssertEqual(
        try path.appending("long").readSymbolicLinkPlatformString(), Array(long.utf8CString))

      XCTAssertThrowsError(try path.readSymbolicLinkPlatformString()) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try path.appending("missing").readSymbolicLinkPlatformString()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        XCTAssertEqual(
          try FilePath("link").readSymbolicLinkPlatformString(relativeTo: dir), contents)
        XCTAssertEqual(
          try "long".withCString {
            try FilePath.readSymbolicLinkPlatformString($0, relativeTo: dir)
          },
          Array(long.utf8CString))
        XCTAssertThrowsError(
          try FilePath("missing").readSymbolicLinkPlatformString(relativeTo: dir)
        ) {
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

  @available(System 199, *)
  func testCheckAccess() throws {
    XCTAssertEqual(FilePath.Access.read.rawValue, R_OK)
    XCTAssertEqual(FilePath.Access.write.rawValue, W_OK)
    XCTAssertEqual(FilePath.Access.execute.rawValue, X_OK)
    XCTAssertEqual(FilePath.Access().rawValue, F_OK)

    try withTemporaryFilePath(basename: "testCheckAccess") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()

      try file.checkAccess()
      try file.checkAccess(.read)
      try file.withCString { try FilePath.checkAccess($0, [.read, .write]) }
      try path.checkAccess([.read, .write, .execute])
      XCTAssertThrowsError(try path.appending("missing").checkAccess()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      #if !os(WASI) // WASI has no permissions
      // Even root needs an execute bit to execute a file.
      XCTAssertThrowsError(try file.checkAccess(.execute)) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
      #endif

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("file").checkAccess(relativeTo: dir)
        try FilePath("file").checkAccess(
          [.read, .write], relativeTo: dir, useEffectiveIDs: true)
        try "file".withCString {
          try FilePath.checkAccess($0, .read, relativeTo: dir)
        }
        XCTAssertThrowsError(try FilePath("missing").checkAccess(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }

        // A dangling symbolic link exists only if it isn't followed.
        try path.appending("dangling").makeSymbolicLink(to: "missing")
        XCTAssertThrowsError(try FilePath("dangling").checkAccess(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
        #if SYSTEM_PACKAGE_DARWIN
        try FilePath("dangling").checkAccess(relativeTo: dir, flags: .symlinkNoFollow)
        #endif
      }
    }
  }

  @available(System 199, *)
  func testCurrentWorkingDirectory() throws {
    let original = try FilePath.currentWorkingDirectory()
    XCTAssertTrue(original.isAbsolute)
    defer { try? FilePath.setCurrentWorkingDirectory(original) }

    // Compare by identity, since the path may differ through symbolic links,
    // such as /var and /private/var on Darwin.
    func isCurrent(_ path: FilePath) throws -> Bool {
      let current = try FilePath.currentWorkingDirectory().stat()
      let expected = try path.stat()
      return current.deviceID == expected.deviceID && current.inode == expected.inode
    }

    try withTemporaryFilePath(basename: "testCurrentWorkingDirectory") { path in
      try FilePath.setCurrentWorkingDirectory(path)
      XCTAssertTrue(try isCurrent(path))
      // Relative paths now resolve against it.
      try FilePath("sub").makeDirectory(permissions: .ownerReadWriteExecute)
      XCTAssertEqual(try path.appending("sub").stat().type, .directory)

      try path.appending("sub").withCString { try FilePath.setCurrentWorkingDirectory($0) }
      XCTAssertTrue(try isCurrent(path.appending("sub")))

      #if !os(WASI) // WASI has no fchdir
      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath.setCurrentWorkingDirectory(dir)
        XCTAssertTrue(try isCurrent(path))
      }
      #endif

      XCTAssertThrowsError(try FilePath.setCurrentWorkingDirectory(path.appending("missing"))) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      try FilePath.setCurrentWorkingDirectory(original)
    }
    XCTAssertEqual(try FilePath.currentWorkingDirectory(), original)
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

  @available(System 199, *)
  func testMakeFIFO() throws {
    try withTemporaryFilePath(basename: "testMakeFIFO") { path in
      let fifo = path.appending("fifo")
      try fifo.makeFIFO(permissions: .ownerReadWrite)
      XCTAssertEqual(try fifo.stat().type, .fifo)
      XCTAssertEqual(try fifo.stat().permissions, .ownerReadWrite)
      XCTAssertThrowsError(try fifo.makeFIFO(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }

      try path.appending("c string").withCString {
        try FilePath.makeFIFO($0, permissions: .ownerRead)
      }
      XCTAssertEqual(try path.appending("c string").stat().type, .fifo)
      XCTAssertEqual(try path.appending("c string").stat().permissions, .ownerRead)

      guard #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) else {
        throw XCTSkip("mkfifoat requires macOS 13 or newer")
      }
      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("relative").makeFIFO(relativeTo: dir, permissions: .ownerReadWrite)
        XCTAssertEqual(try path.appending("relative").stat().type, .fifo)

        try "relative c string".withCString {
          try FilePath.makeFIFO($0, relativeTo: dir, permissions: .ownerReadWrite)
        }
        XCTAssertEqual(try path.appending("relative c string").stat().type, .fifo)

        XCTAssertThrowsError(
          try FilePath("missing/fifo").makeFIFO(relativeTo: dir, permissions: .ownerRead)
        ) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }
  #endif // !os(WASI)

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  @available(System 199, *)
  func testSetFileFlags() throws {
    try withTemporaryFilePath(basename: "testSetFileFlags") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      let original = try file.stat().flags
      XCTAssertFalse(original.contains(.noDump))

      try file.setFileFlags(original.union(.noDump))
      XCTAssertEqual(try file.stat().flags, original.union(.noDump))
      try file.withCString { try FilePath.setFileFlags($0, original) }
      XCTAssertEqual(try file.stat().flags, original)

      #if SYSTEM_PACKAGE_DARWIN
      // By default, a symbolic link's target changes.
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "file")
      let linkOriginal = try link.stat(followTargetSymlink: false).flags
      try link.setFileFlags(original.union(.noDump))
      XCTAssertEqual(try file.stat().flags, original.union(.noDump))
      XCTAssertEqual(try link.stat(followTargetSymlink: false).flags, linkOriginal)

      try link.setFileFlags(linkOriginal.union(.hidden), followTargetSymlink: false)
      XCTAssertEqual(
        try link.stat(followTargetSymlink: false).flags, linkOriginal.union(.hidden))
      XCTAssertEqual(try file.stat().flags, original.union(.noDump))
      try file.setFileFlags(original)
      #endif

      XCTAssertThrowsError(try path.appending("missing").setFileFlags(original)) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      #if os(FreeBSD) || os(OpenBSD)
      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("file").setFileFlags(original.union(.noDump), relativeTo: dir)
        XCTAssertEqual(try file.stat().flags, original.union(.noDump))
        try "file".withCString { try FilePath.setFileFlags($0, original, relativeTo: dir) }
        XCTAssertEqual(try file.stat().flags, original)
      }
      #endif
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
}

#endif // !os(Windows)
