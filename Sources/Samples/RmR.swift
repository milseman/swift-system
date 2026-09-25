/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct RmR: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rm-r",
    abstract: "Remove files and directory trees, as rm -r does, never following a symbolic link"
  )

  @Argument(help: "The files and directories to remove")
  var paths: [String]

  @Flag(name: .shortAndLong, help: "Print each file as it's removed")
  var verbose = false

  func run() throws {
    var failed = false
    for path in paths.map({ FilePath($0) }) {
      if !(try remove(path, verbose: verbose)) { failed = true }
    }
    if failed { throw ExitCode.failure }
  }
}

/// Removes `path` and, if it's a directory, everything under it,
/// printing a line for each failure, and returns whether it removed it.
///
/// A postorder walk visits each directory after its contents, so each
/// directory is empty by the time it's removed. Every removal is relative to
/// the descriptor of the directory it's in, and the walk opens directories
/// the same way without following symbolic links, so replacing a directory
/// with a link partway through can't lead the removal out of the tree.
private func remove(_ path: FilePath, verbose: Bool) throws -> Bool {
  guard let top = try openDirectoryWithoutFollowing(path) else {
    // A file, or a symbolic link, which rm -r removes rather than following.
    do {
      try path.unlink()
    } catch {
      complain("Error: \(path): \(error)")
      return false
    }
    if verbose { print("removed \(path)") }
    return true
  }
  var walk = DirectoryWalk(try DirectoryStream(top), path: path, order: .postorder)
  var removedAll = true
  while let entry = try walk.next() {
    if let error = entry.error {
      complain("Error: \(entry.path): \(error)")
      removedAll = false
      continue
    }
    let name = FilePath(root: nil, components: entry.name)
    do {
      if entry.type == .directory {
        try name.removeDirectory(relativeTo: walk.parentDirectory)
      } else {
        try name.unlink(relativeTo: walk.parentDirectory)
      }
    } catch {
      complain("Error: \(entry.path): \(error)")
      removedAll = false
      continue
    }
    if verbose { print("removed \(entry.path)") }
  }
  guard removedAll else { return false }
  try walk.close()
  do {
    try path.removeDirectory()
  } catch {
    complain("Error: \(path): \(error)")
    return false
  }
  if verbose { print("removed \(path)") }
  return true
}

/// Opens `path` if it's a directory, or returns `nil` if it's a file or a
/// symbolic link, even one to a directory.
///
/// (The pattern catch is in a function of its own because Swift 6.2 crashes
/// compiling one followed by a call that converts an owner, such as
/// `DirectoryStream(top)` above.)
private func openDirectoryWithoutFollowing(_ path: FilePath) throws -> OwnedFD? {
  do {
    return try OwnedFD.open(path, .readOnly, options: [.directory, .noFollow])
  } catch let error where error == .notDirectory || error == .tooManySymbolicLinkLevels {
    // POSIX has O_NOFOLLOW fail on a link with ELOOP. Darwin fails with
    // ENOTDIR instead when O_DIRECTORY is set too.
    return nil
  }
}
