/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Checks of the prototype, which run.sh builds as a client of SystemPackage
// and MemoryPrototype, and runs. Each check prints "ok" or what failed.

import SystemPackage
import MemoryPrototype
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

nonisolated(unsafe) var failures = 0

func expect(_ condition: Bool, _ what: String, line: Int = #line) {
  if !condition {
    failures += 1
    print("  FAIL (line \(line)): \(what)")
  }
}

func check(_ name: String, _ body: () throws -> Void) {
  let before = failures
  do { try body() } catch {
    failures += 1
    print("  FAIL: threw \(error)")
  }
  print("\(failures == before ? "ok" : "FAILED"): \(name)")
}

func address(_ pointer: UnsafeRawPointer?) -> Int { Int(bitPattern: pointer) }

@available(System 199, *)
func elements<T: BitwiseCopyable>(_ buffer: borrowing Memory.Buffer<T>) -> [T] {
  buffer.withUnsafeBufferPointer { Array($0) }
}

// MARK: - Buffers

@available(System 199, *)
func checkBuffers() {
  check("an empty buffer has room, and grows by realloc as it's appended to") {
    var buffer = try Memory.Buffer<Int>(capacity: 4)
    expect(buffer.count == 0 && buffer.capacity == 4 && buffer.isEmpty, "empty, with room for 4")
    for i in 0..<4 { try buffer.append(i) }
    expect(buffer.capacity == 4, "appending within capacity doesn't grow")
    for i in 4..<100 { try buffer.append(i) }
    expect(buffer.count == 100 && buffer.capacity >= 100, "grew to hold 100")
    expect(elements(buffer) == Array(0..<100), "kept every element in order")
    buffer.removeLast(90)
    expect(elements(buffer) == Array(0..<10), "removeLast")
    let capacity = buffer.capacity
    buffer.removeAll()
    expect(buffer.isEmpty && buffer.capacity == capacity, "removeAll keeps the capacity")
  }

  check("growth asks for whole blocks, on Darwin") {
    var bytes = try Memory.Buffer<UInt8>(capacity: 0)
    try bytes.append(1)
    #if canImport(Darwin)
    expect(bytes.capacity == Memory.goodSize(for: 16), "grew to a good size, not 1: \(bytes.capacity)")
    #else
    expect(bytes.capacity >= 1, "grew")
    #endif
    try bytes.reserveCapacity(1000)
    expect(bytes.capacity >= 1000, "reserveCapacity")
    try bytes.shrinkToFit()
    expect(bytes.capacity >= 1 && bytes.capacity < 1000, "shrinkToFit: \(bytes.capacity)")
    expect(elements(bytes) == [1], "kept the byte")
  }

  check("repeating zeros allocates zeroed memory, and other values fill it") {
    let zeros = try Memory.Buffer<Int64>(repeating: 0, count: 1000)
    expect(zeros.count == 1000 && elements(zeros).allSatisfy { $0 == 0 }, "1000 zeros")
    let sevens = try Memory.Buffer<Int64>(repeating: 7, count: 10)
    expect(elements(sevens) == Array(repeating: 7, count: 10), "10 sevens")
    let vectors = try Memory.Buffer<CInterop.IOVec>(repeating: CInterop.IOVec(), count: 3)
    expect(elements(vectors).allSatisfy { $0.iov_base == nil && $0.iov_len == 0 }, "3 empty iovecs")
    let empty = try Memory.Buffer<Int64>(repeating: 0, count: 0)
    expect(empty.isEmpty, "zero copies")
  }

  check("spans cover the elements, not the capacity") {
    var buffer = try Memory.Buffer<UInt16>(capacity: 8)
    try buffer.append(1)
    try buffer.append(2)
    expect(buffer.span.count == 2 && buffer.span[1] == 2, "span")
    expect(buffer.bytes.byteCount == 4, "bytes")
    do {
      var span = buffer.mutableSpan
      span[0] = 10
    }
    expect(elements(buffer) == [10, 2], "mutableSpan writes")
  }

  check("unused capacity fills through an output span") {
    var buffer = try Memory.Buffer<Int>(capacity: 2)
    try buffer.reserveCapacity(10)
    let appended = buffer.withUnusedCapacity { output in
      for i in 0..<5 { output.append(i * i) }
      return output.count
    }
    expect(appended == 5 && elements(buffer) == [0, 1, 4, 9, 16], "appended five squares")
    // A thrown error keeps what was initialized before it.
    struct Stop: Error {}
    do {
      try buffer.withUnusedCapacity { (output: inout OutputSpan<Int>) throws(Stop) in
        output.append(25)
        throw Stop()
      }
    } catch {}
    expect(elements(buffer) == [0, 1, 4, 9, 16, 25], "kept the element before the throw")
  }

  check("a byte buffer reads from a descriptor into its unused capacity") {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    _ = try pipe.writeEnd.writeAll("hello, buffer".utf8)
    var buffer = try Memory.Buffer<UInt8>(capacity: 5)
    try buffer.reserveCapacity(64)
    let read = try buffer.withUnusedByteCapacity { output throws(Errno) in
      try pipe.readEnd.read(into: &output)
    }
    expect(read == 13 && elements(buffer) == Array("hello, buffer".utf8), "read 13 bytes")
    do {
      var bytes = buffer.mutableBytes
      bytes.storeBytes(of: UInt8(ascii: "j"), toByteOffset: 0, as: UInt8.self)
    }
    expect(buffer.span[0] == UInt8(ascii: "j"), "mutableBytes writes")
  }

  check("an aligned buffer stays aligned as it grows") {
    var buffer = try Memory.Buffer<UInt8>(capacity: 10, alignment: 4096)
    expect(buffer.withUnsafeBufferPointer { address($0.baseAddress) } % 4096 == 0, "aligned")
    for i in 0..<10_000 { try buffer.append(UInt8(truncatingIfNeeded: i)) }
    expect(buffer.withUnsafeBufferPointer { address($0.baseAddress) } % 4096 == 0, "still aligned")
    expect(elements(buffer) == (0..<10_000).map { UInt8(truncatingIfNeeded: $0) }, "kept the bytes")
    expect(throws: Errno.invalidArgument) { _ = try Memory.Buffer<UInt8>(capacity: 1, alignment: 3) }
  }

  check("an element type of the largest Swift alignment gets it") {
    // Swift caps a type's alignment at 16, malloc's own, so only an
    // imported C type can need more, which the buffer would then ask for.
    var lines = try Memory.Buffer<CacheLine>(capacity: 1)
    for _ in 0..<20 { try lines.append(CacheLine()) }
    expect(MemoryLayout<CacheLine>.alignment == 16, "the type's alignment")
    expect(lines.withUnsafeBufferPointer { address($0.baseAddress) } % 16 == 0, "aligned")
  }

  check("a capacity too large to represent is noMemory") {
    expect(throws: Errno.noMemory) { _ = try Memory.Buffer<Int64>(capacity: .max / 4) }
    expect(throws: Errno.noMemory) { _ = try Memory.Buffer<Int64>(repeating: 0, count: .max / 4) }
  }

  check("ownership moves to C and back") {
    var buffer = try Memory.Buffer<CChar>(capacity: 8)
    for c in "abc".utf8CString { try buffer.append(c) }
    let (start, count, _) = buffer.relinquish()
    expect(String(cString: start) == "abc" && count == 4, "relinquished the string")
    // C frees what C's malloc allocated.
    Memory.freeFunction(start)

    // And a buffer frees what C allocated.
    let copy = strdup("from C")!
    let adopted = Memory.Buffer(unsafeTaking: copy, count: 7, capacity: 7)
    expect(adopted.withUnsafeBufferPointer { String(cString: $0.baseAddress!) } == "from C", "adopted")
    adopted.free()
  }
}

