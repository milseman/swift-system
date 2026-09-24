/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct ChmodH: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "chmod-h",
    abstract: "Change a symbolic link's own permissions, as chmod -h does, rather than its target's"
  )

  @Argument(help: "Where to make a scratch directory, which is removed afterward")
  var parent: String

  func run() throws {
    let directory = FilePath(parent).appending("chmod-h-demo-\(ProcessID.current.rawValue)")
    try directory.makeDirectory(permissions: .ownerReadWriteExecute)
    let target = directory.appending("target")
    let link = directory.appending("link")
    defer {
      try? link.unlink()
      try? target.unlink()
      try? directory.removeDirectory()
    }
    let file = try FileDescriptor.open(
      target, .writeOnly, options: [.create, .exclusiveCreate],
      permissions: [.ownerReadWrite, .groupRead, .otherRead])
    try file.closeAfter { _ = try file.writeAll("hello".utf8) }
    try link.makeSymbolicLink(to: "target")
    print("Made \(link) -> target")

    var rows = [["", "link", "target", "reading the link", "reading through it"]]
    func step(_ name: String, _ change: () throws -> Void) {
      do {
        try change()
        rows.append([name] + describe(link: link, target: target))
      } catch {
        rows.append([name, "fails: \(error)"])
      }
    }
    step("at the start") {}
    // followTargetSymlink: false changes the link itself, with lchmod.
    step("chmod -h 000 link") {
      try link.setPermissions([], followTargetSymlink: false)
    }
    // By default, the change follows the link to its target, with chmod.
    step("chmod 600 link") {
      try link.setPermissions(.ownerReadWrite)
    }
    // Relative to a directory, .symlinkNoFollow changes the link itself,
    // with fchmodat.
    let fd = try FileDescriptor.open(directory, .readOnly, options: .directory)
    try fd.closeAfter {
      step("chmod -h 755 link") {
        try FilePath("link").setPermissions(
          [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute],
          relativeTo: fd, flags: .symlinkNoFollow)
      }
    }
    printTable(rows)
  }
}

/// Describes the permissions of a link and its target, and what reading
/// the link, and the target through it, gives.
private func describe(link: FilePath, target: FilePath) -> [String] {
  func attempt(_ body: () throws -> String) -> String {
    do { return try body() } catch { return "\(error)" }
  }
  return [
    attempt { symbolic(try link.stat(followTargetSymlink: false).permissions) },
    attempt { symbolic(try target.stat().permissions) },
    // On Darwin, a link's permissions govern reading the link itself,
    // but not following it.
    attempt { "\(try link.readSymbolicLink())" },
    attempt {
      let fd = try FileDescriptor.open(link, .readOnly)
      return try fd.closeAfter {
        var buffer = [UInt8](repeating: 0, count: 64)
        let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
        return String(decoding: buffer[..<count], as: UTF8.self)
      }
    },
  ]
}

/// Formats permissions as ls(1) does, such as "rw-r--r--".
private func symbolic(_ permissions: FilePermissions) -> String {
  let bits: [(FilePermissions, Character)] = [
    (.ownerRead, "r"), (.ownerWrite, "w"), (.ownerExecute, "x"),
    (.groupRead, "r"), (.groupWrite, "w"), (.groupExecute, "x"),
    (.otherRead, "r"), (.otherWrite, "w"), (.otherExecute, "x"),
  ]
  return String(bits.map { permissions.contains($0.0) ? $0.1 : "-" })
}
