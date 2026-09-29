/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread.Mutex against real pthread mutexes.

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

@Suite("PThread.Mutex")
private struct PThreadMutexTests {
  @available(System 199, *)
  final class Counter: @unchecked Sendable {
    let mutex: PThread.Mutex
    var count = 0
    init(_ attributes: PThread.Mutex.Attributes = .init()) throws {
      mutex = try PThread.Mutex(attributes: attributes)
    }
  }

  @available(System 199, *)
  @Test(arguments: [PThread.Mutex.Kind.default, .normal, .errorChecking, .recursive])
  func mutualExclusion(kind: PThread.Mutex.Kind) throws {
    let counter = try Counter(.init(kind: kind))
    var threads: [PThread.ID] = []
    for _ in 0..<4 {
      threads.append(try PThread {
        for _ in 0..<10_000 {
          try! counter.mutex.withLock { counter.count += 1 }
        }
      }.relinquish())
    }
    for id in threads {
      try PThread(taking: id).join()
    }
    #expect(counter.count == 40_000)
  }

  @available(System 199, *)
  @Test func tryLockWhileAnotherThreadHolds() throws {
    let counter = try Counter()
    let locked = Latch()
    let release = Latch()
    let holder = try PThread {
      try! counter.mutex.lock()
      locked.open()
      _ = release.wait()
      try! counter.mutex.unlock()
    }
    do {
      defer { release.open() }
      #expect(locked.wait())
      #expect(try counter.mutex.tryLock() == false)
    }
    try holder.join()
    #expect(try counter.mutex.tryLock() == true)
    try counter.mutex.unlock()
  }

  @available(System 199, *)
  @Test func errorChecking() throws {
    let mutex = try PThread.Mutex(attributes: .init(kind: .errorChecking))
    try mutex.lock()
    #expect(throws: Errno.deadlock) { try mutex.lock() }
    try mutex.unlock()
    #expect(throws: Errno.notPermitted) { try mutex.unlock() }
  }

  @available(System 199, *)
  @Test func errorCheckingUnlockFromAnotherThread() throws {
    let counter = try Counter(.init(kind: .errorChecking))
    try counter.mutex.lock()
    let result = Locked<Errno?>(nil)
    let thread = try PThread {
      do throws(Errno) {
        try counter.mutex.unlock()
      } catch {
        result.withValue { $0 = error }
      }
    }
    try thread.join()
    try counter.mutex.unlock()
    #expect(result.value == .notPermitted)
  }

  @available(System 199, *)
  @Test func recursive() throws {
    let counter = try Counter(.init(kind: .recursive))
    try counter.mutex.lock()
    try counter.mutex.lock()
    #expect(try counter.mutex.tryLock())
    try counter.mutex.unlock()
    try counter.mutex.unlock()
    // Still held once, so another thread can't lock it.
    let acquired = Locked<Bool?>(nil)
    let thread = try PThread { acquired.withValue { $0 = try? counter.mutex.tryLock() } }
    try thread.join()
    #expect(acquired.value == false)
    try counter.mutex.unlock()
    #expect(throws: Errno.notPermitted) { try counter.mutex.unlock() }
  }

