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

// A walk with `.includesRoot`, which visits the root itself (fts's level 0),
// and `.includesStatus`, which gives each entry's fstatat (fts's fts_statp,
// or FTS_NS).
@Suite("DirectoryWalk, the root and each entry's status")
private struct DirectoryWalkRootAndStatusTests {
  /// Every entry of a walk.
  @available(System 199, *)
  func entries(
    _ root: FilePath, order: DirectoryWalk.Order,
    opening: DirectoryWalk.DirectoryOpening = .whenRead,
    options: DirectoryWalk.Options
  ) throws -> [DirectoryWalk.Entry] {
    var walk = try DirectoryWalk(root, order: order, opening: opening, options: options)
    var entries: [DirectoryWalk.Entry] = []
    while let entry = try walk.next() {
      entries.append(entry)
      if entry.depth == 0 {
        // During the root's visits, parentDirectory is the root, and the
        // entry's name, `.`, reaches the root through it.
        let status = try FilePath(root: nil, components: entry.name)
          .stat(relativeTo: walk.parentDirectory, flags: .symlinkNoFollow)
        #expect(try status.inode == root.stat().inode)
      }
    }
    return entries
  }

  @available(System 199, *)
  func visits(_ entries: [DirectoryWalk.Entry], under root: FilePath) -> [String] {
    entries.map {
      let relative = $0.depth == 0 ? "." : String($0.path.string.dropFirst(root.string.count + 1))
      return $0.isPostorderVisit ? relative + "/" : relative
    }
  }

  /// The root's visits come where the order puts any directory's, around
  /// the same visits of its contents as a walk without the option.
  @available(System 199, *)
  @Test func theRootIsVisitedInEachOrder() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_root") { root in
      try DirectoryFixture.makeTree(in: root)
      for options in [DirectoryWalk.Options(), .boundedDescriptors] {
        for order in [DirectoryWalk.Order.preorder, .postorder, .preorderAndPostorder] {
          for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
            let withRoot = try entries(
              root, order: order, opening: opening, options: options.union(.includesRoot))
            let without = try entries(root, order: order, opening: opening, options: options)
            var expected = visits(without, under: root)
            if order != .postorder { expected.insert(".", at: 0) }
            if order == .postorder { expected.append("./") }
            if order == .preorderAndPostorder { expected.append("./") }
            #expect(visits(withRoot, under: root) == expected, "\(order), \(opening), \(options)")
            for entry in withRoot where entry.depth == 0 {
              #expect(entry.name == "." && entry.path == root && entry.type == .directory)
              #expect(entry.error == nil && entry.status == nil && entry.statusError == nil)
            }
          }
        }
      }
    }
  }

  /// Skipping after the root's first visit skips everything, including its
  /// second visit; the root is still the parentDirectory until next().
  @available(System 199, *)
  @Test func skippingTheRootsContentsEndsTheWalk() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_rootSkip") { root in
      try DirectoryFixture.makeTree(in: root)
      for order in [DirectoryWalk.Order.preorder, .preorderAndPostorder] {
        var walk = try DirectoryWalk(root, order: order, options: .includesRoot)
        let first = try #require(try walk.next())
        #expect(first.depth == 0)
        walk.skipDescendants()
        #expect(try Stat(walk.parentDirectory).inode == root.stat().inode)
        #expect(try walk.next() == nil, "\(order)")
        #expect(try walk.next() == nil)
      }
    }
  }

  /// Each entry's status is the file's own, without following a link; a
  /// directory's postorder visit has the status of its first; the type
  /// agrees; and a walk without the option has none.
  @available(System 199, *)
  @Test func eachEntrysStatus() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_status") { root in
      try DirectoryFixture.makeTree(in: root)
      for options in [DirectoryWalk.Options(), .boundedDescriptors] {
        for order in [DirectoryWalk.Order.preorder, .postorder, .preorderAndPostorder] {
          for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
            let found = try entries(
              root, order: order, opening: opening,
              options: options.union([.includesStatus, .includesRoot]))
            for entry in found {
              let status = try #require(entry.status, "\(entry.path)")
              #expect(entry.statusError == nil)
              #expect(try status.inode == entry.path.stat(followTargetSymlink: false).inode)
              #expect(status.type == entry.type)
            }
            #expect(found.first { $0.name == "link" }?.status?.type == .symbolicLink)
            if order == .preorderAndPostorder {
              for directory in ["a", "a/b", "."] {
                let visits = found.filter {
                  ($0.depth == 0 ? "." : String($0.path.string.dropFirst(root.string.count + 1)))
                    == directory
                }
                #expect(visits.count == 2)
                #expect(visits.first?.status == visits.last?.status, "\(directory)")
              }
            }
            let without = try entries(root, order: order, opening: opening, options: options)
            #expect(without.allSatisfy { $0.status == nil && $0.statusError == nil })
          }
        }
      }
    }
  }

  #if !os(WASI) // WASI's files have no permissions
  /// The entries of a directory that can be read but not searched have no
  /// status (fts's FTS_NS): the error is permissionDenied, and the type is
  /// the one the directory records.
  @available(System 199, *)
  @Test(.enabled(if: geteuid() != 0, "root can search any directory"))
  func entriesWhoseStatusCantBeRead() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_noStatus") { root in
      let listed = root.appending("listed")
      try DirectoryFixture.directory(listed)
      try DirectoryFixture.file(listed.appending("file"))
      try DirectoryFixture.directory(listed.appending("directory"))
      try listed.setPermissions(.ownerRead)
      defer { try? listed.setPermissions(.ownerReadWriteExecute) }
      for options in [DirectoryWalk.Options(), .boundedDescriptors] {
        let found = try entries(
          root, order: .preorderAndPostorder, options: options.union(.includesStatus))
        let listedEntry = try #require(found.first { $0.name == "listed" })
        #expect(listedEntry.status != nil && listedEntry.error == nil)
        let file = try #require(found.first { $0.name == "file" })
        #expect(file.status == nil && file.statusError == .permissionDenied)
        let directory = try #require(found.first { $0.name == "directory" })
        #expect(directory.status == nil && directory.statusError == .permissionDenied)
        // Opening it fails too, and it has no contents.
        #expect(directory.error == .permissionDenied)
        #if SYSTEM_PACKAGE_DARWIN
        // APFS records each entry's type in its directory.
        #expect(file.type == .regular && directory.type == .directory)
        #endif
      }
    }
  }
  #endif
}

#endif // !os(Windows)
