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

  #if SYSTEM_PACKAGE_DARWIN
  // quotactl's command is QCMD(command, type), which Swift doesn't import.
  func testQuotaSyscalls() {
    let path: FilePath = "/a/path"
    func command(_ command: CInt, _ type: CInt) -> CInt {
      (command << SUBCMDSHIFT) | (type & SUBCMDMASK)
    }
    let userStatus = command(Q_QUOTASTAT, USRQUOTA)
    let groupStatus = command(Q_QUOTASTAT, GRPQUOTA)
    let userQuota = command(Q_GETQUOTA, USRQUOTA)
    let groupQuota = command(Q_GETQUOTA, GRPQUOTA)

    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "quotactl", .interruptable, "/a/path", userStatus, 0, Wildcard()) {
        retryOnInterrupt in
        _ = try path.quotasEnabled(for: .user, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "quotactl", .interruptable, "/a/path", groupStatus, 0, Wildcard()) {
        retryOnInterrupt in
        _ = try path.withPlatformString {
          try FilePath.quotasEnabled($0, for: .group, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "quotactl", .interruptable, "/a/path", userQuota, 501, Wildcard()) {
        retryOnInterrupt in
        _ = try path.diskQuota(for: UserID(rawValue: 501), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "quotactl", .interruptable, "/a/path", userQuota, 501, Wildcard()) {
        retryOnInterrupt in
        _ = try path.withPlatformString {
          try FilePath.diskQuota(
            $0, for: UserID(rawValue: 501), retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "quotactl", .interruptable, "/a/path", groupQuota, 20, Wildcard()) {
        retryOnInterrupt in
        _ = try path.diskQuota(for: GroupID(rawValue: 20), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "quotactl", .interruptable, "/a/path", groupQuota, 20, Wildcard()) {
        retryOnInterrupt in
        _ = try path.withPlatformString {
          try FilePath.diskQuota(
            $0, for: GroupID(rawValue: 20), retryOnInterrupt: retryOnInterrupt)
        }
      },

      // quotactl takes the ID as an int, so one past Int32.max, such as
      // nobody's, goes by its bit pattern.
      MockTestCase(name: "quotactl", .interruptable, "/a/path", userQuota, CInt(-2), Wildcard()) {
        retryOnInterrupt in
        _ = try path.diskQuota(
          for: UserID(rawValue: 4_294_967_294), retryOnInterrupt: retryOnInterrupt)
      },
    ]

    syscallTestCases.forEach { $0.runAllTests() }
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
