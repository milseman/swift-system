/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Reading a passphrase on a terminal, on Linux and Android, where System
// takes readpassphrase's steps itself (ReadPassphrase.swift). The process
// has no controlling terminal in a container, so these call the steps with
// a pseudoterminal as the terminal. ReadPassphraseTest has the rest, on
// every platform. XCTest, since a thread reads while the test types.

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

@available(System 199, *)
final class ReadPassphraseLinuxTest: XCTestCase {
  /// Reads `count` bytes from `fd`, which has them or will.
  private func read(_ fd: FileDescriptor, count: Int) throws -> [UInt8] {
    var bytes: [UInt8] = []
    var byte: UInt8 = 0
    while bytes.count < count {
      let read = try withUnsafeMutableBytes(of: &byte) { try fd.read(into: $0) }
      guard read == 1 else { break }
      bytes.append(byte)
    }
    return bytes
  }

  /// Reads a passphrase on `terminal` in a thread, and returns the prompt
  /// that the controller reads first, once echo is off, then what it reads
  /// after typing `typed`, the result, and the buffer. The controller reads
  /// all of that before the thread is joined: restoring the attributes
  /// (TCSAFLUSH) waits until the terminal's output is read, on Darwin.
  private func readPassphrase(
    controller: FileDescriptor, terminal: FileDescriptor,
    options: TerminalDescriptor.PassphraseOptions, typing typed: String,
    expectedAfter: Int
  ) throws -> (prompt: [UInt8], after: [UInt8], count: Int, buffer: [UInt8]) {
    let result = Locked<(Result<Int, Errno>, [UInt8])?>(nil)
    let thread = try PThread {
      var buffer = [UInt8](repeating: 0xFF, count: 16)
      let count = buffer.withUnsafeMutableBytes {
        TerminalDescriptor._readPassphrase(
          prompt: "Password: ", into: $0, options: options,
          input: terminal, output: terminal, onTerminal: true)
      }
      result.withValue { $0 = (count, buffer) }
    }
    // The prompt comes after echo is off and what was typed ahead is gone.
    let prompt = try read(controller, count: "Password: ".utf8.count)
    _ = try controller.writeAll(typed.utf8)
    let after = try read(controller, count: expectedAfter)
    try thread.join()
    let (count, buffer) = try XCTUnwrap(result.value)
    return (prompt, after, try count.get(), buffer)
  }

  /// Nothing typed is echoed, a newline follows, and the terminal's
  /// attributes are as they were.
  func testEchoIsOff() throws {
    try withPseudoterminal { controller, terminal in
      let before = try TerminalDescriptor(terminal).attributes()
      XCTAssertTrue(before.localFlags.contains(.echo))
      // The terminal's output turns the newline into CR LF (ONLCR).
      let read = try readPassphrase(
        controller: controller, terminal: terminal, options: [],
        typing: "Secret\n", expectedAfter: 2)
      XCTAssertEqual(read.prompt, Array("Password: ".utf8))
      XCTAssertEqual(read.count, 6)
      XCTAssertEqual(Array(read.buffer[..<7]), Array("Secret".utf8) + [0])
      XCTAssertEqual(read.after, Array("\r\n".utf8))
      // And nothing more: the thread's writes are done once it's joined.
      XCTAssertEqual(try controller.poll(for: .readable, timeout: .zero), [])
      XCTAssertEqual(try TerminalDescriptor(terminal).attributes().localFlags, before.localFlags)
    }
  }

  /// With echo, what's typed comes back, and no newline is added.
  func testEcho() throws {
    try withPseudoterminal { controller, terminal in
      let read = try readPassphrase(
        controller: controller, terminal: terminal, options: [.echo, .uppercase],
        typing: "pin\n", expectedAfter: 5)
      XCTAssertEqual(read.count, 3)
      XCTAssertEqual(Array(read.buffer[..<4]), Array("PIN".utf8) + [0])
      XCTAssertEqual(read.after, Array("pin\r\n".utf8))
    }
  }
}

#endif // os(Linux) || os(Android)
