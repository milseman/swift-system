/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Small widenings to FreeBSD and OpenBSD, where nothing here builds: O_SYNC
// and O_DSYNC (FreeBSD's O_DSYNC, from 13.0, is a flag of its own, and
// OpenBSD's is O_SYNC), OpenBSD's O_RSYNC (O_SYNC too), dladdr, and
// FreeBSD's pthread_suspend_all_np. SmallGapsTests, SmallDarwinGapsTests and
// SmallLinuxGapsTests have the other platforms'.

#if os(FreeBSD) || os(OpenBSD)

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SmallBSDGapsTests: XCTestCase {
  func testSynchronizedIO() throws {
    #if os(OpenBSD)
    XCTAssertEqual(FileDescriptor.OpenOptions.dataSync, .sync)
    XCTAssertEqual(FileDescriptor.OpenOptions.readSync, .sync)
    XCTAssertEqual(FileDescriptor.StatusFlags.readSync, .sync)
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

  /// dladdr finds the library that contains a function, and its symbol.
  func testSymbolInfo() throws {
    let program = try DynamicLibrary.mainProgram()
    let found = program.address(of: "getpid")
    let getpidAddress = try XCTUnwrap(found)
    try program.close()
    let info = try XCTUnwrap(DynamicLibrary.symbolInfo(containing: getpidAddress))
    // The nearest symbol can be an alias, such as _getpid.
    XCTAssertTrue(info.symbolName?.hasSuffix("getpid") == true, "\(String(describing: info.symbolName))")
    XCTAssertEqual(info.symbolAddress, UnsafeRawPointer(getpidAddress))
    XCTAssertTrue(info.libraryPath.string.contains("libc.so"), "\(info.libraryPath)")
    XCTAssertNotNil(info.libraryAddress)
    // An address that no library contains.
    XCTAssertNil(DynamicLibrary.symbolInfo(containing: UnsafeRawPointer(bitPattern: 0x10)!))
  }

  #if os(FreeBSD)
  /// A thread that's running, or about to, when the others are suspended
  /// finishes once they're resumed.
  func testSuspendingTheOtherThreads() throws {
    let thread = try PThread { _ = (0..<1000).reduce(0, +) }
    PThread.suspendAll()
    PThread.resumeAll()
    try thread.join()
  }
  #endif
}

#endif // os(FreeBSD) || os(OpenBSD)
