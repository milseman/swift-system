/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// errno belongs to the calling thread, so these can run in parallel.
@Suite("errno")
private struct ErrnoAccessTests {
  private let missing = "/nonexistent-\(getpid())/file"

  @available(System 199, *)
  @Test func currentGetsAndSets() {
    Errno.current = .fileExists
    #expect(Errno.current == .fileExists)
    Errno.current = Errno(rawValue: 0)
    #expect(Errno.current.rawValue == 0)
  }

  @available(System 199, *)
  @Test func currentAfterAFailingCall() {
    // Read errno before anything else runs, #expect included.
    let result = close(-1)
    let error = Errno.current
    #expect(result == -1)
    #expect(error == .badFileDescriptor)
  }

  /// The hazard that `current`'s documentation describes: a release between
  /// the call and the read runs a deinitializer that changes errno.
  @available(System 199, *)
  @Test func aReleaseBeforeTheReadCanChangeErrno() {
    var object: ClosesOnDeinit? = ClosesOnDeinit()
    let result = open(missing, O_RDONLY)
    // Keep the object alive past the call, then release it.
    withExtendedLifetime(object) {}
    object = nil
    let error = Errno.current
    #expect(result == -1)
    #expect(error == .badFileDescriptor, "the open's ENOENT is gone")
    #expect(object == nil)
  }

  @available(System 199, *)
  @Test func checkCapturesErrnoWithTheCall() {
    var object: ClosesOnDeinit? = ClosesOnDeinit()
    #expect(throws: Errno.noSuchFileOrDirectory) {
      try Errno.check { open(missing, O_RDONLY) }
    }
    withExtendedLifetime(object) {}
    object = nil
    #expect(object == nil)
  }

  @available(System 199, *)
  @Test func checkIntegerResults() throws {
    #expect(try Errno.check { getpid() } == getpid())
    #expect(throws: Errno.badFileDescriptor) { try Errno.check { close(-1) } }

    // A result without a sign fails with every bit set, as C's (size_t)-1.
    #expect(throws: Errno.invalidArgument) {
      try Errno.check { () -> UInt in
        Errno.current = .invalidArgument
        return .max
      }
    }
    #expect(try Errno.check { () -> UInt in 5 } == 5)
  }

  @available(System 199, *)
  @Test func checkRetriesOnlyWhenAsked() throws {
    var calls = 0
    let result = try Errno.check { () -> CInt in
      calls += 1
      guard calls == 3 else {
        Errno.current = .interrupted
        return -1
      }
      return 42
    }
    #expect(result == 42)
    #expect(calls == 3)

    calls = 0
    #expect(throws: Errno.interrupted) {
      try Errno.check(retryOnInterrupt: false) { () -> CInt in
        calls += 1
        Errno.current = .interrupted
        return -1
      }
    }
    #expect(calls == 1)

    // Other errors aren't retried.
    calls = 0
    #expect(throws: Errno.ioError) {
      try Errno.check { () -> CInt in
        calls += 1
        Errno.current = .ioError
        return -1
      }
    }
    #expect(calls == 1)
  }

  @available(System 199, *)
  @Test func checkPointerResults() throws {
    let directory = try Errno.check { opendir("/") }
    closedir(directory)
    #expect(throws: Errno.noSuchFileOrDirectory) { try Errno.check { opendir(missing) } }

    var calls = 0
    let pointer = try Errno.check { () -> UnsafeMutableRawPointer? in
      calls += 1
      guard calls == 2 else {
        Errno.current = .interrupted
        return nil
      }
      return UnsafeMutableRawPointer(bitPattern: 0x10)
    }
    #expect(pointer == UnsafeMutableRawPointer(bitPattern: 0x10))
    #expect(calls == 2)
  }

  @available(System 199, *)
  @Test func checkOptionalReadsADirectory() throws {
    try withTemporaryFilePath(basename: "checkOptional") { path in
      for name in ["a", "b", "c"] {
        let fd = try FileDescriptor.open(
          path.appending(name), .writeOnly, options: .create, permissions: .ownerReadWrite)
        try fd.close()
      }
      let directory = try path.withPlatformString { path in
        try Errno.check { opendir(path) }
      }
      defer { closedir(directory) }
      var names: [String] = []
      while let entry = try Errno.checkOptional({ readdir(directory) }) {
        names.append(withUnsafeBytes(of: entry.pointee.d_name) {
          String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
        })
      }
      #expect(Set(names) == [".", "..", "a", "b", "c"])
    }
  }

  @available(System 199, *)
  @Test func checkOptionalTellsNothingFromFailure() throws {
    // A stale errno from before the call doesn't count: it's cleared first.
    Errno.current = .ioError
    #expect(try Errno.checkOptional { () -> UnsafeMutableRawPointer? in nil } == nil)

    #expect(throws: Errno.ioError) {
      try Errno.checkOptional { () -> UnsafeMutableRawPointer? in
        Errno.current = .ioError
        return nil
      }
    }
  }
}

/// A class whose deinitializer makes a failing system call,
/// as a deinitializer that closes a descriptor twice would.
private final class ClosesOnDeinit {
  deinit { _ = close(-1) }
}

#endif // !os(Windows) && !os(WASI)
