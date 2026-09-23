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

final class FileTimesTest: XCTestCase {
  #if ENABLE_MOCKING && !os(WASI) // Would need to use _getConst funcs from CSystem
  @available(System 199, *)
  func testSyscalls() {
    let fd = FileDescriptor(rawValue: 1)
    let dir = FileDescriptor(rawValue: 42)
    let path: FilePath = "a path"
    let access = timespec(tv_sec: 1, tv_nsec: 2)
    let modification = timespec(tv_sec: 3, tv_nsec: 4)
    let now = Int(UTIME_NOW)
    let omit = Int(UTIME_OMIT)

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "futimens", .interruptable, 1, 1, 2, 3, 4) { retryOnInterrupt in
        try fd.setTimes(
          access: access, modification: modification, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "futimens", .interruptable, 1, 0, omit, 3, 4) { retryOnInterrupt in
        try fd.setTimes(
          access: nil, modification: modification, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "futimens", .interruptable, 1, 0, now, 0, now) { retryOnInterrupt in
        try fd.setTimesToNow(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "futimens", .interruptable, 1, 0, now, 0, omit) {
        retryOnInterrupt in
        try fd.setTimesToNow(modification: false, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "utimensat", .interruptable, AT_FDCWD, "a path", 1, 2, 0, omit, 0
      ) { retryOnInterrupt in
        try path.setTimes(access: access, modification: nil, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "utimensat", .interruptable,
        AT_FDCWD, "a path", 1, 2, 3, 4, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setTimes(
            $0, access: access, modification: modification, followTargetSymlink: false,
            retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "utimensat", .interruptable, 42, "a path", 1, 2, 3, 4, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try path.setTimes(
          relativeTo: dir, access: access, modification: modification,
          flags: .symlinkNoFollow, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "utimensat", .interruptable, 42, "a path", 0, omit, 3, 4, 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setTimes(
            $0, relativeTo: dir, access: nil, modification: modification,
            retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "utimensat", .interruptable, AT_FDCWD, "a path", 0, now, 0, now, 0
      ) { retryOnInterrupt in
        try path.setTimesToNow(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "utimensat", .interruptable,
        AT_FDCWD, "a path", 0, omit, 0, now, AT_SYMLINK_NOFOLLOW
      ) { retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setTimesToNow(
            $0, access: false, followTargetSymlink: false, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "utimensat", .interruptable, 42, "a path", 0, now, 0, omit, 0) {
        retryOnInterrupt in
        try path.setTimesToNow(
          relativeTo: dir, modification: false, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "utimensat", .interruptable, 42, "a path", 0, now, 0, now, 0) {
        retryOnInterrupt in
        try "a path".withCString {
          try FilePath.setTimesToNow(
            $0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]

    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  @available(System 199, *)
  func testSetTimes() throws {
    func equal(_ a: timespec, _ b: timespec) -> Bool {
      a.tv_sec == b.tv_sec && a.tv_nsec == b.tv_nsec
    }
    let access = timespec(tv_sec: 1_000_000_000, tv_nsec: 123_000)
    let modification = timespec(tv_sec: 1_500_000_000, tv_nsec: 456_000)

    try withTemporaryFilePath(basename: "testSetTimes") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.setTimes(access: access, modification: modification)
        XCTAssertTrue(equal(try fd.stat().st_atim, access))
        XCTAssertTrue(equal(try fd.stat().st_mtim, modification))

        // A nil time is left unchanged, and "now" is at least the start.
        let start = try fd.stat().st_ctim.tv_sec
        try fd.setTimes(access: nil, modification: access)
        XCTAssertTrue(equal(try fd.stat().st_atim, access))
        XCTAssertTrue(equal(try fd.stat().st_mtim, access))
        try fd.setTimesToNow(access: false)
        XCTAssertTrue(equal(try fd.stat().st_atim, access))
        XCTAssertGreaterThanOrEqual(try fd.stat().st_mtim.tv_sec, start)
        try fd.setTimesToNow()
        XCTAssertGreaterThanOrEqual(try fd.stat().st_atim.tv_sec, start)
      }

      try file.setTimes(access: modification, modification: access)
      XCTAssertTrue(equal(try file.stat().st_atim, modification))
      XCTAssertTrue(equal(try file.stat().st_mtim, access))
      try file.withCString { try FilePath.setTimes($0, access: access, modification: nil) }
      XCTAssertTrue(equal(try file.stat().st_atim, access))
      XCTAssertTrue(equal(try file.stat().st_mtim, access))

      // A symbolic link's target changes by default.
      let link = path.appending("link")
      try link.makeSymbolicLink(to: "file")
      try link.setTimes(access: nil, modification: modification)
      XCTAssertTrue(equal(try file.stat().st_mtim, modification))
      try link.setTimes(access: nil, modification: access, followTargetSymlink: false)
      XCTAssertTrue(equal(try link.stat(followTargetSymlink: false).st_mtim, access))
      XCTAssertTrue(equal(try file.stat().st_mtim, modification))

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        try FilePath("file").setTimes(relativeTo: dir, access: nil, modification: access)
        XCTAssertTrue(equal(try file.stat().st_mtim, access))
        try "link".withCString {
          try FilePath.setTimes(
            $0, relativeTo: dir, access: nil, modification: modification,
            flags: .symlinkNoFollow)
        }
        XCTAssertTrue(equal(try link.stat(followTargetSymlink: false).st_mtim, modification))
        XCTAssertTrue(equal(try file.stat().st_mtim, access))

        let start = try file.stat().st_ctim.tv_sec
        try FilePath("file").setTimesToNow(relativeTo: dir, access: false)
        XCTAssertTrue(equal(try file.stat().st_atim, access))
        XCTAssertGreaterThanOrEqual(try file.stat().st_mtim.tv_sec, start)
        try "file".withCString { try FilePath.setTimesToNow($0, relativeTo: dir) }
        XCTAssertGreaterThanOrEqual(try file.stat().st_atim.tv_sec, start)

        XCTAssertThrowsError(try FilePath("missing").setTimesToNow(relativeTo: dir)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }

      try file.setTimes(access: access, modification: access)
      try file.withCString { try FilePath.setTimesToNow($0, modification: false) }
      XCTAssertTrue(equal(try file.stat().st_mtim, access))
      try file.setTimesToNow()
      XCTAssertGreaterThan(try file.stat().st_mtim.tv_sec, access.tv_sec)
      XCTAssertThrowsError(try path.appending("missing").setTimesToNow()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
    }
  }
}

#endif // !os(Windows)
