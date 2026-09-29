/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@available(System 199, *)
extension CInterop {
  /// Darwin's unfair lock.
  ///
  /// The corresponding C type is `os_unfair_lock`.
  ///
  /// - Note: Only available on Darwin.
  public typealias UnfairLock = os_unfair_lock
}

/// Darwin's unfair lock: a small, fast mutual exclusion lock
/// that doesn't queue the threads that wait for it.
///
/// To protect a value, prefer the standard library's
/// `Synchronization.Mutex`, which is this lock on Darwin,
/// from macOS 15, iOS 18, watchOS 11, tvOS 18, and visionOS 2.
/// ``PThread/Mutex`` is for a pthread mutex's kinds
/// (recursive, error-checking, robust),
/// for sharing a lock between processes,
/// and for waiting on a ``PThread/Condition``.
/// Use `UnfairLock` for `os_unfair_lock` itself:
/// before those releases, for its ownership assertions
/// and its adaptive spinning, or to share a lock with C code.
/// It needs no import of `os`, whose `OSAllocatedUnfairLock`
/// re-exports all of Darwin.
///
///     let lock = UnfairLock()
///     lock.withLock {
///       queue.append(job)
///     }
///
/// The lock is unfair: a thread that unlocks it can lock it again
/// ahead of the threads that were waiting,
/// which keeps the lock fast, and can starve a waiter.
/// A waiter doesn't spin; it sleeps until the lock is free,
/// and lends its priority to the lock's owner.
/// The lock isn't recursive:
/// locking it again from the thread that holds it crashes the process,
/// as unlocking it from another thread does.
///
/// `UnfairLock` can't be copied. It keeps the C lock at one address
/// from its creation until its destruction,
/// so moving an `UnfairLock` doesn't move the C lock.
/// Destroying a locked lock is a programming error,
/// which this type doesn't detect.
///
/// The corresponding C type is `os_unfair_lock`.
///
/// - Note: Only available on Darwin.
@frozen
@available(System 199, *)
public struct UnfairLock: ~Copyable, @unchecked Sendable {
  @usableFromInline
  internal let _address: UnsafeMutablePointer<CInterop.UnfairLock>

  // Whether the storage was allocated by this type, rather than provided
  // by the caller of init(unsafeAddress:).
  @usableFromInline
  internal let _deallocates: Bool

  /// Creates an unlocked lock.
  ///
  /// The corresponding C constant is `OS_UNFAIR_LOCK_INIT`.
  @_alwaysEmitIntoClient
  public init() {
    self._address = UnfairLock._allocate()
    self._deallocates = true
  }

  @usableFromInline
  internal static func _allocate() -> UnsafeMutablePointer<CInterop.UnfairLock> {
    let address = UnsafeMutablePointer<CInterop.UnfairLock>.allocate(capacity: 1)
    address.initialize(to: os_unfair_lock())
    return address
  }

  /// Uses a lock in memory that the caller provides,
  /// such as a lock in a C structure.
  ///
  /// - Parameter address: The C lock.
  ///   It must be initialized, as `OS_UNFAIR_LOCK_INIT` or all zero bytes,
  ///   and must stay at this address, without being moved or reused,
  ///   until the `UnfairLock` instance is destroyed.
  ///
  /// Destroying the `UnfairLock` doesn't deallocate the memory.
  @_alwaysEmitIntoClient
  public init(unsafeAddress address: UnsafeMutablePointer<CInterop.UnfairLock>) {
    self._address = address
    self._deallocates = false
  }

  deinit {
    // An unfair lock has nothing to destroy, and so no error to drop.
    if _deallocates {
      _address.deinitialize(count: 1)
      _address.deallocate()
    }
  }
}

@available(System 199, *)
extension UnfairLock {
  /// Locks the lock, waiting until it's free.
  ///
  /// Locking a lock that the calling thread holds crashes the process.
  ///
  /// The corresponding C function is `os_unfair_lock_lock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock() {
    _lock()
  }

  @usableFromInline
  internal func _lock() {
    system_os_unfair_lock_lock(_address)
  }

  /// Locks the lock if it's free, without waiting.
  ///
  /// - Returns: `true` if the calling thread locked the lock,
  ///   or `false` if a thread holds it.
  ///
  /// It returns `false`, rather than crash,
  /// for a lock that the calling thread holds.
  ///
  /// The corresponding C function is `os_unfair_lock_trylock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func tryLock() -> Bool {
    _tryLock()
  }

  @usableFromInline
  internal func _tryLock() -> Bool {
    system_os_unfair_lock_trylock(_address)
  }

  /// Unlocks the lock.
  ///
  /// Only the thread that locked the lock can unlock it;
  /// unlocking it from another thread, or when it isn't locked,
  /// crashes the process.
  ///
  /// The corresponding C function is `os_unfair_lock_unlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func unlock() {
    _unlock()
  }

  @usableFromInline
  internal func _unlock() {
    system_os_unfair_lock_unlock(_address)
  }

  /// Locks the lock, calls a closure, and then unlocks the lock,
  /// even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the lock locked.
  /// - Returns: The value that `body` returns.
  ///
  /// The corresponding C functions are `os_unfair_lock_lock`
  /// and `os_unfair_lock_unlock`.
  @_alwaysEmitIntoClient
  public func withLock<R: ~Copyable>(_ body: () throws -> R) rethrows -> R {
    _lock()
    defer { _unlock() }
    return try body()
  }

  /// Crashes the process unless the calling thread holds the lock.
  ///
  /// The corresponding C function is `os_unfair_lock_assert_owner`.
  @_alwaysEmitIntoClient
  public func assertOwned() {
    _assertOwned()
  }

  @usableFromInline
  internal func _assertOwned() {
    system_os_unfair_lock_assert_owner(_address)
  }

  /// Crashes the process if the calling thread holds the lock.
  ///
  /// The corresponding C function is `os_unfair_lock_assert_not_owner`.
  @_alwaysEmitIntoClient
  public func assertNotOwned() {
    _assertNotOwned()
  }

  @usableFromInline
  internal func _assertNotOwned() {
    system_os_unfair_lock_assert_not_owner(_address)
  }
}

// MARK: - Locking with options

@available(System 199, *)
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension UnfairLock {
  /// Options for locking an unfair lock.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct LockOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed options value from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Spins for a while before waiting,
    /// while the lock's owner is running on another core.
    ///
    /// Use it only for a lock whose critical sections are always very short.
    ///
    /// The corresponding C constant is `OS_UNFAIR_LOCK_FLAG_ADAPTIVE_SPIN`,
    /// which Swift can't import.
    @_alwaysEmitIntoClient
    public static var adaptiveSpin: LockOptions { LockOptions(rawValue: 0x0004_0000) }
  }

  /// Locks the lock, waiting until it's free, with options.
  ///
  /// - Parameter options: How to wait.
  ///
  /// See ``lock()``.
  ///
  /// The corresponding C function is `os_unfair_lock_lock_with_flags`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock(options: LockOptions) {
    _lock(options: options)
  }

  @usableFromInline
  internal func _lock(options: LockOptions) {
    system_os_unfair_lock_lock_with_flags(_address, options.rawValue)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
