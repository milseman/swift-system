/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

// Tests for the open file description locks placed by `lock` and `unlock`.
// Locks belong to open files, so each test opens its own scratch file.
@available(System 199, *)
final class FileLockTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let fd = FileDescriptor(rawValue: 1)
    let rawFD = fd.rawValue
    let start = CShort(SEEK_SET)
    let pid = CInterop.ProcessID(0)

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_RDLCK, start, Int64(0),
        Int64(0), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.read, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(10),
        Int64(10), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.write, byteRange: 10..<20, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_RDLCK, start, Int64(0),
        Int64(50), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.shared, byteRange: ..<50, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(50),
        Int64(0), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.exclusive, byteRange: 50..., retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(0),
        Int64(6), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.write, byteRange: 0...5, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLKW, _F_WRLCK, start, Int64(0),
        Int64(0), pid
      ) { retryOnInterrupt in
        try fd.lock(.write, wait: true, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(0),
        Int64(0), pid
      ) { retryOnInterrupt in
        try fd.lock(.write, wait: false, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_UNLCK, start, Int64(0),
        Int64(0), pid
      ) { retryOnInterrupt in
        _ = try fd.lock(.none, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_UNLCK, start, Int64(0),
        Int64(0), pid
      ) { retryOnInterrupt in
        try fd.unlock(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_UNLCK, start, Int64(5),
        Int64(2), pid
      ) { retryOnInterrupt in
        try fd.unlock(byteRange: 5..<7, retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in syscallTestCases { test.runAllTests() }

    #if SYSTEM_PACKAGE_DARWIN
    if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
      let timeoutCases: Array<MockTestCase> = [
        MockTestCase(
          name: "fcntl", .interruptable, rawFD, _F_OFD_SETLKWTIMEOUT, _F_WRLCK, start,
          Int64(0), Int64(0), pid, 1, 500_000_000
        ) { retryOnInterrupt in
          _ = try fd.lock(
            .write, timeout: .milliseconds(1500), retryOnInterrupt: retryOnInterrupt)
        },

        MockTestCase(
          name: "fcntl", .interruptable, rawFD, _F_OFD_SETLKWTIMEOUT, _F_RDLCK, start,
          Int64(8), Int64(0), pid, 0, 1
        ) { retryOnInterrupt in
          // A timeout under a nanosecond rounds up, since zero means forever.
          _ = try fd.lock(
            .read, byteRange: 8..., timeout: Duration(secondsComponent: 0, attosecondsComponent: 1),
            retryOnInterrupt: retryOnInterrupt)
        },

        // A timeout of zero or less doesn't wait at all.
        MockTestCase(
          name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(0),
          Int64(0), pid
        ) { retryOnInterrupt in
          _ = try fd.lock(.write, timeout: .zero, retryOnInterrupt: retryOnInterrupt)
        },

        MockTestCase(
          name: "fcntl", .interruptable, rawFD, _F_OFD_SETLK, _F_WRLCK, start, Int64(0),
          Int64(0), pid
        ) { retryOnInterrupt in
          _ = try fd.lock(.write, timeout: .seconds(-1), retryOnInterrupt: retryOnInterrupt)
        },
      ]
      for test in timeoutCases { test.runAllTests() }
    }
    #endif // SYSTEM_PACKAGE_DARWIN
  }

  func testLockInTheWayReturnsFalse() throws {
    let fd = FileDescriptor(rawValue: 1)
    try MockingDriver.withMockingEnabled { driver in
      driver.forceErrno = .always(errno: EAGAIN)
      XCTAssertFalse(try fd.lock(.write))
      XCTAssertFalse(try fd.lock(.read, byteRange: 1..<2))
      XCTAssertFalse(try fd.lock(.write, wait: false))
      #if SYSTEM_PACKAGE_DARWIN
      if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
        driver.forceErrno = .always(errno: ETIMEDOUT)
        XCTAssertFalse(try fd.lock(.write, timeout: .milliseconds(1)))
        driver.forceErrno = .always(errno: EAGAIN)
      }
      #endif
      // Unlocking is never in the way of a lock, so EAGAIN there is an error.
      XCTAssertThrowsError(try fd.unlock()) {
        XCTAssertEqual($0 as? Errno, .resourceTemporarilyUnavailable)
      }
      driver.forceErrno = .always(errno: EBADF)
      XCTAssertThrowsError(try fd.lock(.write)) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
    }
  }

  func testEmptyRangeLocksNothing() throws {
    let fd = FileDescriptor(rawValue: 1)
    try MockingDriver.withMockingEnabled { driver in
      XCTAssertTrue(try fd.lock(.write, byteRange: 5..<5))
      XCTAssertTrue(try fd.lock(.write, byteRange: ..<0))
      XCTAssertTrue(try fd.lock(.write, byteRange: 5..<5, wait: true))
      try fd.unlock(byteRange: 7..<7)
      #if SYSTEM_PACKAGE_DARWIN
      if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
        XCTAssertTrue(try fd.lock(.write, byteRange: 5..<5, timeout: .seconds(1)))
      }
      #endif
      XCTAssertNil(driver.trace.dequeue())
    }
  }
  #endif // ENABLE_MOCKING

  func testLockBounds() {
    func check(
      _ range: some RangeExpression<Int64>,
      _ expected: (start: Int64, length: Int64)?,
      line: UInt = #line
    ) {
      let bounds = FileDescriptor._lockBounds(range)
      XCTAssertEqual(bounds?.start, expected?.start, line: line)
      XCTAssertEqual(bounds?.length, expected?.length, line: line)
    }
    check(2..<5, (start: 2, length: 3))
    check(2...5, (start: 2, length: 4))
    check(..<5, (start: 0, length: 5))
    check(...5, (start: 0, length: 6))
    check(5..., (start: 5, length: 0))
    check(5..<Int64.max, (start: 5, length: 0))
    check(Int64.min..<Int64.max, (start: 0, length: 0))
    // The whole file, when the range is omitted.
    let omitted = FileDescriptor._lockBounds(Range<Int64>?.none)
    XCTAssertEqual(omitted?.start, 0)
    XCTAssertEqual(omitted?.length, 0)
    // Empty ranges map to nothing, rather than to a length of 0,
    // which would mean the rest of the file.
    check(5..<5, nil)
    check(..<0, nil)
    // Negative offsets pass through, for the kernel to reject.
    check((-3)..<2, (start: -3, length: 5))
  }

  func testLocks() throws {
    try withTemporaryFilePath(basename: "testLocks") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      defer { try? a.close() }
      let dupA = try a.duplicate()
      defer { try? dupA.close() }
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }
      let dupB = try b.duplicate()
      defer { try? dupB.close() }

      // A write lock excludes every lock from another open file,
      // even within one process, but not from a duplicate.
      XCTAssertTrue(try a.lock(.read))
      XCTAssertTrue(try a.lock(.write))
      XCTAssertTrue(try dupA.lock(.write))
      XCTAssertFalse(try b.lock(.read))
      XCTAssertFalse(try b.lock(.write))
      XCTAssertFalse(try dupB.lock(.write))
      // A duplicate shares the lock, so it can release it.
      try dupA.unlock()

      // Read locks coexist, and exclude write locks.
      XCTAssertTrue(try dupA.lock(.read))
      XCTAssertTrue(try b.lock(.read))
      XCTAssertFalse(try a.lock(.write))
      XCTAssertFalse(try dupA.lock(.write))
      XCTAssertFalse(try b.lock(.write))
      XCTAssertFalse(try dupB.lock(.write))
      try dupB.unlock()
      // With the other read lock gone, the read lock can become a write lock.
      XCTAssertTrue(try a.lock(.write))
      XCTAssertFalse(try dupB.lock(.read))
      XCTAssertFalse(try b.lock(.write))
      try dupA.unlock()

      // Locks on byte ranges only exclude locks that overlap them.
      XCTAssertTrue(try a.lock(.read, byteRange: ..<50))
      XCTAssertTrue(try b.lock(.write, byteRange: 50...))
      XCTAssertTrue(try a.lock(.write, byteRange: 10..<20))
      XCTAssertTrue(try b.lock(.read, byteRange: 40..<50))
      XCTAssertFalse(try b.lock(.read, byteRange: 17..<18))
      XCTAssertFalse(try a.lock(.read, byteRange: 60..<70))
      // A range with no upper bound extends past the end of the file.
      XCTAssertFalse(try a.lock(.read, byteRange: 1_000_000..<1_000_001))
      // Unlocking part of a range leaves the rest locked.
      try dupA.unlock(byteRange: 11..<12)
      XCTAssertTrue(try b.lock(.read, byteRange: 11..<12))
      XCTAssertTrue(try a.lock(.read, byteRange: 11..<12))
      XCTAssertFalse(try b.lock(.write, byteRange: 11..<12))
      XCTAssertFalse(try a.lock(.write, byteRange: 11..<12))
      XCTAssertFalse(try b.lock(.read, byteRange: 12..<13))
      // Passing `.none` unlocks too.
      XCTAssertTrue(try b.lock(.none))
      XCTAssertTrue(try a.lock(.write, byteRange: 50..<60))
      try a.unlock()
      XCTAssertTrue(try b.lock(.write))
      try b.unlock()
    }
  }

  func testClosingReleasesLocks() throws {
    try withTemporaryFilePath(basename: "testClosingReleasesLocks") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      let dupA = try a.duplicate()
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }

      XCTAssertTrue(try a.lock(.write))
      // The lock lasts until the last descriptor for the open file closes.
      try a.close()
      XCTAssertFalse(try b.lock(.write))
      try dupA.close()
      XCTAssertTrue(try b.lock(.write))
    }
  }

  func testLockErrors() throws {
    try withTemporaryFilePath(basename: "testLockErrors") { path in
      let file = path.appending("file.txt")
      let readOnly = try FileDescriptor.open(
        file, .readOnly, options: .create, permissions: .ownerReadWrite)
      defer { try? readOnly.close() }
      let writeOnly = try FileDescriptor.open(file, .writeOnly)
      defer { try? writeOnly.close() }

      // Each kind of lock needs the matching access.
      XCTAssertTrue(try readOnly.lock(.read))
      XCTAssertThrowsError(try readOnly.lock(.write)) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      try readOnly.unlock()
      XCTAssertTrue(try writeOnly.lock(.write))
      XCTAssertThrowsError(try writeOnly.lock(.read)) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      // Unlocking bytes that aren't locked isn't an error.
      try writeOnly.unlock(byteRange: 100..<200)
      try writeOnly.unlock()
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).lock(.read)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).unlock()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  func testWaitingLock() throws {
    try withTemporaryFilePath(basename: "testWaitingLock") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      defer { try? a.close() }
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }

      XCTAssertTrue(try a.lock(.write))
      let locked = DispatchSemaphore(value: 0)
      nonisolated(unsafe) var result: Result<Bool, Errno>? = nil
      let rawB = b.rawValue
      DispatchQueue.global().async {
        result = Result { () throws(Errno) in
          try FileDescriptor(rawValue: rawB).lock(.write, wait: true)
        }
        locked.signal()
      }
      // The other open file waits while the lock is in the way.
      XCTAssertEqual(locked.wait(timeout: .now() + .milliseconds(100)), .timedOut)
      try a.unlock()
      XCTAssertEqual(locked.wait(timeout: .now() + .seconds(10)), .success)
      XCTAssertEqual(try result?.get(), true)
      XCTAssertFalse(try a.lock(.read))
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  func testLockTimeout() throws {
    try withTemporaryFilePath(basename: "testLockTimeout") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      defer { try? a.close() }
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }

      XCTAssertTrue(try a.lock(.write, byteRange: ..<10))
      let clock = ContinuousClock()
      let start = clock.now
      XCTAssertFalse(try b.lock(.read, byteRange: 5..<6, timeout: .milliseconds(50)))
      XCTAssertGreaterThanOrEqual(clock.now - start, .milliseconds(40))
      // Without a timeout, the kernel would wait forever, so these don't wait.
      XCTAssertFalse(try b.lock(.read, byteRange: 5..<6, timeout: .zero))
      XCTAssertFalse(try b.lock(.read, byteRange: 5..<6, timeout: .seconds(-1)))
      // Bytes that aren't locked don't wait.
      XCTAssertTrue(try b.lock(.write, byteRange: 10..., timeout: .seconds(10)))
      try a.unlock()
      XCTAssertTrue(try b.lock(.write, timeout: .seconds(10)))
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN

  func testWholeFileLocksAreDistinct() throws {
    try withTemporaryFilePath(basename: "testWholeFileLocksAreDistinct") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      defer { try? a.close() }
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }

      try a.lockWholeFile()
      #if SYSTEM_PACKAGE_DARWIN
      // Darwin keeps the two kinds of lock together.
      XCTAssertFalse(try b.lock(.write))
      #else
      // Linux keeps them apart.
      XCTAssertTrue(try b.lock(.write))
      try b.unlock()
      #endif
      try a.unlockWholeFile()
      XCTAssertTrue(try b.lock(.write))
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
