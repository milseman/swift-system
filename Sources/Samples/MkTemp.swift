/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct MkTemp: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mktemp",
    abstract: "Make a file or directory with a unique name, as mktemp(1) does, describe it, and remove it"
  )

  @Flag(name: .short, help: "Make a directory rather than a file")
  var directory = false

  @Flag(help: "Keep what was made, rather than removing it")
  var keep = false

  @Argument(help: "A template ending in at least six X's; relative ones are in the temporary directory")
  var template: String = "system-samples.XXXXXXXX"

  func run() throws {
    let base = FilePath.temporaryDirectory()
    print("temporary directory: \(base)")
    var path = FilePath(template)
    if !path.isAbsolute { path = base.pushing(path) }

    let made: FilePath
    if directory {
      made = try path.makeUniqueDirectory()
    } else {
      let (file, fd) = try path.makeUniqueFile(options: .closeOnExec)
      try fd.close()
      made = file
    }
    print("made: \(made)")
    // The temporary directory can be behind a symbolic link, as /var and
    // /tmp are on Darwin.
    print("canonical path: \(try made.canonicalized())")

    // Reading the creation mask means setting it and setting it back,
    // which another thread could see in between.
    let mask = FilePermissions.setCreationMask([])
    FilePermissions.setCreationMask(mask)
    let permissions = try made.stat().permissions
    print("permissions: 0o\(String(permissions.rawValue, radix: 8)), with a creation mask of 0o\(String(mask.rawValue, radix: 8))")

    if keep {
      print("kept")
    } else {
      // remove(3) takes a file or an empty directory alike.
      try made.remove()
      print("removed")
    }
  }
}

#else
struct MkTemp: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mktemp",
    abstract: "Unavailable: System has no mkstemp or mkdtemp on Windows or WASI"
  )

  func run() throws {
    complain("mktemp isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
