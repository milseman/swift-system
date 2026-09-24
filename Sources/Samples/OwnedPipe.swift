/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct OwnedPipe: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-pipe",
    abstract: "Close the ends of an OwnedFD.Pipe by consuming them, and see when end of file comes"
  )

  func run() throws {
    // The ends come out of the pipe one at a time, so each can go its own way.
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    // A read that would wait fails with EAGAIN instead, which tells an empty
    // pipe with a writer from one without, whose reads return end of file.
    let flags = try readEnd.fileDescriptor.statusFlags()
    try readEnd.fileDescriptor.setStatusFlags(flags.union(.nonBlocking))
    print("Took the ends out of an OwnedFD.pipe(), and made the read end nonblocking")

    do {
      let copy = OwnedFD(taking: try writeEnd.fileDescriptor.duplicate())
      print("Duplicated the write end into a second OwnedFD")
      try send("first", andClose: writeEnd)
      // Using writeEnd from here on is a compile-time error.
      print("send(_:andClose:) consumed the write end, writing \"first\"; "
        + "the end closed when the function returned")
      print("  read gets \(describeRead(from: readEnd))")
      print("  read gets \(describeRead(from: readEnd))")
      try copy.writeAll("second".utf8)
      print("The duplicate wrote \"second\", then went out of scope, which closed it")
    }
    print("  read gets \(describeRead(from: readEnd))")
    print("  read gets \(describeRead(from: readEnd))")
  }
}

/// Writes text to a pipe's write end, taking ownership of it,
/// so the end closes when this function returns.
private func send(_ text: String, andClose writeEnd: consuming OwnedFD) throws(Errno) {
  try writeEnd.writeAll(text.utf8)
}

/// Reads what's available from a nonblocking read end, and describes it.
private func describeRead(from readEnd: borrowing OwnedFD) -> String {
  var buffer = [UInt8](repeating: 0, count: 64)
  do {
    let count = try buffer.withUnsafeMutableBytes { try readEnd.read(into: $0) }
    if count == 0 { return "end of file: no write end is left" }
    return "\"\(String(decoding: buffer[..<count], as: UTF8.self))\""
  } catch Errno.wouldBlock {
    return "nothing yet, EAGAIN: a write end is still open"
  } catch {
    return "\(error)"
  }
}
