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

import ucrt

// The provisional FileStream on Windows, over the UCRT's stdio.
@available(System 199, *)
final class Win32FileStreamTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(FileStream.Buffering.full.rawValue, ucrt._IOFBF)
    XCTAssertEqual(FileStream.Buffering.line.rawValue, ucrt._IOLBF)
    XCTAssertEqual(FileStream.Buffering.unbuffered.rawValue, ucrt._IONBF)
    XCTAssertEqual(_EOF, ucrt.EOF)
  }

  func testWritingAndReading() throws {
    try withTemporaryFilePath(basename: "testFileStreamWriting") { directory in
      let path = directory.appending("file.txt")
      let output = try FileStream.open(path, mode: "wb")
      try output.write("one\n")
      try Array("two".utf8).withUnsafeBytes { try output.write($0) }
      try "\r\n".withCString { try output.write(cString: $0) }
      try output.write(byte: UInt8(ascii: "3"))
      try output.close()
      XCTAssertEqual(win32RawContents(of: path), Array("one\ntwo\r\n3".utf8))

      let input = try FileStream.open(path, mode: "rb")
      XCTAssertEqual(try input.readLine(), "one")
      XCTAssertEqual(try input.readLine(strippingNewline: false), "two\r\n")
      XCTAssertEqual(try input.readLine(), "3")
      XCTAssertNil(try input.readLine())
      XCTAssertTrue(input.isAtEnd)
      input.clearError()
      XCTAssertFalse(input.isAtEnd)
      try input.close()
    }
  }

  func testTextModeTranslatesNewlines() throws {
    try withTemporaryFilePath(basename: "testFileStreamText") { directory in
      let path = directory.appending("file.txt")
      let output = try FileStream.open(path, mode: "w")
      try output.write("a\nb")
      try output.close()
      XCTAssertEqual(win32RawContents(of: path), Array("a\r\nb".utf8))
    }
  }

  func testBuffering() throws {
    try withTemporaryFilePath(basename: "testFileStreamBuffering") { directory in
      let path = directory.appending("file.txt")
      let output = try FileStream.open(path, mode: "wb")
      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 256, alignment: 1)
      defer { buffer.deallocate() }
      try output.setBuffering(.full, buffer: buffer)
      try output.write("held")
      XCTAssertEqual(win32RawContents(of: path), [])
      try output.flush()
      XCTAssertEqual(win32RawContents(of: path), Array("held".utf8))
      try output.close()
    }
  }

  func testRejectedArgumentsThrowRatherThanEndTheProcess() throws {
    try withTemporaryFilePath(basename: "testFileStreamRejected") { directory in
      let path = directory.appending("file.txt")
      XCTAssertThrowsError(try FileStream.open(path, mode: "z")) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      XCTAssertThrowsError(try FileStream.open(FileDescriptor(rawValue: -1), mode: "r")) { error in
        XCTAssertEqual(error as? Errno, .badFileDescriptor)
      }
      let output = try FileStream.open(path, mode: "wb")
      XCTAssertThrowsError(try output.setBuffering(FileStream.Buffering(rawValue: 99))) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      let tiny = UnsafeMutableRawBufferPointer.allocate(byteCount: 1, alignment: 1)
      defer { tiny.deallocate() }
      XCTAssertThrowsError(try output.setBuffering(.full, buffer: tiny)) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      try output.close()
    }
  }

  func testStandardStreamsAndLocking() throws {
    let descriptor = try FileStream.standardError.fileDescriptor()
    XCTAssertEqual(descriptor.rawValue, 2)
    let value = FileStream.standardError.withLock {
      FileStream.standardError.withLock { 42 }
    }
    XCTAssertEqual(value, 42)
    try FileStream.flushAll()
  }
}

#endif // os(Windows)
