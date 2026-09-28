/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && ENABLE_MOCKING

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// A mocked allocation that succeeds allocates for real, so these tests free
// what they allocate. free itself has no mock hook.
@available(System 199, *)
final class MemoryMockTests: XCTestCase {
  // The calls record their pointers as optionals, which AnyHashable doesn't
  // equate with the pointers themselves.
  private func optional(_ pointer: UnsafeMutableRawPointer?) -> AnyHashable { pointer }

  private func entries(_ mocking: MockingDriver) -> [(String, [AnyHashable])] {
    var result: [(String, [AnyHashable])] = []
    while let entry = mocking.trace.dequeue() { result.append((entry.name, entry.arguments)) }
    return result
  }

  func testRequests() throws {
    let pointerSize = MemoryLayout<UnsafeRawPointer>.size
    try MockingDriver.withMockingEnabled { mocking in
      Memory.free(try Memory.allocate(byteCount: 100))
      Memory.free(try Memory.allocate(byteCount: 0))
      Memory.free(try Memory.allocateZeroed(byteCount: 10))
      Memory.free(try Memory.allocateZeroed(count: 3, stride: 8))
      Memory.free(try Memory.allocateZeroed(count: 0, stride: 8))
      Memory.free(try Memory.allocate(byteCount: 10, alignment: 2))
      Memory.free(try Memory.allocate(byteCount: 0, alignment: 64))
      let block = try Memory.reallocate(nil, byteCount: 5)
      let grown = try Memory.reallocate(block, byteCount: 0)
      Memory.free(grown)

      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), [
        "malloc", "malloc", "calloc", "calloc", "calloc",
        "posix_memalign", "posix_memalign", "realloc", "realloc",
      ])
      // Zero is one byte, and a small alignment a pointer's.
      XCTAssertEqual(calls.map(\.1), [
        [100], [1], [1, 10], [3, 8], [1, 1],
        [pointerSize, 10], [64, 1], [optional(nil), 5], [optional(block), 1],
      ] as [[AnyHashable]])
    }
  }

  func testAnInvalidAlignmentMakesNoCall() throws {
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertThrowsError(try Memory.allocate(byteCount: 16, alignment: 12)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }

  func testFailures() throws {
    try MockingDriver.withMockingEnabled { mocking in
      // A failed allocation is noMemory, whatever errno says.
      for error in [ENOMEM, EIO] {
        mocking.forceErrno = .counted(errno: error, count: 1)
        XCTAssertThrowsError(try Memory.allocate(byteCount: 8)) {
          XCTAssertEqual($0 as? Errno, .noMemory)
        }
      }
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try Memory.allocateZeroed(count: 2, stride: 2)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      // posix_memalign returns its error, which is thrown.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      XCTAssertThrowsError(try Memory.allocate(byteCount: 8, alignment: 64)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }

      // A failed reallocation leaves the block as it was.
      let block = try Memory.allocate(byteCount: 8)
      block.storeBytes(of: 7, as: Int.self)
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try Memory.reallocate(block, byteCount: 64)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      XCTAssertEqual(block.load(as: Int.self), 7)
      Memory.free(block)
      XCTAssertEqual(entries(mocking).map(\.0), [
        "malloc", "malloc", "calloc", "posix_memalign", "malloc", "realloc",
      ])
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testDarwinAllocators() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let block = try Memory.allocatePageAligned(byteCount: 0)
      let grown = try Memory.reallocateFreeingOnFailure(block, byteCount: 50)
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      // The mock frees the block when it fails, as reallocf does.
      XCTAssertThrowsError(try Memory.reallocateFreeingOnFailure(grown, byteCount: 60)) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), ["valloc", "reallocf", "reallocf"])
      XCTAssertEqual(calls.map(\.1), [[1], [optional(block), 50], [optional(grown), 60]])
    }
  }

  func testZones() throws {
    try MockingDriver.withMockingEnabled { mocking in
      let zone = try Memory.Zone.create(name: "mocked")
      let block = try zone.allocate(byteCount: 64)
      let zeroed = try zone.allocateZeroed(byteCount: 0)
      let aligned = try zone.allocate(byteCount: 8, alignment: 4)
      let page = try zone.allocatePageAligned(byteCount: 8)
      let moved = try zone.reallocate(block, byteCount: 128)
      for pointer in [moved, zeroed, aligned, page] { zone.free(pointer) }
      zone.destroy()

      let z = zone.rawValue as AnyHashable
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), [
        "malloc_create_zone", "malloc_set_zone_name", "malloc_zone_malloc",
        "malloc_zone_calloc", "malloc_zone_memalign", "malloc_zone_valloc",
        "malloc_zone_realloc", "malloc_zone_free", "malloc_zone_free",
        "malloc_zone_free", "malloc_zone_free", "malloc_destroy_zone",
      ])
      XCTAssertEqual(calls.map(\.1), [
        [], [z, "mocked" as String?], [z, 64],
        [z, 1, 1], [z, MemoryLayout<UnsafeRawPointer>.size, 8], [z, 8],
        [z, optional(block), 128], [z, optional(moved)], [z, optional(zeroed)],
        [z, optional(aligned)], [z, optional(page)], [z],
      ] as [[AnyHashable]])

      // A zone that can't be created isn't named.
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      XCTAssertThrowsError(try Memory.Zone.create(name: "never")) {
        XCTAssertEqual($0 as? Errno, .noMemory)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["malloc_create_zone"])
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
