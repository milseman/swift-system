/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// O_SYNC and O_DSYNC on FreeBSD, whose O_DSYNC (from 13.0) is a flag of its
// own, and OpenBSD, whose O_DSYNC is O_SYNC. SmallGapsTests has Darwin's,
// and SmallLinuxGapsTests Linux's.

#if os(FreeBSD) || os(OpenBSD)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SynchronizedIOBSDTest: XCTestCase {
  func testSynchronizedIO() throws {
    #if os(OpenBSD)
    XCTAssertEqual(FileDescriptor.OpenOptions.dataSync, .sync)
    #else
    XCTAssertNotEqual(FileDescriptor.OpenOptions.dataSync, .sync)
    #endif
    try withTemporaryFilePath(basename: "testSynchronizedIO") { dir in
      let path = dir.appending("file")
      let sync = try FileDescriptor.open(
        path, .writeOnly, options: [.create, .sync], permissions: .ownerReadWrite)
      defer { try? sync.close() }
      XCTAssertTrue(try sync.statusFlags().contains(.sync))
      let dataSync = try FileDescriptor.open(path, .writeOnly, options: .dataSync)
      defer { try? dataSync.close() }
      XCTAssertTrue(try dataSync.statusFlags().contains(.dataSync))
      try dataSync.writeAll("synchronized".utf8)
    }
  }
}

#endif // os(FreeBSD) || os(OpenBSD)
