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

/// Calls `body` with a null-terminated C array of null-terminated C strings
/// that hold `strings`' bytes, which needn't be UTF-8.
internal func withCStringArray<R>(
  _ strings: [[UInt8]], _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> R
) rethrows -> R {
  let copies: [UnsafeMutablePointer<CChar>?] = strings.map { bytes in
    let copy = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
    for (i, byte) in bytes.enumerated() { copy[i] = CChar(bitPattern: byte) }
    copy[bytes.count] = 0
    return copy
  } + [nil]
  defer { copies.forEach { $0?.deallocate() } }
  return try copies.withUnsafeBufferPointer { try body($0.baseAddress!) }
}

/// A shell script that exits 0 if its first argument is one byte, 0xFF,
/// which isn't UTF-8, and so is the environment variable `BYTE` if it's set.
internal let checksTheByte: [UInt8] = Array(
  #"b="$(printf '\377')"; [ "$1" = "$b" ] && [ "${BYTE-$b}" = "$b" ]"#.utf8)

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

  /// C attributes' flags, read and replaced, keeping the flags that
  /// System's other settings imply.
  func testCAttributesFlags() throws {
    let attributes = SpawnAttributes(flags: .resetIDs, processGroup: .new)
    try attributes.withCAttributes { attributes in
      var flags = try SpawnAttributes.Flags(of: &attributes)
      XCTAssertTrue(flags.contains(.resetIDs))
      XCTAssertEqual(flags.rawValue & CShort(POSIX_SPAWN_SETPGROUP), CShort(POSIX_SPAWN_SETPGROUP))
      flags.insert(.closeOnExecByDefault)
      flags.remove(.resetIDs)
      try flags.store(in: &attributes)
      let stored = try SpawnAttributes.Flags(of: &attributes)
      XCTAssertEqual(stored, flags)
      var cFlags: CShort = 0
      XCTAssertEqual(posix_spawnattr_getflags(&attributes, &cFlags), 0)
      XCTAssertEqual(cFlags, flags.rawValue)
    }
  }

  /// A flag that a closure adds to C attributes takes effect,
  /// as Subprocess's preSpawnProcessConfigurator adds one.
  func testSpawningWithAStoredFlag() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    let actions: [SpawnFileAction] = [.duplicate(reader, as: .standardInput), .close(writer)]
    let child = try SpawnFileAction.withCFileActions(actions) { fileActions in
      try SpawnAttributes().withCAttributes { attributes in
        var flags = try SpawnAttributes.Flags(of: &attributes)
        flags.insert(.createSession)
        try flags.store(in: &attributes)
        // The child waits for its standard input to close.
        return try ProcessID.spawn(
          "/bin/sh", arguments: ["sh", "-c", "read line; exit 3"],
          cFileActions: &fileActions, cAttributes: &attributes)
      }
    }
    try reader.close()
    let session = try child.sessionID()
    try writer.close()
    XCTAssertEqual(try child.wait(), .exited(3))
    XCTAssertEqual(session, child)
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

  /// Arguments and an environment as C arrays, whose bytes needn't be UTF-8.
  func testSpawningWithCArrays() throws {
    let child = try withCStringArray([Array("sh".utf8), Array("-c".utf8), checksTheByte, Array("sh".utf8), [0xff]]) {
      arguments in
      try withCStringArray([Array("BYTE=".utf8) + [0xff]]) { environment in
        try ProcessID.spawn(
          "/bin/sh", arguments: arguments, environment: environment, cFileActions: nil, cAttributes: nil)
      }
    }
    XCTAssertEqual(try child.wait(), .exited(0))
    // The byte is what the child compares: another one fails.
    let other = try withCStringArray([Array("sh".utf8), Array("-c".utf8), checksTheByte, Array("sh".utf8), [0xfe]]) {
      try ProcessID.spawn("/bin/sh", arguments: $0, environment: nil, cFileActions: nil, cAttributes: nil)
    }
    XCTAssertEqual(try other.wait(), .exited(1))
  }

  /// Actions added to C file actions that other code built,
  /// as a pre-spawn configurator does.
  func testAddingActionsToCFileActions() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    let child = try SpawnFileAction.withCFileActions([]) { fileActions in
      try SpawnFileAction.setWorkingDirectory("/usr").add(to: &fileActions)
      try SpawnFileAction.duplicate(writer, as: .standardOutput).add(to: &fileActions)
      try SpawnFileAction.close(writer).add(to: &fileActions)
      return try ProcessID.spawn(
        "/bin/pwd", arguments: ["pwd"], cFileActions: &fileActions, cAttributes: nil)
    }
    try writer.close()
    XCTAssertEqual(try child.wait(), .exited(0))
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { buffer.deallocate() }
    let count = try reader.read(into: buffer)
    XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "/usr\n")

    // An action that the system rejects throws its error.
    XCTAssertThrowsError(
      try SpawnFileAction.withCFileActions([]) { fileActions in
        try SpawnFileAction.close(FileDescriptor(rawValue: -1)).add(to: &fileActions)
      }
    ) { XCTAssertEqual($0 as? Errno, .badFileDescriptor) }
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
