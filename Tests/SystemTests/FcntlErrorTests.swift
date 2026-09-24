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

// Error paths for the typed fcntl methods: descriptorFlags,
// setDescriptorFlags, statusFlags, setStatusFlags, and accessMode, and on
// Darwin, synchronizeFully and synchronizeWithBarrier. Invalid descriptors
// are -1, rather than a closed descriptor, whose number another open could
// reuse.

#if !os(Windows)
@available(System 199, *)
final class FcntlErrorTest: XCTestCase {
  /// Checks that `body` throws `expected`.
  private func check(
    _ expected: Errno, file: StaticString = #filePath, line: UInt = #line,
    _ body: () throws -> Void
  ) {
    XCTAssertThrowsError(try body(), file: file, line: line) {
      XCTAssertEqual($0 as? Errno, expected, file: file, line: line)
    }
  }

  func testInvalidDescriptor() {
    let fd = FileDescriptor(rawValue: -1)
    #if !os(WASI)
    check(.badFileDescriptor) { _ = try fd.descriptorFlags() }
    check(.badFileDescriptor) { try fd.setDescriptorFlags(.closeOnExec) }
    check(.badFileDescriptor) { try fd.setDescriptorFlags([]) }
    #endif
    check(.badFileDescriptor) { _ = try fd.statusFlags() }
    check(.badFileDescriptor) { try fd.setStatusFlags(.nonBlocking) }
    check(.badFileDescriptor) { try fd.setStatusFlags([]) }
    check(.badFileDescriptor) { _ = try fd.accessMode() }
    #if SYSTEM_PACKAGE_DARWIN
    check(.badFileDescriptor) { try fd.synchronizeFully() }
    check(.badFileDescriptor) { try fd.synchronizeWithBarrier() }
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testSynchronizeFullyFailures() throws {
    // Only a file has storage to flush. F_FULLFSYNC and F_BARRIERFSYNC treat
    // a pipe's descriptor as the wrong kind, and a device, or a file system
    // that doesn't support them, such as devfs, as unsupported.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    check(.badFileDescriptor) { try pipe.writeEnd.synchronizeFully() }
    check(.badFileDescriptor) { try pipe.writeEnd.synchronizeWithBarrier() }

    let device = try FileDescriptor.open("/dev/null", .readWrite)
    try device.closeAfter {
      check(.operationNotSupportedByDevice) { try device.synchronizeFully() }
      check(.operationNotSupportedByDevice) { try device.synchronizeWithBarrier() }
    }

    let devfs = try FileDescriptor.open("/dev", .readOnly, options: .directory)
    try devfs.closeAfter {
      check(.notSupported) { try devfs.synchronizeFully() }
      check(.notSupported) { try devfs.synchronizeWithBarrier() }
    }

    // The flush needs no write access.
    try withTemporaryFilePath(basename: "testSynchronizeFullyFailures") { path in
      let file = path.appending("file")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let fd = try FileDescriptor.open(file, .readOnly)
      try fd.closeAfter {
        try fd.synchronizeFully()
        try fd.synchronizeWithBarrier()
      }
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN
}
#endif // !os(Windows)
