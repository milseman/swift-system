/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Reading a passphrase. XCTest, since the real reads replace the process's
// standard input with a pipe.

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class ReadPassphraseTest: XCTestCase {
  /// Calls `body` with standard input reading `input` from a pipe.
  private func withStandardInput<R>(_ input: String, _ body: () throws -> R) throws -> R {
    let saved = try FileDescriptor.standardInput.duplicate()
    defer {
      _ = try? saved.duplicate(as: .standardInput)
      try? saved.close()
    }
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    _ = try writeEnd.writeAll(input.utf8)
    try writeEnd.close()
    _ = try readEnd.duplicate(as: .standardInput)
    try readEnd.close()
    return try body()
  }

  func testStandardInput() throws {
    // An empty prompt, since it goes to standard error.
    try withStandardInput("Secret word\nnext line\n") {
      let options: TerminalDescriptor.PassphraseOptions = .standardInput
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "", options: options), "Secret word")
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "", options: options), "next line")
    }
    try withStandardInput("MiXeD\nMiXeD\nMiXeD\n\u{E9}\n") {
      XCTAssertEqual(
        try TerminalDescriptor.readPassphrase(prompt: "", options: [.standardInput, .lowercase]), "mixed")
      XCTAssertEqual(
        try TerminalDescriptor.readPassphrase(prompt: "", options: [.standardInput, .uppercase]), "MIXED")
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "", options: .standardInput), "MiXeD")
      // é is 0xC3 0xA9, which lose their high bits.
      XCTAssertEqual(
        try TerminalDescriptor.readPassphrase(prompt: "", options: [.standardInput, .sevenBit]), "C)")
    }
  }

  func testALongLineIsCut() throws {
    try withStandardInput("abcdefgh\nijk\n") {
      // The rest of the line is discarded, not left for the next read.
      XCTAssertEqual(
        try TerminalDescriptor.readPassphrase(prompt: "", maxByteCount: 3, options: .standardInput), "abc")
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "", options: .standardInput), "ijk")
    }
    try withStandardInput("secret\n") {
      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
      defer {
        Memory.secureZero(buffer)
        buffer.deallocate()
      }
      buffer.initializeMemory(as: UInt8.self, repeating: 0xFF)
      let count = try TerminalDescriptor.readPassphrase(prompt: "", into: buffer, options: .standardInput)
      XCTAssertEqual(count, 6)
      XCTAssertEqual(Array(buffer[..<7]), Array("secret".utf8) + [0])
    }
  }

  func testRequiringATerminal() throws {
    // Only without a controlling terminal, which the test would read.
    let terminal = open("/dev/tty", O_RDWR)
    if terminal != -1 {
      close(terminal)
      throw XCTSkip("the process has a controlling terminal")
    }
    XCTAssertThrowsError(try TerminalDescriptor.readPassphrase(prompt: "", options: .requireTerminal)) {
      XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
    }
  }

  #if ENABLE_MOCKING
  func testCalls() throws {
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "Password: "), "")
      XCTAssertEqual(
        try TerminalDescriptor.readPassphrase(
          prompt: "PIN: ", maxByteCount: 8, options: [.echo, .requireTerminal]),
        "")
      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 32, alignment: 1)
      defer { buffer.deallocate() }
      XCTAssertEqual(try TerminalDescriptor.readPassphrase(prompt: "", into: buffer), 0)
      var calls: [(String, [AnyHashable])] = []
      while let entry = mocking.trace.dequeue() { calls.append((entry.name, entry.arguments)) }
      XCTAssertEqual(calls.map(\.0), ["readpassphrase", "readpassphrase", "readpassphrase"])
      XCTAssertEqual(calls.map(\.1), [
        ["Password: ", 1025, CInt(0)], ["PIN: ", 9, RPP_ECHO_ON | RPP_REQUIRE_TTY], ["", 32, CInt(0)],
      ] as [[AnyHashable]])

      // An interruption isn't retried: the user sent the signal to stop.
      mocking.forceErrno = .counted(errno: EINTR, count: 1)
      XCTAssertThrowsError(try TerminalDescriptor.readPassphrase(prompt: "")) {
        XCTAssertEqual($0 as? Errno, .interrupted)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "readpassphrase")
      XCTAssertTrue(mocking.trace.isEmpty)

      // An empty buffer makes no call.
      XCTAssertThrowsError(
        try TerminalDescriptor.readPassphrase(prompt: "", into: UnsafeMutableRawBufferPointer(start: nil, count: 0))
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN
