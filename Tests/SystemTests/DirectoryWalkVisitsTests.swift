/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
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

// A walk that visits each directory before and after its contents, as
// copying a tree needs (fts's FTS_D and FTS_DP).
@Suite("DirectoryWalk, both visits")
private struct DirectoryWalkVisitsTests {
  /// The walk's visits, as "path" and "path/" for a directory's second one.
  @available(System 199, *)
  func visits(_ root: FilePath, skipping skip: String? = nil) throws -> [String] {
    var walk = try DirectoryWalk(root, order: .preorderAndPostorder)
    var visits: [String] = []
    while let entry = try walk.next() {
      let relative = String(entry.path.string.dropFirst(root.string.count + 1))
      visits.append(entry.isPostorderVisit ? relative + "/" : relative)
      if relative == skip { walk.skipDescendants() }
    }
    return visits
  }

  @available(System 199, *)
  @Test func eachDirectoryTwice() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_both") { root in
      try DirectoryFixture.makeTree(in: root)
      let visits = try visits(root)
      // Each entry once, and each directory again after its contents.
      #expect(Set(visits) == DirectoryFixture.treePaths.union(["a/", "a/b/"]))
      #expect(visits.count == DirectoryFixture.treePaths.count + 2)
      func at(_ visit: String) -> Int { visits.firstIndex(of: visit)! }
      #expect(at("a") < at("a/b") && at("a/b") < at("a/b/c.txt"))
      #expect(at("a/b/c.txt") < at("a/b/") && at("a/b/") < at("a/"))
      #expect(at("a/d.txt") < at("a/"))
      // A link, which the walk doesn't follow, is visited once.
      #expect(!visits.contains("link/"))
    }
  }

  @available(System 199, *)
  @Test func skippingADirectorysContentsSkipsItsSecondVisit() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_bothSkip") { root in
      try DirectoryFixture.makeTree(in: root)
      let visits = try visits(root, skipping: "a/b")
      #expect(visits.contains("a/b"))
      #expect(!visits.contains("a/b/c.txt") && !visits.contains("a/b/"))
      #expect(visits.contains("a/"))
    }
  }

  /// A directory the walk can't open is visited once, with its error.
  @available(System 199, *)
  @Test func anUnreadableDirectoryOnce() throws {
    try #require(getuid() != 0, "root can read any directory")
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_bothUnreadable") { root in
      try DirectoryFixture.makeTree(in: root)
      let locked = root.appending("a/b")
      try locked.setPermissions([])
      defer { try? locked.setPermissions(.ownerReadWriteExecute) }
      var walk = try DirectoryWalk(root, order: .preorderAndPostorder)
      var entries: [DirectoryWalk.Entry] = []
      while let entry = try walk.next() { entries.append(entry) }
      let b = entries.filter { $0.name == "b" }
      #expect(b.count == 1)
      #expect(b.first?.error == .permissionDenied && b.first?.type == .directory)
      #expect(b.first?.isPostorderVisit == false)
    }
  }

  /// In a postorder walk, a directory's only visit is its postorder one.
  @available(System 199, *)
  @Test func postorderVisitsAreMarked() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_postorderMarked") { root in
      try DirectoryFixture.makeTree(in: root)
      var walk = try DirectoryWalk(root, order: .postorder)
      while let entry = try walk.next() {
        #expect(entry.isPostorderVisit == (entry.type == .directory))
      }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
