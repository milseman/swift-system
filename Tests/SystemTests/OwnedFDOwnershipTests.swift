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

// PROTOTYPE: more tests for Sources/System/OwnedFD.swift: the syscall and
// retry behavior of each forwarded method, ownership transfer, and errors.

final class OwnedFDOwnershipTest: XCTestCase {
  #if ENABLE_MOCKING && !os(WASI) // Would need to use _getConst funcs from CSystem
  /// Calls `body` with an `OwnedFD` for descriptor 42, then relinquishes it,
  /// so that the mocked trace records no `close`.
  private func withOwnedFD42(
    _ body: (borrowing OwnedFD) throws(Errno) -> Void
  ) throws(Errno) {
    let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
    let result = Result { () throws(Errno) in try body(fd) }
    _ = fd.relinquish()
    try result.get()
  }

  func testForwardedSyscalls() {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 100, alignment: 4)
    defer { buffer.deallocate() }
    let address = buffer.baseAddress
    let count = buffer.count
    let bytes = UnsafeRawBufferPointer(buffer)
    let bytesAddress = bytes.baseAddress

    // Each case checks the syscall and its arguments, and that the
    // `retryOnInterrupt` argument reaches the syscall wrapper.
    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "open", .interruptable, "a path", O_RDWR | O_APPEND) {
        retryOnInterrupt in
        _ = try OwnedFD.open(
          "a path", .readWrite, options: [.append], retryOnInterrupt: retryOnInterrupt
        ).relinquish()
      },
      MockTestCase(name: "open", .interruptable, "a path", O_WRONLY | O_CREAT, 0o600) {
        retryOnInterrupt in
        _ = try OwnedFD.open(
          "a path", .writeOnly, options: [.create], permissions: .ownerReadWrite,
          retryOnInterrupt: retryOnInterrupt
        ).relinquish()
      },
      MockTestCase(name: "read", .interruptable, 42, address, count) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.read(into: buffer, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "pread", .interruptable, 42, address, count, 5) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.read(
            fromAbsoluteOffset: 5, into: buffer, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "write", .interruptable, 42, bytesAddress, count) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.write(bytes, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "pwrite", .interruptable, 42, bytesAddress, count, 7) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.write(toAbsoluteOffset: 7, bytes, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "lseek", .noInterrupt, 42, -2, SEEK_END) { _ in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.seek(offset: -2, from: .end)
        }
      },
      MockTestCase(name: "close", .noInterrupt, 42) { _ in
        try OwnedFD(taking: FileDescriptor(rawValue: 42)).close()
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }

  func testForwardedSpanSyscalls() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      throw XCTSkip("Span-based I/O requires macOS 15 or later")
    }
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 100, alignment: 4)
    defer { buffer.deallocate() }
    let address = buffer.baseAddress
    let count = buffer.count
    let bytes = UnsafeRawBufferPointer(buffer)
    let bytesAddress = bytes.baseAddress

    // The mocked read returns 0, which the `filling:` methods treat as end
    // of file. The `writeAll` methods aren't here: they retry a write that
    // returns 0, so they would never return.
    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "write", .interruptable, 42, bytesAddress, count) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.write(RawSpan(_unsafeBytes: bytes), retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "pwrite", .interruptable, 42, bytesAddress, count, 7) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          _ = try fd.write(
            toAbsoluteOffset: 7, RawSpan(_unsafeBytes: bytes),
            retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "read", .interruptable, 42, address, count) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
          _ = try fd.read(into: &output, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "pread", .interruptable, 42, address, count, 5) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
          _ = try fd.read(
            fromAbsoluteOffset: 5, into: &output, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "read", .interruptable, 42, address, count) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
          try fd.read(filling: &output, retryOnInterrupt: retryOnInterrupt)
        }
      },
      MockTestCase(name: "pread", .interruptable, 42, address, count, 5) { retryOnInterrupt in
        try self.withOwnedFD42 { fd throws(Errno) in
          var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
          try fd.read(
            fromAbsoluteOffset: 5, filling: &output, retryOnInterrupt: retryOnInterrupt)
        }
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }

  func testVendingMakesNoSyscall() {
    MockingDriver.withMockingEnabled { mocking in
      let fd = OwnedFD(taking: FileDescriptor(rawValue: 42))
      XCTAssertEqual(fd.fileDescriptor.rawValue, 42)
      XCTAssertEqual(fd.fileDescriptor, fd.fileDescriptor)
      XCTAssertTrue(mocking.trace.isEmpty)
      _ = fd.relinquish()
    }
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  func testStandardStreamValues() {
    XCTAssertEqual(OwnedFD.standardInput.fileDescriptor, .standardInput)
    XCTAssertEqual(OwnedFD.standardOutput.fileDescriptor, .standardOutput)
    XCTAssertEqual(OwnedFD.standardError.fileDescriptor, .standardError)
  }

  func testForwardsReportBadFileDescriptor() {
    let fd = OwnedFD(taking: FileDescriptor(rawValue: -1))
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 1)
    defer { buffer.deallocate() }
    let bytes = UnsafeRawBufferPointer(buffer)

    func check(_ body: () throws -> Void, line: UInt = #line) {
      XCTAssertThrowsError(try body(), line: line) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor, line: line)
      }
    }
    check { _ = try fd.seek(offset: 0, from: .current) }
    check { _ = try fd.read(into: buffer) }
    check { _ = try fd.read(fromAbsoluteOffset: 0, into: buffer) }
    check { _ = try fd.write(bytes) }
    check { _ = try fd.write(toAbsoluteOffset: 0, bytes) }
    check { _ = try fd.writeAll([1, 2, 3]) }
    check { _ = try fd.writeAll(toAbsoluteOffset: 0, [1, 2, 3]) }
    _ = fd.relinquish()
  }

  func testOpenErrors() throws {
    try withTemporaryFilePath(basename: "testOpenErrors") { path in
      let file = path.appending("file.txt")
      try OwnedFD.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()

      func check(_ expected: Errno, line: UInt = #line, _ body: () throws -> OwnedFD) {
        XCTAssertThrowsError(try body().close(), line: line) {
          XCTAssertEqual($0 as? Errno, expected, line: line)
        }
      }
      check(.noSuchFileOrDirectory) { try OwnedFD.open(path.appending("missing"), .readOnly) }
      check(.notDirectory) { try OwnedFD.open(file.appending("child"), .readOnly) }
      check(.isDirectory) { try OwnedFD.open(path, .writeOnly) }
      check(.fileExists) {
        try OwnedFD.open(
          file, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
      }

      #if !os(WASI) // WASI has no process credentials
      // Only a privileged process can open a file that has no permissions.
      if geteuid() != 0 {
        let locked = path.appending("locked.txt")
        try OwnedFD.open(locked, .writeOnly, options: .create, permissions: []).close()
        check(.permissionDenied) { try OwnedFD.open(locked, .readOnly) }
      }
      #endif
    }
  }

  func testPositionalIOLeavesOffsetUnchanged() throws {
    try withTemporaryFilePath(basename: "testPositionalIO") { path in
      let fd = try OwnedFD.open(
        path.appending("file.txt"), .readWrite,
        options: [.create, .truncate], permissions: .ownerReadWrite)
      XCTAssertEqual(try fd.writeAll("abcdef".utf8), 6)
      XCTAssertEqual(try fd.seek(offset: 1, from: .start), 1)

      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
      defer { buffer.deallocate() }
      let count = try fd.read(fromAbsoluteOffset: 2, into: buffer)
      XCTAssertEqual(Array(buffer[..<count]), Array("cdef".utf8))
      XCTAssertEqual(try fd.writeAll(toAbsoluteOffset: 6, "gh".utf8), 2)
      XCTAssertEqual(try fd.seek(offset: 0, from: .current), 1)

      // The unpositioned methods start at, and advance, the offset.
      XCTAssertEqual(try fd.read(into: UnsafeMutableRawBufferPointer(rebasing: buffer[..<3])), 3)
      XCTAssertEqual(Array(buffer[..<3]), Array("bcd".utf8))
      XCTAssertEqual(try fd.seek(offset: 0, from: .current), 4)
      XCTAssertEqual(try fd.seek(offset: 0, from: .end), 8)
      try fd.close()
    }
  }

  #if !os(WASI) // WASI has no pipe
  /// Reads everything from `fd` until end of file, as UTF-8 text.
  private func readToEnd(_ fd: borrowing OwnedFD) throws(Errno) -> String {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { buffer.deallocate() }
    var result: [UInt8] = []
    while true {
      let count = try fd.read(into: buffer)
      if count == 0 { return String(decoding: result, as: UTF8.self) }
      result += buffer[..<count]
    }
  }

  private func send(_ text: String, andDestroy fd: consuming OwnedFD) throws(Errno) {
    try fd.writeAll(text.utf8)
  }

  func testConsumingParameterClosesInCallee() throws {
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    // The callee owns the write end, and closes it when it returns.
    try send("abc", andDestroy: OwnedFD(taking: pipe.writeEnd))
    XCTAssertEqual(try readToEnd(readEnd), "abc")
  }

  func testReassignmentClosesPreviousDescriptor() throws {
    let first = try FileDescriptor.pipe()
    let second = try FileDescriptor.pipe()
    let firstRead = OwnedFD(taking: first.readEnd)
    let secondRead = OwnedFD(taking: second.readEnd)

    var writeEnd = OwnedFD(taking: first.writeEnd)
    try writeEnd.writeAll("1".utf8)
    writeEnd = OwnedFD(taking: second.writeEnd)
    XCTAssertEqual(try readToEnd(firstRead), "1")

    try writeEnd.writeAll("2".utf8)
    try writeEnd.close()
    XCTAssertEqual(try readToEnd(secondRead), "2")
  }

  func testOptionalSetToNilCloses() throws {
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    var writeEnd: OwnedFD? = OwnedFD(taking: pipe.writeEnd)
    switch writeEnd {
    case .some(let fd): try fd.writeAll("abc".utf8)
    case .none: XCTFail("writeEnd should be non-nil")
    }
    writeEnd = nil
    XCTAssertEqual(try readToEnd(readEnd), "abc")
  }

  func testRelinquishedDescriptorStaysOpen() throws {
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    let writeEnd = OwnedFD(taking: pipe.writeEnd).relinquish()
    XCTAssertEqual(writeEnd, pipe.writeEnd)
    // The descriptor is still open, and the caller is responsible for it.
    try writeEnd.writeAll("abc".utf8)
    try writeEnd.close()
    XCTAssertEqual(try readToEnd(readEnd), "abc")
  }

  func testClosingVendedDescriptorLeavesOwnerStale() throws {
    // Nothing prevents closing the vended descriptor, as
    // Prototype/Verify/V10a_prototype_escape_hatch.swift notes. Then the
    // owner's own close fails. (Destroying the owner instead drops the
    // error; see OwnedFDDeinitTests.swift.)
    let pipe = try FileDescriptor.pipe()
    let readEnd = OwnedFD(taking: pipe.readEnd)
    let writeEnd = OwnedFD(taking: pipe.writeEnd)
    try writeEnd.fileDescriptor.close()
    XCTAssertEqual(try readToEnd(readEnd), "")
    do {
      try writeEnd.close()
      XCTFail("close should have thrown")
    } catch {
      XCTAssertEqual(error, .badFileDescriptor)
    }
  }
  #endif // !os(WASI)
}
