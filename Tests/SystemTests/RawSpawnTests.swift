/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// posix_spawn's C attributes and file actions (RawSpawn.swift), with real
// children, as in SpawnTests.

#if !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class RawSpawnTests: XCTestCase {
  /// The C attributes have System's settings, and a closure can add more.
  func testCAttributes() throws {
    let attributes = SpawnAttributes(flags: .resetIDs, processGroup: .new)
    let flags = try attributes.withCAttributes { attributes -> CShort in
      var flags: CShort = 0
      XCTAssertEqual(posix_spawnattr_getflags(&attributes, &flags), 0)
      var group: pid_t = -1
      XCTAssertEqual(posix_spawnattr_getpgroup(&attributes, &group), 0)
      XCTAssertEqual(group, 0)
      return flags
    }
    XCTAssertEqual(flags & CShort(POSIX_SPAWN_RESETIDS), CShort(POSIX_SPAWN_RESETIDS))
    XCTAssertEqual(flags & CShort(POSIX_SPAWN_SETPGROUP), CShort(POSIX_SPAWN_SETPGROUP))
  }

  /// A closure's error comes out, and a rejected setting stops the call
  /// before the closure runs.
  func testErrors() throws {
    struct Stop: Error {}
    XCTAssertThrowsError(try SpawnAttributes().withCAttributes { _ in throw Stop() }) {
      XCTAssertTrue($0 is Stop)
    }
    XCTAssertThrowsError(
      try SpawnFileAction.withCFileActions([.close(FileDescriptor(rawValue: -1))]) { _ -> Void in
        XCTFail("the closure ran")
      }
    ) { XCTAssertEqual($0 as? Errno, .badFileDescriptor) }
  }

  /// A spawn with C values that System built and a closure changed.
  func testSpawningWithCValues() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    let child = try SpawnFileAction.withCFileActions([.duplicate(writer, as: .standardOutput)]) {
      fileActions in
      // The closure's own action: close the pipe's write end after dup2.
      XCTAssertEqual(posix_spawn_file_actions_addclose(&fileActions, writer.rawValue), 0)
      return try SpawnAttributes().withCAttributes { attributes in
        try ProcessID.spawn(
          "/bin/sh", arguments: ["sh", "-c", "echo raw; exit 7"],
          cFileActions: &fileActions, cAttributes: &attributes)
      }
    }
    try writer.close()
    XCTAssertEqual(try child.wait(), .exited(7))
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }
    let count = try reader.read(into: buffer)
    XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "raw\n")
  }

  func testSpawningWithoutCValues() throws {
    let child = try ProcessID.spawn(
      searchingPathFor: "sh", arguments: ["sh", "-c", "exit 4"], cFileActions: nil, cAttributes: nil)
    XCTAssertEqual(try child.wait(), .exited(4))
    XCTAssertThrowsError(
      try ProcessID.spawn("/nonexistent/program", arguments: ["program"], cFileActions: nil, cAttributes: nil)
    ) { XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory) }
  }
}

#endif // !os(Windows) && !os(WASI) && !os(watchOS) && !os(tvOS) && !os(Android)
