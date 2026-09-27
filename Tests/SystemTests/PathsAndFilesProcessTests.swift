/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

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

// The creation mask and the environment belong to the whole process, so
// these are XCTests, which run one at a time in a process of their own.
@available(System 199, *)
final class PathsAndFilesProcessTests: XCTestCase {
  func testSetCreationMask() throws {
    let mask: FilePermissions = [.groupWrite, .otherReadWriteExecute]
    let original = FilePermissions.setCreationMask(mask)
    defer { FilePermissions.setCreationMask(original) }
    XCTAssertEqual(FilePermissions.setCreationMask(mask), mask)

    try withTemporaryFilePath(basename: "creationMask") { directory in
      let file = directory.appending("file")
      try FileDescriptor.open(
        file, .writeOnly, options: .create,
        permissions: [.ownerReadWrite, .groupReadWrite, .otherReadWrite]
      ).close()
      XCTAssertEqual(try file.stat().permissions, [.ownerReadWrite, .groupRead])

      // mkdtemp's 0o700 loses nothing to this mask.
      let unique = try directory.appending("d.XXXXXX").makeUniqueDirectory()
      XCTAssertEqual(try unique.stat().permissions, .ownerReadWriteExecute)
    }
  }

  func testTemporaryDirectory() throws {
    let saved = ProcessEnvironment.value(of: "TMPDIR")
    defer {
      if let saved { try? ProcessEnvironment.set("TMPDIR", to: saved) }
      else { try? ProcessEnvironment.remove("TMPDIR") }
    }

    try ProcessEnvironment.set("TMPDIR", to: "/some/where/")
    XCTAssertEqual(FilePath.temporaryDirectory(), "/some/where")

    // Without TMPDIR, the platform's own.
    #if SYSTEM_PACKAGE_DARWIN
    var buffer = [CChar](repeating: 0, count: 1024)
    XCTAssertGreaterThan(confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count), 0)
    let expected = FilePath(String(cString: buffer))
    #elseif os(Android)
    let expected: FilePath = "/data/local/tmp"
    #else
    let expected: FilePath = "/tmp"
    #endif
    try ProcessEnvironment.set("TMPDIR", to: "")
    XCTAssertEqual(FilePath.temporaryDirectory(), expected)
    try ProcessEnvironment.remove("TMPDIR")
    XCTAssertEqual(FilePath.temporaryDirectory(), expected)
  }

  #if ENABLE_MOCKING
  func testMockedCalls() {
    let path: FilePath = "a path"
    let template: FilePath = "dir/f-XXXXXX"
    let cases: [MockTestCase] = [
      MockTestCase(name: "realpath", .noInterrupt, "a path") { _ in
        _ = try path.canonicalized()
      },
      MockTestCase(name: "remove", .interruptable, "a path") { retryOnInterrupt in
        try path.remove(retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "mkostemp", .interruptable, "dir/f-XXXXXX", O_CLOEXEC) {
        retryOnInterrupt in
        _ = try template.makeUniqueFile(options: .closeOnExec, retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "mkdtemp", .interruptable, "dir/f-XXXXXX") { retryOnInterrupt in
        _ = try template.makeUniqueDirectory(retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in cases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  /// A retry starts from the original template, not the name that the
  /// failed call left in it.
  func testRetryRestoresTheTemplate() throws {
    var template = Array("f-XXXXXX".utf8CString)
    var seen: [String] = []
    let result = template.withUnsafeMutableBufferPointer { buffer in
      _retryingTemplate(buffer.baseAddress!, retryOnInterrupt: true) { () -> Int? in
        seen.append(String(cString: buffer.baseAddress!))
        guard seen.count == 2 else {
          // Rewrite the X's, as mkstemp does, then fail.
          "f-abcdef".withCString { _ = strcpy(buffer.baseAddress!, $0) }
          Errno.current = .interrupted
          return nil
        }
        return 7
      }
    }
    XCTAssertEqual(try result.get(), 7)
    XCTAssertEqual(seen, ["f-XXXXXX", "f-XXXXXX"])
  }
}

#endif // !os(Windows) && !os(WASI)
