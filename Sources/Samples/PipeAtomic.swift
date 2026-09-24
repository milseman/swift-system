/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct PipeAtomic: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pipe-atomic",
    abstract: "Fill a nonblocking pipe, and show that a write of up to PIPE_BUF bytes is never split"
  )

  func run() throws {
    let pipe = try OwnedFD.pipe()
    // A write of at most PIPE_BUF bytes goes into the pipe whole, so the
    // data of several writers never interleaves within one.
    guard let atomicSize = try SystemConfig.value(
      .maxAtomicPipeWriteBytes, for: pipe.writeEnd.fileDescriptor)
    else {
      complain("Error: this system reports no PIPE_BUF for pipes")
      throw ExitCode.failure
    }
    print("PIPE_BUF for this pipe is \(atomicSize) bytes (fpathconf's _PC_PIPE_BUF)")

    // Without O_NONBLOCK, a write to a full pipe would wait for a reader.
    let flags = try pipe.writeEnd.fileDescriptor.statusFlags()
    try pipe.writeEnd.fileDescriptor.setStatusFlags(flags.union(.nonBlocking))
    print("Turned on O_NONBLOCK for the write end")

    let capacity = try write(1 << 20, to: pipe.writeEnd).get()
    print("A 1 MiB write wrote \(capacity) bytes, as much as the pipe holds")
    let full = write(1, to: pipe.writeEnd)
    print("A 1-byte write \(describe(full, of: 1))"
      + (full.isWouldBlock ? ": the pipe is full" : ""))

    let room = atomicSize / 2
    var buffer = [UInt8](repeating: 0, count: room)
    let read = try buffer.withUnsafeMutableBytes { try pipe.readEnd.read(into: $0) }
    print("Read \(read) bytes, which leaves room for \(read)")

    // A write of PIPE_BUF bytes doesn't fit in the room left, and can't be
    // split, so it fails. One byte more, and it takes what fits.
    let whole = write(atomicSize, to: pipe.writeEnd)
    print("A \(atomicSize)-byte write, PIPE_BUF exactly, \(describe(whole, of: atomicSize))"
      + (whole.isWouldBlock ? ": it's written whole or not at all" : ""))
    let larger = write(atomicSize + 1, to: pipe.writeEnd)
    print("A \(atomicSize + 1)-byte write, one more than PIPE_BUF, "
      + describe(larger, of: atomicSize + 1)
      + (larger.isPartial(of: atomicSize + 1) ? ": a larger write can be split" : ""))
  }
}

/// Writes that many bytes to a pipe's write end, in one call.
private func write(_ count: Int, to fd: borrowing OwnedFD) -> Result<Int, Errno> {
  // Array.withUnsafeBytes rethrows, which would turn Errno into any Error,
  // so the bytes go in a buffer allocated here.
  let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
  defer { bytes.deallocate() }
  bytes.initializeMemory(as: UInt8.self, repeating: 0x2A)
  return Result { () throws(Errno) -> Int in try fd.write(UnsafeRawBufferPointer(bytes)) }
}

/// Describes the result of a write of `count` bytes.
private func describe(_ result: Result<Int, Errno>, of count: Int) -> String {
  switch result {
  case .success(count): return "wrote all \(count) bytes"
  case .success(let written): return "wrote \(written) bytes"
  case .failure(let error): return "fails with \(error)"
  }
}

extension Result<Int, Errno> {
  fileprivate var isWouldBlock: Bool {
    if case .failure(.wouldBlock) = self { return true }
    return false
  }

  fileprivate func isPartial(of count: Int) -> Bool {
    if case .success(let written) = self { return written < count }
    return false
  }
}
