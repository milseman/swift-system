/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unique files with a suffix or relative to a directory, O_SYNC and
// O_DSYNC, a clock's reading as a timespec, and a signal's message.

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SmallGapsTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mkostemps", .interruptable, "aXXXXXX.txt", CInt(4), O_CLOEXEC) { retryOnInterrupt in
        _ = try FilePath("aXXXXXX.txt").makeUniqueFile(
          suffixLength: 4, options: .closeOnExec, retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "mkostempsat_np", .interruptable, 42, "aXXXXXX", CInt(0), CInt(0)) { retryOnInterrupt in
        _ = try FilePath("aXXXXXX").makeUniqueFile(
          relativeTo: FileDescriptor(rawValue: 42), retryOnInterrupt: retryOnInterrupt)
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testUniqueFileWithASuffix() throws {
    try withTemporaryFilePath(basename: "testUniqueFileWithASuffix") { dir in
      let (path, fd) = try dir.appending("report-XXXXXX.txt").makeUniqueFile(suffixLength: 4)
      try fd.close()
      let name = try XCTUnwrap(path.lastComponent?.string)
      XCTAssertTrue(name.hasPrefix("report-") && name.hasSuffix(".txt"))
      XCTAssertEqual(name.count, "report-XXXXXX.txt".count)
      XCTAssertFalse(name.contains("XXXXXX"))
      XCTAssertEqual(try path.stat().type, .regular)
      // Six X's must come before the suffix.
      XCTAssertThrowsError(try dir.appending("report-XXXXX.txt").makeUniqueFile(suffixLength: 4)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try dir.appending("XXXXXX").makeUniqueFile(suffixLength: 1)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  func testUniqueFileRelativeToADirectory() throws {
    try withTemporaryFilePath(basename: "testUniqueFileRelativeToADirectory") { dir in
      let directory = try FileDescriptor.open(dir, .readOnly)
      defer { try? directory.close() }
      let (path, fd) = try FilePath("data-XXXXXX.tmp").makeUniqueFile(
        relativeTo: directory, suffixLength: 4, options: .closeOnExec)
      defer { try? fd.close() }
      XCTAssertFalse(path.isAbsolute)
      XCTAssertEqual(try dir.appending(path.components).stat().type, .regular)
      XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))
      // The mode is 0600, until the caller changes it.
      XCTAssertEqual(try fd.stat().mode.permissions, .ownerReadWrite)
      try fd.setPermissions([.ownerReadWrite, .groupRead])
      XCTAssertEqual(try fd.stat().mode.permissions, [.ownerReadWrite, .groupRead])
    }
  }

  func testSynchronizedIO() throws {
    try withTemporaryFilePath(basename: "testSynchronizedIO") { dir in
      let path = dir.appending("file")
      let sync = try FileDescriptor.open(
        path, .writeOnly, options: [.create, .sync], permissions: .ownerReadWrite)
      defer { try? sync.close() }
      XCTAssertTrue(try sync.statusFlags().contains(.sync))
      let dataSync = try FileDescriptor.open(path, .writeOnly, options: .dataSync)
      defer { try? dataSync.close() }
      XCTAssertTrue(try dataSync.statusFlags().contains(.dataSync))
      XCTAssertFalse(try dataSync.statusFlags().contains(.sync))
      try dataSync.setStatusFlags(try dataSync.statusFlags().union(.sync))
      XCTAssertTrue(try dataSync.statusFlags().contains(.sync))
      try dataSync.writeAll("synchronized".utf8)
    }
  }

  func testClockTimeSpec() throws {
    let now = try ClockID.realtime.currentTimeSpec()
    XCTAssertLessThan(abs(now.seconds - Int(time(nil))), 5)
    XCTAssertTrue((0..<1_000_000_000).contains(now.nanoseconds))
    let later = try ClockID.monotonic.currentTimeSpec()
    let again = try ClockID.monotonic.currentTimeSpec()
    XCTAssertGreaterThanOrEqual(again.seconds * 1_000_000_000 + again.nanoseconds, later.seconds * 1_000_000_000 + later.nanoseconds)
    let calendar: CInterop.Time = time(nil)
    XCTAssertGreaterThan(calendar, 0)
  }

  func testSignalMessages() {
    XCTAssertEqual(Signal.terminate.message, "Terminated: 15")
    XCTAssertEqual(Signal.interrupt.message, "Interrupt: 2")
    XCTAssertEqual(Signal.terminate.description, "SIGTERM")
    XCTAssertTrue(Signal(rawValue: 999).message.contains("999"))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
