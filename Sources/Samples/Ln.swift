/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Ln: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ln",
    abstract: "Make a hard or symbolic link, and show what it refers to"
  )

  @Flag(name: .short, help: "Make a symbolic link, rather than a hard link")
  var symbolic = false

  @Flag(name: .customShort("L"), help: "Hard-link to a symbolic link's target")
  var followLink = false

  @Flag(name: .customShort("P"), help: "Hard-link to a symbolic link itself")
  var linkToLink = false

  @Argument(help: "The file to link to")
  var target: String

  @Argument(help: "The link to create")
  var link: String

  func validate() throws {
    if followLink && linkToLink {
      throw ValidationError("-L and -P can't be combined")
    }
    if symbolic && (followLink || linkToLink) {
      throw ValidationError("-L and -P apply only to hard links")
    }
  }

  func run() throws {
    let target = FilePath(target)
    let link = FilePath(link)
    if symbolic {
      // The link stores the target as given, and a relative target is
      // resolved from the link's directory, whenever the link is followed.
      try link.makeSymbolicLink(to: target)
    } else if followLink || linkToLink {
      // Only linkat takes the choice, and it resolves relative paths
      // against directory descriptors.
      let directory = try FileDescriptor.open(".", .readOnly, options: .directory)
      try directory.closeAfter {
        try link.makeHardLink(
          relativeTo: directory, to: target, relativeTo: directory,
          flags: followLink ? .symlinkFollow : [])
      }
    } else {
      // If the target is a symbolic link, link(2) links to the link's
      // target on Darwin, and to the link itself on Linux.
      try link.makeHardLink(to: target)
    }
    print(describe(link))
  }
}

/// Describes the file at `path`, without following a symbolic link.
private func describe(_ path: FilePath) -> String {
  do {
    let status = try path.stat(followTargetSymlink: false)
    let links = "\(status.linkCount) \(status.linkCount == 1 ? "link" : "links")"
    var text = "\(path): inode \(status.inode.rawValue), \(links)"
    if status.type == .symbolicLink {
      text += ", a symbolic link to \(try path.readSymbolicLink())"
    }
    return text
  } catch {
    return "\(path): \(error)"
  }
}
