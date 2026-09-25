/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE, sample 1: cross-platform code that uses only the common subset.
// It never switches over a Platform.File, and has no `#if`.
//
// The "same" operations behave differently, and the comments marked
// SEMANTICS say how. The output shows the one that's easiest to miss: a
// positional copy leaves both files' positions alone on Unix, and moves them
// to the end on Windows.

import ArgumentParser
import SystemPackage

struct PlatformCopy: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "copy",
    abstract: "Copy a file, or standard input, with only the common subset of Platform.File"
  )

  @OptionGroup var simulation: SimulationOptions

  @Argument(help: "The file to copy. '-' reads standard input.")
  var source: String

  @Argument(help: "The destination, which is created or truncated")
  var destination: String

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    try copy()
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func copy() throws {
    // SEMANTICS: neither is inherited by child processes, a choice the
    // common subset makes. Unix's default is to inherit; Windows' isn't. On
    // Windows the destination is also shared for reading, writing, and
    // deletion, so another program's exclusive open makes this throw a
    // sharing violation, which Unix has no counterpart for.
    let output = try Platform.File.open(FilePath(destination), .readWrite, .createOrTruncate)
    print("destination: \(output.summary)")

    if source == "-" {
      // SEMANTICS: a Windows process can have no standard input, so the
      // static is optional. A switch borrows it; `if let` would consume it.
      switch Platform.File.standardInput {
      case .some(let input):
        print("source: standard input, \(input.summary)")
        let bytes = try copySequentially(from: input, to: output)
        print("Copied \(bytes) bytes")
      case .none:
        complain("Error: this process has no standard input")
        throw ExitCode.failure
      }
    } else {
      let input = try Platform.File.open(FilePath(source), .read)
      print("source: \(input.summary)")

      // SEMANTICS: extending a file reads back as zeros on both, but Unix
      // file systems leave a hole that uses no space, where Windows writes
      // the zeros unless the file is marked sparse.
      let size = try input.size()
      try output.resize(to: size)
      try copyPositionally(from: input, to: output, count: size)
      print("Copied \(size) bytes, positionally")

      // SEMANTICS: pread and pwrite leave the position where it was; Windows'
      // positional ReadFile and WriteFile move it past what they transferred.
      let inputPosition = try input.seek(offset: 0, from: .current)
      let outputPosition = try output.seek(offset: 0, from: .current)
      print("Positions after the positional copy: source \(inputPosition), destination \(outputPosition)")
      if inputPosition != 0 || outputPosition != 0 {
        print("  (moved: positional transfers move a Windows file pointer)")
      } else {
        print("  (unmoved: positional transfers leave a Unix offset alone)")
      }

      // Closing explicitly reports a close error; the destination's
      // close below matters more.
      try input.close()
    }

    // SEMANTICS: each platform's call for surviving a power failure. Darwin's
    // is F_FULLFSYNC, not fsync, which leaves data in the drive's cache;
    // Linux's is fsync; Windows' is FlushFileBuffers, which on a pipe would
    // wait until the reader drains it.
    try output.flush()

    // SEMANTICS: Unix's close can report a failed write-back, on NFS for
    // example. Windows' can't, so on Windows flush() is where it shows.
    try output.close()
  }
}

/// Copies `source` from its current position to its end, at `destination`'s
/// current position, returning the number of bytes.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func copySequentially(
  from source: borrowing Platform.File, to destination: borrowing Platform.File
) throws(Platform.Error) -> Int64 {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { storage.deallocate() }
  var total: Int64 = 0
  while true {
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    // SEMANTICS: from a pipe or terminal, a read can return less than the
    // buffer holds on both. A Windows console read that Ctrl+C interrupts
    // throws operationAborted instead.
    let count = try source.read(into: &buffer)
    if count == 0 { return total }
    // SEMANTICS: writes everything on both, with a loop on Unix. To a pipe
    // whose reader closed, Unix raises SIGPIPE (and throws brokenPipe if it's
    // ignored); Windows throws noData.
    try destination.write(buffer.bytes)
    total += Int64(count)
  }
}

/// Copies the first `count` bytes of `source` to the same offsets in
/// `destination`, as OwnedCopy's `copyRange` does. Its comment there says
/// this doesn't change either file offset, which holds only on Unix.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func copyPositionally(
  from source: borrowing Platform.File, to destination: borrowing Platform.File, count: Int64
) throws(Platform.Error) {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { storage.deallocate() }
  var offset: Int64 = 0
  while offset < count {
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    let read = try source.read(fromAbsoluteOffset: offset, into: &buffer)
    if read == 0 { break }
    try destination.write(buffer.bytes, toAbsoluteOffset: offset)
    offset += Int64(read)
  }
}
