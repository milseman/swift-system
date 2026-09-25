/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: event notification sample. poll(2) over several pipes, with
// FileDescriptor.poll. OwnedPoll does the same with the C function.

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct EventsPoll: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "events-poll",
    abstract: "Wait on several pipes with FileDescriptor.poll, and see a timeout and a hang-up"
  )

  func run() throws {
    guard #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) else {
      complain("events-poll uses Duration, which requires macOS 13 or later")
      throw ExitCode.failure
    }
    try waitOnPipes()
  }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
private func waitOnPipes() throws {
  let first = try OwnedFD.pipe()
  let second = try OwnedFD.pipe()
  let third = try OwnedFD.pipe()
  try second.writeEnd.writeAll("second".utf8)
  try third.writeEnd.writeAll("third".utf8)

  // The entries name the read ends, which stay open while the pipes do.
  var entries = [
    FileDescriptor.PollEntry(first.readEnd.fileDescriptor, events: .readable),
    FileDescriptor.PollEntry(second.readEnd.fileDescriptor, events: .readable),
    FileDescriptor.PollEntry(third.readEnd.fileDescriptor, events: .readable),
  ]
  let ready = try poll(&entries, timeout: .seconds(1))
  print("\(ready) of \(entries.count) pipes are readable")
  for (index, entry) in entries.enumerated() where entry.returnedEvents.contains(.readable) {
    let text = try readText(from: entry.fileDescriptor)
    print("  pipe \(index): \"\(text)\"")
  }

  // Everything was read, so polling again waits for the whole timeout.
  let start = ContinuousClock.now
  let readyAgain = try poll(&entries, timeout: .milliseconds(50))
  let waited = (ContinuousClock.now - start) / .milliseconds(1)
  print("Then \(readyAgain) pipes were readable, after waiting at least 50 ms: \(waited >= 50)")

  // Polling reports a hang-up whether or not an entry asks for it.
  let writeEnd = first.writeEnd
  try writeEnd.close()
  try poll(&entries, timeout: .zero)
  print("Once pipe 0's write end closed, polling reported \(entries[0].returnedEvents) for it")
}

/// Polls `entries` through a mutable span over the array's storage.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@discardableResult
private func poll(
  _ entries: inout [FileDescriptor.PollEntry], timeout: Duration?
) throws -> Int {
  // Array's mutableSpan needs macOS 26, so the span comes from its buffer.
  try entries.withUnsafeMutableBufferPointer { buffer in
    var span = MutableSpan(_unsafeElements: buffer)
    return try FileDescriptor.poll(&span, timeout: timeout)
  }
}

/// Reads whatever is available from `file`, up to 1 KiB, as UTF-8 text.
private func readText(from file: FileDescriptor) throws -> String {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { buffer.deallocate() }
  let count = try file.read(into: buffer)
  return String(decoding: buffer[..<count], as: UTF8.self)
}

#else
struct EventsPoll: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "events-poll",
    abstract: "Unavailable: this platform has no poll"
  )

  func run() throws {
    complain("Error: events-poll needs poll, which this platform doesn't have")
    throw ExitCode.failure
  }
}
#endif // !os(Windows) && !os(WASI)
