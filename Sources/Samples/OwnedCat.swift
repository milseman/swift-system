/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: OwnedFD sample. Reads standard input through `OwnedFD.standardInput`.

import ArgumentParser
import SystemPackage

struct OwnedCat: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owned-cat",
    abstract: "Concatenate files, or standard input, to standard output using OwnedFD"
  )

  @Argument(help: "Files to concatenate. '-' or no arguments reads standard input.")
  var paths: [String] = []

  func run() throws {
    guard !paths.isEmpty else {
      try copyAll(from: OwnedFD.standardInput, to: OwnedFD.standardOutput)
      return
    }
    for path in paths {
      if path == "-" {
        try copyAll(from: OwnedFD.standardInput, to: OwnedFD.standardOutput)
        continue
      }
      let file = try OwnedFD.open(FilePath(path), .readOnly)
      try copyAll(from: file, to: OwnedFD.standardOutput)
      // Close explicitly to report the error; letting `file` go out of scope
      // would also close it, but would drop the error.
      try file.close()
    }
  }
}

/// Copies everything from `source` to `destination`.
///
/// Both parameters are borrowed, so this function can't close either
/// descriptor or keep it after returning.
func copyAll(
  from source: borrowing OwnedFD, to destination: borrowing OwnedFD
) throws(Errno) {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { buffer.deallocate() }
  while true {
    let count = try source.read(into: buffer)
    if count == 0 { return }
    try destination.writeAll(UnsafeRawBufferPointer(rebasing: buffer[..<count]))
  }
}
