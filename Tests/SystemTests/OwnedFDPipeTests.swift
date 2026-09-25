/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// PROTOTYPE: tests for OwnedFD.pipe() and OwnedFD.Pipe in
// Sources/System/OwnedFD.swift. This module is a client of the one that
// declares OwnedFD.Pipe, so taking a pipe apart here also checks that Pipe
// is frozen (see Prototype/Verify/V13b_crossmodule_frozen_pair).

#if !os(WASI) // WASI has no pipe
@available(System 199, *)
final class OwnedFDPipeTest: XCTestCase {
  #if ENABLE_MOCKING
  func testPipeSyscalls() {
    // The descriptors land in a buffer local to `pipe()`, whose address isn't
    // known in advance, so the pointer argument matches anything. Each body
    // relinquishes both ends, so that the trace records no `close`.
    var syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "pipe", .noInterrupt, Wildcard()) { _ in
        let pipe = try OwnedFD.pipe()
        _ = pipe.readEnd.relinquish()
        _ = pipe.writeEnd.relinquish()
      },
    ]
    if #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) {
      syscallTestCases.append(
        MockTestCase(name: "pipe2", .noInterrupt, Wildcard(), O_CLOEXEC) { _ in
          let pipe = try OwnedFD.pipe(options: .closeOnExec)
          _ = pipe.readEnd.relinquish()
          _ = pipe.writeEnd.relinquish()
        })
    }
    for test in syscallTestCases { test.runAllTests() }
  }

  func testDestroyingPipeClosesBothEnds() {
    MockingDriver.withMockingEnabled { mocking in
      do {
        _ = OwnedFD.Pipe(
          readEnd: OwnedFD(taking: FileDescriptor(rawValue: 42)),
          writeEnd: OwnedFD(taking: FileDescriptor(rawValue: 43)))
      }
      var closed: [String] = []
      while let entry = mocking.trace.dequeue() {
        closed.append("\(entry.name)(\(entry.arguments.map { "\($0)" }.joined()))")
      }
      XCTAssertEqual(closed.sorted(), ["close(42)", "close(43)"])
    }
  }
  #endif // ENABLE_MOCKING

  /// Reads everything from `fd` until end of file, as UTF-8 text.
  private func readToEnd(_ fd: borrowing OwnedFD) throws(Errno) -> String {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 1)
    defer { buffer.deallocate() }
    var result: [UInt8] = []
    while true {
      let count = try fd.read(into: buffer)
      if count == 0 { return String(decoding: result, as: UTF8.self) }
      result += buffer[..<count]
    }
  }

  private func send(_ text: String, andClose fd: consuming OwnedFD) throws(Errno) {
    try fd.writeAll(text.utf8)
    try fd.close()
  }

  func testEndsCanBeTakenApart() throws {
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    try send("abc", andClose: pipe.writeEnd)
    // The write end is closed, so reading drains "abc" and then sees EOF.
    XCTAssertEqual(try readToEnd(readEnd), "abc")
    try readEnd.close()
  }

  func testEndsCanBeClosedInPlace() throws {
    let pipe = try OwnedFD.pipe()
    try pipe.writeEnd.writeAll("xy".utf8)
    try pipe.writeEnd.close()
    // Once one end is consumed, a closure can't capture `pipe`, and
    // XCTAssertEqual's arguments are autoclosures, so read outside it.
    let text = try readToEnd(pipe.readEnd)
    XCTAssertEqual(text, "xy")
    try pipe.readEnd.close()
  }

  func testReplacingAnEndClosesTheOldOne() throws {
    var pipe = try OwnedFD.pipe()
    let other = try OwnedFD.pipe()
    let otherReadEnd = other.readEnd
    // Moving the other pipe's write end in closes this pipe's write end.
    pipe.writeEnd = other.writeEnd
    XCTAssertEqual(try readToEnd(pipe.readEnd), "")
    try pipe.writeEnd.writeAll("moved".utf8)
    try pipe.writeEnd.close()
    XCTAssertEqual(try readToEnd(otherReadEnd), "moved")
  }

  func testRelinquishedEndsStayOpen() throws {
    let pipe = try OwnedFD.pipe()
    let raw = (readEnd: pipe.readEnd.relinquish(), writeEnd: pipe.writeEnd.relinquish())
    try raw.writeEnd.writeAll("raw".utf8)
    try raw.writeEnd.close()
    let readEnd = OwnedFD(taking: raw.readEnd)
    XCTAssertEqual(try readToEnd(readEnd), "raw")
  }

  #if !os(Windows)
  @available(System 199, *)
  func testPipeOptionsApplyToBothEnds() throws {
    guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
      throw XCTSkip("pipe2 and PipeOptions require Darwin 27 or newer")
    }
    let pipe = try OwnedFD.pipe(options: .closeOnExec)
    XCTAssert(try pipe.readEnd.fileDescriptor.descriptorFlags().contains(.closeOnExec))
    XCTAssert(try pipe.writeEnd.fileDescriptor.descriptorFlags().contains(.closeOnExec))
    let plain = try OwnedFD.pipe()
    XCTAssertFalse(try plain.readEnd.fileDescriptor.descriptorFlags().contains(.closeOnExec))
  }
  #endif // !os(Windows)
}
#endif // !os(WASI)
