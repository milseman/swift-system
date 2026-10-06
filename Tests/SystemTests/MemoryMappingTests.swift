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

@available(System 199, *)
private let pageSize = (try? SystemConfig.value(.pageSize)).flatMap { $0 } ?? 4096

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
private func contents(_ bytes: RawSpan) -> [UInt8] {
  bytes.withUnsafeBytes { Array($0) }
}

@Suite("Memory mapping")
private struct MemoryMappingTests {
  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func anonymousMemoryStartsZeroedAndHoldsWrites() throws {
    var mapping = try MemoryMapping(byteCount: 3 * pageSize)
    #expect(mapping.byteCount == 3 * pageSize)
    #expect(contents(mapping.bytes).allSatisfy { $0 == 0 })
    do {
      var bytes = mapping.mutableBytes
      bytes.storeBytes(of: 0xAB, toByteOffset: 0, as: UInt8.self)
      bytes.storeBytes(of: 0xCD, toByteOffset: 3 * pageSize - 1, as: UInt8.self)
    }
    let all = contents(mapping.bytes)
    #expect(all.first == 0xAB && all.last == 0xCD)
    try mapping.unmap()
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func aFileMappingReadsTheFile() throws {
    try withTemporaryFilePath(basename: "mapRead") { directory in
      let path = directory.appending("file")
      let text = Array("hello, mapping".utf8)
      let fd = try FileDescriptor.open(
        path, .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      defer { try? fd.close() }
      try fd.writeAll(text)

      let mapping = try MemoryMapping(file: fd, byteCount: text.count)
      #expect(contents(mapping.bytes) == text)
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func sharedWritesReachTheFileAndPrivateOnesDont() throws {
    try withTemporaryFilePath(basename: "mapWrite") { directory in
      let fd = try FileDescriptor.open(
        directory.appending("file"), .readWrite, options: [.create, .truncate],
        permissions: .ownerReadWrite)
      defer { try? fd.close() }
      try fd.resize(to: Int64(pageSize))

      var shared = try MemoryMapping(
        file: fd, byteCount: pageSize, protection: [.read, .write], options: .shared)
      do {
        var bytes = shared.mutableBytes
        bytes.storeBytes(of: 0x5A, toByteOffset: 10, as: UInt8.self)
      }
      try shared.synchronize()
      #expect(try byte(at: 10, of: fd) == 0x5A)

      var copy = try MemoryMapping(
        file: fd, byteCount: pageSize, protection: [.read, .write], options: .private)
      do {
        var bytes = copy.mutableBytes
        bytes.storeBytes(of: 0x11, toByteOffset: 10, as: UInt8.self)
      }
      #expect(contents(copy.bytes)[10] == 0x11)
      #expect(try byte(at: 10, of: fd) == 0x5A)
      #expect(contents(shared.bytes)[10] == 0x5A)
    }
  }

  @available(System 199, *)
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @Test func protectionAdviceAndResidency() throws {
    var mapping = try MemoryMapping(byteCount: 4 * pageSize)
    try mapping.setProtection(.read)
    try mapping.setProtection([.read, .write], range: 0..<pageSize)
    try mapping.setProtection([.read, .write])
    do {
      var bytes = mapping.mutableBytes
      for page in 0..<4 { bytes.storeBytes(of: 1, toByteOffset: page * pageSize, as: UInt8.self) }
    }
    try mapping.advise(.sequential)
    try mapping.advise(.willNeed, range: pageSize..<(2 * pageSize))
    try mapping.advise(.normal)
    #if !os(OpenBSD)
    #expect(try mapping.residentPages() == [true, true, true, true])
    #endif
    // Linux rejects advice that starts inside a page, and Darwin rounds
    // the start down, so neither is checked here.
  }

  @available(System 199, *)
  @Test func errors() throws {
    #expect(throws: Errno.invalidArgument) { try MemoryMapping(byteCount: 0) }
    #expect(throws: Errno.badFileDescriptor) {
      try MemoryMapping(file: FileDescriptor(rawValue: -1), byteCount: 16, options: .private)
    }
    try withTemporaryFilePath(basename: "mapErrors") { directory in
      let path = directory.appending("file")
      try FileDescriptor.open(path, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let readOnly = try FileDescriptor.open(path, .readOnly)
      defer { try? readOnly.close() }
      // An offset that isn't a multiple of the page size is invalid.
      #expect(throws: Errno.invalidArgument) {
        try MemoryMapping(file: readOnly, offset: 1, byteCount: 16)
      }
      // A shared, writable mapping needs a descriptor that can write.
      #expect(throws: Errno.permissionDenied) {
        try MemoryMapping(file: readOnly, byteCount: 16, protection: [.read, .write])
      }
      let mapping = try MemoryMapping(file: readOnly, byteCount: 16)
      #expect(throws: Errno.permissionDenied) { try mapping.setProtection([.read, .write]) }
    }
  }

  @available(System 199, *)
  @Test func relinquishAndTakeBack() throws {
    let mapping = try MemoryMapping(byteCount: pageSize)
    let buffer = mapping.relinquish()
    #expect(buffer.count == pageSize)
    let adopted = MemoryMapping(unsafeTaking: buffer.baseAddress!, byteCount: buffer.count)
    #expect(adopted.unsafeBuffer.baseAddress == buffer.baseAddress)
    try adopted.unmap()
  }
}

/// The byte at an offset of a file, read with pread.
@available(System 199, *)
private func byte(at offset: Int64, of fd: FileDescriptor) throws -> UInt8 {
  var value: UInt8 = 0
  _ = try withUnsafeMutableBytes(of: &value) { try fd.read(fromAbsoluteOffset: offset, into: $0) }
  return value
}

#endif // !os(Windows) && !os(WASI)
