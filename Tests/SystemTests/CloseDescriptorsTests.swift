/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: closing, or marking close-on-exec, ranges of descriptors. These
// are XCTest tests, which run one at a time in a process of their own, since
// they close the process's descriptors.

#if os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(macOS)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
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

@available(System 199, *)
final class CloseDescriptorsTests: XCTestCase {
  // Three free descriptor numbers that this test occupies, so that closing
  // a range of them can't close anyone else's: an unbounded range would
  // close XCTest's own descriptors.
  private func occupyThreeDescriptors() throws -> FileDescriptor {
    let limit = try ResourceLimit.current(for: .openFiles).soft
    let top = CInt(clamping: min(limit.rawValue, 1024)) - 8
    let first = FileDescriptor(rawValue: top - 3)
    for fd in first.rawValue..<(first.rawValue + 3) {
      guard fcntl(fd, F_GETFD) == -1 && errno == EBADF else {
        throw XCTSkip("Descriptor \(fd) is in use")
      }
    }
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    for offset: CInt in 0..<3 {
      _ = try pipe.readEnd.duplicate(as: FileDescriptor(rawValue: first.rawValue + offset))
    }
    return first
  }

  private func isOpen(_ fd: CInt) -> Bool { fcntl(fd, F_GETFD) != -1 }

  func testClosingARange() throws {
    let first = try occupyThreeDescriptors()
    let third = FileDescriptor(rawValue: first.rawValue + 2)
    defer { try? third.close() }
    try FileDescriptor.closeAll(from: first, through: FileDescriptor(rawValue: first.rawValue + 1))
    XCTAssertFalse(isOpen(first.rawValue))
    XCTAssertFalse(isOpen(first.rawValue + 1))
    XCTAssertTrue(isOpen(third.rawValue))
  }

  #if !os(OpenBSD)
  func testMarkingARangeCloseOnExec() throws {
    let first = try occupyThreeDescriptors()
    defer {
      for fd in first.rawValue..<(first.rawValue + 3) { close(fd) }
    }
    try FileDescriptor.setCloseOnExecForAll(
      from: first, through: FileDescriptor(rawValue: first.rawValue + 1))
    XCTAssertTrue(try first.descriptorFlags().contains(.closeOnExec))
    XCTAssertTrue(
      try FileDescriptor(rawValue: first.rawValue + 1).descriptorFlags().contains(.closeOnExec))
    XCTAssertFalse(
      try FileDescriptor(rawValue: first.rawValue + 2).descriptorFlags().contains(.closeOnExec))
  }
  #endif

  #if os(Linux) || os(Android)
  /// The fallback for kernels before 5.11, which have no
  /// CLOSE_RANGE_CLOEXEC: the descriptors that /proc/self/fd lists.
  func testMarkingARangeFromTheListing() throws {
    let first = try occupyThreeDescriptors()
    defer {
      for fd in first.rawValue..<(first.rawValue + 3) { close(fd) }
    }
    try FileDescriptor._markListedDescriptorsCloseOnExec(
      first, FileDescriptor(rawValue: first.rawValue + 1)
    ).get()
    XCTAssertTrue(try first.descriptorFlags().contains(.closeOnExec))
    XCTAssertTrue(
      try FileDescriptor(rawValue: first.rawValue + 1).descriptorFlags().contains(.closeOnExec))
    XCTAssertFalse(
      try FileDescriptor(rawValue: first.rawValue + 2).descriptorFlags().contains(.closeOnExec))
  }
  #endif

  func testAnEmptyRangeIsInvalid() {
    XCTAssertThrowsError(
      try FileDescriptor.closeAll(
        from: FileDescriptor(rawValue: 10), through: FileDescriptor(rawValue: 9))
    ) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }
}
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(macOS)
