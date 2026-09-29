/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && !os(Android)

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// Shared memory objects and named semaphores. Their names are the system's,
// so each test uses names of its own process ID, and removes them.
@available(System 199, *)
final class SharedMemoryTest: XCTestCase {
  /// A name that no other running process uses. A test run that crashed
  /// can have left objects of the name behind, which would make an
  /// exclusive create fail, so this removes them first.
  private func name(_ suffix: String) -> String {
    let name = "/sys.\(ProcessID.current.rawValue).\(suffix)"
    try? FileDescriptor.removeSharedMemory(named: name)
    try? NamedSemaphore.remove(named: name)
    return name
  }

  #if ENABLE_MOCKING
  func testSyscalls() {
    let semaphore = NamedSemaphore(rawValue: _mockSemaphore)
    let address = Int(bitPattern: _mockSemaphore)
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "shm_open", .noInterrupt, "/a name", O_RDWR | O_CREAT, CInterop.Mode(0o600)) { _ in
        _ = try FileDescriptor.openSharedMemory(
          named: "/a name", .readWrite, options: .create, permissions: .ownerReadWrite)
      },
      MockTestCase(name: "shm_open", .noInterrupt, "/a name", O_RDONLY, CInterop.Mode(0)) { _ in
        _ = try FileDescriptor.openSharedMemory(named: "/a name", .readOnly)
      },
      MockTestCase(name: "shm_unlink", .noInterrupt, "/a name") { _ in
        try FileDescriptor.removeSharedMemory(named: "/a name")
      },
      MockTestCase(
        name: "sem_open", .noInterrupt, "/a name", O_CREAT | O_EXCL, CInterop.Mode(0o600), CUnsignedInt(3)
      ) { _ in
        _ = try NamedSemaphore.open(
          named: "/a name", options: [.create, .exclusiveCreate], permissions: .ownerReadWrite, value: 3)
      },
      MockTestCase(name: "sem_close", .noInterrupt, address) { _ in
        try semaphore.close()
      },
      MockTestCase(name: "sem_unlink", .noInterrupt, "/a name") { _ in
        try NamedSemaphore.remove(named: "/a name")
      },
      MockTestCase(name: "sem_wait", .interruptable, address) { retryOnInterrupt in
        try semaphore.wait(retryOnInterrupt: retryOnInterrupt)
      },
      MockTestCase(name: "sem_post", .noInterrupt, address) { _ in
        try semaphore.post()
      },
    ]
    syscallTestCases.forEach { $0.runAllTests() }
  }
  #endif

  func testSharedMemory() throws {
    let name = name("shm")
    let owner = try FileDescriptor.openSharedMemory(
      named: name, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    defer {
      try? owner.close()
      try? FileDescriptor.removeSharedMemory(named: name)
    }
    XCTAssertTrue(try owner.descriptorFlags().contains(.closeOnExec))
    XCTAssertEqual(try owner.stat().size, 0)
    XCTAssertThrowsError(
      try FileDescriptor.openSharedMemory(
        named: name, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    ) { XCTAssertEqual($0 as? Errno, .fileExists) }

    try owner.resize(to: 4096)
    let size = Int(try owner.stat().size)
    XCTAssertGreaterThanOrEqual(size, 4096)
    let writer = try MemoryMapping(file: owner, byteCount: size, protection: [.read, .write])
    writer.unsafeBuffer.copyBytes(from: "shared".utf8)

    // Another descriptor on the name sees the same memory.
    let other = try FileDescriptor.openSharedMemory(named: name, .readOnly)
    defer { try? other.close() }
    let reader = try MemoryMapping(file: other, byteCount: size)
    XCTAssertEqual(String(decoding: reader.unsafeBuffer.prefix(6), as: UTF8.self), "shared")

    // Removing the name leaves the object to its mappings.
    try FileDescriptor.removeSharedMemory(named: name)
    XCTAssertEqual(String(decoding: reader.unsafeBuffer.prefix(6), as: UTF8.self), "shared")
    XCTAssertThrowsError(try FileDescriptor.removeSharedMemory(named: name)) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(try FileDescriptor.openSharedMemory(named: name, .readOnly)) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    try writer.unmap()
    try reader.unmap()
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Darwin's limits: names of at most 31 bytes, one resize, no truncate,
  /// and no reading or writing through the descriptor.
  func testDarwinSharedMemoryLimits() throws {
    XCTAssertThrowsError(
      try FileDescriptor.openSharedMemory(
        named: "/" + String(repeating: "n", count: 40), .readWrite, options: .create,
        permissions: .ownerReadWrite)
    ) { XCTAssertEqual($0 as? Errno, .fileNameTooLong) }
    let name = name("limits")
    let fd = try FileDescriptor.openSharedMemory(
      named: name, .readWrite, options: .create, permissions: .ownerReadWrite)
    defer {
      try? fd.close()
      try? FileDescriptor.removeSharedMemory(named: name)
    }
    try fd.resize(to: 100)
    XCTAssertThrowsError(try fd.resize(to: 200)) { XCTAssertEqual($0 as? Errno, .invalidArgument) }
    XCTAssertThrowsError(try FileDescriptor.openSharedMemory(named: name, .readWrite, options: .truncate)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
    XCTAssertThrowsError(try fd.writeAll("x".utf8)) { XCTAssertEqual($0 as? Errno, .noSuchAddressOrDevice) }
  }
  #endif

  func testNamedSemaphore() throws {
    let name = name("sem")
    let first = try NamedSemaphore.open(
      named: name, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite, value: 2)
    defer {
      try? first.close()
      try? NamedSemaphore.remove(named: name)
    }
    XCTAssertTrue(try first.tryWait())
    XCTAssertTrue(try first.tryWait())
    XCTAssertFalse(try first.tryWait())

    // Another handle on the name shares the count.
    let second = try NamedSemaphore.open(named: name)
    defer { try? second.close() }
    try second.post()
    XCTAssertTrue(try first.tryWait())
    XCTAssertFalse(try second.tryWait())

    XCTAssertThrowsError(
      try NamedSemaphore.open(
        named: name, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    ) { XCTAssertEqual($0 as? Errno, .fileExists) }
    XCTAssertGreaterThan(NamedSemaphore.maxValue, 0)

    try NamedSemaphore.remove(named: name)
    XCTAssertThrowsError(try NamedSemaphore.remove(named: name)) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(try NamedSemaphore.open(named: name)) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
  }

  /// A wait waits until another thread posts.
  func testWaitingForAPost() throws {
    let name = name("wait")
    let semaphore = try NamedSemaphore.open(
      named: name, options: .create, permissions: .ownerReadWrite)
    defer {
      try? semaphore.close()
      try? NamedSemaphore.remove(named: name)
    }
    let posted = expectation(description: "posted")
    let poster = Thread {
      usleep(50_000)
      try? semaphore.post()
      posted.fulfill()
    }
    poster.start()
    try semaphore.wait()
    wait(for: [posted], timeout: TimeInterval(hangGuardSeconds))
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
