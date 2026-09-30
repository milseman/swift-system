/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Watching files and directories with inotify (FileWatcher.swift). The
// kernel queues an event during the call that causes it, so a nonblocking
// read right after the call has it.

#if os(Linux) || os(Android)

import XCTest

#if canImport(Glibc)
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
final class FileWatcherTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      // Through the internal calls, so that no watcher owns (and closes)
      // the descriptors that mocking makes up.
      MockTestCase(name: "inotify_init1", .noInterrupt, CInt(IN_NONBLOCK) | CInt(IN_CLOEXEC)) { _ in
        _ = try FileWatcher._create(FileWatcher.Options([.nonBlocking, .closeOnExec]).rawValue).get()
      },
      MockTestCase(name: "inotify_add_watch", .noInterrupt, CInt(-1), "/tmp/watched", UInt32(IN_CREATE | IN_DELETE)) { _ in
        _ = try FileWatcher._add(FileDescriptor(rawValue: -1), "/tmp/watched", events: [.created, .deleted]).get()
      },
      MockTestCase(name: "inotify_rm_watch", .noInterrupt, CInt(-1), CInt(3)) { _ in
        try FileWatcher._remove(FileDescriptor(rawValue: -1), FileWatcher.Watch(rawValue: 3)).get()
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testTheMask() {
    XCTAssertEqual(FileWatcher.Mask.closed.rawValue, UInt32(IN_CLOSE))
    XCTAssertEqual(FileWatcher.Mask.moved.rawValue, UInt32(IN_MOVE))
    // IN_ALL_EVENTS, an OR of twelve macros that Swift can't import.
    XCTAssertEqual(FileWatcher.Mask.allEvents.rawValue, 0xFFF)
    XCTAssertEqual(FileWatcher.minimumReadByteCount, 16 + 255 + 1)
  }

  /// A directory's watch reports its entries' events, with their names,
  /// in order, and then the watch's removal.
  func testADirectory() throws {
    try withTemporaryFilePath(basename: "testADirectory") { dir in
      let watcher = try FileWatcher(options: [.nonBlocking, .closeOnExec])
      let watch = try watcher.add(dir, events: [.created, .deleted, .moved])
      XCTAssertThrowsError(try watcher.read()) {
        XCTAssertEqual($0 as? Errno, .resourceTemporarilyUnavailable)
      }

      try FileDescriptor.open(
        dir.appending("a"), .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
      XCTAssertEqual(try watcher.read(), [.init(watch: watch, mask: .created, name: "a")])

      try dir.appending("a").rename(to: dir.appending("b"))
      let moved = try watcher.read()
      XCTAssertEqual(moved.map(\.mask), [.movedFrom, .movedTo])
      XCTAssertEqual(moved.map(\.name), ["a", "b"])
      XCTAssertEqual(moved.first?.cookie, moved.last?.cookie)
      XCTAssertNotEqual(moved.first?.cookie, 0)

      try dir.appending("sub").makeDirectory(permissions: .ownerReadWriteExecute)
      XCTAssertEqual(
        try watcher.read(), [.init(watch: watch, mask: [.created, .isDirectory], name: "sub")])

      try dir.appending("b").unlink()
      XCTAssertEqual(try watcher.read(), [.init(watch: watch, mask: .deleted, name: "b")])

      try watcher.remove(watch)
      XCTAssertEqual(try watcher.read(), [.init(watch: watch, mask: .ignored)])
      XCTAssertThrowsError(try watcher.remove(watch)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      try watcher.close()
    }
  }

  /// A file's own watch reports events with no name, and a buffer too small
  /// for the next event throws EINVAL.
  func testAFile() throws {
    try withTemporaryFilePath(basename: "testAFile") { dir in
      let path = dir.appending("file")
      try FileDescriptor.open(path, .writeOnly, options: .create, permissions: .ownerReadWrite).close()
      let watcher = try FileWatcher(options: .nonBlocking)
      let watch = try watcher.add(path, events: [.modified, .closedAfterWriting])
      let fd = try FileDescriptor.open(path, .writeOnly)
      _ = try fd.writeAll("x".utf8)
      try fd.close()
      XCTAssertEqual(try watcher.read(), [
        .init(watch: watch, mask: .modified), .init(watch: watch, mask: .closedAfterWriting),
      ])
      // onlyDirectory refuses a file.
      XCTAssertThrowsError(try watcher.add(path, events: [.modified, .onlyDirectory])) {
        XCTAssertEqual($0 as? Errno, .notDirectory)
      }

      _ = try watcher.add(dir, events: .created)
      try FileDescriptor.open(
        dir.appending("named"), .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
      var small = [UInt8](repeating: 0, count: 16)
      XCTAssertThrowsError(try small.withUnsafeMutableBytes { try watcher.read(into: $0) }) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertEqual(try watcher.read().map(\.name), ["named"])
    }
  }
}

#endif // os(Linux) || os(Android)
