/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct MMap: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mmap",
    abstract: "Count a file's lines through a memory mapping, watching its pages come into memory"
  )

  @Argument(help: "The file to map")
  var path: String

  func run() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("mmap uses Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let fd = try FileDescriptor.open(FilePath(path), .readOnly)
    defer { try? fd.close() }
    let size = Int(try fd.stat().size)
    guard size > 0 else {
      print("\(path) is empty, and an empty mapping isn't allowed")
      return
    }

    // The mapping doesn't need the descriptor after this.
    let mapping = try MemoryMapping(file: fd, byteCount: size)
    print("Mapped \(amount(Int64(size))) of \(path)")
    try report(mapping, "before reading")

    // Sequential advice lets the system read ahead, and drop pages behind.
    try mapping.advise(.sequential)
    print("\(countLines(mapping)) lines, counted without copying the file")
    try report(mapping, "after reading")

    // Unmapping reports an error, where dropping the mapping would ignore it.
    try mapping.unmap()
  }

  /// Counts the newlines in the mapping.
  ///
  /// The span borrows the mapping, which can't be unmapped while it lives.
  /// It's read here, in a function of its own, because Swift 6.2 won't let
  /// `run()` consume a `let` mapping after a span has borrowed it there,
  /// even once the span is gone.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func countLines(_ mapping: borrowing MemoryMapping) -> Int {
    mapping.bytes.withUnsafeBytes { $0.reduce(0) { $1 == UInt8(ascii: "\n") ? $0 + 1 : $0 } }
  }

  private func report(_ mapping: borrowing MemoryMapping, _ when: String) throws {
    #if !os(OpenBSD)
    let pages = try mapping.residentPages()
    print("  \(pages.filter { $0 }.count) of \(pages.count) pages in memory \(when)")
    #endif
  }
}

#else
struct MMap: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mmap",
    abstract: "Unavailable: System has no memory mapping on Windows or WASI"
  )

  func run() throws {
    complain("mmap isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
