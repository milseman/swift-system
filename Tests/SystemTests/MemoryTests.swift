/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

private let pageSize = (try? SystemConfig.value(.pageSize)).flatMap { $0 } ?? 4096

private func address(_ pointer: UnsafeMutableRawPointer) -> Int { Int(bitPattern: pointer) }

@Suite("Memory")
private struct MemoryTests {
  @available(System 199, *)
  @Test func allocateHoldsWritesAndIsAlignedForAnyType() throws {
    let block = try Memory.allocate(byteCount: 100)
    defer { Memory.free(block) }
    #expect(address(block) % MemoryLayout<Double>.alignment == 0)
    #expect(address(block) % (2 * MemoryLayout<Int>.size) == 0)
    let bytes = UnsafeMutableRawBufferPointer(start: block, count: 100)
    for i in bytes.indices { bytes[i] = UInt8(i) }
    #expect(bytes.elementsEqual(0..<100))
  }

  @available(System 199, *)
  @Test func zeroBytesAllocateABlockToFree() throws {
    let block = try Memory.allocate(byteCount: 0)
    #if !os(OpenBSD) && !os(WASI)
    #expect(Memory.usableSize(of: block) >= 1)
    #endif
    Memory.free(block)
    Memory.free(try Memory.allocateZeroed(byteCount: 0))
    Memory.free(try Memory.allocateZeroed(count: 0, stride: 8))
    Memory.free(try Memory.allocateZeroed(count: 8, stride: 0))
    Memory.free(try Memory.allocate(byteCount: 0, alignment: 64))
    Memory.free(nil)
  }

  // On 32-bit platforms, Int.max bytes are half the address space, which
  // WebAssembly's allocator can provide.
  #if _pointerBitWidth(_64)
  @available(System 199, *)
  @Test func tooLargeARequestIsNoMemory() {
    #expect(throws: Errno.noMemory) { try Memory.allocate(byteCount: .max) }
    #expect(throws: Errno.noMemory) { try Memory.allocateZeroed(byteCount: .max) }
    #expect(throws: Errno.noMemory) { try Memory.allocate(byteCount: .max, alignment: 64) }
  }
  #endif

