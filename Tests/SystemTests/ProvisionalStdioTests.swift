/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// The provisional C standard I/O streams (Provisional+Stdio.swift).
@available(System 199, *)
final class ProvisionalStdioTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let stream = FileStream(rawValue: _mockStream)
    let address = Int(bitPattern: _mockStream)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }

    // A stream doesn't retry: it can have written some of a buffer.
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "fopen", .noInterrupt, "a path", "r") { _ in
        _ = try FileStream.open("a path", mode: "r")
      },
      MockTestCase(name: "fopen", .noInterrupt, "a path", "w") { _ in
        _ = try "a path".withCString { try FileStream.open($0, mode: "w") }
      },
      MockTestCase(name: "fdopen", .noInterrupt, 42, "a") { _ in
        _ = try FileStream.open(FileDescriptor(rawValue: 42), mode: "a")
      },
      MockTestCase(name: "fclose", .noInterrupt, address) { _ in
        try stream.close()
      },
      MockTestCase(name: "fflush", .noInterrupt, address) { _ in
        try stream.flush()
      },
      MockTestCase(name: "fflush", .noInterrupt, 0) { _ in
        try FileStream.flushAll()
      },
      MockTestCase(name: "fwrite", .noInterrupt, address, 8) { _ in
        try stream.write(UnsafeRawBufferPointer(buffer))
      },
      MockTestCase(name: "fwrite", .noInterrupt, address, 5) { _ in
        try stream.write("hello")
      },
      MockTestCase(name: "fputs", .noInterrupt, address, "a C string") { _ in
        try stream.write(cString: "a C string")
      },
      MockTestCase(name: "fputc", .noInterrupt, address, CInt(0x41)) { _ in
        try stream.write(byte: 0x41)
      },
      // A mocked getline reads an empty line; a failure would ask the
      // placeholder stream for its error indicator.
      MockTestCase(name: "getline", .noError, address) { _ in
        _ = try stream.readLine()
      },
      MockTestCase(name: "fileno", .noInterrupt, address) { _ in
        _ = try stream.fileDescriptor()
      },
      MockTestCase(name: "setvbuf", .noInterrupt, address, 0, _IONBF, 0) { _ in
        try stream.setBuffering(.unbuffered)
      },
      MockTestCase(
        name: "setvbuf", .noInterrupt, address, Int(bitPattern: buffer.baseAddress), _IOFBF, 8
      ) { _ in
        try stream.setBuffering(.full, buffer: buffer)
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testWritingAndReadingAFile() throws {
    try withTemporaryFilePath(basename: "testWritingAndReadingAFile") { dir in
      let path = dir.appending("file")
      let output = try FileStream.open(path, mode: "w")
      try "hello, ".utf8.withContiguousStorageIfAvailable { try output.write(UnsafeRawBufferPointer($0)) }
      try output.write("wor")
      // A C string stops at its null byte.
      try [CChar(0x6c), 0, 0x78].withUnsafeBufferPointer { try output.write(cString: $0.baseAddress!) }
      try output.write(byte: UInt8(ascii: "d"))
      try output.close()

      let input = try FileStream.open(path, mode: "r")
      defer { try? input.close() }
      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
      defer { buffer.deallocate() }
      XCTAssertFalse(input.isAtEnd)
      let count = try input.read(into: buffer)
      XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "hello, world")
      XCTAssertTrue(input.isAtEnd)
      XCTAssertEqual(try input.read(into: buffer), 0)
      input.clearError()
      XCTAssertFalse(input.isAtEnd)
    }
  }

  func testReadingLines() throws {
    try withTemporaryFilePath(basename: "testReadingLines") { dir in
      let path = dir.appending("file")
      // Longer than getline's first buffer, so that it grows the buffer.
      let long = String(repeating: "x", count: 10_000)
      let output = try FileStream.open(path, mode: "w")
      try output.write("one\ntwo\r\n\n\(long)\na\u{0}b\n")
      // A byte that isn't UTF-8, then a last line without a newline.
      try [UInt8(0x61), 0xFF, 0x0A, 0x6C, 0x61, 0x73, 0x74].withUnsafeBytes { try output.write($0) }
      try output.close()

      let input = try FileStream.open(path, mode: "r")
      defer { try? input.close() }
      XCTAssertEqual(try input.readLine(), "one")
      XCTAssertEqual(try input.readLine(), "two")
      XCTAssertEqual(try input.readLine(), "")
      XCTAssertEqual(try input.readLine(), long)
      XCTAssertEqual(try input.readLine(), "a\u{0}b")
      XCTAssertEqual(try input.readLine(), "a\u{FFFD}")
      XCTAssertFalse(input.isAtEnd)
      XCTAssertEqual(try input.readLine(), "last")
      XCTAssertNil(try input.readLine())
      XCTAssertTrue(input.isAtEnd)
      XCTAssertFalse(input.hasError)

      let again = try FileStream.open(path, mode: "r")
      defer { try? again.close() }
      XCTAssertEqual(try again.readLine(strippingNewline: false), "one\n")
      XCTAssertEqual(try again.readLine(strippingNewline: false), "two\r\n")
      XCTAssertEqual(try again.readLine(strippingNewline: false), "\n")

      // A stream opened for writing only can't be read.
      let appending = try FileStream.open(path, mode: "a")
      defer { try? appending.close() }
      XCTAssertThrowsError(try appending.readLine()) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      XCTAssertTrue(appending.hasError)
    }
  }

  #if !os(WASI) // WASI has no pipe
  func testAStreamOnADescriptor() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    let stream = try FileStream.open(writer, mode: "w")
    XCTAssertEqual(try stream.fileDescriptor(), writer)
    // A pipe's stream is fully buffered, so nothing arrives until a flush.
    try stream.write("buffered")
    try stream.flush()
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }
    let count = try reader.read(into: buffer)
    XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "buffered")
    // Closing the stream closes the descriptor.
    try stream.close()
    XCTAssertEqual(try reader.read(into: buffer), 0)
  }

  func testBuffering() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? reader.close() }
    try reader.setStatusFlags(.nonBlocking)
    let stream = try FileStream.open(writer, mode: "w")
    defer { try? stream.close() }
    // glibc writes a stream's first write straight to its descriptor
    // when the buffer is smaller than 128 bytes.
    let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 256, alignment: 1)
    defer { storage.deallocate() }
    try stream.setBuffering(.line, buffer: storage)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }
    try stream.write("part")
    XCTAssertThrowsError(try reader.read(into: buffer)) {
      XCTAssertEqual($0 as? Errno, .wouldBlock)
    }
    // A newline writes the line.
    try stream.write(" line\n")
    let count = try reader.read(into: buffer)
    XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "part line\n")
    XCTAssertEqual(FileStream.Buffering.line.description, "line")
  }

  #endif // !os(WASI)

  func testErrors() throws {
    try withTemporaryFilePath(basename: "testErrors") { dir in
      XCTAssertThrowsError(try FileStream.open(dir.appending("missing"), mode: "r")) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      XCTAssertThrowsError(try FileStream.open(dir.appending("file"), mode: "zz")) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      let fd = try FileDescriptor.open(
        dir.appending("file"), .readOnly, options: .create, permissions: .ownerReadWrite)
      defer { try? fd.close() }
      // The mode must be one the descriptor allows.
      XCTAssertThrowsError(try FileStream.open(fd, mode: "w")) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      let input = try FileStream.open(dir.appending("file"), mode: "r")
      defer { try? input.close() }
      XCTAssertThrowsError(try input.write("x")) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      XCTAssertTrue(input.hasError)
      input.clearError()
      XCTAssertFalse(input.hasError)
      // fputs and fputc report the same error.
      XCTAssertThrowsError(try input.write(cString: "x")) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
      XCTAssertThrowsError(try input.write(byte: 0x78)) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
    }
  }

  func testTheStandardStreams() throws {
    XCTAssertEqual(try FileStream.standardInput.fileDescriptor(), .standardInput)
    XCTAssertEqual(try FileStream.standardOutput.fileDescriptor(), .standardOutput)
    XCTAssertEqual(try FileStream.standardError.fileDescriptor(), .standardError)
  }

  #if !os(WASI)
  func testLocking() throws {
    try withTemporaryFilePath(basename: "testLocking") { dir in
      let stream = try FileStream.open(dir.appending("file"), mode: "w")
      defer { try? stream.close() }
      XCTAssertEqual(try stream.withLock { () throws(Errno) -> Int in
        try stream.write("locked")
        return 42
      }, 42)
      // The lock is recursive, and other threads can't take it.
      stream.lock()
      XCTAssertTrue(stream.tryLock())
      stream.unlock()
      let other = Thread { XCTAssertFalse(stream.tryLock()) }
      other.start()
      while !other.isFinished { usleep(1000) }
      stream.unlock()
      XCTAssertTrue(stream.tryLock())
      stream.unlock()
    }
  }
  #endif
}

#endif // !os(Windows)
