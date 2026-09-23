/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: OwnedFD sample. Positional I/O through borrowed descriptors.

import ArgumentParser
import SystemPackage

struct OwnedCopy: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-copy",
    abstract: "Copy a file and its permissions using OwnedFD and positional I/O"
  )

  @Argument(help: "The file to copy")
  var source: String

  @Argument(help: "The destination, which is created or truncated")
  var destination: String

  func run() throws {
    let input = try OwnedFD.open(FilePath(source), .readOnly)

    // OwnedFD doesn't forward `stat()`.
    let permissions = try input.withDescriptor { try $0.stat() }.permissions

    let output = try OwnedFD.open(
      FilePath(destination), .writeOnly,
      options: [.create, .truncate], permissions: permissions)

    let size = try input.seek(offset: 0, from: .end)
    try copyRange(from: input, to: output, count: size)

    // Close the output explicitly so that a close error is reported.
    // The input is closed when it goes out of scope.
    try output.close()
    print("Copied \(size) bytes from \(source) to \(destination)")
  }
}

/// Copies the first `count` bytes of `source` to the same offsets
/// in `destination`, without using or changing either file offset.
func copyRange(
  from source: borrowing OwnedFD, to destination: borrowing OwnedFD, count: Int64
) throws(Errno) {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { buffer.deallocate() }
  var offset: Int64 = 0
  while offset < count {
    let read = try source.read(fromAbsoluteOffset: offset, into: buffer)
    if read == 0 { break }
    try destination.writeAll(
      toAbsoluteOffset: offset, UnsafeRawBufferPointer(rebasing: buffer[..<read]))
    offset += Int64(read)
  }
}
