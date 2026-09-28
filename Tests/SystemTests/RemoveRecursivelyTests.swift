/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class RemoveRecursivelyTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let recursive = _REMOVEFILE_RECURSIVE
    let keep = _REMOVEFILE_RECURSIVE | _REMOVEFILE_KEEP_PARENT
    let dir = FileDescriptor(rawValue: 42)

    // A removal doesn't retry: it throws, and calling it again removes
    // what's left.
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "removefile", .noInterrupt, "a path", false, recursive) { _ in
        try FilePath("a path").removeRecursively()
      },

      MockTestCase(name: "removefile", .noInterrupt, "a path", false, keep) { _ in
        try "a path".withCString { try FilePath.removeRecursively($0, options: .keepDirectory) }
      },

      MockTestCase(name: "removefile", .noInterrupt, "a path", true, recursive) { _ in
        try FilePath("a path").removeRecursively { _ in .proceed }
      },

      MockTestCase(name: "removefile", .noInterrupt, "a path", true, keep) { _ in
        try "a path".withCString {
          try FilePath.removeRecursively($0, options: .keepDirectory) { _ in .proceed }
        }
      },

      MockTestCase(name: "removefileat", .noInterrupt, 42, "a path", false, recursive) { _ in
        try FilePath("a path").removeRecursively(relativeTo: dir)
      },

      MockTestCase(name: "removefileat", .noInterrupt, 42, "a path", false, keep) { _ in
        try "a path".withCString {
          try FilePath.removeRecursively($0, relativeTo: dir, options: .keepDirectory)
        }
      },

      MockTestCase(name: "removefileat", .noInterrupt, 42, "a path", true, recursive) { _ in
        try FilePath("a path").removeRecursively(relativeTo: dir) { _ in .proceed }
      },

      MockTestCase(name: "removefileat", .noInterrupt, 42, "a path", true, recursive) { _ in
        try "a path".withCString {
          try FilePath.removeRecursively($0, relativeTo: dir) { _ in .proceed }
        }
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  /// A directory with two files and a subdirectory holding a third.
  private func makeTree(_ root: FilePath) throws {
    try root.makeDirectory(permissions: .ownerReadWriteExecute)
    try root.appending("d").makeDirectory(permissions: .ownerReadWriteExecute)
    for file in ["a", "b", "d/c"] {
      try FileDescriptor.open(
        root.appending(file), .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
    }
  }

  private func exists(_ path: FilePath) -> Bool {
    (try? path.stat(followTargetSymlink: false)) != nil
  }

  func testRemovesAHierarchy() throws {
    try withTemporaryFilePath(basename: "testRemovesAHierarchy") { temporary in
      let root = temporary.appending("tree")
      try makeTree(root)
      try root.removeRecursively()
      XCTAssertFalse(exists(root))

      // A file, and the C-string form.
      let file = temporary.appending("file")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      try file.withPlatformString { try FilePath.removeRecursively($0) }
      XCTAssertFalse(exists(file))
    }
  }

  func testKeepDirectory() throws {
    try withTemporaryFilePath(basename: "testKeepDirectory") { temporary in
      let root = temporary.appending("tree")
      try makeTree(root)
      try root.removeRecursively(options: .keepDirectory)
      XCTAssertTrue(exists(root))
      for name in ["a", "b", "d"] { XCTAssertFalse(exists(root.appending(name))) }
    }
  }

  func testRemovesALinkNotItsTarget() throws {
    try withTemporaryFilePath(basename: "testRemovesALinkNotItsTarget") { temporary in
      let target = temporary.appending("target")
      try makeTree(target)
      let link = temporary.appending("link")
      try link.makeSymbolicLink(to: target)
      try link.removeRecursively()
      XCTAssertFalse(exists(link))
      XCTAssertTrue(exists(target.appending("d/c")))
    }
  }

  func testRelativeToADirectory() throws {
    try withTemporaryFilePath(basename: "testRelativeToADirectory") { temporary in
      try makeTree(temporary.appending("one"))
      try makeTree(temporary.appending("two"))
      let dir = try FileDescriptor.open(temporary, .readOnly)
      defer { try? dir.close() }
      try FilePath("one").removeRecursively(relativeTo: dir)
      try "two".withCString { try FilePath.removeRecursively($0, relativeTo: dir) }
      XCTAssertFalse(exists(temporary.appending("one")))
      XCTAssertFalse(exists(temporary.appending("two")))
      XCTAssertThrowsError(try FilePath("three").removeRecursively(relativeTo: FileDescriptor(rawValue: -1))) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
    }
  }

  func testAMissingPathThrows() throws {
    try withTemporaryFilePath(basename: "testAMissingPathThrows") { temporary in
      XCTAssertThrowsError(try temporary.appending("missing").removeRecursively()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
    }
  }

  /// Each file starts before it finishes, a directory starts before and
  /// finishes after what's in it, and the path given finishes last.
  func testProgressOrder() throws {
    try withTemporaryFilePath(basename: "testProgressOrder") { temporary in
      let root = temporary.appending("tree")
      try makeTree(root)
      // The removal reports real paths: the temporary directory is in /var,
      // which is a link to /private/var.
      let real = try root.canonicalized()
      XCTAssertNotEqual(real, root)
      var events: [(FilePath.RemoveProgress.Stage, String)] = []
      try root.removeRecursively { progress in
        XCTAssertTrue(progress.path.starts(with: real), "\(progress.path)")
        let relative = progress.path == real ? "." : String(progress.path.string.dropFirst(real.string.count + 1))
        events.append((progress.stage, relative))
        XCTAssertNil(progress.error)
        return .proceed
      }
      XCTAssertFalse(exists(root))
      func index(_ stage: FilePath.RemoveProgress.Stage, _ name: String) -> Int {
        events.firstIndex { $0.0 == stage && $0.1 == name } ?? -1
      }
      XCTAssertEqual(events.count, 10)
      XCTAssertEqual(index(.start, "."), 0)
      XCTAssertEqual(index(.finish, "."), events.count - 1)
      for name in [".", "a", "b", "d", "d/c"] {
        XCTAssertGreaterThanOrEqual(index(.start, name), 0, name)
        XCTAssertLessThan(index(.start, name), index(.finish, name), name)
      }
      XCTAssertLessThan(index(.start, "d"), index(.start, "d/c"))
      XCTAssertLessThan(index(.finish, "d/c"), index(.finish, "d"))
    }
  }

  /// Skipping a file leaves it, and the directory that holds it then can't
  /// be removed; proceeding past that error ignores it.
  func testSkippingAFile() throws {
    try withTemporaryFilePath(basename: "testSkippingAFile") { temporary in
      let root = temporary.appending("tree")
      try makeTree(root)
      var errors: [(FilePath, Errno?)] = []
      try root.removeRecursively { progress in
        if progress.stage == .error { errors.append((progress.path, progress.error)) }
        return progress.stage == .start && progress.path.lastComponent == "b" ? .skip : .proceed
      }
      XCTAssertTrue(exists(root.appending("b")))
      XCTAssertFalse(exists(root.appending("a")))
      XCTAssertFalse(exists(root.appending("d")))
      XCTAssertEqual(errors.map(\.0), [try root.canonicalized()])
      XCTAssertEqual(errors.map(\.1), [.directoryNotEmpty])
    }
  }

  func testStoppingThrowsCanceled() throws {
    try withTemporaryFilePath(basename: "testStoppingThrowsCanceled") { temporary in
      let root = temporary.appending("tree")
      try makeTree(root)
      XCTAssertThrowsError(
        try root.removeRecursively { $0.stage == .start && $0.path.lastComponent == "d" ? .stop : .proceed }
      ) { XCTAssertEqual($0 as? Errno, .canceled) }
      XCTAssertTrue(exists(root.appending("d/c")))
    }
  }

  /// A directory the removal can't write to holds a file it can't remove.
  func testErrors() throws {
    try withTemporaryFilePath(basename: "testErrors") { temporary in
      for stop in [true, false] {
        let root = temporary.appending(stop ? "stopped" : "proceeded")
        try makeTree(root)
        let locked = root.appending("d")
        try locked.setPermissions(.ownerReadExecute)
        defer { try? locked.setPermissions(.ownerReadWriteExecute) }
        var errors: [(String, Errno?)] = []
        let remove = {
          try root.removeRecursively { progress in
            guard progress.stage == .error else { return .proceed }
            errors.append((progress.path.lastComponent?.string ?? "", progress.error))
            return stop ? .stop : .proceed
          }
        }
        if stop {
          // Stopping at an error throws it.
          XCTAssertThrowsError(try remove()) { XCTAssertEqual($0 as? Errno, .permissionDenied) }
          XCTAssertEqual(errors.map(\.0), ["c"])
        } else {
          // Proceeding ignores every error: c, then d and the root, which
          // aren't empty.
          XCTAssertNoThrow(try remove())
          XCTAssertEqual(errors.map(\.0), ["c", "d", root.lastComponent!.string])
          XCTAssertEqual(errors.map(\.1), [.permissionDenied, .directoryNotEmpty, .directoryNotEmpty])
        }
        XCTAssertTrue(exists(locked.appending("c")))
        // Without a handler, the first error ends the removal.
        XCTAssertThrowsError(try root.removeRecursively()) {
          XCTAssertEqual($0 as? Errno, .permissionDenied)
        }
      }
    }
  }

  func testDescriptions() {
    XCTAssertEqual(FilePath.RemoveProgress.Stage.start.description, "start")
    XCTAssertEqual(FilePath.RemoveProgress.Stage.error.description, "error")
    XCTAssertEqual(FilePath.RemoveProgress.Action.skip.description, "skip")
    XCTAssertEqual(
      FilePath.RemoveOptions([.keepDirectory, .crossMountPoints]).description,
      "[.keepDirectory, .crossMountPoints]")
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
