/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

import Testing

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

// The limits that CompileTimeLimitsTest checks on Darwin, which Linux
// enforces differently.
@Suite("Compile-time limits on Linux")
private struct CompileTimeLimitsLinuxTests {
  @available(System 199, *)
  @Test func theHeadersValues() {
    #if canImport(Glibc) || canImport(Musl)
    #expect(SystemConfig.maxSymbolicLinks == 20)
    #endif
    #expect(SystemConfig.maxExtendedAttributeNameBytes == 255)
  }

  /// The kernel follows more links than the headers' limit: a chain of
  /// maxSymbolicLinks links opens, and so does one of 40, but not one of 41.
  @available(System 199, *)
  @Test func theKernelFollowsFortyLinks() throws {
    try withTemporaryFilePath(basename: "theKernelFollowsFortyLinks") { dir in
      let target = dir.appending("target")
      try FileDescriptor.open(
        target, .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
      // link0 -> link1 -> ... -> link(n-1) -> target: opening link0 follows n links.
      func chain(_ n: Int, _ prefix: String) throws -> FilePath {
        for k in 0..<n {
          let next = k == n - 1 ? "target" : "\(prefix)\(k + 1)"
          try dir.appending("\(prefix)\(k)").makeSymbolicLink(to: FilePath(next))
        }
        return FilePath("\(prefix)0")
      }
      let fd = try FileDescriptor.open(dir, .readOnly)
      defer { try? fd.close() }
      let headers = try chain(SystemConfig.maxSymbolicLinks, "a")
      let forty = try chain(40, "b")
      let fortyOne = try chain(41, "c")
      try FileDescriptor.open(headers, relativeTo: fd, .readOnly).close()
      try FileDescriptor.open(forty, relativeTo: fd, .readOnly).close()
      #expect(throws: Errno.tooManySymbolicLinkLevels) {
        try FileDescriptor.open(fortyOne, relativeTo: fd, .readOnly).close()
      }
    }
  }

  /// An extended attribute's name, with its namespace, can be
  /// maxExtendedAttributeNameBytes bytes long, and a longer one throws
  /// ERANGE, where Darwin throws ENAMETOOLONG.
  @available(System 199, *)
  @Test func extendedAttributeNames() throws {
    try withTemporaryFilePath(basename: "extendedAttributeNames") { dir in
      let file = dir.appending("file")
      try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
      let longest = "user." + String(
        repeating: "a", count: SystemConfig.maxExtendedAttributeNameBytes - 5)
      do {
        try file.setExtendedAttribute(longest, to: [1])
      } catch {
        // The file system has no user attributes.
        #expect((error as? Errno) == Errno.notSupported)
        return
      }
      #expect(throws: Errno.outOfRange) {
        try file.setExtendedAttribute(longest + "a", to: [1])
      }
    }
  }
}

#endif // os(Linux) || os(Android)
