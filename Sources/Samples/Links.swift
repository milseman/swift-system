/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Links: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Resolve a path one component at a time, showing each symbolic link it follows"
  )

  @Argument(help: "The path to resolve")
  var path: String

  func run() throws {
    let path = FilePath(path)
    // A relative path starts from the working directory, which getcwd
    // reports with its symbolic links already resolved.
    var resolved = path.isAbsolute ? FilePath("/") : try FilePath.currentWorkingDirectory()
    // The components left to resolve, in reverse order, so the next is last.
    var pending = Array(path.components.reversed())
    var linkCount = 0

    while let component = pending.popLast() {
      switch component.kind {
      case .currentDirectory:
        continue
      case .parentDirectory:
        // `resolved` has no symbolic links, so its lexical parent is its
        // actual parent.
        resolved.removeLastComponent()
        continue
      case .regular:
        break
      }

      let next = resolved.appending(component)
      let status: Stat
      do {
        status = try next.stat(followTargetSymlink: false)
      } catch {
        complain("\(next): \(error)")
        throw ExitCode.failure
      }
      guard status.type == .symbolicLink else {
        resolved = next
        continue
      }

      // Darwin gives up after 32 symbolic links, and Linux after 40.
      linkCount += 1
      guard linkCount <= 32 else { throw Errno.tooManySymbolicLinkLevels }
      let target = try next.readSymbolicLink()
      print("\(next) -> \(target)")
      // A relative target is resolved from the link's directory, which
      // `resolved` still is. An absolute one starts over at the root.
      if target.isAbsolute { resolved = FilePath("/") }
      pending.append(contentsOf: target.components.reversed())
    }
    print("\(resolved): \(describe(try resolved.stat()))")
  }
}

private func describe(_ status: Stat) -> String {
  switch status.type {
  case .regular: return "regular file, \(status.size) bytes"
  case .directory: return "directory"
  case .characterSpecial: return "character device"
  case .blockSpecial: return "block device"
  case .fifo: return "FIFO"
  case .socket: return "socket"
  default: return "file of type \(String(status.type.rawValue, radix: 8))"
  }
}
