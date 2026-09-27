/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Linux's sendfile, from a file to any descriptor. Sockets are tested in
// SystemSocketsTests, on Darwin too.

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

@Suite("sendfile to a descriptor")
private struct SendFileTests {
  @available(System 199, *)
  @Test func copiesARangeToAFileOrAPipe() throws {
    try withTemporaryFilePath(basename: "sendFile") { directory in
      let source = try FileDescriptor.open(
        directory.appending("source"), .readWrite, options: .create, permissions: .ownerReadWrite)
      defer { try? source.close() }
      _ = try source.writeAll((0..<200).map { UInt8($0) })

      let copy = try FileDescriptor.open(
        directory.appending("copy"), .readWrite, options: .create, permissions: .ownerReadWrite)
      defer { try? copy.close() }
      #expect(try copy.sendFile(source, fromAbsoluteOffset: 50, count: 100) == 100)
      #expect(try source.seek(offset: 0, from: .current) == 200)
      var copied = [UInt8](repeating: 0, count: 100)
      #expect(try copied.withUnsafeMutableBytes { try copy.read(fromAbsoluteOffset: 0, into: $0) } == 100)
      #expect(copied == (50..<150).map { UInt8($0) })

      let pipe = try FileDescriptor.pipe()
      defer {
        try? pipe.readEnd.close()
        try? pipe.writeEnd.close()
      }
      #expect(try pipe.writeEnd.sendFile(source, fromAbsoluteOffset: 190, count: 100) == 10)
      var piped = [UInt8](repeating: 0, count: 10)
      #expect(try piped.withUnsafeMutableBytes { try pipe.readEnd.read(into: $0) } == 10)
      #expect(piped == (190..<200).map { UInt8($0) })

      // A pipe can't be the source: EINVAL, or ESPIPE on newer kernels.
      #expect(throws: Errno.self) {
        try copy.sendFile(pipe.readEnd, fromAbsoluteOffset: 0, count: 1)
      }
    }
  }

  #if ENABLE_MOCKING
  @available(System 199, *)
  @Test func mockedCalls() throws {
    try MockingDriver.withMockingEnabled { mocking throws in
      mocking.byteCounts = [42]
      let out = FileDescriptor(rawValue: 3), source = FileDescriptor(rawValue: 4)
      #expect(try out.sendFile(source, fromAbsoluteOffset: 8, count: 64) == 42)
      #expect(try out.sendFile(source, fromAbsoluteOffset: 8, count: 0) == 0)
      let entry = mocking.trace.dequeue()
      #expect(entry?.name == "sendfile")
      #expect(entry?.arguments == [CInt(3), CInt(4), _COffT(8), 64])
      #expect(mocking.trace.dequeue() == nil)
    }
  }
  #endif
}

#endif // os(Linux) || os(Android)
