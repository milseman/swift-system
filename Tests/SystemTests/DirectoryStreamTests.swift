/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

/// Builds the directory trees that the directory stream and walk tests read.
@available(System 199, *)
internal enum DirectoryFixture {
  /// Makes a regular file.
  static func file(_ path: FilePath) throws {
    let fd = try FileDescriptor.open(
      path, .writeOnly, options: [.create, .exclusiveCreate],
      permissions: .ownerReadWrite)
    try fd.close()
  }

  /// Makes a directory.
  static func directory(_ path: FilePath) throws {
    try path.makeDirectory(permissions: .ownerReadWriteExecute)
  }

  /// Makes this tree in `root`:
  ///
  ///     a/
  ///     a/b/
  ///     a/b/c.txt
  ///     a/d.txt
  ///     e.txt
  ///     link -> a
  static func makeTree(in root: FilePath) throws {
    try directory(root.appending("a"))
    try directory(root.appending("a/b"))
    try file(root.appending("a/b/c.txt"))
    try file(root.appending("a/d.txt"))
    try file(root.appending("e.txt"))
    try root.appending("link").makeSymbolicLink(to: "a")
  }

  /// The paths of `makeTree(in:)`, relative to its root.
  static let treePaths: Set<String> = ["a", "a/b", "a/b/c.txt", "a/d.txt", "e.txt", "link"]

  /// Calls `body` with a new, empty temporary directory,
  /// which is removed afterward, with everything in it.
  ///
  /// This removes the directory's contents with a postorder walk first,
  /// which is iterative. `withTemporaryFilePath`'s own removal recurses, and
  /// in a debug build it overflows the stack of the thread that runs a
  /// swift-testing test somewhere between 40 and 60 levels deep. The
  /// descriptor-limit test makes a tree 100 deep.
  static func withTemporaryDirectory<R>(
    _ basename: FilePath.Component, _ body: (FilePath) throws -> R
  ) throws -> R {
    try withTemporaryFilePath(basename: basename) { root in
      defer { try? removeContents(of: root) }
      return try body(root)
    }
  }

  /// Removes everything in a directory, as `rm -r` does.
  static func removeContents(of root: FilePath) throws {
    var walk = try DirectoryWalk(root, order: .postorder)
    while let entry = try walk.next() {
      let name = FilePath(root: nil, components: entry.name)
      if entry.type == .directory {
        try name.removeDirectory(relativeTo: walk.parentDirectory)
      } else {
        try name.unlink(relativeTo: walk.parentDirectory)
      }
    }
  }

  /// The names of a directory's entries.
  static func names(_ stream: inout DirectoryStream) throws -> [String] {
    var names: [String] = []
    while let entry = try stream.next() {
      names.append(entry.name.string)
    }
    return names
  }
}

@Suite("DirectoryStream")
private struct DirectoryStreamTests {
  @available(System 199, *)
  @Test func readsEachEntryOnce() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_readsEachEntryOnce") { root in
      try DirectoryFixture.makeTree(in: root)
      var stream = try DirectoryStream.open(root)
      var entries: [String: DirectoryStream.Entry] = [:]
      while let entry = try stream.next() {
        let previous = entries.updateValue(entry, forKey: entry.name.string)
        #expect(previous == nil, "\(entry.name) came twice")
      }
      try stream.close()

