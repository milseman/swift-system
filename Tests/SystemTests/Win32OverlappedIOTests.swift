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

/// An `OVERLAPPED` on the heap, zeroed, as an operation's structure must stay
/// at one address.
private func allocateOverlapped() -> UnsafeMutablePointer<OVERLAPPED> {
  let overlapped = UnsafeMutablePointer<OVERLAPPED>.allocate(capacity: 1)
  overlapped.initialize(to: OVERLAPPED())
  return overlapped
}

/// An inbound named pipe: an overlapped server end that reads, and a
/// synchronous client end that writes.
@available(System 199, *)
private struct Win32TestNamedPipe: ~Copyable {
  var server: Win32.OverlappedFileHandle
  var client: Win32.FileHandle

  init(_ name: String) throws {
    let path = "\\\\.\\pipe\\system-tests-\(GetCurrentProcessId())-\(name)"
    let server = path.withCString(encodedAs: UTF16.self) { path in
      CreateNamedPipeW(
        path, DWORD(PIPE_ACCESS_INBOUND) | 0x4000_0000,  // FILE_FLAG_OVERLAPPED
        DWORD(PIPE_TYPE_BYTE | PIPE_WAIT), 1, 4096, 4096, 0, nil)
    }
    guard let server, server != INVALID_HANDLE_VALUE else { throw Win32.Error(GetLastError()) }
    let owner = Win32.OverlappedFileHandle(unsafelyAdopting: server)!
    // Opening the client end connects the pipe.
    let client = try Win32.FileHandle.open(FilePath(path), access: .genericWrite)
    self.server = owner
    self.client = client
  }
}

