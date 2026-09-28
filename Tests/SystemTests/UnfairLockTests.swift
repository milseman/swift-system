/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Testing
import Darwin

#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

@Suite("Unfair lock")
private struct UnfairLockTests {
  @available(System 199, *)
  @Test func lockingAndUnlocking() {
    let lock = UnfairLock()
    lock.assertNotOwned()
    lock.lock()
    lock.assertOwned()
    lock.unlock()
    let locked = lock.tryLock()
    #expect(locked)
    lock.unlock()
    let result = lock.withLock { () -> Int in
      lock.assertOwned()
      return 42
    }
    #expect(result == 42)
    lock.assertNotOwned()
  }

  /// Another thread's tryLock fails while one thread holds the lock.
  @available(System 199, *)
  @Test func tryLockFromAnotherThread() throws {
    let lock = UnfairLock()
    let result = Locked<Bool?>(nil)
    lock.lock()
    let thread = try PThread { result.withValue { $0 = lock.tryLock() } }
    try thread.join()
    lock.unlock()
    #expect(result.value == false)
  }

  /// A lock and the count it protects, which threads share.
  private final class Counter: @unchecked Sendable {
    let lock = UnfairLock()
    var count = 0

    func increment(times: Int) {
      for _ in 0..<times { lock.withLock { count += 1 } }
    }
  }

  @available(System 199, *)
  @Test func counting() throws {
    let counter = Counter()
    // PThread can't be copied, so no array of them.
    let first = try PThread { counter.increment(times: 10_000) }
    let second = try PThread { counter.increment(times: 10_000) }
    let third = try PThread { counter.increment(times: 10_000) }
    counter.increment(times: 10_000)
    try first.join()
    try second.join()
    try third.join()
    #expect(counter.lock.withLock { counter.count } == 40_000)
  }

  /// A lock in memory the caller owns, as in a C structure.
  @available(System 199, *)
  @Test func aLockAtAnAddress() {
    let storage = UnsafeMutablePointer<CInterop.UnfairLock>.allocate(capacity: 1)
    storage.initialize(to: os_unfair_lock())
    defer { storage.deallocate() }
    do {
      let lock = UnfairLock(unsafeAddress: storage)
      lock.withLock { os_unfair_lock_assert_owner(storage) }
    }
    // The lock is still there, and still usable.
    #expect(os_unfair_lock_trylock(storage))
    os_unfair_lock_unlock(storage)
  }

  @available(System 199, *)
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @Test func lockingWithOptions() {
    let lock = UnfairLock()
    lock.lock(options: .adaptiveSpin)
    lock.assertOwned()
    lock.unlock()
    lock.lock(options: [])
    lock.unlock()
  }

  @available(System 199, *)
  /// The C library ends the process for a misused lock, with SIGKILL on
  /// macOS 26.
  @Test func unlockingALockThatIsntHeldCrashes() async {
    await #expect(processExitsWith: .failure) {
      UnfairLock().unlock()
    }
  }

  @available(System 199, *)
  @Test func assertingOwnershipOfAFreeLockCrashes() async {
    await #expect(processExitsWith: .failure) {
      UnfairLock().assertOwned()
    }
  }
}

@Suite("C library random numbers")
private struct RandomGeneratorTests {
  @available(System 199, *)
  @Test func generating() {
    // 64 random 32-bit numbers are all zero with probability 2^-2048.
    #expect((0..<64).contains { _ in Entropy.generate() != 0 })
    for bound: UInt32 in [1, 2, 7, 1000, .max] {
      for _ in 0..<100 { #expect(Entropy.generate(below: bound) < bound) }
    }
    #expect(Entropy.generate(below: 0) == 0)
    // Every value below a small bound comes up.
    var seen = Set<UInt32>()
    for _ in 0..<1000 { seen.insert(Entropy.generate(below: 4)) }
    #expect(seen == [0, 1, 2, 3])
  }

  @available(System 199, *)
  @Test func fillingABuffer() {
    // Larger than getentropy's 256 bytes a call.
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 1)
    defer { buffer.deallocate() }
    buffer.initializeMemory(as: UInt8.self, repeating: 0)
    Entropy.generate(into: buffer)
    #expect(buffer.contains { $0 != 0 })
    Entropy.generate(into: UnsafeMutableRawBufferPointer(start: nil, count: 0))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