  @available(System 199, *)
  @Test func allocateZeroedIsZeros() throws {
    // Large enough to come fresh from the system, and small enough to be
    // a reused block.
    for byteCount in [24, 4096, 1 << 20] {
      let block = try Memory.allocateZeroed(byteCount: byteCount)
      defer { Memory.free(block) }
      #expect(UnsafeRawBufferPointer(start: block, count: byteCount).allSatisfy { $0 == 0 })
    }
    let elements = try Memory.allocateZeroed(count: 10, stride: MemoryLayout<Int64>.stride)
    defer { Memory.free(elements) }
    #expect(UnsafeBufferPointer(start: elements.assumingMemoryBound(to: Int64.self), count: 10)
      .allSatisfy { $0 == 0 })
  }

  @available(System 199, *)
  @Test func aTotalThatOverflowsIsNoMemory() {
    // count * stride would trap; calloc reports it.
    #expect(throws: Errno.noMemory) { try Memory.allocateZeroed(count: .max, stride: 2) }
    // A product past size_t's range on any platform: 1 << 40 is 0 in a
    // 32-bit Int.
    let half = 1 << (Int.bitWidth / 2 + 1)
    #expect(throws: Errno.noMemory) { try Memory.allocateZeroed(count: half, stride: half) }
  }

  @available(System 199, *)
  @Test func reallocateKeepsTheContents() throws {
    var block = try Memory.reallocate(nil, byteCount: 16)
    UnsafeMutableRawBufferPointer(start: block, count: 16).copyBytes(from: 0..<16)
    block = try Memory.reallocate(block, byteCount: 1 << 20)
    #expect(UnsafeRawBufferPointer(start: block, count: 16).elementsEqual(0..<16))
    block = try Memory.reallocate(block, byteCount: 4)
    #expect(UnsafeRawBufferPointer(start: block, count: 4).elementsEqual(0..<4))
    // Zero resizes to one byte, rather than freeing the block.
    block = try Memory.reallocate(block, byteCount: 0)
    #expect(UnsafeRawBufferPointer(start: block, count: 1)[0] == 0)
    Memory.free(block)
  }

  #if _pointerBitWidth(_64) // As for tooLargeARequestIsNoMemory()
  @available(System 199, *)
  @Test func aFailedReallocationLeavesTheBlock() throws {
    let block = try Memory.allocate(byteCount: 8)
    defer { Memory.free(block) }
    block.storeBytes(of: 0x0123_4567_89AB_CDEF, as: UInt64.self)
    #expect(throws: Errno.noMemory) { try Memory.reallocate(block, byteCount: .max) }
    #expect(block.load(as: UInt64.self) == 0x0123_4567_89AB_CDEF)
  }
  #endif

  @available(System 199, *)
  @Test func alignedAllocationIsAligned() throws {
    for alignment in [1, 2, 4, 8, 16, 64, 256, 4096, 1 << 16] {
      let block = try Memory.allocate(byteCount: 100, alignment: alignment)
      defer { Memory.free(block) }
      #expect(address(block) % max(alignment, MemoryLayout<UnsafeRawPointer>.size) == 0)
    }
  }

  @available(System 199, *)
  @Test func anAlignmentThatIsntAPowerOfTwoIsInvalid() {
    for alignment in [0, 3, 24, 100, -8, .min] {
      #expect(throws: Errno.invalidArgument) {
        try Memory.allocate(byteCount: 16, alignment: alignment)
      }
    }
  }

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
  @available(System 199, *)
  @Test func pageAlignedAllocationStartsAPage() throws {
    let block = try Memory.allocatePageAligned(byteCount: 10)
    defer { Memory.free(block) }
    #expect(address(block) % pageSize == 0)
  }
  #endif

  #if os(Linux) && canImport(Glibc)
  @available(System 199, *)
  @Test func pagesAreWholePages() throws {
    let block = try Memory.allocatePages(byteCount: 1)
    defer { Memory.free(block) }
    #expect(address(block) % pageSize == 0)
    #expect(Memory.usableSize(of: block) >= pageSize)
  }
  #endif

  #if !os(OpenBSD) && !os(WASI)
  @available(System 199, *)
  @Test func usableSizeIsAtLeastTheRequest() throws {
    for byteCount in [1, 17, 100, 1000, 100_000] {
      let block = try Memory.allocate(byteCount: byteCount)
      defer { Memory.free(block) }
      #expect(Memory.usableSize(of: block) >= byteCount)
    }
  }
  #endif

  #if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func memoryThatNoZoneAllocatedHasNoSize() {
    var local = 0
    withUnsafeMutableBytes(of: &local) { #expect(Memory.usableSize(of: $0.baseAddress!) == 0) }
  }

  @available(System 199, *)
  @Test func aGoodSizeFillsItsBlock() throws {
    for byteCount in [0, 1, 17, 100, 1000, 100_000] {
      let good = Memory.goodSize(for: byteCount)
      #expect(good >= byteCount)
      let block = try Memory.allocate(byteCount: good)
      defer { Memory.free(block) }
      #expect(Memory.usableSize(of: block) >= good)
    }
  }

  #endif

  @available(System 199, *)
  @Test func theCFunctionValuesAllocate() throws {
    let block = try #require(Memory.allocateFunction(100))
    let grown = try #require(Memory.reallocateFunction(block, 200))
    Memory.freeFunction(grown)
    let zeroed = try #require(Memory.allocateZeroedFunction(4, 8))
    #expect(UnsafeRawBufferPointer(start: zeroed, count: 32).allSatisfy { $0 == 0 })
    Memory.freeFunction(zeroed)
    Memory.freeFunction(nil)
  }

  /// The shapes of NIO's ByteBufferAllocator hooks, which differ from C's
  /// for all but allocation: a context-free closure adapts the others.
  @available(System 199, *)
  @Test func theCFunctionValuesFitNIOsHooks() throws {
    typealias Allocate = @convention(c) (Int) -> UnsafeMutableRawPointer?
    typealias Reallocate = @convention(c) (UnsafeMutableRawPointer?, Int, Int) -> UnsafeMutableRawPointer?
    typealias Deallocate = @convention(c) (UnsafeMutableRawPointer) -> Void
    let allocate: Allocate = Memory.allocateFunction
    let reallocate: Reallocate = { pointer, _, newSize in Memory.reallocateFunction(pointer, newSize) }
    let deallocate: Deallocate = { Memory.freeFunction($0) }
    // The throwing API works in such a closure too, through try?.
    let allocateChecked: Allocate = { try? Memory.allocate(byteCount: $0) }

    let block = try #require(allocate(64))
    let grown = try #require(reallocate(block, 64, 128))
    deallocate(grown)
    deallocate(try #require(allocateChecked(8)))
  }
}

