/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("DirectoryWalk")
private struct DirectoryWalkTests {
  /// Walks the tree under `root`, with paths relative to it.
  @available(System 199, *)
  func walk(
    _ root: FilePath, order: DirectoryWalk.Order
  ) throws -> [DirectoryWalk.Entry] {
    var walk = DirectoryWalk(try DirectoryStream.open(root), order: order)
    var entries: [DirectoryWalk.Entry] = []
    while let entry = try walk.next() { entries.append(entry) }
    return entries
  }

  @available(System 199, *)
  @Test func preorderVisitsEachDirectoryBeforeItsContents() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_preorder") { root in
      try DirectoryFixture.makeTree(in: root)
      let paths = try walk(root, order: .preorder).map(\.path.string)
      // Each entry once, without following `link`, and without the root.
      #expect(paths.count == DirectoryFixture.treePaths.count)
      #expect(Set(paths) == DirectoryFixture.treePaths)
      #expect(paths.firstIndex(of: "a")! < paths.firstIndex(of: "a/b")!)
      #expect(paths.firstIndex(of: "a")! < paths.firstIndex(of: "a/d.txt")!)
      #expect(paths.firstIndex(of: "a/b")! < paths.firstIndex(of: "a/b/c.txt")!)
    }
  }

  @available(System 199, *)
  @Test func postorderVisitsEachDirectoryAfterItsContents() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_postorder") { root in
      try DirectoryFixture.makeTree(in: root)
      let paths = try walk(root, order: .postorder).map(\.path.string)
      #expect(paths.count == DirectoryFixture.treePaths.count)
      #expect(Set(paths) == DirectoryFixture.treePaths)
      #expect(paths.firstIndex(of: "a/b/c.txt")! < paths.firstIndex(of: "a/b")!)
      #expect(paths.firstIndex(of: "a/b")! < paths.firstIndex(of: "a")!)
      #expect(paths.firstIndex(of: "a/d.txt")! < paths.firstIndex(of: "a")!)
    }
  }

  @available(System 199, *)
  @Test func typesAndDepths() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_typesAndDepths") { root in
      try DirectoryFixture.makeTree(in: root)
      for order in [DirectoryWalk.Order.preorder, .postorder] {
        var found: [String: DirectoryWalk.Entry] = [:]
        for entry in try walk(root, order: order) { found[entry.path.string] = entry }
        #expect(found["a"]?.type == .directory)
        #expect(found["a"]?.depth == 1)
        #expect(found["a/b"]?.type == .directory)
        #expect(found["a/b"]?.depth == 2)
        #expect(found["a/b/c.txt"]?.type == .regular)
        #expect(found["a/b/c.txt"]?.depth == 3)
        #expect(found["a/b/c.txt"]?.name.string == "c.txt")
        #expect(found["link"]?.type == .symbolicLink)
        #expect(found.values.allSatisfy { $0.error == nil })
      }
    }
  }

  @available(System 199, *)
  @Test func pathsStartWithTheRoot() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_paths") { root in
      try DirectoryFixture.makeTree(in: root)
      var walk = try DirectoryWalk(root)
      var relative: Set<String> = []
      while let entry = try walk.next() {
        #expect(entry.path.starts(with: root))
        #expect(entry.path.lastComponent == entry.name)
        relative.insert(FilePath(root: nil, entry.path.components.dropFirst(root.components.count)).string)
      }
      #expect(relative == DirectoryFixture.treePaths)
    }
  }

  @available(System 199, *)
  @Test func walkingFromAPartlyReadStream() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_partlyRead") { root in
      for name in ["x", "y", "z"] { try DirectoryFixture.file(root.appending(name)) }
      var stream = try DirectoryStream.open(root)
      let first = try #require(try stream.next())
      var walk = DirectoryWalk(stream, path: root)
      var names: Set<String> = []
      while let entry = try walk.next() { names.insert(entry.name.string) }
      #expect(names == Set(["x", "y", "z"]).subtracting([first.name.string]))
    }
  }

  @available(System 199, *)
  @Test func skippingADirectorysContents() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_skipping") { root in
      try DirectoryFixture.makeTree(in: root)
      var walk = DirectoryWalk(try DirectoryStream.open(root))
      var paths: [String] = []
      while let entry = try walk.next() {
        paths.append(entry.path.string)
        if entry.name == "a" { walk.skipDescendants() }
      }
      #expect(Set(paths) == ["a", "e.txt", "link"])

      // After a file, or in a postorder walk, skipping does nothing.
      var postorder = DirectoryWalk(try DirectoryStream.open(root), order: .postorder)
      var count = 0
      while try postorder.next() != nil {
        postorder.skipDescendants()
        count += 1
      }
      #expect(count == DirectoryFixture.treePaths.count)
    }
  }

  #if !os(WASI) // WASI's files have no permissions
  // Permissions don't stop the superuser from opening a directory.
  @available(System 199, *)
  @Test(.enabled(if: geteuid() != 0))
  func anUnreadableDirectoryIsReportedAndSkipped() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_unreadable") { root in
      try DirectoryFixture.makeTree(in: root)
      try root.appending("a/b").setPermissions([])
      defer { try? root.appending("a/b").setPermissions(.ownerReadWriteExecute) }
      for order in [DirectoryWalk.Order.preorder, .postorder] {
        let entries = try walk(root, order: order)
        let paths = entries.map(\.path.string)
        #expect(Set(paths) == DirectoryFixture.treePaths.subtracting(["a/b/c.txt"]))
        let b = try #require(entries.first { $0.path == "a/b" })
        #expect(b.type == .directory)
        #expect(b.error == .permissionDenied)
      }
    }
  }
  #endif

  #if !os(WASI) // WasmKit, which runs WASI's tests, can't rename (ENOTSUP)
  @available(System 199, *)
  @Test func aDirectoryReplacedByALinkIsNotFollowed() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_replaced") { root in
      let tree = root.appending("tree")
      try DirectoryFixture.directory(tree)
      try DirectoryFixture.directory(tree.appending("x"))
      try DirectoryFixture.directory(tree.appending("y"))
      try DirectoryFixture.file(tree.appending("x/inside"))
      try DirectoryFixture.file(tree.appending("y/inside"))
      try DirectoryFixture.directory(root.appending("outside"))
      try DirectoryFixture.file(root.appending("outside/precious"))

      var walk = DirectoryWalk(try DirectoryStream.open(tree))
      var entries: [String: DirectoryWalk.Entry] = [:]
      var replaced: String? = nil
      while let entry = try walk.next() {
        entries[entry.path.string] = entry
        guard replaced == nil else { continue }
        // readdir has read both x and y into its buffer by now, and the walk
        // has opened this one. Replace the other with a link out of the
        // tree, as another process could between readdir and open.
        let other = entry.name == "x" ? "y" : "x"
        try tree.appending(other).rename(to: tree.appending("\(other).moved"))
        try tree.appending(other).makeSymbolicLink(to: "../outside")
        replaced = other
      }
      let other = try #require(replaced)
      #expect(entries["\(other)/precious"] == nil)
      #expect(!entries.keys.contains { $0.hasPrefix("\(other)/") })
      // readdir still reports the name as a directory, which the walk then
      // fails to open, rather than following the link.
      let entry = try #require(entries[other])
      #expect(entry.type == .directory)
      #expect(entry.error == .notDirectory || entry.error == .tooManySymbolicLinkLevels)
    }
  }
  #endif

  @available(System 199, *)
  @Test func theParentDirectoryContainsTheEntry() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_parent") { root in
      try DirectoryFixture.makeTree(in: root)
      for order in [DirectoryWalk.Order.preorder, .postorder] {
        var walk = try DirectoryWalk(root, order: order)
        #expect(try Stat(walk.parentDirectory).inode == root.stat().inode)
        while let entry = try walk.next() {
          let status = try FilePath(root: nil, components: entry.name)
            .stat(relativeTo: walk.parentDirectory, flags: .symlinkNoFollow)
          #expect(try status.inode == entry.path.stat(followTargetSymlink: false).inode)
        }
      }
    }
  }

  @available(System 199, *)
  @Test func aPostorderWalkCanRemoveTheTree() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_remove") { root in
      let tree = root.appending("tree")
      try DirectoryFixture.directory(tree)
      try DirectoryFixture.makeTree(in: tree)
      var walk = try DirectoryWalk(tree, order: .postorder)
      while let entry = try walk.next() {
        let name = FilePath(root: nil, components: entry.name)
        if entry.type == .directory {
          try name.removeDirectory(relativeTo: walk.parentDirectory)
        } else {
          try name.unlink(relativeTo: walk.parentDirectory)
        }
      }
      try walk.close()
      try tree.removeDirectory()
    }
  }

  @available(System 199, *)
  @Test func typesComeFromStatusWhenTheDirectoryDoesntRecordThem() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_resolveType") { root in
      try DirectoryFixture.makeTree(in: root)
      let fd = try FileDescriptor.open(root, .readOnly, options: .directory)
      defer { try? fd.close() }
      // What the walk does with an entry whose d_type is DT_UNKNOWN,
      // which no file system here produces.
      func resolve(_ name: FilePath) -> Result<FileType, Errno> {
        name.withPlatformString { _resolveType($0, in: fd.rawValue, retryOnInterrupt: true) }
      }
      #expect(try resolve("a").get() == .directory)
      #expect(try resolve("e.txt").get() == .regular)
      #expect(try resolve("link").get() == .symbolicLink)
      #expect(throws: Errno.noSuchFileOrDirectory) { try resolve("missing").get() }
    }
  }

  @available(System 199, *)
  @Test func emptyAndMissingRoots() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_roots") { root in
      var empty = try DirectoryWalk(root)
      #expect(try empty.next() == nil)
      #expect(try empty.next() == nil)

      try DirectoryFixture.file(root.appending("file"))
      #expect(throws: Errno.notDirectory) { _ = try DirectoryWalk(root.appending("file")) }
      #expect(throws: Errno.noSuchFileOrDirectory) { _ = try DirectoryWalk(root.appending("missing")) }
    }
  }

  @available(System 199, *)
  @Test func closingPartway() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_closing") { root in
      try DirectoryFixture.makeTree(in: root)
      var walk = try DirectoryWalk(root)
      // Stop somewhere inside the tree, with directories open.
      while let entry = try walk.next(), entry.depth < 2 {}
      try walk.close()
    }
  }
}

#endif // !os(Windows)
