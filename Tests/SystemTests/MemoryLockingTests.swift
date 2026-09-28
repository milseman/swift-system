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
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class MemoryLockingTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64, alignment: 16)
    defer { buffer.deallocate() }
    let start = Int(bitPattern: buffer.baseAddress)

    // Locking faults pages in, but doesn't report EINTR, so it isn't retried.
    var syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "mlock", .noInterrupt, start, 64) { _ in
        try Memory.lockPages(UnsafeRawBufferPointer(buffer))
      },
      MockTestCase(name: "munlock", .noInterrupt, start, 64) { _ in
        try Memory.unlockPages(UnsafeRawBufferPointer(buffer))
      },
      MockTestCase(name: "mlock", .noInterrupt, 0, 0) { _ in
        try Memory.lockPages(UnsafeRawBufferPointer(start: nil, count: 0))
      },
    ]
    #if !SYSTEM_PACKAGE_DARWIN
    syscallTestCases += [
      MockTestCase(name: "mlockall", .noInterrupt, MCL_CURRENT | MCL_FUTURE) { _ in
        try Memory.lockAllPages([.current, .future])
      },
      MockTestCase(name: "munlockall", .noInterrupt) { _ in
        try Memory.unlockAllPages()
      },
    ]
    #endif
    syscallTestCases.forEach { $0.runAllTests() }
  }

  /// A mapping's range is offsets into it.
  func testMappingSyscalls() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let mapping = try MemoryMapping(byteCount: 3 * 4096)
      let start = Int(bitPattern: mapping.unsafeBuffer.baseAddress)
      try mapping.lockPages()
      try mapping.unlockPages(range: 4096..<8192)
      try mapping.unmap()
      var calls: [(String, [AnyHashable])] = []
      while let entry = mocking.trace.dequeue() { calls.append((entry.name, entry.arguments)) }
      XCTAssertEqual(calls.map(\.0), ["mmap", "mlock", "munlock", "munmap"])
      XCTAssertEqual(calls[1].1, [start, 3 * 4096] as [AnyHashable])
      XCTAssertEqual(calls[2].1, [start + 4096, 4096] as [AnyHashable])
    }
  }
  #endif

  func testLockingAHeapBuffer() throws {
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 3 * 4096 + 100, alignment: 16)
    defer { buffer.deallocate() }
    try Memory.lockPages(UnsafeRawBufferPointer(buffer))
    try Memory.unlockPages(UnsafeRawBufferPointer(buffer))
    // Unlocking pages that aren't locked does nothing.
    try Memory.unlockPages(UnsafeRawBufferPointer(buffer))
    try Memory.lockPages(UnsafeRawBufferPointer(start: nil, count: 0))
  }

  /// Locking brings a fresh mapping's pages into memory.
  func testLockingAMappingBringsItIn() throws {
    let pageSize = try XCTUnwrap(SystemConfig.value(.pageSize))
    let mapping = try MemoryMapping(byteCount: 4 * pageSize)
    XCTAssertEqual(try mapping.residentPages(), [false, false, false, false])
    try mapping.lockPages(range: pageSize..<(2 * pageSize))
    XCTAssertEqual(try mapping.residentPages(), [false, true, false, false])
    try mapping.lockPages()
    XCTAssertEqual(try mapping.residentPages(), [true, true, true, true])
    try mapping.unlockPages()
    try mapping.unmap()
  }

  /// Memory that isn't mapped can't be locked.
  func testLockingUnmappedMemory() throws {
    let pageSize = try XCTUnwrap(SystemConfig.value(.pageSize))
    let buffer = try MemoryMapping(byteCount: 2 * pageSize).relinquish()
    try MemoryMapping(unsafeTaking: buffer.baseAddress!, byteCount: buffer.count).unmap()
    XCTAssertThrowsError(try Memory.lockPages(UnsafeRawBufferPointer(buffer))) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
