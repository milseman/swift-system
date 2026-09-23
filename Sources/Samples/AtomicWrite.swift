/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

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

struct AtomicWrite: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "atomic-write",
    abstract: "Replace a file's contents atomically and durably"
  )

  @Argument(help: "The file to replace, or to create")
  var path: String

  @Argument(help: "The new contents")
  var contents: String

  @Option(name: .shortAndLong, help: "The new file's permissions, in octal")
  var permissions: String = "644"

  @Option(name: .shortAndLong, help: "The new file's group ID")
  var group: CInterop.GroupID?

  func validate() throws {
    guard let mode = CInterop.Mode(permissions, radix: 8), mode <= 0o7777 else {
      throw ValidationError("'\(permissions)' isn't an octal file mode")
    }
    guard FilePath(path).lastComponent != nil else {
      throw ValidationError("'\(path)' doesn't name a file")
    }
  }

  func run() throws {
    let target = FilePath(path)
    let name = target.lastComponent!.string
    var directoryPath = target.removingLastComponent()
    if directoryPath.isEmpty { directoryPath = "." }

    // Open the directory once, and resolve each name against it, so that
    // every step applies to the same directory, even if it's renamed.
    let directory = try FileDescriptor.open(directoryPath, .readOnly, options: .directory)
    try directory.closeAfter {
      // Readers never see a partial file: they see the old one, or the new
      // one once it's complete and renamed into place.
      let temporary = ".\(name).\(ProcessID.current.rawValue).tmp"
      let file = try FileDescriptor.open(
        FilePath(temporary), relativeTo: directory, .writeOnly,
        options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
      print("Created \(temporary) in \(directoryPath)")
      do {
        try file.closeAfter {
          try file.writeAll(contents.utf8)
          // Unlike `open`, `setPermissions` doesn't apply the umask.
          try file.setPermissions(FilePermissions(rawValue: CInterop.Mode(permissions, radix: 8)!))
          if let group {
            try file.setOwner(group: GroupID(group))
          }
          try file.synchronize()
        }
        let count = contents.utf8.count
        print("Wrote \(count) \(count == 1 ? "byte" : "bytes"), set its mode to \(permissions)"
          + (group.map { " and its group to \($0)" } ?? "") + ", and flushed it")

        guard renameat(directory.rawValue, temporary, directory.rawValue, name) == 0 else {
          throw Errno(rawValue: errno)
        }
      } catch {
        _ = unlinkat(directory.rawValue, temporary, 0)
        throw error
      }
      // The rename changed the directory; flush that too.
      try directory.synchronize()
      print("Renamed it to \(name), and flushed the directory")
    }
  }
}
