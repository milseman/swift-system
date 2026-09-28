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

// A mocked mmap returns an address that nothing may touch, so every mapping
// made while mocking is also destroyed while mocking, where munmap is mocked.
@available(System 199, *)
final class MemoryMappingMockTests: XCTestCase {
  private func entries(_ mocking: MockingDriver) -> [(String, [AnyHashable])] {
    var result: [(String, [AnyHashable])] = []
    while let entry = mocking.trace.dequeue() { result.append((entry.name, entry.arguments)) }
    return result
  }

  func testMapAndUnmap() throws {
    try MockingDriver.withMockingEnabled { mocking in
      do {
        let mapping = try MemoryMapping(byteCount: 8192, protection: .read, options: .shared)
        try mapping.unmap()
      }
      do {
        _ = try MemoryMapping(file: FileDescriptor(rawValue: 3), offset: 4096, byteCount: 100)
      }
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), ["mmap", "munmap", "mmap", "munmap"])
      XCTAssertEqual(calls[0].1, [8192, PROT_READ, MAP_SHARED | MAP_ANON, -1, 0] as [AnyHashable])
      XCTAssertEqual(calls[2].1, [100, PROT_READ, MAP_SHARED, 3, 4096] as [AnyHashable])
      XCTAssertEqual(calls[1].1[1], 8192 as AnyHashable)
      XCTAssertEqual(calls[3].1[1], 100 as AnyHashable)

      // A failed mmap maps nothing, so nothing is unmapped.
      mocking.forceErrno = .counted(errno: ENOMEM, count: 1)
      do {
        _ = try MemoryMapping(byteCount: 8192)
        XCTFail("mmap should have failed")
      } catch {
        XCTAssertEqual(error as? Errno, .noMemory)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["mmap"])
    }
  }

  func testOperations() throws {
    let start = UnsafeMutableRawPointer(bitPattern: 0x10000)!
    try MockingDriver.withMockingEnabled { mocking in
      do {
        let mapping = MemoryMapping(unsafeTaking: start, byteCount: 3 * 4096)
        try mapping.setProtection([.read, .write], range: 4096..<8192)
        try mapping.synchronize()
        try mapping.synchronize(asynchronously: true, invalidatingCaches: true)
        try mapping.advise(.willNeed)
      }
      let calls = entries(mocking)
      XCTAssertEqual(calls.map(\.0), ["mprotect", "msync", "msync", "madvise", "munmap"])
      XCTAssertEqual(calls[0].1, [start + 4096, 4096, PROT_READ | PROT_WRITE] as [AnyHashable])
      XCTAssertEqual(calls[1].1, [start, 3 * 4096, MS_SYNC] as [AnyHashable])
      XCTAssertEqual(calls[2].1, [start, 3 * 4096, MS_ASYNC | MS_INVALIDATE] as [AnyHashable])
      XCTAssertEqual(calls[3].1, [start, 3 * 4096, MADV_WILLNEED] as [AnyHashable])
      XCTAssertEqual(calls[4].1, [start, 3 * 4096] as [AnyHashable])

      // unmap reports an error, and the deinit doesn't unmap again.
      mocking.forceErrno = .counted(errno: EINVAL, count: 1)
      do {
        try MemoryMapping(unsafeTaking: start, byteCount: 4096).unmap()
        XCTFail("munmap should have failed")
      } catch {
        XCTAssertEqual(error as? Errno, .invalidArgument)
      }
      XCTAssertEqual(entries(mocking).map(\.0), ["munmap"])
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
