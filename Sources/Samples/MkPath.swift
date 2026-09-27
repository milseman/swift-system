/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN

struct MkPath: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mkpath",
    abstract: "Make directories and their missing parents in one call, with mkpath_np"
  )

  @Argument(help: "The directories to make")
  var paths: [String]

  func run() throws {
    var failed = false
    for path in paths.map({ FilePath($0) }) {
      do {
        // A directory that's already there isn't an error.
        let made = try path.makeDirectories(permissions: [
          .ownerReadWriteExecute, .groupReadExecute, .otherReadExecute,
        ])
        print(made ? "Made \(path)" : "\(path) exists")
      } catch Errno.notDirectory {
        complain("Error: \(path), or a directory before it, exists and isn't a directory")
        failed = true
      } catch {
        complain("Error: \(path): \(error)")
        failed = true
      }
    }
    if failed { throw ExitCode.failure }
  }
}

#else

struct MkPath: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mkpath",
    abstract: "Unavailable: this platform has no mkpath_np; see mkdir-p"
  )

  func run() throws {
    complain("Error: mkpath needs Darwin's mkpath_np; mkdir-p works everywhere")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
