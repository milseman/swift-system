/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Ls: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ls",
    abstract: "List a directory with a directory stream, or a whole tree with a walk"
  )

  @Argument(help: "The directories to list (default: the current directory)")
  var paths: [String] = []

  @Flag(name: .customShort("l"), help: "Show each entry's mode, links, size, and inode")
  var long = false

  @Flag(name: .customShort("R"), help: "List the whole tree, in the order a walk visits it")
  var recursive = false

  func run() throws {
    let paths = self.paths.isEmpty ? ["."] : self.paths
    var failed = false
    for (index, path) in paths.enumerated() {
      if paths.count > 1 { print(index == 0 ? "\(path):" : "\n\(path):") }
      do {
        if recursive {
          try listTree(FilePath(path))
        } else {
          try listDirectory(FilePath(path), long: long)
        }
      } catch {
        complain("Error: \(path): \(error)")
        failed = true
      }
    }
    if failed { throw ExitCode.failure }
  }
}

/// Lists a directory's entries sorted by name, as ls(1) does.
private func listDirectory(_ path: FilePath, long: Bool) throws {
  var stream = try DirectoryStream.open(path)
  var entries: [DirectoryStream.Entry] = []
  while let entry = try stream.next() {
    entries.append(entry)
  }
  entries.sort { $0.name.string < $1.name.string }
  guard long else {
    for entry in entries { print("\(entry.name)\(suffix(entry.type))") }
    try stream.close()
    return
  }
  // Each entry's status comes from its name relative to the stream's
  // descriptor, so the directory's path is resolved only once, by open.
  var rows: [[String]] = []
  for entry in entries {
    let name = FilePath(root: nil, components: entry.name)
    do {
      let status = try name.stat(relativeTo: stream.fileDescriptor, flags: .symlinkNoFollow)
      var shown = "\(entry.name)\(suffix(entry.type))"
      if status.type == .symbolicLink {
        let target = try name.readSymbolicLink(relativeTo: stream.fileDescriptor)
        shown += " -> \(target)"
      }
      rows.append([
        modeString(status.type, status.permissions), "\(status.linkCount)",
        "\(status.size)", "inode \(entry.inode.rawValue)", shown,
      ])
    } catch {
      rows.append(["?", "", "", "inode \(entry.inode.rawValue)", "\(entry.name): \(error)"])
    }
  }
  printTable(rows)
  try stream.close()
}

/// Lists every entry under a directory, indented by depth,
/// in the order a preorder walk visits them.
private func listTree(_ path: FilePath) throws {
  var walk = try DirectoryWalk(path)
  var directories = 0
  var others = 0
  while let entry = try walk.next() {
    let indent = String(repeating: "  ", count: entry.depth - 1)
    if let error = entry.error {
      print("\(indent)\(entry.name)\(suffix(entry.type))  (not listed: \(error))")
    } else {
      print("\(indent)\(entry.name)\(suffix(entry.type))")
    }
    if entry.type == .directory { directories += 1 } else { others += 1 }
  }
  print("\(directories) directories, \(others) other files")
}

/// The mark that `ls -F` puts after a name of the given type.
private func suffix(_ type: FileType?) -> String {
  switch type {
  case .directory?: return "/"
  case .symbolicLink?: return "@"
  case .fifo?: return "|"
  case .socket?: return "="
  case nil: return "?"
  default: return ""
  }
}

/// Formats a file's type and permissions as `ls -l` does, such as "drwxr-xr-x".
private func modeString(_ type: FileType, _ permissions: FilePermissions) -> String {
  let kinds: [(FileType, Character)] = [
    (.directory, "d"), (.symbolicLink, "l"), (.fifo, "p"), (.socket, "s"),
    (.characterSpecial, "c"), (.blockSpecial, "b"),
  ]
  let kind = kinds.first { $0.0 == type }?.1 ?? "-"
  let bits: [(FilePermissions, Character)] = [
    (.ownerRead, "r"), (.ownerWrite, "w"), (.ownerExecute, "x"),
    (.groupRead, "r"), (.groupWrite, "w"), (.groupExecute, "x"),
    (.otherRead, "r"), (.otherWrite, "w"), (.otherExecute, "x"),
  ]
  return String([kind] + bits.map { permissions.contains($0.0) ? $0.1 : "-" })
}