@_alignment(16)
struct CacheLine: BitwiseCopyable {
  var value: Int64 = 0
}

// Untyped, since Swift 6.2 infers a closure's thrown type as `any Error`.
func expect<E: Error & Equatable>(throws expected: E, _ body: () throws -> Void, line: Int = #line) {
  do {
    try body()
    expect(false, "didn't throw \(expected)", line: line)
  } catch {
    expect((error as? E) == expected, "threw \(error), not \(expected)", line: line)
  }
}

// MARK: - Zones

#if canImport(Darwin)
@available(System 199, *)
func checkZones() {
  check("a buffer in a zone grows in it, and frees to it") {
    let zone = try Memory.Zone.create()
    defer { zone.destroy() }
    let baseline = zone.statistics().blocksInUse
    do {
      var buffer = try Memory.Buffer<Int>(capacity: 1, in: zone)
      for i in 0..<10_000 { try buffer.append(i) }
      let start = buffer.withUnsafeBufferPointer { $0.baseAddress! }
      expect(Memory.Zone(containing: start) == zone, "grew in the zone")
      expect(zone.statistics().blocksInUse == baseline + 1, "one block in use")
    }
    expect(zone.statistics().blocksInUse == baseline, "freed to the zone")
  }

  check("an owned zone destroys itself, and its buffers can't outlive it") {
    let arena = try Memory.OwnedZone(name: "checks")
    let baseline = arena.zone.statistics().blocksInUse
    // The buffers live in a function of their own, which borrows the zone:
    // Swift 6.2 won't let `arena` be consumed after a non-Escapable value
    // borrowed it in the same function, even once the value is gone, and
    // with `var arena` the buffers can't be used past their first
    // statement (Verify/M4).
    try fillZoneBuffers(in: arena, baseline: baseline)
    expect(arena.zone.statistics().blocksInUse == baseline, "the buffers freed to the zone")
    arena.destroy()
  }
}

