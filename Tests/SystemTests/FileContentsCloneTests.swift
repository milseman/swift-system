/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

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

// Cloning a file's contents (FICLONE). The containers' file systems, ext4,
// overlayfs and tmpfs, don't share storage between files, so the clone
// itself is checked only on one that does; the checks the kernel makes
// first are checked everywhere.
@available(System 199, *)
final class FileContentsCloneTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    MockTestCase(name: "ficlone", .noInterrupt, CInt(7), CInt(8)) { _ in
      try FileDescriptor(rawValue: 7).cloneContents(of: FileDescriptor(rawValue: 8))
    }.runAllTests()
  }
  #endif

  func testCloningContents() throws {
    try withTemporaryFilePath(basename: "testCloningContents") { dir in
      let source = try FileDescriptor.open(
        dir.appending("source"), .readWrite, options: .create, permissions: .ownerReadWrite)
      defer { try? source.close() }
      _ = try source.writeAll("cloned".utf8)
      let destination = try FileDescriptor.open(
        dir.appending("destination"), .readWrite, options: .create,
        permissions: .ownerReadWrite)
      defer { try? destination.close() }

      // The kernel checks the descriptors before the file system:
      // a pipe isn't a regular file, and the destination must be writable.
      let pipe = try FileDescriptor.pipe()
      defer {
        try? pipe.readEnd.close()
        try? pipe.writeEnd.close()
      }
      XCTAssertThrowsError(try destination.cloneContents(of: pipe.readEnd)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      let readOnly = try FileDescriptor.open(dir.appending("destination"), .readOnly)
      defer { try? readOnly.close() }
      XCTAssertThrowsError(try readOnly.cloneContents(of: source)) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }

      do {
        try destination.cloneContents(of: source)
      } catch {
        // A file system that doesn't share storage between files.
        XCTAssertEqual(error as? Errno, .notSupported)
        return
      }
      XCTAssertEqual(try destination.stat().size, 6)
      var bytes = [UInt8](repeating: 0, count: 6)
      let count = try bytes.withUnsafeMutableBytes {
        try destination.read(fromAbsoluteOffset: 0, into: $0)
      }
      XCTAssertEqual(count, 6)
      XCTAssertEqual(bytes, Array("cloned".utf8))
    }
  }
}

#endif // os(Linux) || os(Android)
