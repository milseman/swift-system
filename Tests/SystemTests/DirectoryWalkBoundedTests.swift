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

// A walk with `.boundedDescriptors`, which reads each directory whole and
// reopens it by name when it comes back to it (fts's FTS_NOCHDIR).
@Suite("DirectoryWalk, bounded descriptors")
private struct DirectoryWalkBoundedTests {
  /// The walk's visits, as "path", "path/" for a directory's postorder
  /// visit, and the error after a space. Checks that each entry is in the
  /// walk's parentDirectory, and that a skipped directory was skipped.
  @available(System 199, *)
  func visits(
    _ root: FilePath, order: DirectoryWalk.Order,
    opening: DirectoryWalk.DirectoryOpening = .whenRead,
    options: DirectoryWalk.Options, skipping skip: String? = nil
  ) throws -> [String] {
    var walk = try DirectoryWalk(root, order: order, opening: opening, options: options)
    var visits: [String] = []
    while let entry = try walk.next() {
      let relative = String(entry.path.string.dropFirst(root.string.count + 1))
      var visit = entry.isPostorderVisit ? relative + "/" : relative
      if let error = entry.error { visit += " \(error)" }
      visits.append(visit)
      let status = try FilePath(root: nil, components: entry.name)
        .stat(relativeTo: walk.parentDirectory, flags: .symlinkNoFollow)
      #expect(try status.inode == entry.path.stat(followTargetSymlink: false).inode, "\(visit)")
      if relative == skip { walk.skipDescendants() }
    }
    return visits
  }

  /// The same visits as a walk that holds a descriptor per level,
  /// in the same order, whatever the order, the opening, and skipping.
  @available(System 199, *)
  @Test func visitsTheSame() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_boundedSame") { root in
      try DirectoryFixture.makeTree(in: root)
      try DirectoryFixture.directory(root.appending("a/b/f"))
      try DirectoryFixture.file(root.appending("a/b/f/g.txt"))
      for order in [DirectoryWalk.Order.preorder, .postorder, .preorderAndPostorder] {
        for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
          for skip in [nil, "a/b"] {
            let bounded = try visits(
              root, order: order, opening: opening, options: .boundedDescriptors,
              skipping: skip)
            #expect(
              bounded == (try visits(root, order: order, opening: opening, options: [], skipping: skip)),
              "\(order), \(opening), skipping \(skip ?? "nothing")")
            #expect(bounded.count > 4)
          }
        }
      }
    }
  }

  /// A directory the walk can't open gets the same visits.
  @available(System 199, *)
  @Test func anUnreadableDirectory() throws {
    try #require(getuid() != 0, "root can read any directory")
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_boundedUnreadable") { root in
      try DirectoryFixture.makeTree(in: root)
      let locked = root.appending("a/b")
      try locked.setPermissions([])
      defer { try? locked.setPermissions(.ownerReadWriteExecute) }
      for order in [DirectoryWalk.Order.preorder, .postorder, .preorderAndPostorder] {
        for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
          let bounded = try visits(
            root, order: order, opening: opening, options: .boundedDescriptors)
          #expect(
            bounded == (try visits(root, order: order, opening: opening, options: [])),
            "\(order), \(opening)")
          #expect(bounded.contains { $0.hasPrefix("a/b") && $0.hasSuffix(" \(Errno.permissionDenied)") })
        }
      }
    }
  }

  /// A directory that's moved, and replaced by another, while the walk is
  /// in one of its subdirectories isn't there when the walk comes back to it:
  /// the walk throws, leaves it, and goes on with the rest of the tree.
  /// Without the option, the walk reads the directory where it is.
  @available(System 199, *)
  @Test func aDirectoryMovedAwayIsLeft() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_boundedMoved") { root in
      func walk(_ options: DirectoryWalk.Options) throws -> (visits: [String], errors: [Errno]) {
        let tree = root.appending("tree-\(options.rawValue)")
        try DirectoryFixture.directory(tree)
        try DirectoryFixture.makeTree(in: tree)
        var walk = try DirectoryWalk(tree, order: .preorderAndPostorder, options: options)
        var visits: [String] = []
        var errors: [Errno] = []
        while true {
          let next: DirectoryWalk.Entry?
          do {
            next = try walk.next()
          } catch {
            errors.append(error)
            continue
          }
          guard let entry = next else { break }
          let relative = String(entry.path.string.dropFirst(tree.string.count + 1))
          visits.append(entry.isPostorderVisit ? relative + "/" : relative)
          if relative == "a/b/c.txt" {
            // Move a away, and put another directory in its place.
            try tree.appending("a").rename(to: tree.appending("moved"))
            try DirectoryFixture.directory(tree.appending("a"))
          }
        }
        return (visits, errors)
      }

      let bounded = try walk(.boundedDescriptors)
      #expect(bounded.errors == [.noSuchFileOrDirectory])
      // Coming back to a for b's postorder visit failed, so the walk left a:
      // neither directory has a postorder visit, and the rest of the tree
      // (the root's entries, read whole at the start) is still visited.
      #expect(bounded.visits.contains("a/b/c.txt"))
      #expect(!bounded.visits.contains("a/b/") && !bounded.visits.contains("a/"))
      #expect(bounded.visits.contains("e.txt") && bounded.visits.contains("link"))
      #expect(!bounded.visits.contains { $0.hasPrefix("moved") })

      let perLevel = try walk([])
      #expect(perLevel.errors.isEmpty)
      #expect(perLevel.visits.contains("a/b/") && perLevel.visits.contains("a/"))
    }
  }

  /// A directory replaced by a symbolic link while the walk is in one of
  /// its subdirectories: the walk reopens it by name, without following
  /// the link, and so doesn't go out of the tree.
  @available(System 199, *)
  @Test func aDirectoryReplacedByALinkIsNotFollowedBack() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_boundedReplaced") { root in
      let tree = root.appending("tree")
      try DirectoryFixture.directory(tree)
      try DirectoryFixture.directory(tree.appending("x"))
      try DirectoryFixture.directory(tree.appending("x/y"))
      try DirectoryFixture.file(tree.appending("x/y/inside"))
      try DirectoryFixture.file(tree.appending("x/z"))
      try DirectoryFixture.directory(root.appending("outside"))
      try DirectoryFixture.file(root.appending("outside/precious"))
      try DirectoryFixture.file(root.appending("outside/z"))

      var walk = try DirectoryWalk(
        tree, order: .preorderAndPostorder, options: .boundedDescriptors)
      var visits: [String] = []
      var errors: [Errno] = []
      while true {
        let next: DirectoryWalk.Entry?
        do throws(Errno) {
          next = try walk.next()
        } catch {
          errors.append(error)
          continue
        }
        guard let entry = next else { break }
        let relative = String(entry.path.string.dropFirst(tree.string.count + 1))
        visits.append(entry.isPostorderVisit ? relative + "/" : relative)
        #expect(entry.name != "precious")
        if relative == "x/y/inside" {
          try tree.appending("x").rename(to: tree.appending("x.moved"))
          try tree.appending("x").makeSymbolicLink(to: "../outside")
        }
      }
      #expect(errors.count == 1)
      #expect(errors.allSatisfy { $0 == .notDirectory || $0 == .tooManySymbolicLinkLevels })
      #expect(!visits.contains("x/y/") && !visits.contains("x/"))
      #expect(try root.appending("outside/precious").stat().type == .regular)
    }
  }
}

