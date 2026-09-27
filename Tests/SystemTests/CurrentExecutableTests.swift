/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class CurrentExecutableTest: XCTestCase {
  func testCurrentExecutable() throws {
    let path = FilePath.currentExecutable()
    XCTAssertTrue(path.isAbsolute)
    let status = try path.stat()
    XCTAssertEqual(status.type, .regular)
    XCTAssertTrue(status.permissions.contains(.ownerExecute))

    // It's the same file as the kernel's path, which is resolved.
    #if os(macOS)
    let resolved = try ProcessID.current.executablePath()
    XCTAssertEqual(try resolved.stat().inode, status.inode)
    XCTAssertEqual(try resolved.stat().deviceID, status.deviceID)
    #endif

    // The first argument names the same executable.
    XCTAssertEqual(
      path.lastComponent, FilePath(CommandLine.arguments[0]).lastComponent)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