  @available(System 199, *)
  @Test func withLockReturnsAndRethrows() throws {
    struct Failure: Error {}
    let mutex = try PThread.Mutex(attributes: .init(kind: .errorChecking))
    #expect(try mutex.withLock { 7 } == 7)
    #expect(throws: Failure.self) {
      try mutex.withLock { throw Failure() }
    }
    // The mutex was unlocked when the closure threw.
    #expect(try mutex.tryLock())
    try mutex.unlock()
  }

  @available(System 199, *)
  @Test func withLockReturnsANoncopyableValue() throws {
    struct Token: ~Copyable { let value: Int }
    let mutex = try PThread.Mutex()
    let token = try mutex.withLock { Token(value: 3) }
    #expect(token.value == 3)
  }

  @available(System 199, *)
  @Test func withLockDoesNotRunBodyWhenLockingFails() throws {
    let mutex = try PThread.Mutex(attributes: .init(kind: .errorChecking))
    try mutex.lock()
    var ran = false
    #expect(throws: Errno.deadlock) {
      try mutex.withLock { ran = true }
    }
    #expect(!ran)
    try mutex.unlock()
  }

  @available(System 199, *)
  @Test func invalidKind() {
    #expect(throws: Errno.invalidArgument) {
      _ = try PThread.Mutex(attributes: .init(kind: .init(rawValue: 99)))
    }
  }

  @available(System 199, *)
  @Test func defaultAttributes() {
    let attributes = PThread.Mutex.Attributes()
    #expect(attributes.kind == .default)
    #expect(!attributes.isProcessShared)
    #if !os(Android)
    #expect(attributes.priorityProtocol == .none)
    #expect(attributes.priorityCeiling == nil)
    #endif
  }

  #if !os(Android)
  @available(System 199, *)
  @Test func priorityProtocols() throws {
    var inherit = PThread.Mutex.Attributes()
    inherit.priorityProtocol = .inherit
    let inheriting = try PThread.Mutex(attributes: inherit)
    try inheriting.withLock {}

    var protect = PThread.Mutex.Attributes()
    protect.priorityProtocol = .protect
    // POSIX puts ceilings in SCHED_FIFO's range. glibc enforces that, and
    // SCHED_OTHER's range there is 0...0, below it; Darwin allows either.
    let range = try PThread.SchedulingPolicy.fifo.priorityRange()
    protect.priorityCeiling = range.upperBound
    let protecting = try PThread.Mutex(attributes: protect)
    #expect(try protecting.priorityCeiling() == range.upperBound)
    #expect(try protecting.setPriorityCeiling(range.upperBound - 1) == range.upperBound)
    #expect(try protecting.priorityCeiling() == range.upperBound - 1)
  }
  #endif

  // MARK: Placement and C interoperation

  @available(System 199, *)
  @Test func processSharedMutexInSharedMemory() throws {
    let size = MemoryLayout<CInterop.PThreadMutex>.size
    let memory = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0)
    try #require(memory != MAP_FAILED)
    defer { munmap(memory, size) }
    let address = memory!.bindMemory(to: CInterop.PThreadMutex.self, capacity: 1)
    do {
      let mutex = try PThread.Mutex(
        unsafeUninitializedAddress: address,
        attributes: .init(kind: .errorChecking, isProcessShared: true))
      #expect(mutex.unsafeAddress == address)
      try mutex.withLock {}
      #expect(try mutex.tryLock())
      try mutex.unlock()
    }
    // The owner destroyed the mutex but left the memory, so it can hold
    // another one.
    let again = try PThread.Mutex(unsafeUninitializedAddress: address)
    try again.withLock {}
  }

  @available(System 199, *)
  @Test func unsafeAddressIsTheMutexThatCUses() throws {
    let counter = try Counter()
    #expect(pthread_mutex_lock(counter.mutex.unsafeAddress) == 0)
    let acquired = Locked<Bool?>(nil)
    let thread = try PThread { acquired.withValue { $0 = try? counter.mutex.tryLock() } }
    try thread.join()
    #expect(acquired.value == false)
    try counter.mutex.unlock()
  }

  @available(System 199, *)
  @Test func borrowingAMutexThatCOwns() throws {
    let address = UnsafeMutablePointer<CInterop.PThreadMutex>.allocate(capacity: 1)
    defer { address.deallocate() }
    #expect(pthread_mutex_init(address, nil) == 0)
    let result = try PThread.Mutex.withUnsafeMutex(at: address) { mutex in
      try mutex.withLock { 5 }
    }
    #expect(result == 5)
    struct Failure: Error {}
    #expect(throws: Failure.self) {
      try PThread.Mutex.withUnsafeMutex(at: address) { _ in throw Failure() }
    }
    // Neither call destroyed the mutex, so destroying it now succeeds.
    #expect(pthread_mutex_trylock(address) == 0)
    #expect(pthread_mutex_unlock(address) == 0)
    #expect(pthread_mutex_destroy(address) == 0)
  }

  // MARK: Linux

  #if !SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func timedLock() throws {
    let counter = try Counter()
    let locked = Latch()
    let release = Latch()
    let holder = try PThread {
      try! counter.mutex.lock()
      locked.open()
      _ = release.wait()
      try! counter.mutex.unlock()
    }
    do {
      defer { release.open() }
      #expect(locked.wait())
      #expect(try counter.mutex.lock(until: realtimeDeadline(nanoseconds: 10_000_000)) == false)
    }
    try holder.join()
    #expect(try counter.mutex.lock(until: realtimeDeadline(seconds: 10)) == true)
    try counter.mutex.unlock()
  }
  #endif

  #if os(Linux) || os(FreeBSD)
  @available(System 199, *)
  @Test func robustMutexWhoseOwnerEnded() throws {
    var attributes = PThread.Mutex.Attributes()
    attributes.isRobust = true
    let counter = try Counter(attributes)
    let thread = try PThread { try! counter.mutex.lock() }
    try thread.join()
    #expect(throws: Errno.previousOwnerDied) { try counter.mutex.lock() }
    // The calling thread holds the mutex now.
    try counter.mutex.markConsistent()
    try counter.mutex.unlock()
    try counter.mutex.withLock {}
  }
  #endif

  #if SYSTEM_PACKAGE_DARWIN
  /// The static initializers make C objects that work without an init call,
  /// of the kinds they name.
  @available(System 199, *)
  @Test func staticInitializers() {
    let mutex = UnsafeMutablePointer<CInterop.PThreadMutex>.allocate(capacity: 1)
    defer { mutex.deallocate() }
    mutex.initialize(to: .initializer)
    #expect(pthread_mutex_trylock(mutex) == 0)
    #expect(pthread_mutex_trylock(mutex) == EBUSY)
    #expect(pthread_mutex_unlock(mutex) == 0)
    #expect(pthread_mutex_destroy(mutex) == 0)

    mutex.initialize(to: .errorCheckingInitializer)
    #expect(pthread_mutex_lock(mutex) == 0)
    #expect(pthread_mutex_lock(mutex) == EDEADLK)
    #expect(pthread_mutex_unlock(mutex) == 0)
    #expect(pthread_mutex_unlock(mutex) == EPERM)
    #expect(pthread_mutex_destroy(mutex) == 0)

    mutex.initialize(to: .recursiveInitializer)
    #expect(pthread_mutex_lock(mutex) == 0)
    #expect(pthread_mutex_lock(mutex) == 0)
    #expect(pthread_mutex_unlock(mutex) == 0)
    #expect(pthread_mutex_unlock(mutex) == 0)
    #expect(pthread_mutex_destroy(mutex) == 0)

    let condition = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    defer { condition.deallocate() }
    condition.initialize(to: .initializer)
    #expect(pthread_cond_signal(condition) == 0)
    #expect(pthread_cond_destroy(condition) == 0)

    let lock = UnsafeMutablePointer<CInterop.PThreadReadWriteLock>.allocate(capacity: 1)
    defer { lock.deallocate() }
    lock.initialize(to: .initializer)
    #expect(pthread_rwlock_rdlock(lock) == 0)
    #expect(pthread_rwlock_rdlock(lock) == 0)
    #expect(pthread_rwlock_trywrlock(lock) == EBUSY)
    #expect(pthread_rwlock_unlock(lock) == 0)
    #expect(pthread_rwlock_unlock(lock) == 0)
    #expect(pthread_rwlock_destroy(lock) == 0)
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
