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

// PROTOTYPE: tests for Sources/System/OwnedFD.swift.

private struct BodyError: Error {}

final class OwnedFDTest: XCTestCase {
  #if ENABLE_MOCKING
  /// Drains the mocked syscall trace into `name(args)` strings.
  private func drain(_ mocking: MockingDriver) -> [String] {
    var calls: [String] = []
    while let entry = mocking.trace.dequeue() {
      let args = entry.arguments.map { "\($0)" }.joined(separator: ", ")
      calls.append("\(entry.name)(\(args))")
    }
    return calls
  }

  private func syscallNames(_ mocking: MockingDriver) -> [String] {
    drain(mocking).map { String($0.prefix { $0 != "(" }) }
  }

  func testDeinitClosesOnce() {
    MockingDriver.withMockingEnabled { mocking in
      do {
        let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
        _ = fd.withDescriptor { $0.rawValue }
      }
      XCTAssertEqual(drain(mocking), ["close(42)"])
    }
  }

  func testCloseClosesOnce() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
      try fd.close()
      XCTAssertEqual(drain(mocking), ["close(42)"])
    }
  }

  func testCloseFailureDoesNotCloseAgain() {
    MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EIO)
      let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
      do {
        try fd.close()
        XCTFail("close should have thrown")
      } catch {
        XCTAssertEqual(error as? Errno, .ioError)
      }
      mocking.forceErrno = .none
      XCTAssertEqual(drain(mocking), ["close(42)"])
    }
  }

  func testRelinquishDoesNotClose() {
    MockingDriver.withMockingEnabled { mocking in
      let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
      let raw = fd.relinquish()
      XCTAssertEqual(raw.rawValue, 42)
      XCTAssertEqual(drain(mocking), [])
    }
  }

  private func useBorrowed(_ fd: borrowing OwnedFD) throws(Errno) {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    _ = try fd.seek(offset: 0, from: .start)
    _ = try fd.read(into: buffer)
    _ = try fd.read(fromAbsoluteOffset: 4, into: buffer)
    _ = try fd.write(UnsafeRawBufferPointer(buffer))
    _ = try fd.write(toAbsoluteOffset: 4, UnsafeRawBufferPointer(buffer))
  }

  func testBorrowingUseDoesNotClose() throws {
    try MockingDriver.withMockingEnabled { mocking in
      do {
        let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
        try useBorrowed(fd)
        try useBorrowed(fd)
        XCTAssertEqual(
          syscallNames(mocking),
          ["lseek", "read", "pread", "write", "pwrite",
           "lseek", "read", "pread", "write", "pwrite"])
      }
      XCTAssertEqual(drain(mocking), ["close(42)"])
    }
  }

  func testStandardStreamsAreNotClosed() throws {
    try MockingDriver.withMockingEnabled { mocking in
      try useBorrowed(OwnedFD.standardInput)
      _ = try OwnedFD.standardOutput.seek(offset: 0, from: .current)
      _ = try OwnedFD.standardError.seek(offset: 0, from: .current)
      XCTAssertFalse(syscallNames(mocking).contains("close"))
    }
  }

  func testThrowingScopeDropsCloseError() throws {
    // When a scope exits by throwing, deinit closes and drops the close
    // error. `closeAfter` drops it in the same situation.
    func openThenThrow() throws {
      let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
      _ = fd.withDescriptor { $0.rawValue }
      throw BodyError()
    }
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EIO)
      XCTAssertThrowsError(try openThenThrow()) { XCTAssert($0 is BodyError) }
      XCTAssertThrowsError(
        try FileDescriptor(rawValue: 43).closeAfter { throw BodyError() }
      ) { XCTAssert($0 is BodyError) }
      mocking.forceErrno = .none
      XCTAssertEqual(drain(mocking), ["close(42)", "close(43)"])
    }
  }

  func testCloseAfterPermitsDoubleClose() throws {
    // For comparison: `FileDescriptor` is copyable, so the body of
    // `closeAfter` can close it too, and it is then closed twice.
    try MockingDriver.withMockingEnabled { mocking in
      let fd = FileDescriptor(rawValue: 42)
      try fd.closeAfter { try fd.close() }
      XCTAssertEqual(drain(mocking), ["close(42)", "close(42)"])
    }
  }
  #endif // ENABLE_MOCKING

  #if !os(WASI) // WASI has no pipe
  func testDeinitClosesRealDescriptor() throws {
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    do {
      let writeEnd = OwnedFD(taking: pipe.writeEnd)
      _ = try writeEnd.writeAll("abc".utf8)
    }
    // The write end is closed, so reading drains "abc" and then sees EOF.
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    XCTAssertEqual(try readEnd.read(into: buffer), 3)
    XCTAssertEqual(try readEnd.read(into: buffer), 0)
    try readEnd.close()
  }

  func testWithDescriptorCanReturnOwnedFD() throws {
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    let writeEnd = OwnedFD(taking: pipe.writeEnd)
    let duplicate = try writeEnd.withDescriptor { OwnedFD(taking: try $0.duplicate()) }
    try writeEnd.close()
    _ = try duplicate.writeAll("xy".utf8)
    try duplicate.close()
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    XCTAssertEqual(try readEnd.read(into: buffer), 2)
    XCTAssertEqual(try readEnd.read(into: buffer), 0)
  }

  func testCloseReportsError() {
    do {
      try OwnedFD(taking: FileDescriptor(rawValue: -1)).close()
      XCTFail("close should have thrown")
    } catch {
      XCTAssertEqual(error, .badFileDescriptor)
    }
  }
  #endif // !os(WASI)

  func testSpanForwards() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }
    try withTemporaryFilePath(basename: "testSpanForwards") { path in
      let fd = try OwnedFD.open(
        path.appending("test.txt"), .readWrite,
        options: [.create, .truncate], permissions: .ownerReadWrite)
      let abc: [UInt8] = Array("abc".utf8), def: [UInt8] = Array("def".utf8)
      let ghi: [UInt8] = Array("ghi".utf8), jkl: [UInt8] = Array("jkl".utf8)
      XCTAssertEqual(try abc.withUnsafeBytes { try fd.write(RawSpan(_unsafeBytes: $0)) }, 3)
      XCTAssertEqual(try def.withUnsafeBytes {
        try fd.write(toAbsoluteOffset: 3, RawSpan(_unsafeBytes: $0))
      }, 3)
      try fd.seek(offset: 6, from: .start)
      XCTAssertEqual(try ghi.withUnsafeBytes { try fd.writeAll(RawSpan(_unsafeBytes: $0)) }, 3)
      XCTAssertEqual(try jkl.withUnsafeBytes {
        try fd.writeAll(toAbsoluteOffset: 9, RawSpan(_unsafeBytes: $0))
      }, 3)
      XCTAssertEqual(try fd.writeAll(toAbsoluteOffset: 12, "mn".utf8), 2)

      try fd.seek(offset: 0, from: .start)
      let all = try [UInt8](unsafeUninitializedCapacity: 14) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        count = try fd.read(filling: &output)
      }
      XCTAssertEqual(all, abc + def + ghi + jkl + Array("mn".utf8))

      let tail = try [UInt8](unsafeUninitializedCapacity: 5) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        count = try fd.read(fromAbsoluteOffset: 9, filling: &output)
      }
      XCTAssertEqual(tail, jkl + Array("mn".utf8))

      try fd.seek(offset: 3, from: .start)
      let some = try [UInt8](unsafeUninitializedCapacity: 3) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        _ = try fd.read(into: &output)
        count = output.byteCount
      }
      XCTAssert(def.starts(with: some) && !some.isEmpty)

      let positioned = try [UInt8](unsafeUninitializedCapacity: 3) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        _ = try fd.read(fromAbsoluteOffset: 6, into: &output)
        count = output.byteCount
      }
      XCTAssert(ghi.starts(with: positioned) && !positioned.isEmpty)
      try fd.close()
    }
  }
}
