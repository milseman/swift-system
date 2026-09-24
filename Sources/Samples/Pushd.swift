/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Pushd: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Return to a working directory through a descriptor, which, unlike a path, survives a rename"
  )

  @Argument(help: "Where to make a scratch directory, which is removed afterward")
  var parent: String

  func run() throws {
    // Resolve every path against the parent's descriptor, so that relative
    // paths keep their meaning as the working directory changes.
    let parent = try FileDescriptor.open(FilePath(parent), .readOnly, options: .directory)
    defer { try? parent.close() }
    let name = FilePath("pushd-demo-\(ProcessID.current.rawValue)")
    let newName = FilePath("\(name)-renamed")
    try name.makeDirectory(relativeTo: parent, permissions: .ownerReadWriteExecute)
    defer {
      // Leave the scratch directory, then remove it by whichever name it has.
      try? FilePath.setCurrentWorkingDirectory(parent)
      try? name.removeDirectory(relativeTo: parent)
      try? newName.removeDirectory(relativeTo: parent)
    }

    let saved = try FileDescriptor.open(name, relativeTo: parent, .readOnly, options: .directory)
    defer { try? saved.close() }
    try FilePath.setCurrentWorkingDirectory(saved)
    let savedPath = try FilePath.currentWorkingDirectory()
    print("Working in \(savedPath)")

    try FilePath.setCurrentWorkingDirectory(parent)
    print("Changed to \(try FilePath.currentWorkingDirectory())")
    try name.rename(relativeTo: parent, to: newName, relativeTo: parent)
    print("Renamed \(name) to \(newName)")

    // Returning by path, as a shell's popd does, finds nothing there now...
    do {
      try FilePath.setCurrentWorkingDirectory(savedPath)
      print("Changed back to \(savedPath)")
    } catch {
      print("Changing back to \(savedPath) fails: \(error)")
    }
    // ...but the descriptor still refers to the directory itself.
    try FilePath.setCurrentWorkingDirectory(saved)
    print("Changing back through the saved descriptor works: now in \(try FilePath.currentWorkingDirectory())")
  }
}