      // No `.` or `..`.
      #expect(Set(entries.keys) == ["a", "e.txt", "link"])
      #expect(entries["a"]?.type == .directory)
      #expect(entries["e.txt"]?.type == .regular)
      // A link to a directory is a link.
      #expect(entries["link"]?.type == .symbolicLink)
      for (name, entry) in entries {
        let status = try root.appending(name).stat(followTargetSymlink: false)
        #expect(entry.inode == status.inode, "\(name)")
      }
    }
  }

  @available(System 199, *)
  @Test func theEndIsNotAnError() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_theEndIsNotAnError") { root in
      var stream = try DirectoryStream.open(root)
      #expect(try stream.next() == nil)
      // Reading again after the end still finds the end.
      #expect(try stream.next() == nil)
    }
  }

  @available(System 199, *)
  @Test func openingFailures() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_openingFailures") { root in
      try DirectoryFixture.file(root.appending("file"))
      #expect(throws: Errno.noSuchFileOrDirectory) {
        _ = try DirectoryStream.open(root.appending("missing"))
      }
      #expect(throws: Errno.notDirectory) {
        _ = try DirectoryStream.open(root.appending("file"))
      }
      try root.appending("file").withPlatformString { path in
        #expect(throws: Errno.notDirectory) {
          _ = try DirectoryStream.open(path)
        }
      }
    }
  }

  @available(System 199, *)
  @Test func openingRelativeToADirectory() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_openingRelative") { root in
      try DirectoryFixture.makeTree(in: root)
      let parent = try FileDescriptor.open(root, .readOnly, options: .directory)
      defer { try? parent.close() }

      var stream = try DirectoryStream.open("a", relativeTo: parent)
      #expect(Set(try DirectoryFixture.names(&stream)) == ["b", "d.txt"])
      try "a/b".withPlatformString { path in
        var inner = try DirectoryStream.open(path, relativeTo: parent)
        #expect(try DirectoryFixture.names(&inner) == ["c.txt"])
      }

      // Without `.noFollow`, a link to a directory opens the directory;
      // with it, the link doesn't open.
      var followed = try DirectoryStream.open("link", relativeTo: parent)
      #expect(Set(try DirectoryFixture.names(&followed)) == ["b", "d.txt"])
      let error = #expect(throws: Errno.self) {
        _ = try DirectoryStream.open("link", relativeTo: parent, options: .noFollow)
      }
      #expect(error == .notDirectory || error == .tooManySymbolicLinkLevels)

      #expect(throws: Errno.notDirectory) {
        _ = try DirectoryStream.open("e.txt", relativeTo: parent)
      }
    }
  }

  @available(System 199, *)
  @Test func takingADescriptor() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_takingADescriptor") { root in
      try DirectoryFixture.makeTree(in: root)
      let directory = try FileDescriptor.open(root.appending("a"), .readOnly, options: .directory)
      var stream = try DirectoryStream(taking: directory)
      #expect(stream.fileDescriptor == directory)
      #expect(Set(try DirectoryFixture.names(&stream)) == ["b", "d.txt"])
      try stream.close()

      // When the descriptor isn't a directory, the caller still owns it.
      let file = try FileDescriptor.open(root.appending("e.txt"), .readOnly)
      #expect(throws: Errno.notDirectory) {
        _ = try DirectoryStream(taking: file)
      }
      _ = try file.descriptorFlags()
      try file.close()
    }
  }

  @available(System 199, *)
  @Test func convertingAnOwner() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_convertingAnOwner") { root in
      try DirectoryFixture.makeTree(in: root)
      let owner = try OwnedFD.open(root.appending("a"), .readOnly, options: .directory)
      let number = owner.fileDescriptor
      var stream = try DirectoryStream(owner)
      #expect(stream.fileDescriptor == number)
      #expect(Set(try DirectoryFixture.names(&stream)) == ["b", "d.txt"])
    }
  }

  @available(System 199, *)
  @Test func rewindingRereadsTheDirectory() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_rewinding") { root in
      try DirectoryFixture.makeTree(in: root)
      var stream = try DirectoryStream.open(root)
      let before = try DirectoryFixture.names(&stream)
      #expect(Set(before) == ["a", "e.txt", "link"])
      try DirectoryFixture.file(root.appending("late"))
      stream.rewind()
      // After rewinding, the stream reflects the directory as it is now.
      let after = try DirectoryFixture.names(&stream)
      #expect(Set(after) == ["a", "e.txt", "link", "late"])
    }
  }

  @available(System 199, *)
  @Test func theDescriptorIsTheDirectory() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_theDescriptor") { root in
      try DirectoryFixture.makeTree(in: root)
      var stream = try DirectoryStream.open(root)
      #expect(try Stat(stream.fileDescriptor).inode == root.stat().inode)
      #expect(try stream.fileDescriptor.descriptorFlags().contains(.closeOnExec))

      // Each entry's status, relative to the descriptor.
      while let entry = try stream.next() {
        let status = try FilePath(root: nil, components: entry.name)
          .stat(relativeTo: stream.fileDescriptor, flags: .symlinkNoFollow)
        #expect(status.inode == entry.inode)
        #expect(status.type == entry.type)
      }

      let relative = try DirectoryStream.open("a", relativeTo: stream.fileDescriptor)
      #expect(try relative.fileDescriptor.descriptorFlags().contains(.closeOnExec))
    }
  }

  @available(System 199, *)
  @Test func keptEntriesKeepTheirNames() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_keptEntries") { root in
      let expected = (0..<100).map { "file-\($0)" }
      for name in expected { try DirectoryFixture.file(root.appending(name)) }
      var stream = try DirectoryStream.open(root)
      var kept: [DirectoryStream.Entry] = []
      while let entry = try stream.next() { kept.append(entry) }
      // The stream wrote each name over the last one's storage only when
      // nothing else shared it, so every kept entry has its own name.
      #expect(kept.map(\.name.string).sorted() == expected.sorted())
    }
  }

  @available(System 199, *)
  @Test func readingReusesNameStorage() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_reusesStorage") { root in
      for name in ["n1", "n2", "n3", "n4"] { try DirectoryFixture.file(root.appending(name)) }
      var stream = try DirectoryStream.open(root)
      func storage(_ stream: borrowing DirectoryStream) -> UnsafeRawPointer? {
        stream._name.nullTerminatedStorage.withUnsafeBufferPointer {
          UnsafeRawPointer($0.baseAddress)
        }
      }
      // The first name grows the storage; names of the same length reuse it.
      _ = try stream.next()
      let first = storage(stream)
      _ = try stream.next()
      #expect(storage(stream) == first)

      // An entry that's still alive keeps its storage, so the next name
      // goes somewhere new.
      let kept = try stream.next()
      _ = try stream.next()
      #expect(storage(stream) != first)
      #expect(kept?.name.string.count == 2)
    }
  }

  @available(System 199, *)
  @Test func longNames() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryStream_longNames") { root in
      // 255 bytes, the longest name most file systems allow.
      let name = String(repeating: "n", count: 255)
      try DirectoryFixture.file(root.appending(name))
      var stream = try DirectoryStream.open(root)
      #expect(try DirectoryFixture.names(&stream) == [name])
    }
  }
}

#endif // !os(Windows) && !os(WASI)