@available(System 199, *)
func fillZoneBuffers(in arena: borrowing Memory.OwnedZone, baseline: Int) throws {
  var numbers = try Memory.ZoneBuffer<Int>(capacity: 2, in: arena)
  for i in 0..<100 { try numbers.append(i) }
  let points = try Memory.ZoneBuffer<Int32>(repeating: 0, count: 50, in: arena)
  expect(numbers.count == 100 && numbers.span[99] == 99, "appended in the zone")
  expect(points.count == 50 && points.span[49] == 0, "zeroed in the zone")
  expect(arena.zone.statistics().blocksInUse == baseline + 2, "two blocks in the zone")
}
#endif

// MARK: - The I/O vector pool

@available(System 199, *)
func withScratchFile(_ body: (FileDescriptor) throws -> Void) throws {
  let (path, fd) = try FilePath.temporaryDirectory().appending("malloc-pool-XXXXXX").makeUniqueFile()
  defer {
    try? fd.close()
    try? path.remove()
  }
  try body(fd)
}

@available(System 199, *)
func contents(of fd: FileDescriptor) throws -> [UInt8] {
  try fd.seek(offset: 0, from: .start)
  var bytes: [UInt8] = []
  var chunk = [UInt8](repeating: 0, count: 65536)
  while true {
    let n = try chunk.withUnsafeMutableBytes { try fd.read(into: $0) }
    if n == 0 { return bytes }
    bytes += chunk[..<n]
  }
}

@available(System 199, *)
func checkPool() {
  check("a pool gathers buffers into one writev") {
    try withScratchFile { fd in
      var pool = try IOVectorPool()
      expect(pool.limit == (try SystemConfig.value(.maxIOVectors) ?? 0), "IOV_MAX vectors")
      let header = Array("HEAD ".utf8), body = Array("body".utf8), empty: [UInt8] = []
      let written = try header.withUnsafeBytes { h in
        try empty.withUnsafeBytes { e in
          try body.withUnsafeBytes { b in try pool.write([h, e, b], to: fd) }
        }
      }
      expect(written == 9, "wrote 9 bytes")
      expect(pool.lastVectors.map(\.iov_len) == [5, 4], "two vectors; the empty buffer has none")
      expect(try contents(of: fd) == header + body, "the file holds both")
    }
  }

  check("writeAll takes as many writes as the limits need, and resumes inside a buffer") {
    try withScratchFile { fd in
      // Two vectors and 7 bytes a write, so that writes stop inside buffers.
      var pool = try IOVectorPool(limit: 2, byteLimit: 7)
      let capacity = pool.capacity
      let pieces = (0..<10).map { Array(String(repeating: Character(String($0)), count: $0).utf8) }
      let bytes = pieces.flatMap { $0 }
      let buffers = pieces.map { piece in
        let copy = UnsafeMutableRawBufferPointer.allocate(byteCount: piece.count, alignment: 1)
        copy.copyBytes(from: piece)
        return UnsafeRawBufferPointer(copy)
      }
      defer { for buffer in buffers { buffer.deallocate() } }
      let written = try pool.writeAll(buffers, to: fd)
      expect(written == bytes.count, "wrote \(written) of \(bytes.count)")
      expect(try contents(of: fd) == bytes, "in order")
      expect(pool.capacity == capacity, "the pool didn't grow")
    }
  }

  check("a pool of the system's size writes more buffers than IOV_MAX") {
    try withScratchFile { fd in
      var pool = try IOVectorPool()
      let count = 3 * pool.limit + 5
      let storage = [UInt8](repeating: UInt8(ascii: "x"), count: count)
      let written = try storage.withUnsafeBytes { all in
        // One buffer per byte.
        try pool.writeAll((0..<count).map { UnsafeRawBufferPointer(rebasing: all[$0..<($0 + 1)]) }, to: fd)
      }
      expect(written == count, "wrote \(count) one-byte buffers")
      expect(try contents(of: fd) == storage, "all of them")
    }
  }
}

if #available(System 199, *) {
  checkBuffers()
  #if canImport(Darwin)
  checkZones()
  #endif
  checkPool()
}
print(failures == 0 ? "All checks passed." : "\(failures) checks failed.")
exit(failures == 0 ? 0 : 1)
