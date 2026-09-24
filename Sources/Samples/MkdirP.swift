/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct MkdirP: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mkdir-p",
    abstract: "Make directories and any missing parents, as mkdir -p does, one name at a time"
  )

  @Argument(help: "The directories to make")
  var paths: [String]

  func run() throws {
    var failed = false
    for path in paths.map({ FilePath($0) }) {
      if !(try makeDirectories(path)) { failed = true }
    }
    if failed { throw ExitCode.failure }
  }
}

/// Makes a directory and any missing parents, printing a line for each,
/// and returns whether it succeeded.
///
/// Each name is resolved against a descriptor for the directory before it,
/// so the path is only looked up once, and renaming a directory partway
/// through can't send the rest somewhere else.
private func makeDirectories(_ path: FilePath) throws -> Bool {
  // System has no AT_FDCWD, so a relative path starts from ".".
  let start = path.root.map { FilePath(root: $0) } ?? "."
  var parent = try FileDescriptor.open(start, .readOnly, options: .directory)
  defer { try? parent.close() }
  let components = path.components
  for index in components.indices {
    let name = FilePath(root: nil, components: components[index])
    let soFar = FilePath(root: path.root, components[...index])
    let directory: FileDescriptor
    let made: Bool
    do {
      (directory, made) = try openOrMake(name, in: parent)
    } catch Errno.notDirectory {
      complain("Error: \(soFar) exists, and isn't a directory")
      return false
    } catch {
      complain("Error: \(soFar): \(error)")
      return false
    }
    try parent.close()
    parent = directory
    print(made ? "Made \(soFar)" : "\(soFar) exists")
  }
  return true
}

/// Opens the directory `name` in `parent`, making it first if it doesn't
/// exist, and reports whether it did.
private func openOrMake(
  _ name: FilePath, in parent: FileDescriptor
) throws -> (directory: FileDescriptor, made: Bool) {
  while true {
    // Checking for the directory and then making it would leave a window
    // in which another process could make it. Making it and accepting
    // EEXIST leaves none. The umask applies, as it does for mkdir(1).
    var made = true
    do {
      try name.makeDirectory(relativeTo: parent, permissions: FilePermissions(rawValue: 0o777))
    } catch Errno.fileExists {
      made = false
    }
    // Something else of that name, such as a file, throws ENOTDIR.
    do {
      let directory = try FileDescriptor.open(name, relativeTo: parent, .readOnly, options: .directory)
      return (directory, made)
    } catch Errno.noSuchFileOrDirectory where !made {
      // The name existed a moment ago. If it's a symbolic link to nothing,
      // give up. Otherwise, another process removed it, so make it again.
      if (try? name.stat(relativeTo: parent, flags: .symlinkNoFollow)) != nil {
        throw Errno.noSuchFileOrDirectory
      }
    }
  }
}
