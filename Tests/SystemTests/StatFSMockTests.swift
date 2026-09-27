/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// StatFS's calls, checked against the calls they make. The mocks record the
// statfs or statvfs buffer as a pointer, which the tests don't check;
// StatFSTests checks the values on real file systems.
#if ENABLE_MOCKING
@available(System 199, *)
final class StatFSMockTests: XCTestCase {
  func testSyscalls() {
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    let pathCall = "statfs"
    let descriptorCall = "fstatfs"
    #else
    let pathCall = "statvfs"
    let descriptorCall = "fstatvfs"
    #endif
    let path: FilePath = "/a/path"
    let fd = FileDescriptor(rawValue: 42)

    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: pathCall, .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try StatFS(path, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: pathCall, .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try path.withPlatformString {
          try StatFS($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: pathCall, .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try path.statfs(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: descriptorCall, .interruptable, 42, Wildcard()) {
        retryOnInterrupt in
        _ = try StatFS(fd, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: descriptorCall, .interruptable, 42, Wildcard()) {
        retryOnInterrupt in
        _ = try fd.statfs(retryOnInterrupt: retryOnInterrupt)
      },
    ]

    syscallTestCases.forEach { $0.runAllTests() }
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  // mountedFileSystems counts the file systems, and then reads them into room
  // for one more. The mock counts none, and reads none.
  func testMountedFileSystems() throws {
    let size = MemoryLayout<CInterop.StatFS>.stride
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertEqual(try StatFS.mountedFileSystems().count, 0)
      expectCall(mocking, "getfsstat", Wildcard(), 0, MNT_NOWAIT)
      expectCall(mocking, "getfsstat", Wildcard(), size, MNT_NOWAIT)

      // The count never waits.
      _ = try StatFS.mountedFileSystems(waitForUpdates: true)
      expectCall(mocking, "getfsstat", Wildcard(), 0, MNT_NOWAIT)
      expectCall(mocking, "getfsstat", Wildcard(), size, MNT_WAIT)

      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try StatFS.mountedFileSystems(retryOnInterrupt: false)) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      expectCall(mocking, "getfsstat", Wildcard(), 0, MNT_NOWAIT)

      mocking.forceErrno = .counted(errno: EINTR, count: 2)
      _ = try StatFS.mountedFileSystems()
      for byteCount in [0, 0, 0, size] {
        expectCall(mocking, "getfsstat", Wildcard(), byteCount, MNT_NOWAIT)
      }

      mocking.forceErrno = .always(errno: EIO)
      XCTAssertThrowsError(try StatFS.mountedFileSystems()) {
        XCTAssertEqual($0 as? Errno, .ioError)
      }
      expectCall(mocking, "getfsstat", Wildcard(), 0, MNT_NOWAIT)
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif

  #if os(Linux) || os(Android)
  // FileSystemType's calls, which report the f_type that statvfs lacks.
  func testFileSystemTypeSyscalls() {
    let path: FilePath = "/a/path"
    let fd = FileDescriptor(rawValue: 42)

    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "statfs", .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try FileSystemType(path, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "statfs", .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try path.withPlatformString {
          try FileSystemType($0, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "statfs", .interruptable, "/a/path", Wildcard()) {
        retryOnInterrupt in
        _ = try path.fileSystemType(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fstatfs", .interruptable, 42, Wildcard()) {
        retryOnInterrupt in
        _ = try FileSystemType(fd, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fstatfs", .interruptable, 42, Wildcard()) {
        retryOnInterrupt in
        _ = try fd.fileSystemType(retryOnInterrupt: retryOnInterrupt)
      },
    ]

    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif
}

private func expectCall(
  _ mocking: MockingDriver, _ name: String, _ arguments: AnyHashable...,
  file: StaticString = #filePath, line: UInt = #line
) {
  let expected = Trace.Entry(name: name, arguments)
  guard let actual = mocking.trace.dequeue() else {
    XCTFail("expected \(expected), but the trace is empty", file: file, line: line)
    return
  }
  XCTAssertTrue(
    expected.matches(actual), "expected \(expected), got \(actual)", file: file, line: line)
}
#endif // ENABLE_MOCKING

#endif // !os(Windows)
