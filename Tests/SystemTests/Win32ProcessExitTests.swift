/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// swift-testing runs each exit test's body in a process of its own, which
// the body ends.
#if os(Windows)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import ucrt

// ProcessID's exit, exitImmediately and addExitHandler, and
// ProcessID.ExitCode, on Windows.
@Suite("Process exit on Windows")
private struct Win32ProcessExitTests {
  @available(System 199, *)
  @Test func theConstantsAreTheCRuntimes() {
    #expect(_EXIT_SUCCESS == ucrt.EXIT_SUCCESS)
    #expect(_EXIT_FAILURE == ucrt.EXIT_FAILURE)
    #expect(ProcessID.ExitCode.success.rawValue == ucrt.EXIT_SUCCESS)
    #expect(ProcessID.ExitCode.failure.rawValue == ucrt.EXIT_FAILURE)
  }

  @available(System 199, *)
  @Test func descriptions() {
    #expect(ProcessID.ExitCode.success.description == "success (0)")
    #expect(ProcessID.ExitCode.failure.description == "failure (1)")
    #expect(ProcessID.ExitCode(rawValue: 3).description == "3")
    // An access violation's NTSTATUS.
    #expect(
      ProcessID.ExitCode(rawValue: CInt(bitPattern: 0xC000_0005)).description
        == "-1073741819 (0xC0000005)")
  }

  @available(System 199, *)
  @Test func exitEndsTheProcessWithTheStatus() async {
    await #expect(processExitsWith: .exitCode(3)) {
      ProcessID.exit(3)
    }
  }

  /// Windows gives a parent all 32 bits.
  @available(System 199, *)
  @Test func theParentGetsTheWholeStatus() async {
    await #expect(processExitsWith: .exitCode(0x105)) {
      ProcessID.exit(0x105)
    }
    await #expect(processExitsWith: .exitCode(CInt(bitPattern: 0xC000_013A))) {
      ProcessID.exitImmediately(CInt(bitPattern: 0xC000_013A))
    }
  }

  @available(System 199, *)
  @Test func exitRunsTheHandlersInReverseOrder() async throws {
    let result = try await #require(
      processExitsWith: .exitCode(0), observing: [\.standardOutputContent]
    ) {
      try ProcessID.addExitHandler { print("registered first") }
      try ProcessID.addExitHandler { print("registered second") }
      ProcessID.exit(0)
    }
    // The C runtime's text mode writes each newline as \r\n.
    let output = String(
      decoding: result.standardOutputContent.filter { $0 != UInt8(ascii: "\r") }, as: UTF8.self)
    #expect(output == "registered second\nregistered first\n")
  }

  /// The exit test's standard output is a pipe, which the C runtime's
  /// stdout, where `print` writes, buffers until it's flushed.
  @available(System 199, *)
  @Test func exitFlushesBufferedOutput() async throws {
    let result = try await #require(
      processExitsWith: .exitCode(0), observing: [\.standardOutputContent]
    ) {
      print("buffered", terminator: "")
      ProcessID.exit(0)
    }
    #expect(String(decoding: result.standardOutputContent, as: UTF8.self) == "buffered")
  }

  @available(System 199, *)
  @Test func exitImmediatelySkipsTheHandlersAndBufferedOutput() async throws {
    let result = try await #require(
      processExitsWith: .exitCode(4), observing: [\.standardOutputContent]
    ) {
      try ProcessID.addExitHandler {
        _ = "handler".withCString { ucrt._write(1, $0, 7) }
      }
      print("buffered", terminator: "")
      ProcessID.exitImmediately(4)
    }
    let output = String(decoding: result.standardOutputContent, as: UTF8.self)
    #expect(!output.contains("buffered"))
    #expect(!output.contains("handler"))
  }

  @available(System 199, *)
  @Test func exitWithACode() async {
    await #expect(processExitsWith: .failure) {
      ProcessID.exit(.failure)
    }
    await #expect(processExitsWith: .success) {
      ProcessID.exitImmediately(.success)
    }
  }
}

#endif // os(Windows)
