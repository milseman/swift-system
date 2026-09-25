/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for thread names. Each test names a thread of its own,
// since swift-testing runs tests on threads that other tests share.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("PThread names")
private struct PThreadNameTests {
  // Runs `body` on a new thread, and returns its result.
  @available(System 199, *)
  private func onNewThread<R>(
    _ body: @escaping @Sendable () -> R
  ) throws -> R {
    let result = Locked<R?>(nil)
    let thread = try PThread { result.withValue { $0 = body() } }
    try thread.join()
    return result.value!
  }

  @available(System 199, *)
  @Test func setAndGetCurrentName() throws {
    let name = try onNewThread {
      Result { () throws(Errno) in
        try PThread.setCurrentName("worker-1")
        return try PThread.ID.current.name()
      }
    }
    #expect(try name.get() == "worker-1")
  }

  @available(System 199, *)
  @Test func nameOfAnotherThread() throws {
    let named = Latch()
    let release = Latch()
    let thread = try PThread {
      try! PThread.setCurrentName("observed")
      named.open()
      _ = release.wait()
    }
    defer { release.open() }
    #expect(named.wait())
    #expect(try thread.id.name() == "observed")
    _ = thread
  }

  @available(System 199, *)
  @Test func nonASCIIName() throws {
    // Six bytes of UTF-8 in three characters.
    let name = try onNewThread {
      Result { () throws(Errno) in
        try PThread.setCurrentName("fé€")
        return try PThread.ID.current.name()
      }
    }
    #expect(try name.get() == "fé€")
  }

  @available(System 199, *)
  @Test func nameTooLong() throws {
    #if SYSTEM_PACKAGE_DARWIN
    let tooLong = String(repeating: "x", count: 64)
    let fits = String(repeating: "x", count: 63)
    let error = Errno.fileNameTooLong
    #else
    let tooLong = String(repeating: "x", count: 16)
    let fits = String(repeating: "x", count: 15)
    let error = Errno.outOfRange
    #endif
    let results = try onNewThread {
      (Result { () throws(Errno) in try PThread.setCurrentName(tooLong) },
       Result { () throws(Errno) in
         try PThread.setCurrentName(fits)
         return try PThread.ID.current.name()
       })
    }
    #expect(throws: error) { try results.0.get() }
    #expect(try results.1.get() == fits)
  }

  @available(System 199, *)
  @Test func nameWithNUL() throws {
    let result = try onNewThread {
      Result { () throws(Errno) in try PThread.setCurrentName("a\0b") }
    }
    #expect(throws: Errno.invalidArgument) { try result.get() }
  }

  #if os(Linux) || os(Android) || os(FreeBSD)
  @available(System 199, *)
  @Test func setNameOfAnotherThread() throws {
    let release = Latch()
    let thread = try PThread { _ = release.wait() }
    defer { release.open() }
    try thread.id.setName("renamed")
    #expect(try thread.id.name() == "renamed")
  }
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