@Suite("Memory functions")
private struct MemoryFunctionTests {
  @available(System 199, *)
  @Test func compareOrdersBytesAsUnsigned() {
    func compare(_ a: [UInt8], _ b: [UInt8]) -> Int {
      a.withUnsafeBytes { a in b.withUnsafeBytes { b in Memory.compare(a, b) } }
    }
    #expect(compare([1, 2, 3], [1, 2, 3]) == 0)
    #expect(compare([1, 2, 3], [1, 2, 4]) == -1)
    #expect(compare([1, 2, 4], [1, 2, 3]) == 1)
    #expect(compare([0x7F], [0x80]) == -1)
    #expect(compare([0xFF], [0x00]) == 1)
    // A buffer that begins the other orders first.
    #expect(compare([1, 2], [1, 2, 3]) == -1)
    #expect(compare([1, 2, 3], [1, 2]) == 1)
    #expect(compare([], []) == 0)
    #expect(compare([], [0]) == -1)
    #expect(compare([0], []) == 1)
    #expect(compare([9], [1, 2]) == 1)
  }

  @available(System 199, *)
  @Test func firstIndexFindsTheFirstMatch() {
    let bytes: [UInt8] = Array("one\ntwo\nthree".utf8)
    bytes.withUnsafeBytes { buffer in
      #expect(Memory.firstIndex(of: UInt8(ascii: "\n"), in: buffer) == 3)
      #expect(Memory.firstIndex(of: UInt8(ascii: "o"), in: buffer) == 0)
      #expect(Memory.firstIndex(of: UInt8(ascii: "e"), in: buffer) == 2)
      #expect(Memory.firstIndex(of: 0, in: buffer) == nil)
      #expect(Memory.firstIndex(of: UInt8(ascii: "\n"), in: UnsafeRawBufferPointer(rebasing: buffer[4...])) == 3)
      #expect(Memory.firstIndex(of: UInt8(ascii: "o"), in: UnsafeRawBufferPointer(rebasing: buffer[..<0])) == nil)
    }
    #expect(Memory.firstIndex(of: 0, in: UnsafeRawBufferPointer(start: nil, count: 0)) == nil)
  }

  @available(System 199, *)
  @Test func secureZeroClearsTheBuffer() {
    var secret = [UInt8](repeating: 0xAB, count: 100)
    secret.withUnsafeMutableBytes { Memory.secureZero(UnsafeMutableRawBufferPointer(rebasing: $0[10..<90])) }
    #expect(secret[..<10].allSatisfy { $0 == 0xAB })
    #expect(secret[10..<90].allSatisfy { $0 == 0 })
    #expect(secret[90...].allSatisfy { $0 == 0xAB })
    Memory.secureZero(UnsafeMutableRawBufferPointer(start: nil, count: 0))
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func spans() {
    let abc = ContiguousArray("abc".utf8), abd = ContiguousArray("abd".utf8)
    let ab = ContiguousArray("ab".utf8)
    #expect(Memory.compare(RawSpan(_elements: abc.span), RawSpan(_elements: abc.span)) == 0)
    #expect(Memory.compare(RawSpan(_elements: abc.span), RawSpan(_elements: abd.span)) == -1)
    #expect(Memory.compare(RawSpan(_elements: abc.span), RawSpan(_elements: ab.span)) == 1)
    #expect(Memory.firstIndex(of: UInt8(ascii: "c"), in: RawSpan(_elements: abc.span)) == 2)
    #expect(Memory.firstIndex(of: UInt8(ascii: "z"), in: RawSpan(_elements: abc.span)) == nil)

    var key = ContiguousArray<UInt8>(repeating: 0x5A, count: 32)
    do {
      var span = key.mutableSpan
      var bytes = span.mutableBytes
      Memory.secureZero(&bytes)
    }
    #expect(key.allSatisfy { $0 == 0 })
  }
}

#endif // !os(Windows)