@Suite("DirectoryWalk, bounded descriptors, limit")
private struct DirectoryWalkBoundedLimitTests {
  // Only on macOS: RLIMIT_NOFILE's type differs between the C libraries,
  // as in DirectoryStreamClosingTests.
  #if os(macOS)
  /// Under a limit that leaves five descriptors free, a walk with the
  /// option goes all the way down a tree 100 deep, and one without it
  /// stops.
  @available(System 199, *)
  @Test func aWalkWithBoundedDescriptorsGoesDeeperThanTheLimit() async {
    await #expect(processExitsWith: .success) {
      try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_boundedDeep") { root in
        // 100 directories, each inside the last, made relative to each other.
        var parent = try FileDescriptor.open(root, .readOnly, options: .directory)
        for _ in 0..<100 {
          try FilePath("d").makeDirectory(
            relativeTo: parent, permissions: .ownerReadWriteExecute)
          let child = try FileDescriptor.open(
            "d", relativeTo: parent, .readOnly, options: .directory)
          try parent.close()
          parent = child
        }
        try parent.close()

        // Take the five lowest free descriptors, and set the limit just
        // above them, so that exactly five are free below it. (A child
        // process can start with descriptors open.)
        var probes: [FileDescriptor] = []
        for _ in 0..<5 { probes.append(try FileDescriptor.open(root, .readOnly)) }
        let highest = probes.map(\.rawValue).max()!
        for probe in probes { try probe.close() }
        var limit = rlimit()
        getrlimit(RLIMIT_NOFILE, &limit)
        let original = limit.rlim_cur
        limit.rlim_cur = rlim_t(highest + 1)
        setrlimit(RLIMIT_NOFILE, &limit)

        func walk(_ options: DirectoryWalk.Options) throws -> (deepest: Int, errors: Int) {
          var walk = try DirectoryWalk(root, order: .preorderAndPostorder, options: options)
          var deepest = 0
          var errors = 0
          while let entry = try walk.next() {
            deepest = max(deepest, entry.depth)
            if entry.error != nil { errors += 1 }
          }
          return (deepest, errors)
        }
        let bounded = try walk(.boundedDescriptors)
        let perLevel = try walk([])
        // Raise the limit again, so that the cleanup can remove the tree.
        limit.rlim_cur = original
        setrlimit(RLIMIT_NOFILE, &limit)
        if bounded.deepest != 100 || bounded.errors != 0 { exit(1) }
        if perLevel.deepest >= 100 || perLevel.errors != 1 { exit(2) }
      }
    }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