// Win32.OverlappedFileHandle and Win32.CompletionPort. Pending operations
// come from an overlapped named pipe's server end, which waits for its
// client to write.
@available(System 199, *)
final class Win32OverlappedIOTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_ERROR_IO_INCOMPLETE, DWORD(WinSDK.ERROR_IO_INCOMPLETE))
    XCTAssertEqual(_ERROR_NOT_FOUND, DWORD(WinSDK.ERROR_NOT_FOUND))
  }

  func testOpeningAddsTheFlag() throws {
    try withTemporaryFilePath(basename: "testOpeningAddsTheFlag") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.OverlappedFileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      XCTAssertFalse(Win32._isSynchronous(file.unsafeRawHandle))
      let synchronous = try Win32.FileHandle.open(path, access: .genericRead)
      XCTAssertTrue(Win32._isSynchronous(synchronous.unsafeRawHandle))
      try synchronous.close()
      try file.close()
    }
  }

  func testFileReadsAndWrites() throws {
    try withTemporaryFilePath(basename: "testOverlappedFile") { directory in
      let file = try Win32.OverlappedFileHandle.open(
        directory.appending("file.txt"), access: [.genericRead, .genericWrite],
        disposition: .createNew)
      let overlapped = allocateOverlapped()
      defer { overlapped.deallocate() }

      let bytes = Array("hello".utf8)
      let written = try bytes.withUnsafeBytes { buffer in
        let started = try file.write(buffer, toAbsoluteOffset: 0, overlapped: overlapped)
        return try started ?? file.result(of: overlapped, wait: true)
      }
      XCTAssertEqual(written, 5)

      var contents = [UInt8](repeating: 0, count: 16)
      let read = try contents.withUnsafeMutableBytes { buffer in
        let started = try file.read(into: buffer, fromAbsoluteOffset: 1, overlapped: overlapped)
        return try started ?? file.result(of: overlapped, wait: true)
      }
      XCTAssertEqual(read, 4)
      XCTAssertEqual(Array(contents[..<4]), Array("ello".utf8))

      // The end of the file is a failure, now or when the read finishes.
      XCTAssertThrowsWin32Error(.endOfFile) {
        try contents.withUnsafeMutableBytes { buffer in
          let started = try file.read(into: buffer, fromAbsoluteOffset: 100, overlapped: overlapped)
          return try started ?? file.result(of: overlapped, wait: true)
        }
      }
      try file.close()
    }
  }

  func testInvalidRequestsAreRejected() throws {
    try withTemporaryFilePath(basename: "testOverlappedInvalid") { directory in
      let file = try Win32.OverlappedFileHandle.open(
        directory.appending("file.txt"), access: .genericRead, disposition: .createNew)
      let overlapped = allocateOverlapped()
      defer { overlapped.deallocate() }
      var contents = [UInt8](repeating: 0, count: 4)
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try contents.withUnsafeMutableBytes { buffer in
          try file.read(into: buffer, fromAbsoluteOffset: -1, overlapped: overlapped)
        }
      }
      try file.close()
    }
  }

  func testPendingReadsSignalTheirEvent() throws {
    let pipe = try Win32TestNamedPipe("testPendingReadsSignalTheirEvent")
    let overlapped = allocateOverlapped()
    defer { overlapped.deallocate() }
    let event = try XCTUnwrap(CreateEventW(nil, true, false, nil))
    defer { CloseHandle(event) }
    overlapped.pointee.hEvent = event

    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }
    let started = try pipe.server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    XCTAssertNil(started)
    XCTAssertEqual(WaitForSingleObject(event, 50), DWORD(WAIT_TIMEOUT))
    let pending = try pipe.server.result(of: overlapped, wait: false)
    XCTAssertNil(pending)

    _ = try win32RawWrite(pipe.client.unsafeRawHandle, Array("x".utf8)).get()
    XCTAssertEqual(WaitForSingleObject(event, 10_000), WAIT_OBJECT_0)
    let finished = try pipe.server.result(of: overlapped, wait: false)
    XCTAssertEqual(finished, 1)
    XCTAssertEqual(buffer[0], UInt8(ascii: "x"))
  }

  func testCancelingAPendingRead() throws {
    let pipe = try Win32TestNamedPipe("testCancelingAPendingRead")
    let overlapped = allocateOverlapped()
    defer { overlapped.deallocate() }
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    let started = try pipe.server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    XCTAssertNil(started)
    let timedOut = try pipe.server.result(of: overlapped, timeout: .milliseconds(20))
    XCTAssertNil(timedOut)
    let canceled = try pipe.server.cancel(overlapped)
    XCTAssertTrue(canceled)
    XCTAssertThrowsWin32Error(.operationAborted) {
      try pipe.server.result(of: overlapped, wait: true)
    }
    // Nothing is pending now.
    let canceledAgain = try pipe.server.cancel(overlapped)
    XCTAssertFalse(canceledAgain)
    let canceledAny = try pipe.server.cancelAll()
    XCTAssertFalse(canceledAny)
  }

  func testCompletionPort() throws {
    let pipe = try Win32TestNamedPipe("testCompletionPort")
    let port = try Win32.CompletionPort.create()
    try port.associate(pipe.server, key: 42)
    let overlapped = allocateOverlapped()
    defer { overlapped.deallocate() }
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    let started = try pipe.server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    XCTAssertNil(started)
    let none = try port.dequeue(timeout: .zero)
    XCTAssertNil(none)
    _ = try win32RawWrite(pipe.client.unsafeRawHandle, Array("abc".utf8)).get()
    let completion = try XCTUnwrap(try port.dequeue(timeout: .seconds(10)))
    XCTAssertEqual(completion.key, 42)
    XCTAssertEqual(completion.overlapped, overlapped)
    XCTAssertEqual(completion.bytesTransferred, 3)
    XCTAssertNil(completion.error)

    // A posted packet carries the caller's values.
    try port.post(bytesTransferred: 7, key: 9)
    let posted = try XCTUnwrap(try port.dequeue(timeout: .seconds(10)))
    XCTAssertEqual(posted.key, 9)
    XCTAssertEqual(posted.bytesTransferred, 7)
    XCTAssertNil(posted.overlapped)
    XCTAssertNil(posted.error)

    // A handle belongs to one port.
    let other = try Win32.CompletionPort.create(concurrentThreads: 1)
    XCTAssertThrowsWin32Error(.invalidParameter) { try other.associate(pipe.server, key: 1) }
  }

  func testCompletionPortReportsFailures() throws {
    var pipe = try Win32TestNamedPipe("testCompletionPortReportsFailures")
    let port = try Win32.CompletionPort.create()
    try port.associate(pipe.server, key: 5)
    let overlapped = allocateOverlapped()
    defer { overlapped.deallocate() }
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
    defer { buffer.deallocate() }

    _ = try pipe.server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    try pipe.server.cancelAll()
    let canceled = try XCTUnwrap(try port.dequeue(timeout: .seconds(10)))
    XCTAssertEqual(canceled.key, 5)
    XCTAssertEqual(canceled.error, .operationAborted)

    // The writer closing ends a pending read with brokenPipe.
    _ = try pipe.server.read(into: buffer, fromAbsoluteOffset: 0, overlapped: overlapped)
    pipe.client = try Win32.FileHandle.open("NUL", access: .genericWrite)
    let broken = try XCTUnwrap(try port.dequeue(timeout: .seconds(10)))
    XCTAssertEqual(broken.error, .brokenPipe)
  }
}

#endif // os(Windows)
