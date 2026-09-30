/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// SYS-0013: reading, writing, seeking, flushing, and resizing.
@available(System 199, *)
final class Win32FileIOTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(Win32.SeekOrigin.start.rawValue, DWORD(WinSDK.FILE_BEGIN))
    XCTAssertEqual(Win32.SeekOrigin.current.rawValue, DWORD(WinSDK.FILE_CURRENT))
    XCTAssertEqual(Win32.SeekOrigin.end.rawValue, DWORD(WinSDK.FILE_END))
    XCTAssertEqual(_FILE_TYPE_DISK, DWORD(WinSDK.FILE_TYPE_DISK))
    // Splitting a transfer keeps a non-buffered handle's sector alignment.
    XCTAssertEqual(Win32._transferChunkLimit % 65536, 0)
    XCTAssertLessThanOrEqual(Win32._transferChunkLimit, Int(DWORD.max))
  }

  func testWriteThenReadEachSpanKind() throws {
    try withTemporaryFilePath(basename: "testSpanKinds") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      let contents = Array("hello, world".utf8)
      try withRawSpan(contents) { try file.write($0) }

      var bytes = [UInt8](repeating: 0, count: 32)
      do {
        var span = bytes.mutableSpan
        let count = try file.read(fromAbsoluteOffset: 0, into: &span)
        XCTAssertEqual(count, contents.count)
      }
      XCTAssertEqual(Array(bytes[..<contents.count]), contents)

      bytes = [UInt8](repeating: 0, count: 32)
      do {
        var span = bytes.mutableSpan
        var raw = span.mutableBytes
        let count = try file.readFully(fromAbsoluteOffset: 0, into: &raw)
        XCTAssertEqual(count, contents.count)
      }
      XCTAssertEqual(Array(bytes[..<contents.count]), contents)

      let viaOutputRawSpan = try [UInt8](unsafeUninitializedCapacity: 32) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        try file.read(fromAbsoluteOffset: 0, into: &output)
        count = output.byteCount
      }
      XCTAssertEqual(viaOutputRawSpan, contents)

      let viaOutputSpan = try [UInt8](unsafeUninitializedCapacity: 32) { buffer, count in
        var output = OutputSpan(buffer: buffer, initializedCount: 0)
        try file.readFully(fromAbsoluteOffset: 0, into: &output)
        count = output.finalize(for: buffer)
      }
      XCTAssertEqual(viaOutputSpan, contents)

      // The rest of the overloads, reading into what's left of a span.
      let rest = try [UInt8](unsafeUninitializedCapacity: 32) { buffer, count in
        var output = OutputRawSpan(
          buffer: UnsafeMutableRawBufferPointer(buffer), initializedCount: 0)
        try file.readFully(fromAbsoluteOffset: 0, into: &output)
        count = output.byteCount
      }
      XCTAssertEqual(rest, contents)
      bytes = [UInt8](repeating: 0, count: 32)
      do {
        var span = bytes.mutableSpan
        let count = try file.readFully(fromAbsoluteOffset: 7, into: &span)
        XCTAssertEqual(count, contents.count - 7)
      }
      XCTAssertEqual(Array(bytes[..<5]), Array("world".utf8))
      let viaOutputSpanOnce = try [UInt8](unsafeUninitializedCapacity: 5) { buffer, count in
        var output = OutputSpan(buffer: buffer, initializedCount: 0)
        try file.read(fromAbsoluteOffset: 7, into: &output)
        count = output.finalize(for: buffer)
      }
      XCTAssertEqual(viaOutputSpanOnce, Array("world".utf8))
      bytes = [UInt8](repeating: 0, count: 5)
      do {
        var span = bytes.mutableSpan
        var raw = span.mutableBytes
        let count = try file.read(fromAbsoluteOffset: 7, into: &raw)
        XCTAssertEqual(count, 5)
      }
      XCTAssertEqual(bytes, Array("world".utf8))
      try file.close()
    }
  }

  func testPositionalTransfersMoveTheFilePointer() throws {
    try withTemporaryFilePath(basename: "testPositionalPointer") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      try withRawSpan(Array("0123456789".utf8)) { try file.write($0) }
      var bytes = [UInt8](repeating: 0, count: 4)
      do {
        var span = bytes.mutableSpan
        _ = try file.read(fromAbsoluteOffset: 2, into: &span)
      }
      XCTAssertEqual(bytes, Array("2345".utf8))
      // Unlike POSIX `pread`, the read moved the file pointer.
      let afterRead = try file.currentOffset()
      XCTAssertEqual(afterRead, 6)

      try withRawSpan(Array("ab".utf8)) { try file.write($0, toAbsoluteOffset: 0) }
      let afterWrite = try file.currentOffset()
      XCTAssertEqual(afterWrite, 2)
      try file.close()
    }
  }

  func testEndOfFile() throws {
    try withTemporaryFilePath(basename: "testEndOfFile") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      try withRawSpan(Array("abc".utf8)) { try file.write($0) }
      var bytes = [UInt8](repeating: 0, count: 8)
      do {
        var span = bytes.mutableSpan
        // At the file pointer, which is at the end.
        let atPointer = try file.read(into: &span)
        XCTAssertEqual(atPointer, 0)
        // Past the end: ReadFile fails with ERROR_HANDLE_EOF.
        let pastEnd = try file.read(fromAbsoluteOffset: 100, into: &span)
        XCTAssertEqual(pastEnd, 0)
        // A full read stops at the end of a disk file.
        let full = try file.readFully(fromAbsoluteOffset: 1, into: &span)
        XCTAssertEqual(full, 2)
      }
      try file.close()
    }
  }

  func testNegativeValuesAreRejected() throws {
    try withTemporaryFilePath(basename: "testNegativeValues") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      var bytes = [UInt8](repeating: 0, count: 4)
      do {
        var span = bytes.mutableSpan
        XCTAssertThrowsWin32Error(.invalidParameter) {
          try file.read(fromAbsoluteOffset: -1, into: &span)
        }
        XCTAssertThrowsWin32Error(.invalidParameter) {
          try file.readFully(fromAbsoluteOffset: -2, into: &span)
        }
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try withRawSpan([1]) { try file.write($0, toAbsoluteOffset: -1) }
      }
      XCTAssertThrowsWin32Error(.negativeSeek) { try file.seek(to: -1) }
      XCTAssertThrowsWin32Error(.negativeSeek) { try file.seek(offset: -1, from: .start) }
      XCTAssertThrowsWin32Error(.invalidParameter) { try file.resize(to: -1) }
      try file.close()
    }
  }

  func testOversizedSpansAreRejected() throws {
    try withTemporaryFilePath(basename: "testOversizedSpans") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      // These are rejected before any byte is touched, so a small allocation
      // stands in for the span's memory.
      let memory = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
      defer { memory.deallocate() }
      let oversized = UnsafeMutableRawBufferPointer(start: memory, count: Int(DWORD.max) + 1)
      var span = MutableRawSpan(_unsafeBytes: oversized)
      XCTAssertThrowsWin32Error(.invalidParameter) { try file.read(into: &span) }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try file.append(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(oversized)))
      }
      try file.close()
    }
  }

  func testAppend() throws {
    try withTemporaryFilePath(basename: "testAppend") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      try withRawSpan(Array("ab".utf8)) { try file.write($0) }
      try file.seek(to: 0)
      try withRawSpan(Array("cd".utf8)) { try file.append($0) }
      // The file pointer is at the new end of the file.
      let position = try file.currentOffset()
      XCTAssertEqual(position, 4)
      try Array("ef".utf8).withUnsafeBytes { bytes in
        var rest = RawSpan(_unsafeBytes: bytes)
        try file.append(draining: &rest)
        XCTAssertEqual(rest.byteCount, 0)
      }
      try file.close()
      XCTAssertEqual(win32RawContents(of: path), Array("abcdef".utf8))
    }
  }

  func testDrainingWrite() throws {
    try withTemporaryFilePath(basename: "testDrainingWrite") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      try Array("abc".utf8).withUnsafeBytes { bytes in
        var rest = RawSpan(_unsafeBytes: bytes)
        try file.write(draining: &rest)
        XCTAssertEqual(rest.byteCount, 0)
      }
      // An empty span still calls WriteFile, and succeeds.
      try withRawSpan([]) { try file.write($0) }
      try file.close()
      XCTAssertEqual(win32RawContents(of: path), Array("abc".utf8))
    }
  }

  func testSizeAndResize() throws {
    try withTemporaryFilePath(basename: "testSizeAndResize") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      try withRawSpan(Array("abcdef".utf8)) { try file.write($0) }
      let size = try file.size()
      XCTAssertEqual(size, 6)

      // Extending reads as zeros, and leaves the file pointer.
      try file.resize(to: 10)
      let extended = try file.size()
      XCTAssertEqual(extended, 10)
      let position = try file.currentOffset()
      XCTAssertEqual(position, 6)
      try file.flush()
      XCTAssertEqual(win32RawContents(of: path), Array("abcdef".utf8) + [0, 0, 0, 0])

      try file.resize(to: 3)
      let truncated = try file.size()
      XCTAssertEqual(truncated, 3)

      try file.seek(to: 2)
      try file.resizeToCurrentOffset()
      let cut = try file.size()
      XCTAssertEqual(cut, 2)

      let end = try file.seek(offset: -1, from: .end)
      XCTAssertEqual(end, 1)
      try file.close()
      XCTAssertEqual(win32RawContents(of: path), Array("ab".utf8))
    }
  }

  func testDuplicatesShareTheFilePointer() throws {
    try withTemporaryFilePath(basename: "testSharedPointer") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      try withRawSpan(Array("abc".utf8)) { try file.write($0) }
      let duplicate = try file.duplicate()
      let duplicatePosition = try duplicate.currentOffset()
      XCTAssertEqual(duplicatePosition, 3)
      // A reopened handle is a new file object, with a pointer of its own.
      let reopened = try file.reopen(access: .readData)
      let reopenedPosition = try reopened.currentOffset()
      XCTAssertEqual(reopenedPosition, 0)
      try reopened.close()
      try duplicate.close()
      try file.close()
    }
  }

  func testLentHandleSharesTheDescriptorsFilePointer() throws {
    try withTemporaryFilePath(basename: "testLentPointer") { directory in
      let descriptor = try FileDescriptor.open(
        directory.appending("file.txt"), .readWrite, options: [.create],
        permissions: .ownerReadWrite)
      let lent: Void? = try descriptor.withWin32HandleIfAvailable { handle in
        try withRawSpan(Array("abcd".utf8)) { try handle.write($0) }
      }
      XCTAssertNotNil(lent)
      let position = try descriptor.seek(offset: 0, from: .current)
      XCTAssertEqual(position, 4)
      try descriptor.close()
    }
  }

  func testPipeReads() throws {
    let pipe = try Win32TestPipe()
    try withRawSpan(Array("hello".utf8)) { try pipe.writeEnd.write($0) }
    var bytes = [UInt8](repeating: 0, count: 16)
    do {
      var span = bytes.mutableSpan
      // A pipe returns what has arrived.
      let count = try pipe.readEnd.read(into: &span)
      XCTAssertEqual(count, 5)
    }
    XCTAssertEqual(Array(bytes[..<5]), Array("hello".utf8))

    try withRawSpan(Array("abc".utf8)) { try pipe.writeEnd.write($0) }
    try pipe.writeEnd.close()
    do {
      var span = bytes.mutableSpan
      // A full read ends when the writer closes.
      let full = try pipe.readEnd.readFully(into: &span)
      XCTAssertEqual(full, 3)
      // ERROR_BROKEN_PIPE reads as the end of the data.
      let after = try pipe.readEnd.read(into: &span)
      XCTAssertEqual(after, 0)
    }
    try pipe.readEnd.close()
  }

  func testWritingToAPipeWithNoReader() throws {
    // A closure can't capture a partly consumed pipe, so the ends are taken
    // apart first.
    let pipe = try Win32TestPipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try readEnd.close()
    // Where POSIX reports EPIPE, Windows reports ERROR_NO_DATA.
    XCTAssertThrowsWin32Error(.noData) {
      try withRawSpan([1, 2, 3]) { try writeEnd.write($0) }
    }
    try writeEnd.close()
  }

  func testNonblockingPipeWriteIsIncomplete() throws {
    let name = "\\\\.\\pipe\\swift-system-win32-\(GetCurrentProcessId())-nowait"
    let rawServer = name.withCString(encodedAs: UTF16.self) {
      CreateNamedPipeW(
        $0, DWORD(WinSDK.PIPE_ACCESS_OUTBOUND),
        DWORD(WinSDK.PIPE_TYPE_BYTE | WinSDK.PIPE_NOWAIT), 1, 4096, 4096, 0, nil)
    }
    guard let server = Win32.FileHandle(unsafelyAdopting: rawServer) else {
      throw Win32.Error(GetLastError())
    }
    let client = try Win32.FileHandle.open(FilePath(name), access: .genericRead)
    // The client has connected, so this reports ERROR_PIPE_CONNECTED.
    _ = ConnectNamedPipe(server.unsafeRawHandle, nil)

    // A PIPE_NOWAIT write that doesn't fit writes nothing, and succeeds.
    let large = [UInt8](repeating: 0x2A, count: 1 << 20)
    XCTAssertThrowsWin32Error(.incompleteTransfer) {
      try withRawSpan(large) { try server.write($0) }
    }
    large.withUnsafeBytes { bytes in
      var rest = RawSpan(_unsafeBytes: bytes)
      XCTAssertThrowsWin32Error(.incompleteTransfer) { try server.append(draining: &rest) }
      XCTAssertEqual(rest.byteCount, large.count)
    }
    try client.close()
    try server.close()
  }

  func testNonBufferedFullRead() throws {
    try withTemporaryFilePath(basename: "testNonBuffered") { directory in
      let path = directory.appending("file.txt")
      let contents = (0..<8192).map { UInt8(truncatingIfNeeded: $0) }
      let writer = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      try withRawSpan(contents) { try writer.write($0) }
      try writer.close()

      // Sector-aligned memory, offsets, and lengths.
      let memory = UnsafeMutableRawBufferPointer.allocate(byteCount: 8192, alignment: 4096)
      defer { memory.deallocate() }
      let file = try Win32.FileHandle.open(path, access: .genericRead, flags: .noBuffering)
      var span = MutableRawSpan(_unsafeBytes: memory)
      let count = try file.readFully(fromAbsoluteOffset: 0, into: &span)
      XCTAssertEqual(count, 8192)
      let atEnd = try file.readFully(fromAbsoluteOffset: 8192, into: &span)
      XCTAssertEqual(atEnd, 0)
      try file.close()
      XCTAssertEqual(Array(memory), contents)
    }
  }
}

#endif // os(Windows)
