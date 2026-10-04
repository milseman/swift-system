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

  func testSeekingAndTheOffset() throws {
    try withTemporaryFilePath(basename: "testFileStreamSeeking") { directory in
      let stream = try FileStream.open(directory.appending("file"), mode: "w+b")
      defer { try? stream.close() }
      try stream.write("hello world")
      // The offset counts what the buffer holds.
      let written = try stream.offset()
      XCTAssertEqual(written, 11)

      let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
      defer { buffer.deallocate() }
      try stream.seek(offset: 6, from: .start)
      let moved = try stream.offset()
      XCTAssertEqual(moved, 6)
      var count = try stream.read(into: buffer)
      XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "world")
      XCTAssertTrue(stream.isAtEnd)

      try stream.seek(offset: -5, from: .end)
      XCTAssertFalse(stream.isAtEnd)
      try stream.seek(offset: -1, from: .current)
      let back = try stream.offset()
      XCTAssertEqual(back, 5)
      count = try stream.read(into: UnsafeMutableRawBufferPointer(rebasing: buffer[..<3]))
      XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), " wo")
      let afterReading = try stream.offset()
      XCTAssertEqual(afterReading, 8)

      // A write after a seek starts at the new position.
      try stream.seek(offset: 0, from: .start)
      try stream.write("J")
      try stream.seek(offset: 0, from: .start)
      count = try stream.read(into: buffer)
      XCTAssertEqual(String(decoding: buffer[..<count], as: UTF8.self), "Jello world")

      // Past 4 GiB, which a 32-bit offset can't reach; the file stays
      // small until something is written there.
      try stream.seek(offset: 0x1_0000_0001, from: .start)
      let far = try stream.offset()
      XCTAssertEqual(far, 0x1_0000_0001)

      XCTAssertThrowsError(try stream.seek(offset: -1, from: .start)) { error in
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
    }
  }

  func testTextModePositionsCountTheFilesBytes() throws {
    try withTemporaryFilePath(basename: "testFileStreamTextPositions") { directory in
      let stream = try FileStream.open(directory.appending("file.txt"), mode: "w+")
      defer { try? stream.close() }
      try stream.write("a\nb")
      let end = try stream.offset()
      XCTAssertEqual(end, 4)
      try stream.seek(offset: 0, from: .start)
      XCTAssertEqual(try stream.readLine(strippingNewline: false), "a\n")
      let second = try stream.offset()
      XCTAssertEqual(second, 3)
    }
  }

  func testFilesWithNoPosition() throws {
    let (reader, writer) = try FileDescriptor.pipe()
    defer { try? writer.close() }
    let pipe = try FileStream.open(reader, mode: "r")
    defer { try? pipe.close() }
    XCTAssertThrowsError(try pipe.seek(offset: 0, from: .start)) { error in
      XCTAssertEqual(error as? Errno, .illegalSeek)
    }
    XCTAssertThrowsError(try pipe.offset()) { error in
      XCTAssertEqual(error as? Errno, .illegalSeek)
    }

    // NUL is a character device, as a console is.
    let null = try FileStream.open("NUL", mode: "r")
    defer { try? null.close() }
    XCTAssertThrowsError(try null.seek(offset: 0, from: .start)) { error in
      XCTAssertEqual(error as? Errno, .illegalSeek)
    }
    XCTAssertThrowsError(try null.offset()) { error in
      XCTAssertEqual(error as? Errno, .illegalSeek)
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

  #if ENABLE_MOCKING
  func testTheCRuntimeCalls() throws {
    let stream = FileStream(rawValue: _mockStream)
    let address = Int(bitPattern: _mockStream)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
    defer { buffer.deallocate() }
    try MockingDriver.withMockingEnabled { mocking in
      _ = try FileStream.open("a path", mode: "r")
      expectCall(mocking.trace.dequeue(), "_wfopen", ["a path", "r"])
      let path: [CInterop.PlatformChar] = Array("a path".utf16) + [0]
      _ = try path.withUnsafeBufferPointer { try FileStream.open($0.baseAddress!, mode: "w") }
      expectCall(mocking.trace.dequeue(), "_wfopen", ["a path", "w"])
      _ = try FileStream.open(FileDescriptor(rawValue: 42), mode: "a")
      expectCall(mocking.trace.dequeue(), "_fdopen", [CInt(42), "a"])

      try stream.write(UnsafeRawBufferPointer(buffer))
      expectCall(mocking.trace.dequeue(), "fwrite", [address, 8])
      try stream.write("hello")
      expectCall(mocking.trace.dequeue(), "fwrite", [address, 5])
      try "a C string".withCString { try stream.write(cString: $0) }
      expectCall(mocking.trace.dequeue(), "fputs", [address, "a C string"])
      try stream.write(byte: 0x41)
      expectCall(mocking.trace.dequeue(), "fputc", [address, CInt(0x41)])
      try stream.flush()
      expectCall(mocking.trace.dequeue(), "fflush", [address])
      try FileStream.flushAll()
      expectCall(mocking.trace.dequeue(), "fflush", [0])

      _ = try stream.fileDescriptor()
      expectCall(mocking.trace.dequeue(), "_fileno", [address])
      // Positioning asks for the descriptor's handle first, which a mocked
      // descriptor doesn't have.
      try stream.seek(offset: -3, from: .end)
      expectCall(mocking.trace.dequeue(), "_fileno", [address])
      expectCall(mocking.trace.dequeue(), "_get_osfhandle", [CInt(0)])
      expectCall(
        mocking.trace.dequeue(), "_fseeki64",
        [address, Int64(-3), FileDescriptor.SeekOrigin.end.rawValue])
      _ = try stream.offset()
      expectCall(mocking.trace.dequeue(), "_fileno", [address])
      expectCall(mocking.trace.dequeue(), "_get_osfhandle", [CInt(0)])
      expectCall(mocking.trace.dequeue(), "_ftelli64", [address])

      // A buffer the stream allocates is 4 KiB, which the C runtime is told.
      try stream.setBuffering(.unbuffered)
      expectCall(
        mocking.trace.dequeue(), "setvbuf",
        [address, 0, FileStream.Buffering.unbuffered.rawValue, 4096])
      try stream.setBuffering(.full, buffer: buffer)
      expectCall(
        mocking.trace.dequeue(), "setvbuf",
        [address, Int(bitPattern: buffer.baseAddress), FileStream.Buffering.full.rawValue, 8])
      try stream.close()
      expectCall(mocking.trace.dequeue(), "fclose", [address])
      XCTAssertTrue(mocking.trace.isEmpty)

      // A failure throws the call's errno, without a retry.
      mocking.forceErrno = .always(errno: Errno.ioError.rawValue)
      XCTAssertThrowsError(try FileStream.open("a path", mode: "r")) { error in
        XCTAssertEqual(error as? Errno, .ioError)
      }
      expectCall(mocking.trace.dequeue(), "_wfopen", ["a path", "r"])
      XCTAssertThrowsError(try stream.write("hello")) { error in
        XCTAssertEqual(error as? Errno, .ioError)
      }
      expectCall(mocking.trace.dequeue(), "fwrite", [address, 5])
      XCTAssertThrowsError(try stream.fileDescriptor()) { error in
        XCTAssertEqual(error as? Errno, .ioError)
      }
      expectCall(mocking.trace.dequeue(), "_fileno", [address])
      XCTAssertThrowsError(try stream.offset()) { error in
        XCTAssertEqual(error as? Errno, .ioError)
      }
      expectCall(mocking.trace.dequeue(), "_fileno", [address])
      expectCall(mocking.trace.dequeue(), "_ftelli64", [address])
      XCTAssertThrowsError(try stream.setBuffering(.unbuffered)) { error in
        XCTAssertEqual(error as? Errno, .ioError)
      }
      expectCall(
        mocking.trace.dequeue(), "setvbuf",
        [address, 0, FileStream.Buffering.unbuffered.rawValue, 4096])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#if ENABLE_MOCKING
/// Checks a call that the mocking driver recorded.
private func expectCall(
  _ entry: Trace.Entry?, _ name: String, _ arguments: [AnyHashable],
  file: StaticString = #filePath, line: UInt = #line
) {
  XCTAssertEqual(entry?.name, name, file: file, line: line)
  XCTAssertEqual(entry?.arguments, arguments, file: file, line: line)
}
#endif

#endif // os(Windows)
