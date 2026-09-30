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

// SYS-0014: byte-range locking.
@available(System 199, *)
final class Win32LockingTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(_LOCKFILE_EXCLUSIVE_LOCK, DWORD(WinSDK.LOCKFILE_EXCLUSIVE_LOCK))
    XCTAssertEqual(_LOCKFILE_FAIL_IMMEDIATELY, DWORD(WinSDK.LOCKFILE_FAIL_IMMEDIATELY))
  }

  /// Runs `body` with two handles to one 16-byte file: two opens, so two
  /// file objects, as another process would have.
  private func withTwoHandles(
    _ name: FilePath.Component,
    _ body: (borrowing Win32.FileHandle, borrowing Win32.FileHandle) throws -> Void
  ) throws {
    try withTemporaryFilePath(basename: name) { directory in
      let path = directory.appending("file.txt")
      let first = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      try withRawSpan([UInt8](repeating: 0x2A, count: 16)) { try first.write($0) }
      let second = try Win32.FileHandle.open(path, access: [.genericRead, .genericWrite])
      try body(first, second)
      try second.close()
      try first.close()
    }
  }

  /// Reads one byte at `offset` through `handle`, returning the number of
  /// bytes read.
  private func readOneByte(
    _ handle: borrowing Win32.FileHandle, at offset: Int64
  ) throws(Win32.Error) -> Int {
    var bytes = [UInt8](repeating: 0, count: 1)
    var span = bytes.mutableSpan
    return try handle.read(fromAbsoluteOffset: offset, into: &span)
  }

  func testExclusiveLocksAreMandatory() throws {
    try withTwoHandles("testExclusiveLocks") { first, second in
      try first.withLock(byteRange: 0..<8) { () throws(Win32.Error) in
        // Another file object can't read the locked range, though it takes
        // no lock itself.
        XCTAssertThrowsWin32Error(.lockViolation) { try self.readOneByte(second, at: 0) }
        let outside = try self.readOneByte(second, at: 8)
        XCTAssertEqual(outside, 1)
        // The locking handle can.
        let inside = try self.readOneByte(first, at: 0)
        XCTAssertEqual(inside, 1)
      }
      let afterUnlocking = try self.readOneByte(second, at: 0)
      XCTAssertEqual(afterUnlocking, 1)
    }
  }

  func testLockIfAvailable() throws {
    try withTwoHandles("testLockIfAvailable") { first, second in
      try first.withLock(byteRange: 4..<8) { () throws(Win32.Error) in
        let overlapping = try second.withLockIfAvailable(byteRange: 0..<5) { 1 }
        XCTAssertNil(overlapping)
        let disjoint = try second.withLockIfAvailable(byteRange: 8..<12) { 2 }
        XCTAssertEqual(disjoint, 2)
      }
      let afterUnlocking = try second.withLockIfAvailable(byteRange: 0..<5) { 3 }
      XCTAssertEqual(afterUnlocking, 3)
    }
  }

  func testSharedLocks() throws {
    try withTwoHandles("testSharedLocks") { first, second in
      try first.withLock(byteRange: 0..<8, mode: .shared) { () throws(Win32.Error) in
        let shared = try second.withLockIfAvailable(byteRange: 0..<8, mode: .shared) { 1 }
        XCTAssertEqual(shared, 1)
        let exclusive = try second.withLockIfAvailable(byteRange: 0..<8) { 2 }
        XCTAssertNil(exclusive)
        // A shared lock denies writes to the range, even through the handle
        // that took it.
        XCTAssertThrowsWin32Error(.lockViolation) {
          try withRawSpan([1]) { try first.write($0, toAbsoluteOffset: 0) }
        }
        // Anyone may read it.
        let read = try self.readOneByte(second, at: 0)
        XCTAssertEqual(read, 1)
      }
    }
  }

  func testWholeFileByDefault() throws {
    try withTwoHandles("testWholeFile") { first, second in
      try first.withLock { () throws(Win32.Error) in
        XCTAssertThrowsWin32Error(.lockViolation) { try self.readOneByte(second, at: 15) }
        let other = try second.withLockIfAvailable(byteRange: 100..<200) { 1 }
        XCTAssertNil(other, "the default range covers bytes past the end of the file")
      }
    }
  }

  func testEmptyRangeDoesNotLock() throws {
    // LockFileEx fails on a pipe, so these show that it wasn't called.
    let pipe = try Win32TestPipe()
    let locked = try pipe.readEnd.withLock(byteRange: 5..<5) { 1 }
    XCTAssertEqual(locked, 1)
    let available = try pipe.readEnd.withLockIfAvailable(byteRange: ..<0) { 2 }
    XCTAssertEqual(available, 2)
    XCTAssertThrowsWin32Error(.invalidFunction) {
      try pipe.readEnd.withLock(byteRange: 0..<1) { 3 }
    }
  }

  func testNegativeBoundsAreRejected() throws {
    try withTwoHandles("testNegativeBounds") { first, _ in
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try first.withLock(byteRange: -1..<5) { 0 }
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try first.withLock(byteRange: (-5)...) { 0 }
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try first.withLock(byteRange: ..<(-1)) { 0 }
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try first.withLockIfAvailable(byteRange: ...(-1)) { 0 }
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try first.withLockIfAvailable(byteRange: (-5)...(-1)) { 0 }
      }
    }
  }

  func testRangesClosedAtTheLastOffset() throws {
    try withTwoHandles("testLastOffset") { first, _ in
      // Byte Int64.max isn't addressable, so these don't trap.
      let whole = try first.withLock(byteRange: 0...Int64.max) { 1 }
      XCTAssertEqual(whole, 1)
      // This one is empty once it ends at Int64.max, so it locks nothing.
      let last = try first.withLock(byteRange: Int64.max...Int64.max) { 2 }
      XCTAssertEqual(last, 2)
    }
  }

  func testBodyErrorsWinAndTheRangeIsUnlocked() throws {
    struct Failure: Error, Equatable {}
    try withTwoHandles("testBodyErrors") { first, second in
      XCTAssertThrowsError(try first.withLock(byteRange: 0..<8) { throw Failure() }) {
        XCTAssertEqual($0 as? Failure, Failure())
      }
      let relocked = try second.withLockIfAvailable(byteRange: 0..<8) { 1 }
      XCTAssertEqual(relocked, 1)

      XCTAssertThrowsError(
        try first.withLockIfAvailable(byteRange: 0..<8) { throw Failure() }
      ) {
        XCTAssertEqual($0 as? Failure, Failure())
      }
      let relockedAgain = try second.withLockIfAvailable(byteRange: 0..<8) { 2 }
      XCTAssertEqual(relockedAgain, 2)
    }
  }
}

#endif // os(Windows)
