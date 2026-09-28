/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Growing a buffer that's in use, by doubling, from 4 KiB to a final size.
// Memory.Buffer grows through realloc, which can grow a block in place; the
// standard library's allocation can only allocate anew and copy, as Array
// does. Each step writes every byte of the buffer's new half, with memset,
// so that its pages are in memory when it next grows.
//
//   bench <realloc | allocate-copy | array> <final size in bytes>
//
// prints the best of 5 runs, in microseconds. run.sh runs each variant and
// size in a process of its own, since the allocator keeps large freed
// blocks for reuse, which favors whichever runs later. It builds this with
// -O against a release build of SystemPackage.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func growBuffer(to finalSize: Int) throws {
  var buffer = try Memory.Buffer<UInt8>(capacity: 4096)
  var size = 0
  var next = 4096
  while size < finalSize {
    try buffer.reserveCapacity(next)
    let count = next - size
    buffer.withUnusedByteCapacity { output in
      output.withUnsafeMutableBytes { unused, initialized in
        (unused.baseAddress! + initialized).initializeMemory(as: UInt8.self, repeating: 1, count: count)
        initialized += count
      }
    }
    (size, next) = (next, 2 * next)
  }
  precondition(buffer.count == finalSize)
}

func growStandardLibrary(to finalSize: Int) {
  var size = 4096
  var buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 16)
  buffer.initializeMemory(as: UInt8.self, repeating: 1)
  while size < finalSize {
    let grown = UnsafeMutableRawBufferPointer.allocate(byteCount: 2 * size, alignment: 16)
    grown.copyMemory(from: UnsafeRawBufferPointer(buffer))
    buffer.deallocate()
    buffer = grown
    (buffer.baseAddress! + size).initializeMemory(as: UInt8.self, repeating: 1, count: size)
    size *= 2
  }
  buffer.deallocate()
}

func growArray(to finalSize: Int) {
  var array = [UInt8](repeating: 1, count: 4096)
  while array.count < finalSize {
    array.reserveCapacity(2 * array.count)
    array.append(contentsOf: repeatElement(1, count: array.count))
  }
  precondition(array.count == finalSize)
}

if #available(System 199, *) {
  let arguments = Array(CommandLine.arguments.dropFirst())
  guard arguments.count == 2, let finalSize = Int(arguments[1]), finalSize >= 4096 else {
    fatalError("usage: bench <realloc | allocate-copy | array> <final size>")
  }
  var best = Duration.seconds(1_000)
  for _ in 0..<5 {
    let start = ContinuousClock.now
    switch arguments[0] {
    case "realloc": try growBuffer(to: finalSize)
    case "allocate-copy": growStandardLibrary(to: finalSize)
    case "array": growArray(to: finalSize)
    default: fatalError("unknown variant \(arguments[0])")
    }
    best = min(best, ContinuousClock.now - start)
  }
  let (seconds, attoseconds) = best.components
  print(seconds * 1_000_000 + attoseconds / 1_000_000_000_000)
}
