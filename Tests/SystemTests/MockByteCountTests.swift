/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// Mock tests of the loops that write until they've written every byte.
// MockingDriver.byteCounts sets how many bytes each successful mocked read or
// write reports; without them, each reports 0, which a write loop retries
// forever.
#if ENABLE_MOCKING && !os(WASI)
final class MockByteCountTest: XCTestCase {
  func testByteCounts() throws {
    let fd = FileDescriptor(rawValue: 42)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    try MockingDriver.withMockingEnabled { mocking in
      // Successful calls return the counts in order, then 0.
      mocking.byteCounts = [3, 5]
      XCTAssertEqual(try fd.read(into: buffer), 3)
      XCTAssertEqual(try fd.write(UnsafeRawBufferPointer(buffer)), 5)
      XCTAssertEqual(try fd.read(into: buffer), 0)

      // A call that fails doesn't use a count.
      mocking.byteCounts = [4]
      mocking.forceErrno = .counted(errno: EIO, count: 1)
      XCTAssertThrowsError(try fd.read(into: buffer)) {
        XCTAssertEqual($0 as? Errno, .ioError)
      }
      XCTAssertEqual(try fd.read(fromAbsoluteOffset: 7, into: buffer), 4)

      for name in ["read", "write", "read", "read", "pread"] {
        XCTAssertEqual(mocking.trace.dequeue()?.name, name)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testWriteAllContinuesAfterPartialWrites() throws {
    let fd = FileDescriptor(rawValue: 42)
    let bytes: [UInt8] = [1, 2, 3, 4]
    try MockingDriver.withMockingEnabled { mocking in
      // Each write starts where the last one stopped.
      mocking.byteCounts = [1, 2, 1]
      XCTAssertEqual(try fd.writeAll(bytes), 4)
      try expectWrites(mocking, "write", [(0, 4), (1, 3), (3, 1)])

      // The offset advances with the data.
      mocking.byteCounts = [3, 1]
      XCTAssertEqual(try fd.writeAll(toAbsoluteOffset: 7, bytes), 4)
      let first = try XCTUnwrap(mocking.trace.dequeue())
      let second = try XCTUnwrap(mocking.trace.dequeue())
      XCTAssertEqual(first.name, "pwrite")
      XCTAssertEqual(second.name, "pwrite")
      XCTAssertEqual(first.arguments[2], AnyHashable(4))
      XCTAssertEqual(second.arguments[2], AnyHashable(1))
      XCTAssertEqual(first.arguments[3], AnyHashable(7))
      XCTAssertEqual(second.arguments[3], AnyHashable(10))
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testWriteAllRetriesAnInterruptedWrite() throws {
    let fd = FileDescriptor(rawValue: 42)
    let bytes: [UInt8] = [1, 2, 3]
    try MockingDriver.withMockingEnabled { mocking in
      // The Sequence-based writeAll always retries, from where it stopped.
      mocking.forceErrno = .counted(errno: EINTR, count: 2)
      mocking.byteCounts = [3]
      XCTAssertEqual(try fd.writeAll(bytes), 3)
      try expectWrites(mocking, "write", [(0, 3), (0, 3), (0, 3)])
    }
  }

  func testSpanWriteAllRetriesAnInterruptedWriteByDefault() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }
    // WriteAllInterruptTests' mock test checks only retryOnInterrupt: false,
    // since a retried mocked write used to report no bytes.
    let fd = FileDescriptor(rawValue: 42)
    let bytes: [UInt8] = [1, 2, 3]
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      mocking.byteCounts = [2, 1]
      XCTAssertEqual(
        try bytes.withUnsafeBytes { try fd.writeAll(RawSpan(_unsafeBytes: $0)) }, 3)
      try expectWrites(mocking, "write", [(0, 3), (0, 3), (2, 1)])

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      mocking.byteCounts = [3]
      XCTAssertEqual(
        try bytes.withUnsafeBytes {
          try fd.writeAll(toAbsoluteOffset: 7, RawSpan(_unsafeBytes: $0))
        }, 3)
      try expectWrites(mocking, "pwrite", [(0, 3), (0, 3)])
    }
  }
}

/// Checks that the next calls in the trace are the given writes, each of
/// `count` bytes from `offset` bytes into the buffer, and that no others follow.
private func expectWrites(
  _ mocking: MockingDriver, _ name: String, _ writes: [(offset: Int, count: Int)],
  file: StaticString = #filePath, line: UInt = #line
) throws {
  var buffer: UnsafeRawPointer? = nil
  for (offset, count) in writes {
    let call = try XCTUnwrap(mocking.trace.dequeue(), "expected \(name)", file: file, line: line)
    XCTAssertEqual(call.name, name, file: file, line: line)
    XCTAssertEqual(call.arguments[2], AnyHashable(count), file: file, line: line)
    let start = try XCTUnwrap(call.arguments[1] as? UnsafeRawPointer, file: file, line: line)
    let base = buffer ?? start
    buffer = base
    XCTAssertEqual(base.distance(to: start), offset, file: file, line: line)
  }
  XCTAssertTrue(mocking.trace.isEmpty, file: file, line: line)
}
#endif // ENABLE_MOCKING && !os(WASI)
