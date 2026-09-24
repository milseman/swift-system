/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN

struct FDPath: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "fd-path",
    abstract: "Follow an open file across renames and moves by asking its descriptor for its path"
  )

  @Argument(help: "Where to make a scratch directory, which is removed afterward")
  var parent: String

  func run() throws {
    let directory = FilePath(parent).appending("fd-path-demo-\(ProcessID.current.rawValue)")
    try directory.makeDirectory(permissions: .ownerReadWriteExecute)
    let a = directory.appending("a")
    let b = directory.appending("b")
    let c = directory.appending("c")
    try a.makeDirectory(permissions: .ownerReadWriteExecute)
    try b.makeDirectory(permissions: .ownerReadWriteExecute)
    defer {
      for name in ["a/notes.txt", "a/renamed.txt", "b/renamed.txt", "c/renamed.txt", "x", "y"] {
        try? directory.appending(name).unlink()
      }
      for subdirectory in [a, b, c] { try? subdirectory.removeDirectory() }
      try? directory.removeDirectory()
    }

    let original = a.appending("notes.txt")
    let file = try OwnedFD.open(
      original, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    // The path comes from the file itself, so it's absolute, and its
    // symbolic links, such as /tmp, are resolved.
    print("Opened \(original)")
    print("  path() \(describePath(file))")
    // /private is a firmlink into the data volume, which holds the file.
    print("  path(resolvingFirmlinks: true) \(describePath(file, resolvingFirmlinks: true))")

    let steps: [(String, () throws -> Void)] = [
      ("Renamed a/notes.txt to a/renamed.txt", {
        try original.rename(to: a.appending("renamed.txt"))
      }),
      ("Moved it to b/renamed.txt", {
        try a.appending("renamed.txt").rename(to: b.appending("renamed.txt"))
      }),
      ("Renamed directory b to c", { try b.rename(to: c) }),
      // With no name left, the path is the one the file had.
      ("Removed c/renamed.txt, its only name", { try c.appending("renamed.txt").unlink() }),
    ]
    for (step, change) in steps {
      try change()
      print("\(step): path() \(describePath(file))")
    }
    // The open file doesn't need a name.
    let written = try file.writeAll("still writable".utf8)
    print("Wrote \(written) bytes to it anyway")

    // A file with two names reports one of them. Removing that one makes
    // path() fail, although the other still names the file.
    let x = directory.appending("x")
    let y = directory.appending("y")
    let linked = try OwnedFD.open(
      x, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    try y.makeHardLink(to: x)
    print("A second file, with the names x and y: path() \(describePath(linked))")
    try x.unlink()
    print("Removed x, while y remains: path() \(describePath(linked))")

    // A pipe isn't in the file system, so it has no path.
    let pipe = try OwnedFD.pipe()
    print("A pipe: path() \(describePath(pipe.readEnd))")
  }
}

/// Describes the path of the file that an owned descriptor refers to,
/// or how asking for it fails, to follow "path()".
private func describePath(_ fd: borrowing OwnedFD, resolvingFirmlinks: Bool = false) -> String {
  do {
    return "is \(try fd.fileDescriptor.path(resolvingFirmlinks: resolvingFirmlinks))"
  } catch {
    return "fails with \(error)"
  }
}

#else

struct FDPath: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "fd-path",
    abstract: "Unavailable: this platform has no F_GETPATH"
  )

  func run() throws {
    complain("Error: fd-path needs fcntl's F_GETPATH, which only Darwin has")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
