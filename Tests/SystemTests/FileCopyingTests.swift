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
final class FileCopyingTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let source: FilePath = "a source"
    let destination: FilePath = "a destination"
    let fd = FileDescriptor(rawValue: 42)
    let dir = FileDescriptor(rawValue: 43)
    let all = UInt32(COPYFILE_ALL)
    let check = UInt32(COPYFILE_CHECK | COPYFILE_METADATA)
    let noFollow = UInt32(CLONE_NOFOLLOW)

    // Copies don't retry, since an interrupted copy may have written part
    // of the destination.
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), false, all
      ) { _ in
        try source.copy(to: destination, options: .all)
      },

      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), false, all
      ) { _ in
        try "a source".withCString { source in
          try "a destination".withCString { destination in
            try FilePath.copy(source, to: destination, options: .all)
          }
        }
      },

      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), true, all
      ) { _ in
        var state = FilePath.CopyState()
        try source.copy(to: destination, options: .all, state: &state)
      },

      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), true, all
      ) { _ in
        var state = FilePath.CopyState()
        try source.copy(to: destination, options: .all, state: &state) { _ in .continue }
      },

      MockTestCase(name: "copyfile", .noInterrupt, "a source", Optional<String>.none, false, check) {
        _ in
        _ = try source.contentsToCopy(options: .metadata)
      },

      MockTestCase(name: "copyfile", .noInterrupt, "a source", Optional<String>.none, false, check) {
        _ in
        _ = try "a source".withCString { try FilePath.contentsToCopy($0, options: .metadata) }
      },

      MockTestCase(name: "fcopyfile", .noInterrupt, 42, 43, false, all) { _ in
        try fd.copy(to: dir, options: .all)
      },

      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), true, all
      ) { _ in
        var state = FilePath.CopyState()
        try "a source".withCString { source in
          try "a destination".withCString { destination in
            try FilePath.copy(source, to: destination, options: .all, state: &state)
          }
        }
      },

      MockTestCase(
        name: "copyfile", .noInterrupt, "a source", Optional("a destination"), true, all
      ) { _ in
        var state = FilePath.CopyState()
        try "a source".withCString { source in
          try "a destination".withCString { destination in
            try FilePath.copy(source, to: destination, options: .all, state: &state) {
              _ in .continue
            }
          }
        }
      },

      MockTestCase(name: "fcopyfile", .noInterrupt, 42, 43, true, all) { _ in
        var state = FilePath.CopyState()
        try fd.copy(to: dir, options: .all, state: &state)
      },

      MockTestCase(name: "fcopyfile", .noInterrupt, 42, 43, true, all) { _ in
        var state = FilePath.CopyState()
        try fd.copy(to: dir, options: .all, state: &state) { _ in .continue }
      },

      MockTestCase(name: "clonefile", .interruptable, "a source", "a destination", noFollow) {
        retryOnInterrupt in
        try source.clone(
          to: destination, options: .noFollow, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "clonefile", .interruptable, "a source", "a destination", 0) {
        retryOnInterrupt in
        try "a source".withCString { source in
          try "a destination".withCString { destination in
            try FilePath.clone(source, to: destination, retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(
        name: "clonefileat", .interruptable, 42, "a source", 43, "a destination", noFollow
      ) { retryOnInterrupt in
        try source.clone(
          relativeTo: fd, to: destination, relativeTo: dir, options: .noFollow,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "clonefileat", .interruptable, 42, "a source", 43, "a destination", 0
      ) { retryOnInterrupt in
        try "a source".withCString { source in
          try "a destination".withCString { destination in
            try FilePath.clone(
              source, relativeTo: fd, to: destination, relativeTo: dir,
              retryOnInterrupt: retryOnInterrupt)
          }
        }
      },

      MockTestCase(name: "fclonefileat", .interruptable, 42, AT_FDCWD, "a destination", 0) {
        retryOnInterrupt in
        try fd.clone(to: destination, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fclonefileat", .interruptable, 42, AT_FDCWD, "a destination", 0) {
        retryOnInterrupt in
        try "a destination".withCString {
          try fd.clone(to: $0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "fclonefileat", .interruptable, 42, 43, "a destination", noFollow
      ) { retryOnInterrupt in
        try fd.clone(
          to: destination, relativeTo: dir, options: .noFollow,
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fclonefileat", .interruptable, 42, 43, "a destination", 0) {
        retryOnInterrupt in
        try "a destination".withCString {
          try fd.clone(to: $0, relativeTo: dir, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  func testOptions() {
    XCTAssertEqual(FilePath.CopyOptions.all, [.data, .metadata])
    XCTAssertEqual(FilePath.CopyOptions.metadata, [.security, .extendedAttributes])
    XCTAssertEqual(FilePath.CopyOptions.security, [.stat, .accessControlList])
    XCTAssertEqual(FilePath.CopyOptions.noFollow, [.noFollowSource, .noFollowDestination])
    XCTAssertEqual(FilePath.CopyOptions.all.rawValue, UInt32(COPYFILE_ALL))
    XCTAssertEqual(FilePath.CopyOptions.forceClone.rawValue, UInt32(COPYFILE_CLONE_FORCE))
    XCTAssertEqual("\(FilePath.CopyOptions.all)", "[.all]")
    XCTAssertEqual(
      "\([FilePath.CopyOptions.data, .stat, .clone] as FilePath.CopyOptions)",
      "[.stat, .data, .clone]")
    XCTAssertEqual(
      "\(FilePath.CopyOptions(rawValue: 1 << 29))", "[CopyOptions(rawValue: 536870912)]")

    XCTAssertEqual(FilePath.CloneOptions.noFollow.rawValue, UInt32(CLONE_NOFOLLOW))
    XCTAssertEqual(FilePath.CloneOptions.accessControlList.rawValue, UInt32(CLONE_ACL))
    XCTAssertEqual(
      "\([FilePath.CloneOptions.noFollow, .noOwnerCopy] as FilePath.CloneOptions)",
      "[.noFollow, .noOwnerCopy]")

    XCTAssertEqual("\(FilePath.CopyProgress.Kind.directoryCleanup)", "directoryCleanup")
    XCTAssertEqual("\(FilePath.CopyProgress.Stage.progress)", "progress")
    XCTAssertEqual("\(FilePath.CopyProgress.Action.continue)", "continue")
    XCTAssertEqual("\(FilePath.CopyProgress.Action(rawValue: 9))", "Action(rawValue: 9)")
  }

  func testCopy() throws {
    try withTemporaryFilePath(basename: "testCopy") { path in
      let source = path.appending("source")
      let bytes = (0..<100_000).map { UInt8(truncatingIfNeeded: $0 &* 7) }
      try write(bytes, to: source, permissions: [.ownerReadWrite, .groupRead])

      try source.copy(to: path.appending("plain"), options: .all)
      XCTAssertEqual(try contents(of: path.appending("plain")), bytes)
      XCTAssertEqual(
        try path.appending("plain").stat().permissions, [.ownerReadWrite, .groupRead])

      // Without the POSIX information, the copy gets default permissions.
      try source.copy(to: path.appending("data"), options: .data)
      XCTAssertEqual(try contents(of: path.appending("data")), bytes)

      // A state records whether a copy cloned the file.
      var state = FilePath.CopyState()
      try source.copy(to: path.appending("copied"), options: .all, state: &state)
      XCTAssertFalse(state.wasCloned)
      XCTAssertEqual(state.copiedByteCount, Int64(bytes.count))

      // The file system under the temporary directory, APFS, can clone.
      try source.copy(to: path.appending("cloned"), options: [.all, .clone], state: &state)
      XCTAssertEqual(try contents(of: path.appending("cloned")), bytes)
      if state.wasCloned {
        XCTAssertEqual(state.copiedByteCount, 0)
      }

      // Cloning implies an exclusive copy.
      XCTAssertThrowsError(
        try source.copy(to: path.appending("cloned"), options: [.all, .clone])
      ) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertThrowsError(
        try source.copy(to: path.appending("plain"), options: [.all, .exclusive])
      ) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }

      // Only a recursive copy copies into a directory, keeping the name.
      try path.appending("into").makeDirectory(permissions: .ownerReadWriteExecute)
      XCTAssertThrowsError(try source.copy(to: path.appending("into"), options: .all)) {
        XCTAssertEqual($0 as? Errno, .isDirectory)
      }
      try source.withCString { source in
        try path.appending("into").withCString { into in
          try FilePath.copy(source, to: into, options: [.all, .recursive])
        }
      }
      XCTAssertEqual(try contents(of: path.appending("into/source")), bytes)

      // Moving removes the source.
      try source.copy(to: path.appending("moving"), options: .all)
      try path.appending("moving").copy(to: path.appending("moved"), options: [.all, .move])
      XCTAssertThrowsError(try path.appending("moving").stat()) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      XCTAssertEqual(try contents(of: path.appending("moved")), bytes)

      XCTAssertThrowsError(
        try path.appending("missing").copy(to: path.appending("nowhere"), options: .all)
      ) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
    }
  }

  func testCopySymbolicLinks() throws {
    try withTemporaryFilePath(basename: "testCopySymbolicLinks") { path in
      try write([1, 2, 3], to: path.appending("target"))
      try path.appending("link").makeSymbolicLink(to: "target")

      // By default, a copy follows the link.
      try path.appending("link").copy(to: path.appending("followed"), options: .all)
      XCTAssertEqual(try path.appending("followed").stat(followTargetSymlink: false).type, .regular)

      try path.appending("link").copy(
        to: path.appending("copied-link"), options: [.all, .noFollowSource])
      XCTAssertEqual(try path.appending("copied-link").readSymbolicLink(), "target")

    }
  }

  func testCopySettings() throws {
    try withTemporaryFilePath(basename: "testCopySettings") { path in
      let bytes = [UInt8](repeating: 3, count: 100_000)
      try write(bytes, to: path.appending("source"))

      // The system accepts every setting.
      var state = FilePath.CopyState()
      state.sourceBlockSize = 1 << 12
      state.destinationBlockSize = 1 << 12
      state.forbidsCrossingMountPoints = true
      state.preservesSetIDBits = true
      state.skipsProtectionClass = true
      state.forbidsReplacingSymbolicLinks = true
      try path.appending("source").copy(to: path.appending("copy"), options: .all, state: &state)
      XCTAssertEqual(try contents(of: path.appending("copy")), bytes)
      XCTAssertEqual(state.copiedByteCount, Int64(bytes.count))
    }
  }

  func testCopyProgress() throws {
    try withTemporaryFilePath(basename: "testCopyProgress") { path in
      let source = path.appending("source")
      let bytes = [UInt8](repeating: 7, count: 1 << 20)
      try write(bytes, to: source)

      // A small block size makes the data copy report its progress often.
      var state = FilePath.CopyState()
      state.sourceBlockSize = 1 << 16
      var reports: [FilePath.CopyProgress] = []
      try source.copy(to: path.appending("copy"), options: .all, state: &state) {
        reports.append($0)
        return .continue
      }
      XCTAssertEqual(try contents(of: path.appending("copy")), bytes)
      let data = reports.filter { $0.kind == .data && $0.stage == .progress }
      XCTAssertGreaterThanOrEqual(data.count, 2)
      XCTAssertEqual(data.map(\.copiedByteCount), data.map(\.copiedByteCount).sorted())
      XCTAssertEqual(data.last?.copiedByteCount, Int64(bytes.count))
      XCTAssertEqual(data.first?.source, source)
      XCTAssertEqual(data.first?.destination, path.appending("copy"))
      XCTAssertEqual(state.copiedByteCount, Int64(bytes.count))

      // Quitting cancels the copy.
      XCTAssertThrowsError(
        try source.copy(to: path.appending("quit"), options: .all, state: &state) { _ in .quit }
      ) {
        XCTAssertEqual($0 as? Errno, .canceled)
      }

      // Between descriptors, the progress has no paths.
      let input = try FileDescriptor.open(source, .readOnly)
      try input.closeAfter {
        let output = try FileDescriptor.open(
          path.appending("fd-copy"), .writeOnly, options: [.create, .exclusiveCreate],
          permissions: .ownerReadWrite)
        try output.closeAfter {
          reports = []
          try input.copy(to: output, options: .data, state: &state) {
            reports.append($0)
            return .continue
          }
        }
      }
      XCTAssertEqual(try contents(of: path.appending("fd-copy")), bytes)
      XCTAssertFalse(reports.isEmpty)
      XCTAssertTrue(reports.allSatisfy { $0.source == nil && $0.destination == nil })
      XCTAssertEqual(state.copiedByteCount, Int64(bytes.count))
    }
  }

  func testRecursiveCopy() throws {
    try withTemporaryFilePath(basename: "testRecursiveCopy") { path in
      let tree = path.appending("tree")
      try tree.makeDirectory(permissions: .ownerReadWriteExecute)
      try tree.appending("keep").makeDirectory(permissions: .ownerReadWriteExecute)
      try tree.appending("skip").makeDirectory(permissions: .ownerReadWriteExecute)
      try write([1], to: tree.appending("top"))
      try write([2], to: tree.appending("keep/kept"))
      try write([3], to: tree.appending("skip/skipped"))

      var state = FilePath.CopyState()
      var reports: [FilePath.CopyProgress] = []
      try tree.copy(
        to: path.appending("copy"), options: [.all, .recursive], state: &state
      ) { progress in
        reports.append(progress)
        let skip = progress.kind == .directory && progress.stage == .start
          && progress.source?.lastComponent == "skip"
        return skip ? .skip : .continue
      }
      XCTAssertEqual(try contents(of: path.appending("copy/top")), [1])
      XCTAssertEqual(try contents(of: path.appending("copy/keep/kept")), [2])
      XCTAssertThrowsError(try path.appending("copy/skip/skipped").stat())

      // Each file starts and finishes, and each directory also gets cleaned up.
      func stages(_ kind: FilePath.CopyProgress.Kind, _ name: FilePath.Component)
        -> [FilePath.CopyProgress.Stage]
      {
        reports.filter { $0.kind == kind && $0.source?.lastComponent == name }.map(\.stage)
      }
      XCTAssertEqual(stages(.file, "top"), [.start, .finish])
      XCTAssertEqual(stages(.directory, "keep"), [.start, .finish])
      XCTAssertEqual(stages(.directoryCleanup, "keep"), [.start, .finish])
      XCTAssertEqual(stages(.file, "skipped"), [])
      XCTAssertEqual(
        reports.first { $0.kind == .file && $0.stage == .finish }?.destination?.removingLastComponent(),
        path.appending("copy"))

      // Each file's report has its own results, rather than the state.
      let finished = reports.first {
        $0.kind == .file && $0.stage == .finish && $0.source?.lastComponent == "top"
      }
      XCTAssertEqual(finished?.copiedByteCount, 1)
      XCTAssertFalse(state.wasCloned)
      XCTAssertEqual(state.copiedByteCount, 0)

      // Quitting stops the copy with an error, rather than an arbitrary errno.
      system_errno = 0
      XCTAssertThrowsError(
        try tree.copy(to: path.appending("quit"), options: [.all, .recursive], state: &state) {
          $0.kind == .file ? .quit : .continue
        }
      ) {
        XCTAssertEqual($0 as? Errno, .canceled)
      }

      // A recursive clone copies the directories and clones the files.
      reports = []
      try tree.copy(
        to: path.appending("clone"), options: [.all, .recursive, .clone], state: &state
      ) {
        reports.append($0)
        return .continue
      }
      XCTAssertEqual(try contents(of: path.appending("clone/skip/skipped")), [3])
      let cloned = reports.filter { $0.kind == .file && $0.stage == .finish }
      XCTAssertEqual(cloned.count, 3)
      if cloned.contains(where: \.wasCloned) {
        XCTAssertTrue(cloned.allSatisfy { $0.wasCloned && $0.copiedByteCount == 0 })
      }
    }
  }

  func testContentsToCopy() throws {
    try withTemporaryFilePath(basename: "testContentsToCopy") { path in
      let file = path.appending("file")
      try write([1, 2, 3], to: file)
      XCTAssertEqual(try file.contentsToCopy(options: .metadata), [])
      XCTAssertEqual(try file.contentsToCopy(options: .all), [])

      let set = file.withCString { setxattr($0, "org.swift.system.test", "v", 1, 0, 0) }
      XCTAssertEqual(set, 0)
      XCTAssertEqual(try file.contentsToCopy(options: .metadata), .extendedAttributes)
      XCTAssertEqual(
        try file.withCString { try FilePath.contentsToCopy($0, options: .extendedAttributes) },
        .extendedAttributes)
      // Only the contents asked about count.
      XCTAssertEqual(try file.contentsToCopy(options: .security), [])

      // The extended attribute is copied, and reported as it is.
      var state = FilePath.CopyState()
      var names: [String] = []
      try file.copy(to: path.appending("copy"), options: .all, state: &state) {
        if $0.kind == .extendedAttribute, let name = $0.extendedAttributeName {
          names.append(name)
        }
        return .continue
      }
      XCTAssertEqual(try path.appending("copy").contentsToCopy(options: .all), .extendedAttributes)
      XCTAssertTrue(names.contains("org.swift.system.test"))

      // The check doesn't look for the file.
      XCTAssertEqual(try path.appending("missing").contentsToCopy(options: .all), [])
    }
  }

  func testDescriptorCopy() throws {
    try withTemporaryFilePath(basename: "testDescriptorCopy") { path in
      let bytes = (0..<5_000).map { UInt8(truncatingIfNeeded: $0) }
      try write(bytes, to: path.appending("source"))
      let input = try FileDescriptor.open(path.appending("source"), .readOnly)
      try input.closeAfter {
        let output = try FileDescriptor.open(
          path.appending("copy"), .writeOnly, options: [.create, .exclusiveCreate],
          permissions: .ownerReadWrite)
        try output.closeAfter {
          try input.copy(to: output, options: .data)
        }

        // The copy starts from the source's offset.
        _ = try input.seek(offset: 1_000, from: .start)
        let partial = try FileDescriptor.open(
          path.appending("partial"), .writeOnly, options: [.create, .exclusiveCreate],
          permissions: .ownerReadWrite)
        try partial.closeAfter {
          try input.copy(to: partial, options: .data)
        }
      }
      XCTAssertEqual(try contents(of: path.appending("copy")), bytes)
      XCTAssertEqual(try contents(of: path.appending("partial")), Array(bytes[1_000...]))

      XCTAssertThrowsError(
        try FileDescriptor(rawValue: -1).copy(to: FileDescriptor(rawValue: -1), options: .data)
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  func testClone() throws {
    try withTemporaryFilePath(basename: "testClone") { path in
      let bytes = (0..<10_000).map { UInt8(truncatingIfNeeded: $0) }
      try write(bytes, to: path.appending("source"), permissions: .ownerReadWrite)
      do {
        try path.appending("source").clone(to: path.appending("clone"))
      } catch Errno.notSupported {
        throw XCTSkip("The temporary directory's file system can't clone")
      }
      XCTAssertEqual(try contents(of: path.appending("clone")), bytes)

      // Writing the clone leaves the source alone.
      let clone = try FileDescriptor.open(path.appending("clone"), .writeOnly)
      try clone.closeAfter { _ = try clone.writeAll([0xFF]) }
      XCTAssertEqual(try contents(of: path.appending("source")), bytes)

      XCTAssertThrowsError(try path.appending("source").clone(to: path.appending("clone"))) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertThrowsError(try path.appending("missing").clone(to: path.appending("other"))) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }

      try path.appending("source").withCString { source in
        try path.appending("static").withCString { destination in
          try FilePath.clone(source, to: destination)
        }
      }
      XCTAssertEqual(try contents(of: path.appending("static")), bytes)

      // A symbolic link is cloned itself only with the option.
      try path.appending("link").makeSymbolicLink(to: "source")
      try path.appending("link").clone(to: path.appending("followed"))
      XCTAssertEqual(try path.appending("followed").stat(followTargetSymlink: false).type, .regular)
      try path.appending("link").clone(to: path.appending("link-clone"), options: .noFollow)
      XCTAssertEqual(try path.appending("link-clone").readSymbolicLink(), "source")

      try path.appending("one").makeDirectory(permissions: .ownerReadWriteExecute)
      let one = try FileDescriptor.open(path.appending("one"), .readOnly, options: .directory)
      let top = try FileDescriptor.open(path, .readOnly, options: .directory)
      try one.closeAfter {
        try top.closeAfter {
          try FilePath("source").clone(relativeTo: top, to: "at", relativeTo: one)
          try "source".withCString { source in
            try "at-static".withCString { destination in
              try FilePath.clone(source, relativeTo: top, to: destination, relativeTo: one)
            }
          }

          // A descriptor's file can be cloned, relative to a directory or not.
          let source = try FileDescriptor.open(path.appending("source"), .readOnly)
          try source.closeAfter {
            try source.clone(to: path.appending("one/from-fd"))
            try source.clone(to: "from-fd-at", relativeTo: one)
            try path.appending("one/from-fd-static").withCString {
              try source.clone(to: $0)
            }
            try "from-fd-at-static".withCString {
              try source.clone(to: $0, relativeTo: one)
            }
          }
        }
      }
      for name in ["at", "at-static", "from-fd", "from-fd-at", "from-fd-static", "from-fd-at-static"] {
        XCTAssertEqual(try contents(of: path.appending("one").appending(name)), bytes, name)
      }
    }
  }

  // MARK: Helpers

  private func write(
    _ bytes: [UInt8], to path: FilePath, permissions: FilePermissions = .ownerReadWrite
  ) throws {
    let fd = try FileDescriptor.open(
      path, .writeOnly, options: [.create, .truncate], permissions: permissions)
    try fd.closeAfter { _ = try fd.writeAll(bytes) }
  }

  private func contents(of path: FilePath) throws -> [UInt8] {
    let fd = try FileDescriptor.open(path, .readOnly)
    return try fd.closeAfter {
      var result: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 1 << 16)
      while true {
        let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
        if count == 0 { return result }
        result += buffer[..<count]
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
