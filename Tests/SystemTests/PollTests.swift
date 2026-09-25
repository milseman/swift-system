/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

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
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class PollTests: XCTestCase {
  func testReadableAfterWrite() throws {
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd.fileDescriptor
    XCTAssertEqual(try readEnd.poll(for: .readable, timeout: .zero), [])
    try pipe.writeEnd.writeAll("x".utf8)
    XCTAssertEqual(try readEnd.poll(for: .readable, timeout: .zero), .readable)
    XCTAssertEqual(
      try pipe.writeEnd.fileDescriptor.poll(for: .writable, timeout: .zero)
        .intersection(.writable),
      .writable)
  }

  func testHangUp() throws {
    let pipe = try OwnedFD.pipe()
    let readEnd = pipe.readEnd
    let writeEnd = pipe.writeEnd
    try writeEnd.writeAll("x".utf8)
    try writeEnd.close()
    let events = try readEnd.fileDescriptor.poll(for: .readable, timeout: .zero)
    XCTAssertTrue(events.contains(.hangUp), "polling reports hanging up unasked")
    XCTAssertTrue(events.contains(.readable), "data remains to read")
  }

  func testInvalidDescriptor() throws {
    // No descriptor can be this high, so it's never open.
    let notOpen = FileDescriptor(rawValue: .max)
    XCTAssertEqual(try notOpen.poll(for: .readable, timeout: .zero), .invalidDescriptor)
  }

  func testEntries() throws {
    let first = try OwnedFD.pipe()
    let second = try OwnedFD.pipe()
    try second.writeEnd.writeAll("x".utf8)
    var entries = [
      FileDescriptor.PollEntry(first.readEnd.fileDescriptor, events: .readable),
      FileDescriptor.PollEntry(second.readEnd.fileDescriptor, events: .readable),
      // Polling skips an entry with a negative descriptor.
      FileDescriptor.PollEntry(FileDescriptor(rawValue: -1), events: .readable),
    ]
    let ready = try poll(&entries, timeout: .seconds(10))
    XCTAssertEqual(ready, 1)
    XCTAssertEqual(entries.map(\.returnedEvents), [[], .readable, []])
    XCTAssertEqual(entries[1].fileDescriptor, second.readEnd.fileDescriptor)
    XCTAssertEqual(entries[1].events, .readable)
  }

  func testTimeout() throws {
    let pipe = try OwnedFD.pipe()
    let start = ContinuousClock.now
    let events = try pipe.readEnd.fileDescriptor.poll(
      for: .readable, timeout: .milliseconds(20))
    XCTAssertEqual(events, [])
    XCTAssertGreaterThanOrEqual(ContinuousClock.now - start, .milliseconds(15))
  }

  func testEntryEquality() {
    let entry = FileDescriptor.PollEntry(.standardInput, events: [.readable, .priority])
    XCTAssertEqual(entry, FileDescriptor.PollEntry(rawValue: entry.rawValue))
    var other = entry
    other.returnedEvents = .hangUp
    XCTAssertNotEqual(entry, other)
    XCTAssertEqual(Set([entry, other, entry]).count, 2)
  }

  #if ENABLE_MOCKING
  // The mock records each entry's descriptor and events, and the timeout
  // in milliseconds.
  func testSyscalls() {
    let syscallTestCases: [MockTestCase] = [
      MockTestCase(name: "poll", .interruptable, [42], [_POLLIN], -1) { retryOnInterrupt in
        _ = try FileDescriptor(rawValue: 42).poll(
          for: .readable, timeout: nil, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "poll", .interruptable, [1, 2], [_POLLIN, _POLLOUT | _POLLPRI], 1500
      ) { retryOnInterrupt in
        var entries = [
          FileDescriptor.PollEntry(FileDescriptor(rawValue: 1), events: .readable),
          FileDescriptor.PollEntry(FileDescriptor(rawValue: 2), events: [.writable, .priority]),
        ]
        try poll(&entries, timeout: .milliseconds(1500), retryOnInterrupt: retryOnInterrupt)
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }

  func testTimeouts() throws {
    let cases: [(Duration?, milliseconds: CInt)] = [
      (nil, -1),
      (.zero, 0),
      (.seconds(-1), 0),
      // Parts of a millisecond round up, so a positive timeout waits.
      (.nanoseconds(1), 1),
      (.microseconds(1500), 2),
      (.milliseconds(2), 2),
      (.seconds(2_147_482), 2_147_482_000),
      (.seconds(2_147_483), .max),
      (.seconds(Int64.max), .max),
    ]
    for (timeout, milliseconds) in cases {
      try MockingDriver.withMockingEnabled { mocking in
        _ = try FileDescriptor(rawValue: 42).poll(for: .readable, timeout: timeout)
        XCTAssertEqual(
          mocking.trace.dequeue()?.arguments.last, AnyHashable(milliseconds),
          "timeout \(String(describing: timeout))")
      }
    }
  }
  #endif // ENABLE_MOCKING
}

/// Polls `entries` through a mutable span.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@discardableResult
private func poll(
  _ entries: inout [FileDescriptor.PollEntry],
  timeout: Duration?, retryOnInterrupt: Bool = true
) throws -> Int {
  try entries.withUnsafeMutableBufferPointer { buffer in
    var span = MutableSpan(_unsafeElements: buffer)
    return try FileDescriptor.poll(
      &span, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
  }
}
#endif // !os(Windows) && !os(WASI)
