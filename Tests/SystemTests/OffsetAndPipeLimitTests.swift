/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// C's off_t as CInterop.Offset, and the headers' limit on atomic pipe
// writes, PIPE_BUF.

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
final class OffsetAndPipeLimitTest: XCTestCase {
  func testOffsetIsOffT() {
    XCTAssertTrue(CInterop.Offset.self == off_t.self)
    // It holds what System's Int64 offsets hold, on 64-bit platforms.
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertTrue(CInterop.Offset.self == Int64.self)
    #elseif os(Linux) || os(Android)
    XCTAssertTrue(CInterop.Offset.self == Int.self)
    #endif
    let offset: CInterop.Offset = 1 << 40
    XCTAssertEqual(Int64(offset), 1_099_511_627_776)
  }

  func testPipeLimitIsTheHeaders() {
    XCTAssertEqual(SystemConfig.maxAtomicPipeWriteBytes, Int(PIPE_BUF))
    // POSIX's least is _POSIX_PIPE_BUF, 512.
    XCTAssertGreaterThanOrEqual(SystemConfig.maxAtomicPipeWriteBytes, Int(_POSIX_PIPE_BUF))
    XCTAssertEqual(_POSIX_PIPE_BUF, 512)
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertEqual(SystemConfig.maxAtomicPipeWriteBytes, 512)
    #elseif os(Linux)
    XCTAssertEqual(SystemConfig.maxAtomicPipeWriteBytes, 4096)
    #endif
  }

  /// A pipe's own limit, from fpathconf, is the headers' constant on
  /// Darwin and Linux, which define it for every pipe.
  func testAPipesLimit() throws {
    let (readEnd, writeEnd) = try FileDescriptor.pipe()
    defer {
      try? readEnd.close()
      try? writeEnd.close()
    }
    let limit = try XCTUnwrap(SystemConfig.value(.maxAtomicPipeWriteBytes, for: writeEnd))
    XCTAssertGreaterThanOrEqual(limit, Int(_POSIX_PIPE_BUF))
    #if SYSTEM_PACKAGE_DARWIN || os(Linux)
    XCTAssertEqual(limit, SystemConfig.maxAtomicPipeWriteBytes)
    #endif
  }
}

#endif // !os(Windows) && !os(WASI)
