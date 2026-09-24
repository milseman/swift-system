/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

struct Rename: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Rename a file without replacing another, or swap two files atomically"
  )

  @Argument(help: "The file to rename")
  var source: String

  @Argument(help: "The file's new name")
  var destination: String

  @Flag(help: "Fail if the destination exists, rather than replacing it")
  var exclusive = false

  @Flag(help: "Exchange the source and the destination, which must both exist")
  var swap = false

  func validate() throws {
    if exclusive && swap {
      throw ValidationError("--exclusive and --swap can't be combined")
    }
  }

  func run() throws {
    let source = FilePath(source)
    let destination = FilePath(destination)
    print(describe(source))
    print(describe(destination))

    var options: FilePath.RenameOptions = []
    if exclusive { options.insert(.exclusive) }
    if swap { options.insert(.swap) }
    do {
      try source.rename(to: destination, options: options)
    } catch Errno.fileExists {
      // Checking for the destination and then renaming would leave a window
      // in which another process could create it.
      complain("Error: \(destination) exists, so --exclusive left both files in place")
      throw ExitCode.failure
    } catch Errno.directoryNotEmpty {
      complain("Error: rename can't replace \(destination), a directory with files in it,"
        + " but --swap can exchange it")
      throw ExitCode.failure
    }

    print(swap ? "Swapped \(source) and \(destination)" : "Renamed \(source) to \(destination)")
    print(describe(source))
    print(describe(destination))
  }
}

/// Describes the file at `path` by its inode number,
/// which a rename moves along with the file.
private func describe(_ path: FilePath) -> String {
  do {
    let status = try path.stat(followTargetSymlink: false)
    let kind = status.type == .directory ? "directory" : "\(status.size) bytes"
    return "\(path): inode \(status.inode.rawValue), \(kind)"
  } catch {
    return "\(path): \(error)"
  }
}

#else

struct Rename: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no rename options"
  )

  func run() throws {
    complain("Error: rename needs renamex_np or renameat2, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
