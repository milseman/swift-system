/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class VectoredIOMockTests: XCTestCase {
  #if ENABLE_MOCKING
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  func testSyscalls() throws {
    let fd = FileDescriptor(rawValue: 3)
    let storage = UnsafeMutableBufferPointer<CInterop.IOVec>.allocate(capacity: 2)
    defer { storage.deallocate() }
    storage.initialize(repeating: CInterop.IOVec())
    let vectors = UnsafeBufferPointer(storage)
    let base = vectors.baseAddress!

    let cases: [MockTestCase] = [
      MockTestCase(name: "readv", .interruptable, 3, base, 2) { retryOnInterrupt in
        _ = try fd.read(intoVectors: vectors, retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "writev", .interruptable, 3, base, 2) { retryOnInterrupt in
        _ = try fd.write(vectors: vectors, retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "preadv", .interruptable, 3, base, 2, 100) { retryOnInterrupt in
        _ = try fd.read(
          fromAbsoluteOffset: 100, intoVectors: vectors, retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "pwritev", .interruptable, 3, base, 2, 200) { retryOnInterrupt in
        _ = try fd.write(
          toAbsoluteOffset: 200, vectors: vectors, retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in cases { test.runAllTests() }

    // No vectors make no call, on every platform.
    try MockingDriver.withMockingEnabled { mocking in
      let none = UnsafeBufferPointer<CInterop.IOVec>(start: nil, count: 0)
      XCTAssertEqual(try fd.write(vectors: none), 0)
      XCTAssertEqual(try fd.read(intoVectors: none), 0)
      XCTAssertEqual(try fd.write(toAbsoluteOffset: 1, vectors: none), 0)
      XCTAssertEqual(try fd.read(fromAbsoluteOffset: 1, intoVectors: none), 0)
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  /// A write that stops partway through a vector resumes inside it,
  /// and one that ends on a vector's boundary resumes at the next one.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  func testWriteAllResumesAcrossVectors() throws {
    let fd = FileDescriptor(rawValue: 3)
    let a: [UInt8] = [1, 2, 3, 4], b: [UInt8] = [5, 6, 7, 8], c: [UInt8] = [9, 10, 11, 12]
    try MockingDriver.withMockingEnabled { mocking in
      mocking.byteCounts = [2, 6, 4]
      let written = try a.withUnsafeBytes { a in
        try b.withUnsafeBytes { b in
          try c.withUnsafeBytes { c in
            try fd.writeAll(
              RawSpan(_unsafeBytes: a), RawSpan(_unsafeBytes: b), RawSpan(_unsafeBytes: c))
          }
        }
      }
      XCTAssertEqual(written, 12)

      var calls: [(start: UnsafePointer<CInterop.IOVec>, count: CInt)] = []
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "writev")
        calls.append((entry.arguments[1] as! UnsafePointer<CInterop.IOVec>,
                      entry.arguments[2] as! CInt))
      }
      XCTAssertEqual(calls.map(\.count), [3, 3, 1])
      // The first write ended inside the first vector, and the second
      // on the boundary between the second and the third.
      XCTAssertEqual(calls[1].start - calls[0].start, 0)
      XCTAssertEqual(calls[2].start - calls[0].start, 2)
    }
  }
  #endif // ENABLE_MOCKING

  func testAdvanceVectors() {
    var bytes = [UInt8](repeating: 0, count: 12)
    bytes.withUnsafeMutableBytes { bytes in
      let base = bytes.baseAddress!
      let storage = UnsafeMutableBufferPointer<CInterop.IOVec>.allocate(capacity: 4)
      defer { storage.deallocate() }
      func reset() {
        _ = storage.initialize(from: [
          CInterop.IOVec(iov_base: base, iov_len: 0),
          CInterop.IOVec(iov_base: base, iov_len: 4),
          CInterop.IOVec(iov_base: base + 4, iov_len: 0),
          CInterop.IOVec(iov_base: base + 4, iov_len: 8),
        ])
      }

      // Nothing written drops only the empty vectors at the start.
      reset()
      var rest = _advanceVectors(storage, by: 0)
      XCTAssertEqual(rest.count, 3)
      XCTAssertEqual(rest[rest.startIndex].iov_len, 4)

      // Inside the first nonempty vector.
      reset()
      rest = _advanceVectors(storage, by: 3)
      XCTAssertEqual(rest.count, 3)
      XCTAssertEqual(rest[rest.startIndex].iov_base, UnsafeMutableRawPointer(base + 3))
      XCTAssertEqual(rest[rest.startIndex].iov_len, 1)

      // On a boundary, past the empty vector after it.
      reset()
      rest = _advanceVectors(storage, by: 4)
      XCTAssertEqual(rest.count, 1)
      XCTAssertEqual(rest[rest.startIndex].iov_base, UnsafeMutableRawPointer(base + 4))
      XCTAssertEqual(rest[rest.startIndex].iov_len, 8)

      // Inside the last vector, and all of it.
      reset()
      rest = _advanceVectors(storage, by: 10)
      XCTAssertEqual(rest.count, 1)
      XCTAssertEqual(rest[rest.startIndex].iov_base, UnsafeMutableRawPointer(base + 10))
      XCTAssertEqual(rest[rest.startIndex].iov_len, 2)
      reset()
      XCTAssertEqual(_advanceVectors(storage, by: 12).count, 0)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
