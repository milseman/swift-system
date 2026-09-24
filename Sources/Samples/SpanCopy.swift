/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct SpanCopy: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "span-copy",
    abstract: "Copy a file, or standard input, through a span that tracks how much of its buffer is filled"
  )

  @Argument(help: "The file to copy. '-' reads standard input.")
  var source: String

  @Argument(help: "The destination, which is created or truncated")
  var destination: String

  @Option(name: .shortAndLong, help: "The buffer size, in bytes")
  var bufferSize: Int = 64 * 1024

  func validate() throws {
    guard bufferSize > 0 else {
      throw ValidationError("The buffer size must be positive")
    }
  }

  func run() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("span-copy uses Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    if source == "-" {
      try copy(from: OwnedFD.standardInput)
    } else {
      try copy(from: try OwnedFD.open(FilePath(source), .readOnly))
    }
  }

  /// Copies `input` to the destination,
  /// which isn't created until `input` is open.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func copy(from input: borrowing OwnedFD) throws {
    let output = try OwnedFD.open(
      FilePath(destination), .writeOnly,
      options: [.create, .truncate], permissions: [.ownerReadWrite, .groupRead, .otherRead])
    let (bytes, chunks) = try copyInChunks(from: input, to: output)
    // Close explicitly to report the error that dropping `output` would lose.
    try output.close()
    print("Copied \(bytes) \(bytes == 1 ? "byte" : "bytes")"
      + " in \(chunks) \(chunks == 1 ? "chunk" : "chunks") of up to \(bufferSize) bytes")
  }

  /// Copies everything from `source` to `destination`,
  /// returning the number of bytes and of buffer-sized chunks.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func copyInChunks(
    from source: borrowing OwnedFD, to destination: borrowing OwnedFD
  ) throws(Errno) -> (bytes: Int, chunks: Int) {
    // The standard library can create an OutputRawSpan only over memory
    // it's given, so this is the sample's only unsafe code.
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
    defer { storage.deallocate() }

    var bytes = 0
    var chunks = 0
    while true {
      var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
      // Reads until the buffer is full or the input ends, so only the last
      // chunk can be short, even from a pipe that delivers a little at a time.
      let count = try source.read(filling: &buffer)
      if count == 0 { break }
      // `bytes` covers exactly the part of the buffer that was read into.
      _ = try destination.writeAll(buffer.bytes)
      bytes += count
      chunks += 1
    }
    return (bytes, chunks)
  }
}
