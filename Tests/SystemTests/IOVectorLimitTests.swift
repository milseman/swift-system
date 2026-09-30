/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

import Testing

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

@Suite("I/O vector limit")
private struct IOVectorLimitTests {
  /// The headers' limit is 1024 on Darwin and in every Linux C library,
  /// and the system's own is no less.
  @available(System 199, *)
  @Test func theHeadersLimit() throws {
    #expect(SystemConfig.maxIOVectors == 1024)
    if let system = try SystemConfig.value(.maxIOVectors) {
      #expect(system >= SystemConfig.maxIOVectors)
    }
  }

  /// A write of maxIOVectors buffers is accepted, and one of a buffer more
  /// isn't.
  @available(System 199, *)
  @Test func aWriteTakesThatManyBuffers() throws {
    let null = try FileDescriptor.open("/dev/null", .writeOnly, options: .closeOnExec)
    defer { try? null.close() }
    var byte: UInt8 = 0
    try withUnsafeMutableBytes(of: &byte) { byte in
      let vectors = [CInterop.IOVec](
        repeating: CInterop.IOVec(base: byte.baseAddress, length: 1),
        count: SystemConfig.maxIOVectors + 1)
      try vectors.withUnsafeBufferPointer { vectors in
        let limit = UnsafeBufferPointer(rebasing: vectors.dropLast())
        let written = try null.write(vectors: limit)
        #expect(written == SystemConfig.maxIOVectors)
        #expect(throws: Errno.invalidArgument) {
          try null.write(vectors: vectors)
        }
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
