/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Memory on Windows: the C runtime's allocator, memcmp, memchr, and
// RtlSecureZeroMemory. Everything here is memory the test allocates.
@available(System 199, *)
final class Win32MemoryTests: XCTestCase {
  func testAllocateHoldsWritesAndIsAligned() throws {
    let block = try Memory.allocate(byteCount: 100)
    defer { Memory.free(block) }
    XCTAssertEqual(Int(bitPattern: block) % MemoryLayout<Double>.alignment, 0)
    let bytes = UnsafeMutableRawBufferPointer(start: block, count: 100)
    for i in 0..<100 { bytes[i] = UInt8(i) }
    XCTAssertTrue(bytes.elementsEqual(0..<100))
  }

  func testZeroBytesAllocateABlockToFree() throws {
    let block = try Memory.allocate(byteCount: 0)
    Memory.free(block)
    Memory.free(nil)
  }

  func testTooLargeARequestIsNoMemory() {
    XCTAssertThrowsError(try Memory.allocate(byteCount: .max)) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }
    XCTAssertThrowsError(try Memory.allocateZeroed(count: .max, stride: 2)) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }
  }

  func testAllocateZeroedIsZeros() throws {
    let block = try Memory.allocateZeroed(byteCount: 4096)
    defer { Memory.free(block) }
    XCTAssertTrue(UnsafeRawBufferPointer(start: block, count: 4096).allSatisfy { $0 == 0 })
    let elements = try Memory.allocateZeroed(count: 10, stride: MemoryLayout<Int64>.stride)
    defer { Memory.free(elements) }
    XCTAssertTrue(
      UnsafeBufferPointer(start: elements.assumingMemoryBound(to: Int64.self), count: 10)
        .allSatisfy { $0 == 0 })
  }

  func testReallocateKeepsTheContents() throws {
    var block = try Memory.allocate(byteCount: 16)
    defer { Memory.free(block) }
    let bytes = UnsafeMutableRawBufferPointer(start: block, count: 16)
    for i in 0..<16 { bytes[i] = UInt8(i) }
    block = try Memory.reallocate(block, byteCount: 1 << 20)
    XCTAssertTrue(UnsafeRawBufferPointer(start: block, count: 16).elementsEqual(0..<16))
    block = try Memory.reallocate(block, byteCount: 4)
    XCTAssertTrue(UnsafeRawBufferPointer(start: block, count: 4).elementsEqual(0..<4))
  }

  func testTheCFunctionValuesAllocate() throws {
    let block = try XCTUnwrap(Memory.allocateFunction(32))
    let zeroed = try XCTUnwrap(Memory.allocateZeroedFunction(4, 8))
    XCTAssertTrue(UnsafeRawBufferPointer(start: zeroed, count: 32).allSatisfy { $0 == 0 })
    let grown = try XCTUnwrap(Memory.reallocateFunction(block, 64))
    Memory.freeFunction(grown)
    Memory.freeFunction(zeroed)
  }

  func testComparisons() {
    let a: [UInt8] = [1, 2, 3]
    let b: [UInt8] = [1, 2, 4]
    a.withUnsafeBytes { a in
      b.withUnsafeBytes { b in
        XCTAssertEqual(Memory.compare(a, b), -1)
        XCTAssertEqual(Memory.compare(b, a), 1)
        XCTAssertEqual(Memory.compare(a, a), 0)
        // A buffer that begins the other orders first.
        XCTAssertEqual(Memory.compare(UnsafeRawBufferPointer(rebasing: a[..<2]), a), -1)
        XCTAssertEqual(Memory.compare(UnsafeRawBufferPointer(start: nil, count: 0), a), -1)
      }
    }
    XCTAssertEqual(Memory.compare(a.span.bytes, b.span.bytes), -1)
  }

  func testFirstIndex() {
    let bytes: [UInt8] = [7, 0, 9, 0]
    bytes.withUnsafeBytes { buffer in
      XCTAssertEqual(Memory.firstIndex(of: 0, in: buffer), 1)
      XCTAssertEqual(Memory.firstIndex(of: 9, in: buffer), 2)
      XCTAssertNil(Memory.firstIndex(of: 8, in: buffer))
      XCTAssertNil(Memory.firstIndex(of: 0, in: UnsafeRawBufferPointer(start: nil, count: 0)))
    }
    XCTAssertEqual(Memory.firstIndex(of: 9, in: bytes.span.bytes), 2)
  }

  func testSecureZero() {
    var secret: [UInt8] = Array(repeating: 0xA5, count: 33)
    secret.withUnsafeMutableBytes { Memory.secureZero($0) }
    XCTAssertTrue(secret.allSatisfy { $0 == 0 })

    var other = ContiguousArray<UInt8>(repeating: 0x5A, count: 8)
    do {
      var span = other.mutableSpan
      var bytes = span.mutableBytes
      Memory.secureZero(&bytes)
    }
    XCTAssertTrue(other.allSatisfy { $0 == 0 })

    // An empty buffer is nothing to clear.
    Memory.secureZero(UnsafeMutableRawBufferPointer(start: nil, count: 0))
  }
}

#endif // os(Windows)
