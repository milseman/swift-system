/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The calls behind unique files with permissions on Linux, Android,
// FreeBSD and OpenBSD, where System makes the name itself rather than calling mktemp, so a mock
// trace has only the opens. UniqueFilesWithPermissionsTest has the real
// calls, on every platform, and Darwin's mock tests.

#if (os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)) && ENABLE_MOCKING

import XCTest

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class UniqueFilesWithPermissionsLinuxTest: XCTestCase {
  private func entries(_ mocking: MockingDriver) -> [(String, [AnyHashable])] {
    var result: [(String, [AnyHashable])] = []
    while let entry = mocking.trace.dequeue() { result.append((entry.name, entry.arguments)) }
    return result
  }

  /// A name made from the template: its prefix, then six letters or digits.
  private func isMade(_ name: AnyHashable, from prefix: String) -> Bool {
    guard let name = name as? String, name.hasPrefix(prefix) else { return false }
    let made = name.utf8.dropFirst(prefix.utf8.count)
    return made.count == 6 && made.allSatisfy {
      (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0)
        || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains($0)
        || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
    }
  }

  func testCalls() throws {
    let flags = O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC
    let mode = FilePermissions([.ownerReadWrite, .groupRead]).rawValue
    try MockingDriver.withMockingEnabled { mocking in
      let (path, _) = try FilePath("a/b-XXXXXX").makeUniqueFile(
        options: .closeOnExec, permissions: [.ownerReadWrite, .groupRead])
      _ = try FilePath("a/b-XXXXXX").makeUniqueFile(
        relativeTo: FileDescriptor(rawValue: 42), options: .closeOnExec,
        permissions: [.ownerReadWrite, .groupRead])
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), ["open", "openat"])
      XCTAssertEqual(calls.count, 2)
      guard calls.count == 2 else { return }
      XCTAssertTrue(isMade(calls[0].1[0], from: "a/b-"), "\(calls[0].1)")
      XCTAssertEqual(Array(calls[0].1.dropFirst()), [flags, mode] as [AnyHashable])
      XCTAssertEqual(calls[1].1[0], 42 as AnyHashable)
      XCTAssertTrue(isMade(calls[1].1[1], from: "a/b-"), "\(calls[1].1)")
      XCTAssertEqual(Array(calls[1].1.dropFirst(2)), [flags, mode] as [AnyHashable])
      // The path returned is the one opened.
      XCTAssertEqual(path.string as AnyHashable, calls[0].1[0])
    }
  }

  func testRetries() throws {
    let template = FilePath("XXXXXX")
    try MockingDriver.withMockingEnabled { mocking in
      // A taken name is tried again, with a new name.
      mocking.forceErrno = .counted(errno: EEXIST, count: 1)
      _ = try template.makeUniqueFile(permissions: .ownerReadWrite)
      let taken = entries(mocking)
      XCTAssertEqual(taken.map(\.0), ["open", "open"])

      // Up to a limit.
      mocking.forceErrno = .always(errno: EEXIST)
      XCTAssertThrowsError(try template.makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .fileExists)
      }
      XCTAssertEqual(entries(mocking).count, FilePath._uniqueNameAttempts)

      // An interruption is retried only when asked.
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      _ = try template.makeUniqueFile(permissions: .ownerReadWrite)
      XCTAssertEqual(entries(mocking).map(\.0), ["open", "open"])
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(
        try template.makeUniqueFile(permissions: .ownerReadWrite, retryOnInterrupt: false)
      ) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["open"])

      // A bad template makes no call.
      XCTAssertThrowsError(try FilePath("XXXXX").makeUniqueFile(permissions: .ownerReadWrite)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
}

#endif // (os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)) && ENABLE_MOCKING
