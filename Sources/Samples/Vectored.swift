/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

// The vectors are C iovec structures, whose members come from the C library.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

struct Vectored: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vectored",
    abstract: "Write several buffers with one call, and read one call's bytes into several buffers"
  )

  @Argument(help: "Names to send through a pipe")
  var names: [String] = ["ada", "grace", "barbara"]

  func validate() throws {
    guard names.allSatisfy({ $0.utf8.count <= Record.nameBytes }) else {
      throw ValidationError("Each name must fit in \(Record.nameBytes) bytes")
    }
  }

  func run() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("vectored uses Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    try gatherFromAVectorArray(into: pipe.writeEnd)
    print("  read back: \(try readAvailable(from: pipe.readEnd).debugDescription)")
    try exchangeRecords(through: pipe)
  }

  /// Writes every name and a newline after each with one `writev`,
  /// from an array of vectors that could be reused for the next batch,
  /// as an event loop does with its pending writes.
  private func gatherFromAVectorArray(into output: FileDescriptor) throws {
    let newline: [UInt8] = [0x0A]
    let buffers = names.map { Array($0.utf8) }
    let written = try newline.withUnsafeBytes { newline in
      try withBytes(of: buffers) { parts in
        var vectors: [CInterop.IOVec] = []
        vectors.reserveCapacity(parts.count * 2)
        for part in parts {
          vectors.append(CInterop.IOVec(iov_base: .init(mutating: part.baseAddress), iov_len: part.count))
          vectors.append(CInterop.IOVec(iov_base: .init(mutating: newline.baseAddress), iov_len: 1))
        }
        return try vectors.withUnsafeBufferPointer { try output.write(vectors: $0) }
      }
    }
    print("Gathered \(names.count * 2) buffers into one write(vectors:): \(written) bytes")
  }

  /// Sends each name as a fixed-size record, a sequence number and the name,
  /// with one call from two buffers, and reads each record back
  /// into two buffers, with one call.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func exchangeRecords(through pipe: (readEnd: FileDescriptor, writeEnd: FileDescriptor)) throws {
    print("Sending \(names.count) records of a \(Record.numberBytes)-byte number"
      + " and a \(Record.nameBytes)-byte name with writeAll(_:_:):")
    for (index, name) in names.enumerated() {
      let record = Record(number: UInt32(index + 1), name: name)
      // writeAll resumes a partial write inside whichever buffer it stopped in.
      let written = try pipe.writeEnd.writeAll(
        RawSpan(_elements: record.number.span), RawSpan(_elements: record.name.span))
      print("  record \(index + 1): \(written) bytes")
    }

    print("Receiving them with read(into:_:), a number buffer and a name buffer each time:")
    var number = ContiguousArray<UInt8>(repeating: 0, count: Record.numberBytes)
    var name = ContiguousArray<UInt8>(repeating: 0, count: Record.nameBytes)
    for _ in names {
      let count: Int
      do {
        var numberSpan = number.mutableSpan, nameSpan = name.mutableSpan
        var numberBytes = numberSpan.mutableBytes, nameBytes = nameSpan.mutableBytes
        count = try pipe.readEnd.read(into: &numberBytes, &nameBytes)
      }
      // A pipe delivers these records whole: each is smaller than PIPE_BUF.
      let value = number.reduce(0) { $0 << 8 | UInt32($1) }
      let text = String(decoding: name.prefix { $0 != 0 }, as: UTF8.self)
      print("  \(count) bytes: number \(value), name \(text.debugDescription)")
    }
  }
}

/// A record of a big-endian sequence number and a name padded with zeros.
private struct Record {
  static let numberBytes = 4
  static let nameBytes = 12

  var number: ContiguousArray<UInt8>
  var name: ContiguousArray<UInt8>

  init(number: UInt32, name: String) {
    self.number = ContiguousArray((0..<Self.numberBytes).reversed().map {
      UInt8(truncatingIfNeeded: number >> ($0 * 8))
    })
    self.name = ContiguousArray(name.utf8)
    self.name += repeatElement(0, count: Self.nameBytes - self.name.count)
  }
}

/// Calls `body` with the bytes of each of `buffers`.
private func withBytes<R>(
  of buffers: [[UInt8]], _ body: ([UnsafeRawBufferPointer]) throws -> R
) throws -> R {
  func recurse(_ index: Int, _ parts: [UnsafeRawBufferPointer]) throws -> R {
    guard index < buffers.count else { return try body(parts) }
    return try buffers[index].withUnsafeBytes { try recurse(index + 1, parts + [$0]) }
  }
  return try recurse(0, [])
}

/// Reads what's in a pipe now, up to 4 KiB.
private func readAvailable(from input: FileDescriptor) throws -> String {
  var buffer = [UInt8](repeating: 0, count: 4096)
  let count = try buffer.withUnsafeMutableBytes { try input.read(into: $0) }
  return String(decoding: buffer.prefix(count), as: UTF8.self)
}

#else
struct Vectored: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vectored",
    abstract: "Unavailable: System has no vectored I/O on Windows or WASI"
  )

  func run() throws {
    complain("vectored isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
