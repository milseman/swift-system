/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import XCTest

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

@available(System 199, *)
final class SystemConfigTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "sysconf", .noInterrupt, _SC_CHILD_MAX) { _ in
        _ = try SystemConfig.value(.maxUserProcesses)
      },

      MockTestCase(name: "pathconf", .noInterrupt, "a path", _PC_NAME_MAX) { _ in
        _ = try SystemConfig.value(.maxFileNameBytes, for: FilePath("a path"))
      },

      MockTestCase(name: "pathconf", .noInterrupt, "a path", _PC_PATH_MAX) { _ in
        _ = try "a path".withCString {
          try SystemConfig.value(.maxPathBytes, for: $0)
        }
      },

      MockTestCase(name: "fpathconf", .noInterrupt, 1, _PC_PIPE_BUF) { _ in
        _ = try SystemConfig.value(
          .maxAtomicPipeWriteBytes, for: FileDescriptor(rawValue: 1))
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  func testNameValues() {
    XCTAssertEqual(SystemConfig.Name.maxArgumentBytes.rawValue, CInt(_SC_ARG_MAX))
    XCTAssertEqual(SystemConfig.Name.pageSize.rawValue, CInt(_SC_PAGESIZE))
    XCTAssertEqual(SystemConfig.Name.processorsOnline.rawValue, CInt(_SC_NPROCESSORS_ONLN))
    XCTAssertEqual(SystemConfig.Name.maxHostNameBytes.rawValue, CInt(_SC_HOST_NAME_MAX))
    XCTAssertEqual(SystemConfig.PathName.maxFileNameBytes.rawValue, CInt(_PC_NAME_MAX))
    XCTAssertEqual(SystemConfig.PathName.maxAtomicPipeWriteBytes.rawValue, CInt(_PC_PIPE_BUF))
    XCTAssertEqual(SystemConfig.PathName.maxSymbolicLinkBytes.rawValue, CInt(_PC_SYMLINK_MAX))
  }

  func testSystemValues() throws {
    XCTAssertEqual(try SystemConfig.value(.pageSize), Int(getpagesize()))
    let online = try XCTUnwrap(SystemConfig.value(.processorsOnline))
    XCTAssertGreaterThanOrEqual(online, 1)
    XCTAssertGreaterThanOrEqual(try XCTUnwrap(SystemConfig.value(.processorsConfigured)), online)
    XCTAssertGreaterThan(try XCTUnwrap(SystemConfig.value(.physicalMemoryPages)), 0)
    XCTAssertGreaterThan(try XCTUnwrap(SystemConfig.value(.clockTicksPerSecond)), 0)
    XCTAssertGreaterThan(try XCTUnwrap(SystemConfig.value(.maxArgumentBytes)), 0)
    // POSIX has required job control since 2001, and requires only that its
    // value be positive: Darwin gives 200112, and glibc 1.
    XCTAssertGreaterThan(try XCTUnwrap(SystemConfig.value(.jobControl)), 0)
    XCTAssertGreaterThanOrEqual(try XCTUnwrap(SystemConfig.value(.posixVersion)), 200112)
    if let maxOpenFiles = try SystemConfig.value(.maxOpenFiles) {
      XCTAssertGreaterThan(maxOpenFiles, 0)
    }

    #if SYSTEM_PACKAGE_DARWIN
    // Darwin doesn't support the FORTRAN development utilities option,
    // which sysconf reports with -1 and no error.
    XCTAssertNil(try SystemConfig.value(.fortranDevelopment))
    #endif

    // A name the system doesn't recognize is an error, rather than nil.
    XCTAssertThrowsError(try SystemConfig.value(SystemConfig.Name(rawValue: -1))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }

  func testPathValues() throws {
    try withTemporaryFilePath(basename: "testPathValues") { directory in
      let nameLength = try XCTUnwrap(SystemConfig.value(.maxFileNameBytes, for: directory))
      XCTAssertGreaterThanOrEqual(nameLength, 14)  // POSIX's minimum
      let pathLength = try XCTUnwrap(SystemConfig.value(.maxPathBytes, for: directory))
      XCTAssertGreaterThanOrEqual(pathLength, 256)  // POSIX's minimum

      // The C string overload and the file descriptor overload agree.
      XCTAssertEqual(
        try directory.withPlatformString {
          try SystemConfig.value(.maxFileNameBytes, for: $0)
        },
        nameLength)
      let fd = try FileDescriptor.open(directory, .readOnly)
      try fd.closeAfter {
        XCTAssertEqual(try SystemConfig.value(.maxFileNameBytes, for: fd), nameLength)
      }

      // Terminal variables don't apply to a directory. Darwin reports that,
      // and glibc gives the value a terminal would have, MAX_CANON.
      #if os(Linux)
      XCTAssertEqual(
        try SystemConfig.value(.maxTerminalCanonicalLineBytes, for: directory), 255)
      #else
      XCTAssertThrowsError(
        try SystemConfig.value(.maxTerminalCanonicalLineBytes, for: directory)
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      #endif
      XCTAssertThrowsError(
        try SystemConfig.value(SystemConfig.PathName(rawValue: -1), for: directory)
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(
        try SystemConfig.value(.maxFileNameBytes, for: directory.appending("missing"))
      ) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
    }

    // POSIX requires at least 512 bytes for an atomic write to a pipe.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let atomicWrite = try XCTUnwrap(
      SystemConfig.value(.maxAtomicPipeWriteBytes, for: pipe.writeEnd))
    XCTAssertGreaterThanOrEqual(atomicWrite, 512)

    XCTAssertThrowsError(
      try SystemConfig.value(.maxFileNameBytes, for: FileDescriptor(rawValue: -1))
    ) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
