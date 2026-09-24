/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct FDFlags: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "fd-flags",
    abstract: "Show which flags a duplicated descriptor shares with the original"
  )

  func run() throws {
    // A pipe, rather than standard input: the status flags of standard
    // input belong to an open file shared with the shell that started
    // this process, so changing them would change the shell's too.
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    defer {
      try? readEnd.close()
      try? writeEnd.close()
    }

    // Setting close-on-exec as part of duplicating, rather than afterward,
    // means no other thread's exec can inherit the copy in between.
    let copy = try readEnd.duplicate(atLeast: FileDescriptor(rawValue: 10), closeOnExec: true)
    defer { try? copy.close() }
    print("Duplicated descriptor \(readEnd.rawValue), a pipe's read end,"
      + " as descriptor \(copy.rawValue), with close-on-exec")
    // Each descriptor has its own descriptor flags.
    try show(readEnd, copy)

    try readEnd.setStatusFlags(readEnd.statusFlags().union(.nonBlocking))
    print("Turned on nonblocking for descriptor \(readEnd.rawValue)")
    // Both descriptors refer to one open file, which has the status flags.
    try show(readEnd, copy)
  }
}

private func show(_ descriptors: FileDescriptor...) throws {
  for fd in descriptors {
    print("  \(fd.rawValue): descriptor flags \(names(try fd.descriptorFlags()))"
      + ", status flags \(names(try fd.statusFlags()))")
  }
}

private func names(_ flags: FileDescriptor.DescriptorFlags) -> String {
  flags.contains(.closeOnExec) ? "[closeOnExec]" : "[]"
}

private func names(_ flags: FileDescriptor.StatusFlags) -> String {
  var names: [String] = []
  if flags.contains(.nonBlocking) { names.append("nonBlocking") }
  if flags.contains(.append) { names.append("append") }
  return "[\(names.joined(separator: ", "))]"
}
