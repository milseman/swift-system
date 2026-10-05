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

/// A directory that the system has mounted another file system on, in a
/// directory small enough to read, or nil if there's none: /dev in /, where
/// devfs (Darwin) or devtmpfs (Linux) is mounted, or a Linux mount such as
/// /dev/pts. C's `stat`, so that the tests' traits can call it.
private func directoryOnAnotherDevice(
  in parents: [String] = ["/", "/dev"]
) -> (parent: String, name: String)? {
  for parent in parents {
    var parentStatus = stat()
    guard stat(parent, &parentStatus) == 0 else { continue }
    for name in ["dev", "proc", "pts", "shm", "mqueue"] {
      var status = stat()
      let path = parent == "/" ? "/" + name : parent + "/" + name
      guard lstat(path, &status) == 0, status.st_mode & 0o170000 == 0o040000,
            status.st_dev != parentStatus.st_dev
      else { continue }
      return (parent, name)
    }
  }
  return nil
}

// A walk with `.sameDevice`, which doesn't go into a directory on another
// device than the root's (fts's FTS_XDEV). The tests mount nothing: the
// tree they make is on one device, and the directory on another is one the
// system has mounted already, such as /dev, which they only read.
@Suite("DirectoryWalk, one device")
private struct DirectoryWalkSameDeviceTests {
  /// The walk's visits, as "path" and "path/" for a directory's postorder
  /// one.
  @available(System 199, *)
  func visits(
    _ root: FilePath, order: DirectoryWalk.Order, opening: DirectoryWalk.DirectoryOpening,
    options: DirectoryWalk.Options
  ) throws -> [String] {
    var walk = try DirectoryWalk(root, order: order, opening: opening, options: options)
    var visits: [String] = []
    while let entry = try walk.next() {
      let relative = entry.depth == 0
        ? "." : String(entry.path.string.dropFirst(root.string.count + 1))
      visits.append(entry.isPostorderVisit ? relative + "/" : relative)
    }
    return visits
  }

