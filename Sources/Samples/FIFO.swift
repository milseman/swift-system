/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct FIFO: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "fifo",
    abstract: "Pass a message between two descriptors through a FIFO, or named pipe"
  )

  @Argument(help: "The FIFO to create, which is removed afterward")
  var path: String

  @Option(name: .shortAndLong, help: "The message to send")
  var message: String = "Hello through a FIFO"

  func run() throws {
    let fifo = FilePath(path)
    try fifo.makeFIFO(permissions: .ownerReadWrite)
    defer { try? fifo.unlink() }
    print("Created \(fifo), a FIFO")

    // Opening either end of a FIFO waits until the other end is open, so a
    // process that opens both ends can't wait for the first one. Without
    // waiting, opening the write end fails with ENXIO while there's no
    // reader, but opening the read end succeeds.
    let reader = try OwnedFD.open(fifo, .readOnly, options: .nonBlocking)
    let writer = try OwnedFD.open(fifo, .writeOnly)
    print("Opened the read end without waiting, then the write end")

    // Reads don't wait either, so one with nothing to read fails.
    do {
      _ = try readText(from: reader)
    } catch Errno.wouldBlock {
      print("Reading before anything is written fails: \(Errno.wouldBlock)")
    }

    // Nonblocking is a status flag of the open file, so it can be turned off
    // again, to make reads wait for data. OwnedFD doesn't forward fcntl.
    try reader.withDescriptor { fd in
      var flags = try fd.statusFlags()
      flags.remove(.nonBlocking)
      try fd.setStatusFlags(flags)
    }
    print("Turned off nonblocking for the read end")

    try writer.writeAll(message.utf8)
    print("Wrote: \(message)")
    print("Read: \(try readText(from: reader) ?? "")")

    // Once no descriptor has the write end open, reads return end of file.
    try writer.close()
    if try readText(from: reader) == nil {
      print("Closed the write end, so the read end reached end of file")
    }
  }
}

/// Reads up to 1 KiB as UTF-8 text, or returns `nil` at end of file.
private func readText(from fd: borrowing OwnedFD) throws -> String? {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
  return count == 0 ? nil : String(decoding: buffer[..<count], as: UTF8.self)
}
