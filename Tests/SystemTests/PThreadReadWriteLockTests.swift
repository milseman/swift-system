/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread.ReadWriteLock against real rwlocks.

#if !os(Windows) && !os(WASI)

import Testing

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

@Suite("PThread.ReadWriteLock")
private struct PThreadReadWriteLockTests {
  @available(System 199, *)
  final class Table: @unchecked Sendable {
    let lock: PThread.ReadWriteLock
    var entries: [String: Int] = [:]
    init(_ attributes: PThread.ReadWriteLock.Attributes = .init()) throws {
      lock = try PThread.ReadWriteLock(attributes: attributes)
    }
  }

  // Holds `table`'s lock on another thread, for reading or for writing,
  // while `body` runs.
  @available(System 199, *)
  private func whileAnotherThreadHolds(
    _ table: Table, forWriting: Bool, _ body: () throws -> Void
  ) throws {
    let held = Latch()
    let release = Latch()
    let holder = try PThread {
      if forWriting { try! table.lock.lockForWriting() } else { try! table.lock.lockForReading() }
      held.open()
      _ = release.wait()
      try! table.lock.unlock()
    }
    #expect(held.wait())
    defer { release.open() }
    try body()
    _ = holder
  }

  @available(System 199, *)
  @Test func readersShare() throws {
    let table = try Table()
    try whileAnotherThreadHolds(table, forWriting: false) {
      #expect(try table.lock.tryLockForReading())
      try table.lock.unlock()
      #expect(try table.lock.tryLockForWriting() == false)
    }
  }

  @available(System 199, *)
  @Test func writerExcludes() throws {
    let table = try Table()
    try whileAnotherThreadHolds(table, forWriting: true) { () throws in
      #expect(try table.lock.tryLockForReading() == false)
      #expect(try table.lock.tryLockForWriting() == false)
    }
    #expect(try table.lock.tryLockForWriting())
    try table.lock.unlock()
  }

  @available(System 199, *)
  @Test func scopedLocking() throws {
    struct Failure: Error {}
    let table = try Table()
    try table.lock.withLockForWriting { table.entries["a"] = 1 }
    #expect(try table.lock.withLockForReading { table.entries["a"] } == 1)
    #expect(throws: Failure.self) {
      try table.lock.withLockForWriting { throw Failure() }
    }
    #expect(try table.lock.tryLockForWriting())
    try table.lock.unlock()
  }

  @available(System 199, *)
  @Test func concurrentReadersAndWriters() throws {
    let table = try Table()
    var threads: [PThread.ID] = []
    for writer in 0..<2 {
      threads.append(try PThread {
        for i in 0..<1000 {
          try! table.lock.withLockForWriting { table.entries["\(writer)-\(i)"] = i }
        }
      }.relinquish())
    }
    for _ in 0..<4 {
      threads.append(try PThread {
        for _ in 0..<1000 {
          _ = try! table.lock.withLockForReading { table.entries.count }
        }
      }.relinquish())
    }
    for id in threads {
      try PThread(taking: id).join()
    }
    #expect(table.entries.count == 2000)
  }

  @available(System 199, *)
  @Test func processShared() throws {
    let size = MemoryLayout<CInterop.PThreadReadWriteLock>.size
    let memory = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0)
    try #require(memory != MAP_FAILED)
    defer { munmap(memory, size) }
    let lock = try PThread.ReadWriteLock(
      unsafeUninitializedAddress: memory!.bindMemory(
        to: CInterop.PThreadReadWriteLock.self, capacity: 1),
      attributes: .init(isProcessShared: true))
    try lock.withLockForReading {}
    try lock.withLockForWriting {}
  }

  @available(System 199, *)
  @Test func borrowingALockThatCOwns() throws {
    let address = UnsafeMutablePointer<CInterop.PThreadReadWriteLock>.allocate(capacity: 1)
    defer { address.deallocate() }
    #expect(pthread_rwlock_init(address, nil) == 0)
    try PThread.ReadWriteLock.withUnsafeReadWriteLock(at: address) { lock in
      try lock.withLockForWriting {}
    }
    #expect(pthread_rwlock_destroy(address) == 0)
  }
}

#endif // !os(Windows) && !os(WASI)
