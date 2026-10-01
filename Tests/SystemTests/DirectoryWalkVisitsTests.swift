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
  func visits(
    _ root: FilePath, skipping skip: String? = nil,
    order: DirectoryWalk.Order = .preorderAndPostorder,
    opening: DirectoryWalk.DirectoryOpening = .whenRead,
    onVisit: (String) throws -> Void = { _ in }
  ) throws -> [String] {
    var walk = try DirectoryWalk(root, order: order, opening: opening)
    var visits: [String] = []
    while let entry = try walk.next() {
      let relative = String(entry.path.string.dropFirst(root.string.count + 1))
      visits.append(entry.isPostorderVisit ? relative + "/" : relative)
      if relative == skip { walk.skipDescendants() }
      try onVisit(visits.last!)
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
  @Test(.enabled(if: geteuid() != 0, "root can read any directory"))
  func anUnreadableDirectoryOnce() throws {
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

  /// Opening directories as the walk enters them visits the same entries,
  /// in the same order.
  @available(System 199, *)
  @Test func openingWhenEnteredVisitsTheSame() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_whenEntered") { root in
      try DirectoryFixture.makeTree(in: root)
      for order in [DirectoryWalk.Order.preorder, .preorderAndPostorder, .postorder] {
        #expect(
          try visits(root, order: order, opening: .whenEntered) == visits(root, order: order),
          "\(order)")
      }
      #expect(try visits(root, skipping: "a/b", opening: .whenEntered) == visits(root, skipping: "a/b"))
    }
  }

  /// A walk that opens a directory when it enters it reads what the
  /// caller added on the directory's first visit, as copying a tree into
  /// itself does; one that opens it as it reads its entry doesn't, since
  /// Darwin's fdopendir reads the entries then.
  @available(System 199, *)
  @Test func openingWhenEnteredReadsWhatTheFirstVisitAdded() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_whenEnteredAdds") { root in
      try DirectoryFixture.makeTree(in: root)
      func addingOnFirstVisit(_ opening: DirectoryWalk.DirectoryOpening) throws -> [String] {
        let added = root.appending("a/added-\(opening).txt")
        defer { _ = try? added.remove() }
        return try visits(root, opening: opening) { visit in
          if visit == "a" {
            try FileDescriptor.open(
              added, .writeOnly, options: .create, permissions: .ownerReadWrite
            ).close()
          }
        }
      }
      #expect(try addingOnFirstVisit(.whenEntered).contains("a/added-whenEntered.txt"))
      #if SYSTEM_PACKAGE_DARWIN
      #expect(try !addingOnFirstVisit(.whenRead).contains("a/added-whenRead.txt"))
      #endif
    }
  }

  /// A directory that a walk can't open when it enters it is visited
  /// twice: first without an error, then with it, as its postorder visit,
  /// in place of its contents (fts's FTS_D and FTS_DNR). Skipping its
  /// contents after the first visit keeps the walk from opening it.
  @available(System 199, *)
  @Test(.enabled(if: geteuid() != 0, "root can read any directory"))
  func anUnreadableDirectoryWhenEntered() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_whenEnteredUnreadable") { root in
      try DirectoryFixture.makeTree(in: root)
      let locked = root.appending("a/b")
      try locked.setPermissions([])
      defer { try? locked.setPermissions(.ownerReadWriteExecute) }
      for order in [DirectoryWalk.Order.preorder, .preorderAndPostorder] {
        var walk = try DirectoryWalk(root, order: order, opening: .whenEntered)
        var entries: [DirectoryWalk.Entry] = []
        var parentOfTheError: Stat? = nil
        while let entry = try walk.next() {
          entries.append(entry)
          if entry.error != nil { parentOfTheError = try Stat(walk.parentDirectory) }
        }
        let b = entries.filter { $0.name == "b" }
        #expect(b.map(\.error) == [nil, .permissionDenied], "\(order)")
        #expect(b.map(\.isPostorderVisit) == [false, true], "\(order)")
        #expect(b.allSatisfy { $0.type == .directory && $0.depth == 2 })
        #expect(!entries.contains { $0.name == "c.txt" })
        // The error's visit is in a, the directory that contains b.
        #expect(try parentOfTheError?.inode == root.appending("a").stat().inode)
      }
      let skipped = try visits(root, skipping: "a/b", opening: .whenEntered)
      #expect(skipped.filter { $0.hasPrefix("a/b") } == ["a/b"])
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
