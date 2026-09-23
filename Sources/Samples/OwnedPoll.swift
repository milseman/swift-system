/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: OwnedFD sample. A poll(2) loop over a table of owned descriptors.

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

struct OwnedPoll: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-poll",
    abstract: "Wait on several pipes with poll(2), keeping each end in an OwnedFD"
  )

  func run() throws {
    guard #available(macOS 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *) else {
      complain("owned-poll uses InlineArray, which requires macOS 26 or later")
      return
    }
    try pollPipes()
  }
}

@available(macOS 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *)
func pollPipes() throws {
  // `Array` requires copyable elements, so the table is a fixed-size
  // InlineArray. A tuple can't hold noncopyable values either, so each pipe
  // is an OwnedFD.Pipe, which owns both ends.
  let pipes = try InlineArray<3, OwnedFD.Pipe> { _ in try OwnedFD.pipe() }

  // Swift 6.2 rejects `pipes[i].readEnd.read(...)` with "unexpected
  // exclusivity violation. This is a compiler bug", so each use below passes
  // the whole element to a function that borrows it.
  try send("first", through: pipes[0])
  try send("third", through: pipes[2])

  var pollDescriptors: [pollfd] = []
  for i in pipes.indices {
    pollDescriptors.append(pollDescriptor(forReadEndOf: pipes[i]))
  }
  let readyCount = pollDescriptors.withUnsafeMutableBufferPointer {
    poll($0.baseAddress, nfds_t($0.count), 0)
  }
  guard readyCount >= 0 else { throw Errno(rawValue: errno) }

  print("\(readyCount) of \(pipes.count) pipes are readable")
  for i in pipes.indices where pollDescriptors[i].revents & Int16(POLLIN) != 0 {
    print("pipe \(i): \(try readAvailable(from: pipes[i]))")
  }
}

func send(_ text: String, through pipe: borrowing OwnedFD.Pipe) throws(Errno) {
  try pipe.writeEnd.writeAll(text.utf8)
}

/// Describes the read end of `pipe` for poll(2).
///
/// The raw descriptor in the result stays valid only while `pipe` is alive.
func pollDescriptor(forReadEndOf pipe: borrowing OwnedFD.Pipe) -> pollfd {
  // poll(2) takes raw descriptors, and System doesn't wrap it.
  pollfd(fd: pipe.readEnd.fileDescriptor.rawValue, events: Int16(POLLIN), revents: 0)
}

/// Reads whatever is available from the read end of `pipe`,
/// up to 1 KiB, as UTF-8 text.
func readAvailable(from pipe: borrowing OwnedFD.Pipe) throws(Errno) -> String {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { buffer.deallocate() }
  let count = try pipe.readEnd.read(into: buffer)
  return String(decoding: buffer[..<count], as: UTF8.self)
}
