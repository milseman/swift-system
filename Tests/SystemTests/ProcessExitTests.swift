/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// swift-testing runs each exit test's body in a process of its own, which
// the body ends; it has no exit tests on WASI.
#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
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

@Suite("Process exit")
private struct ProcessExitTests {
  @available(System 199, *)
  @Test func exitEndsTheProcessWithTheStatus() async {
    await #expect(processExitsWith: .exitCode(3)) {
      ProcessID.exit(3)
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
    #expect(
      String(decoding: result.standardOutputContent, as: UTF8.self)
        == "registered second\nregistered first\n")
  }

  /// The exit test's standard output is a pipe, so a C stream opened on it
  /// buffers what it's given until it's flushed.
  @available(System 199, *)
  @Test func exitFlushesBufferedOutput() async throws {
    let result = try await #require(
      processExitsWith: .exitCode(0), observing: [\.standardOutputContent]
    ) {
      fputs("buffered", fdopen(FileDescriptor.standardOutput.rawValue, "w"))
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
        _ = try? FileDescriptor.standardOutput.writeAll("handler".utf8)
      }
      fputs("buffered", fdopen(FileDescriptor.standardOutput.rawValue, "w"))
      ProcessID.exitImmediately(4)
    }
    // swift-testing 6.2 captures 32 bytes of its own, the same each time,
    // from a child that ends this way, so look for what shouldn't be there.
    let output = String(decoding: result.standardOutputContent, as: UTF8.self)
    #expect(!output.contains("buffered"))
    #expect(!output.contains("handler"))
  }

  @available(System 199, *)
  @Test func abortEndsTheProcessWithTheAbortSignalAndNoHandlers() async throws {
    let result = try await #require(
      processExitsWith: .signal(SIGABRT), observing: [\.standardOutputContent]
    ) {
      try ProcessID.addExitHandler {
        _ = try? FileDescriptor.standardOutput.writeAll("handler".utf8)
      }
      ProcessID.abort()
    }
    #expect(!String(decoding: result.standardOutputContent, as: UTF8.self).contains("handler"))
  }

  /// A parent that waits with `waitpid` gets only the status's low 8 bits.
  /// swift-testing waits with `waitid`, which on Darwin reports more of them.
  @available(System 199, *)
  @Test func howMuchOfTheStatusAParentGets() async {
    #if SYSTEM_PACKAGE_DARWIN
    await #expect(processExitsWith: .exitCode(0x105)) {
      ProcessID.exit(0x105)
    }
    #else
    await #expect(processExitsWith: .exitCode(5)) {
      ProcessID.exit(0x105)
    }
    #endif
  }
}

#endif // !os(Windows) && !os(WASI)