  /// On one device, the option changes nothing.
  @available(System 199, *)
  @Test func aTreeOnOneDeviceIsWalkedWhole() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_sameDevice") { root in
      try DirectoryFixture.makeTree(in: root)
      for options in [
        DirectoryWalk.Options(), .boundedDescriptors, .includesStatus, .includesRoot,
      ] {
        for order in [DirectoryWalk.Order.preorder, .postorder, .preorderAndPostorder] {
          for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
            let without = try visits(root, order: order, opening: opening, options: options)
            let with = try visits(
              root, order: order, opening: opening, options: options.union(.sameDevice))
            #expect(with == without, "\(order), \(opening), \(options)")
            #expect(without.count >= DirectoryFixture.treePaths.count)
          }
        }
      }
    }
  }

  /// A directory on another device is visited, once or twice as the order
  /// says, and the walk doesn't go into it; without the option, it does.
  /// The walk skips every other directory, so that it reads only the parent.
  @available(System 199, *)
  @Test(.enabled(if: directoryOnAnotherDevice() != nil, "no directory on another device"))
  func aDirectoryOnAnotherDeviceIsntEntered() throws {
    let found = try #require(directoryOnAnotherDevice())
    let parent = FilePath(found.parent)
    let name = try #require(FilePath.Component(found.name))
    for options in [
      DirectoryWalk.Options.sameDevice, [.sameDevice, .boundedDescriptors],
      [.sameDevice, .includesStatus],
    ] {
      for order in [DirectoryWalk.Order.preorder, .preorderAndPostorder] {
        for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
          var walk = try DirectoryWalk(parent, order: order, opening: opening, options: options)
          var visits: [Bool] = []
          var visitedJustBefore = false
          while let entry = try walk.next() {
            if entry.depth > 1 {
              Issue.record("went into \(entry.path), \(order), \(opening), \(options)")
              break
            }
            if entry.name == name {
              #expect(entry.error == nil, "\(order), \(opening), \(options)")
              #expect(entry.type == .directory)
              // Its second visit comes right after its first.
              #expect(!entry.isPostorderVisit || visitedJustBefore)
              visits.append(entry.isPostorderVisit)
              visitedJustBefore = true
              continue
            }
            visitedJustBefore = false
            if entry.type == .directory { walk.skipDescendants() }
          }
          let expected = order == .preorder ? [false] : [false, true]
          #expect(visits == expected, "\(order), \(opening), \(options)")
        }
      }
    }
    // Without the option, the walk goes into it.
    var walk = try DirectoryWalk(parent, opening: .whenEntered)
    var wentIn = false
    while let entry = try walk.next() {
      if entry.depth > 1 {
        wentIn = entry.path.starts(with: parent.appending(name))
        break
      }
      if entry.type == .directory && entry.name != name { walk.skipDescendants() }
    }
    #expect(wentIn)
  }

  /// A postorder walk, which can't skip a directory's contents, visits the
  /// directory on another device once, after nothing. It runs where that
  /// directory is in /dev, as /dev/pts is on Linux, so that the walk reads
  /// only /dev.
  @available(System 199, *)
  @Test(.enabled(
    if: directoryOnAnotherDevice(in: ["/dev"]) != nil, "no directory on another device in /dev"))
  func aPostorderWalkVisitsItOnce() throws {
    let found = try #require(directoryOnAnotherDevice(in: ["/dev"]))
    let parent = FilePath(found.parent)
    let directory = parent.appending(found.name)
    for options in [DirectoryWalk.Options.sameDevice, [.sameDevice, .boundedDescriptors]] {
      var walk = try DirectoryWalk(parent, order: .postorder, options: options)
      var visits: [DirectoryWalk.Entry] = []
      var count = 0
      while let entry = try walk.next() {
        count += 1
        if entry.path.starts(with: directory) && entry.path != directory {
          Issue.record("went into \(directory): \(entry.path), \(options)")
          break
        }
        if entry.path == directory { visits.append(entry) }
        // A bound, should /dev hold a big tree on its own device.
        if count > 100_000 { break }
      }
      #expect(visits.count == 1, "\(options)")
      #expect(visits.first?.isPostorderVisit == true)
      #expect(visits.first?.error == nil)
    }
  }

  #if !os(WASI) // WASI's files have no permissions
  /// A directory whose status can't be read isn't opened: the error from
  /// getting its status is the entry's, as an error from opening it would
  /// be without the option.
  @available(System 199, *)
  @Test(.enabled(if: geteuid() != 0, "root can search any directory"))
  func aDirectoryWhoseStatusCantBeRead() throws {
    try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_sameDeviceNoStatus") { root in
      let listed = root.appending("listed")
      let directory = listed.appending("directory")
      try DirectoryFixture.directory(listed)
      try DirectoryFixture.directory(directory)
      try listed.setPermissions(.ownerRead)
      defer { try? listed.setPermissions(.ownerReadWriteExecute) }
      for opening in [DirectoryWalk.DirectoryOpening.whenRead, .whenEntered] {
        var walk = try DirectoryWalk(
          root, order: .preorderAndPostorder, opening: opening, options: .sameDevice)
        var listedErrors: [Errno?] = []
        var directoryErrors: [Errno?] = []
        while let entry = try walk.next() {
          #expect(!entry.path.starts(with: directory) || entry.path == directory)
          if entry.path == listed { listedErrors.append(entry.error) }
          if entry.path == directory { directoryErrors.append(entry.error) }
        }
        #expect(listedErrors == [nil, nil], "\(opening)")
        // Its only visit has the error, or with `.whenEntered`, its second
        // visit, in place of its contents (or its only one, if the
        // directory doesn't record its type, which can't be read either).
        #expect(directoryErrors.last.flatMap { $0 } == .permissionDenied, "\(opening)")
        #expect(directoryErrors.dropLast().allSatisfy { $0 == nil })
      }
    }
  }
  #endif
}

#endif // !os(Windows)
