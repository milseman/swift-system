/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - SRW locks

@available(System 199, *)
extension Win32 {
  /// A slim reader/writer lock: a lock that one thread holds exclusively, or
  /// any number of threads hold shared.
  ///
  ///     let lock = Win32.SRWLock()
  ///     lock.withLock {
  ///       queue.append(job)
  ///     }
  ///
  /// To protect a value, prefer the standard library's
  /// `Synchronization.Mutex`, which is an SRW lock on Windows. Use this type
  /// to wait on a ``Win32/ConditionVariable``, to hold a lock shared, or to
  /// share a lock with C code.
  ///
  /// An SRW lock isn't recursive: a thread that takes it again while it
  /// holds it exclusively waits forever. Only the thread that took the lock
  /// can release it.
  ///
  /// `SRWLock` can't be copied. It keeps the C lock at one address from its
  /// creation until its destruction, since Windows doesn't let a lock in
  /// use move, so moving an `SRWLock` doesn't move the C lock. An SRW lock
  /// needs no cleanup, so destroying one only frees its storage. Destroying
  /// a lock that a thread holds or waits for is a programming error, which
  /// this type doesn't detect.
  ///
  /// The corresponding C type is `SRWLOCK`.
  @frozen
  public struct SRWLock: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<SRWLOCK>

    /// Creates an unlocked lock.
    ///
    /// The corresponding C function is `InitializeSRWLock`.
    @_alwaysEmitIntoClient
    public init() {
      self._address = Win32.SRWLock._allocate()
    }

    deinit {
      _address.deinitialize(count: 1)
      _address.deallocate()
    }
  }
}

@available(System 199, *)
extension Win32.SRWLock {
  /// Takes the lock exclusively, waiting until no thread holds it.
  ///
  /// The corresponding C function is `AcquireSRWLockExclusive`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock() {
    Win32.SRWLock._lock(_address, shared: false)
  }

  /// Takes the lock exclusively if no thread holds it, without waiting.
  ///
  /// - Returns: Whether the calling thread took the lock.
  ///
  /// The corresponding C function is `TryAcquireSRWLockExclusive`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func tryLock() -> Bool {
    Win32.SRWLock._tryLock(_address, shared: false)
  }

  /// Releases the lock, which the calling thread holds exclusively.
  ///
  /// Releasing a lock that the calling thread doesn't hold exclusively is a
  /// programming error, which can end the process.
  ///
  /// The corresponding C function is `ReleaseSRWLockExclusive`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func unlock() {
    Win32.SRWLock._unlock(_address, shared: false)
  }

  /// Takes the lock shared, waiting while a thread holds it exclusively.
  ///
  /// The corresponding C function is `AcquireSRWLockShared`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withSharedLock(_:), which can't hold the lock across a suspension point")
  public func lockShared() {
    Win32.SRWLock._lock(_address, shared: true)
  }

  /// Takes the lock shared if no thread holds it exclusively, without
  /// waiting.
  ///
  /// - Returns: Whether the calling thread took the lock.
  ///
  /// The corresponding C function is `TryAcquireSRWLockShared`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withSharedLock(_:), which can't hold the lock across a suspension point")
  public func tryLockShared() -> Bool {
    Win32.SRWLock._tryLock(_address, shared: true)
  }

  /// Releases the lock, which the calling thread holds shared.
  ///
  /// Releasing a lock that the calling thread doesn't hold shared is a
  /// programming error, which can end the process.
  ///
  /// The corresponding C function is `ReleaseSRWLockShared`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withSharedLock(_:), which can't hold the lock across a suspension point")
  public func unlockShared() {
    Win32.SRWLock._unlock(_address, shared: true)
  }

  /// Takes the lock exclusively, calls a closure, and then releases the
  /// lock, even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the lock held.
  /// - Returns: The value that `body` returns.
  ///
  /// The corresponding C functions are `AcquireSRWLockExclusive` and
  /// `ReleaseSRWLockExclusive`.
  @_alwaysEmitIntoClient
  public func withLock<R: ~Copyable, E: Error>(_ body: () throws(E) -> R) throws(E) -> R {
    Win32.SRWLock._lock(_address, shared: false)
    defer { Win32.SRWLock._unlock(_address, shared: false) }
    return try body()
  }

  /// Takes the lock shared, calls a closure, and then releases the lock,
  /// even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the lock held.
  /// - Returns: The value that `body` returns.
  ///
  /// The corresponding C functions are `AcquireSRWLockShared` and
  /// `ReleaseSRWLockShared`.
  @_alwaysEmitIntoClient
  public func withSharedLock<R: ~Copyable, E: Error>(_ body: () throws(E) -> R) throws(E) -> R {
    Win32.SRWLock._lock(_address, shared: true)
    defer { Win32.SRWLock._unlock(_address, shared: true) }
    return try body()
  }

  /// The address of the C lock, for Win32 calls that `SRWLock` doesn't
  /// provide.
  ///
  /// The address is valid only while this lock is alive.
  @_alwaysEmitIntoClient
  @unsafe
  public var unsafeAddress: UnsafeMutablePointer<SRWLOCK> { _address }
}

@available(System 199, *)
extension Win32.SRWLock {
  @usableFromInline
  internal static func _allocate() -> UnsafeMutablePointer<SRWLOCK> {
    let address = UnsafeMutablePointer<SRWLOCK>.allocate(capacity: 1)
    address.initialize(to: SRWLOCK())
    system_InitializeSRWLock(address)
    return address
  }

  @usableFromInline
  internal static func _lock(_ address: UnsafeMutablePointer<SRWLOCK>, shared: Bool) {
    if shared {
      system_AcquireSRWLockShared(address)
    } else {
      system_AcquireSRWLockExclusive(address)
    }
  }

  @usableFromInline
  internal static func _tryLock(_ address: UnsafeMutablePointer<SRWLOCK>, shared: Bool) -> Bool {
    // These return a BOOLEAN, a byte, rather than a BOOL.
    if shared {
      return system_TryAcquireSRWLockShared(address) != 0
    }
    return system_TryAcquireSRWLockExclusive(address) != 0
  }

  @usableFromInline
  internal static func _unlock(_ address: UnsafeMutablePointer<SRWLOCK>, shared: Bool) {
    if shared {
      system_ReleaseSRWLockShared(address)
    } else {
      system_ReleaseSRWLockExclusive(address)
    }
  }
}

// MARK: - Critical sections

@available(System 199, *)
extension Win32 {
  /// A critical section: a lock that one thread holds at a time, and can
  /// take again while it holds it.
  ///
  ///     let lock = Win32.CriticalSection()
  ///     lock.withLock {
  ///       queue.append(job)
  ///     }
  ///
  /// Unlike ``Win32/SRWLock``, a critical section is recursive: the thread
  /// that holds one can take it again, and must release it as many times as
  /// it took it. It has no shared mode. Prefer an SRW lock, which is smaller
  /// and faster, unless the code needs to take the lock recursively, or C
  /// code shares it as a `CRITICAL_SECTION`.
  ///
  /// `CriticalSection` can't be copied. It keeps the C critical section at
  /// one address from its creation until its destruction, which deletes it.
  /// Destroying a critical section that a thread holds or waits for is a
  /// programming error, which this type doesn't detect.
  ///
  /// The corresponding C type is `CRITICAL_SECTION`.
  @frozen
  public struct CriticalSection: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<CRITICAL_SECTION>

    /// Creates a critical section that no thread holds.
    ///
    /// The corresponding C function is `InitializeCriticalSection`, which
    /// can't fail.
    @_alwaysEmitIntoClient
    public init() {
      self._address = Win32.CriticalSection._allocate()
    }

    deinit {
      system_DeleteCriticalSection(_address)
      _address.deinitialize(count: 1)
      _address.deallocate()
    }
  }
}

@available(System 199, *)
extension Win32.CriticalSection {
  /// Takes the critical section, waiting until no other thread holds it.
  ///
  /// The thread that holds the critical section can take it again.
  ///
  /// The corresponding C function is `EnterCriticalSection`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock() {
    Win32.CriticalSection._enter(_address)
  }

  /// Takes the critical section if no other thread holds it, without
  /// waiting.
  ///
  /// - Returns: Whether the calling thread took the critical section, which
  ///   it does if it holds it already.
  ///
  /// The corresponding C function is `TryEnterCriticalSection`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func tryLock() -> Bool {
    Win32.CriticalSection._tryEnter(_address)
  }

  /// Releases the critical section once.
  ///
  /// A thread that took the critical section more than once holds it until
  /// it releases it as many times. Releasing a critical section that the
  /// calling thread doesn't hold is a programming error, which can make
  /// another thread wait forever.
  ///
  /// The corresponding C function is `LeaveCriticalSection`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func unlock() {
    Win32.CriticalSection._leave(_address)
  }

  /// Takes the critical section, calls a closure, and then releases the
  /// critical section, even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the critical section held.
  /// - Returns: The value that `body` returns.
  ///
  /// The corresponding C functions are `EnterCriticalSection` and
  /// `LeaveCriticalSection`.
  @_alwaysEmitIntoClient
  public func withLock<R: ~Copyable, E: Error>(_ body: () throws(E) -> R) throws(E) -> R {
    Win32.CriticalSection._enter(_address)
    defer { Win32.CriticalSection._leave(_address) }
    return try body()
  }

  /// The address of the C critical section, for Win32 calls that
  /// `CriticalSection` doesn't provide.
  ///
  /// The address is valid only while this critical section is alive.
  @_alwaysEmitIntoClient
  @unsafe
  public var unsafeAddress: UnsafeMutablePointer<CRITICAL_SECTION> { _address }
}

@available(System 199, *)
extension Win32.CriticalSection {
  @usableFromInline
  internal static func _allocate() -> UnsafeMutablePointer<CRITICAL_SECTION> {
    let address = UnsafeMutablePointer<CRITICAL_SECTION>.allocate(capacity: 1)
    address.initialize(to: CRITICAL_SECTION())
    system_InitializeCriticalSection(address)
    return address
  }

  @usableFromInline
  internal static func _enter(_ address: UnsafeMutablePointer<CRITICAL_SECTION>) {
    system_EnterCriticalSection(address)
  }

  @usableFromInline
  internal static func _tryEnter(_ address: UnsafeMutablePointer<CRITICAL_SECTION>) -> Bool {
    system_TryEnterCriticalSection(address)
  }

  @usableFromInline
  internal static func _leave(_ address: UnsafeMutablePointer<CRITICAL_SECTION>) {
    system_LeaveCriticalSection(address)
  }
}

// MARK: - Condition variables

@available(System 199, *)
extension Win32 {
  /// A condition variable, which threads that hold an SRW lock wait on until
  /// another thread wakes them.
  ///
  ///     let job = try lock.withLock { () throws(Win32.Error) -> Job in
  ///       while queue.isEmpty {
  ///         try condition.wait(on: lock)
  ///       }
  ///       return queue.removeFirst()
  ///     }
  ///
  /// `ConditionVariable` can't be copied. Like ``Win32/SRWLock``, it keeps
  /// the C condition variable at one address for its lifetime, and needs no
  /// cleanup. Destroying one that a thread waits on is a programming error,
  /// which this type doesn't detect.
  ///
  /// The corresponding C type is `CONDITION_VARIABLE`.
  @frozen
  public struct ConditionVariable: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<CONDITION_VARIABLE>

    /// Creates a condition variable.
    ///
    /// The corresponding C function is `InitializeConditionVariable`.
    @_alwaysEmitIntoClient
    public init() {
      self._address = Win32.ConditionVariable._allocate()
    }

    deinit {
      _address.deinitialize(count: 1)
      _address.deallocate()
    }
  }
}

@available(System 199, *)
extension Win32.ConditionVariable {
  /// Waits for another thread to wake the calling thread.
  ///
  /// - Parameters:
  ///   - lock: The lock that protects the state the condition describes.
  ///     The calling thread must hold it.
  ///   - shared: Whether the calling thread holds `lock` shared, rather
  ///     than exclusively.
  ///
  /// This method releases the lock while it waits, and takes it again, the
  /// same way, before it returns or throws. The wait can end without a
  /// wake, so check the state again after it returns.
  ///
  /// The corresponding C function is `SleepConditionVariableSRW`, with
  /// `INFINITE`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(on lock: borrowing Win32.SRWLock, shared: Bool = false) throws(Win32.Error) {
    _ = try _wait(lock._address, shared: shared, milliseconds: _INFINITE).get()
  }

  /// Waits for another thread to wake the calling thread, for at most a
  /// duration.
  ///
  /// - Parameters:
  ///   - lock: The lock that protects the state the condition describes.
  ///     The calling thread must hold it.
  ///   - shared: Whether the calling thread holds `lock` shared, rather
  ///     than exclusively.
  ///   - timeout: How long to wait. A positive duration rounds up to a
  ///     whole millisecond.
  /// - Returns: `false` if the time-out elapsed, or `true` if the wait ended
  ///   for another reason: a wake, or a spurious wake-up.
  ///
  /// This method releases the lock while it waits, and takes it again, the
  /// same way, before it returns or throws. A time-out longer than
  /// `SleepConditionVariableSRW` takes, just under 50 days, ends early, as
  /// a spurious wake-up.
  ///
  /// The corresponding C function is `SleepConditionVariableSRW`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(
    on lock: borrowing Win32.SRWLock, shared: Bool = false, timeout: Duration
  ) throws(Win32.Error) -> Bool {
    try _wait(lock._address, shared: shared, timeout: timeout).get()
  }

  /// Waits for another thread to wake the calling thread, releasing a
  /// critical section while it waits.
  ///
  /// - Parameter criticalSection: The critical section that protects the
  ///   state the condition describes. The calling thread must hold it, and
  ///   only once: a critical section taken more than once stays held while
  ///   the thread waits, so the thread that would wake it can't take it.
  ///
  /// This method takes the critical section again before it returns or
  /// throws. The wait can end without a wake, so check the state again
  /// after it returns.
  ///
  /// The corresponding C function is `SleepConditionVariableCS`, with
  /// `INFINITE`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(on criticalSection: borrowing Win32.CriticalSection) throws(Win32.Error) {
    _ = try _wait(criticalSection._address, milliseconds: _INFINITE).get()
  }

  /// Waits for another thread to wake the calling thread, for at most a
  /// duration, releasing a critical section while it waits.
  ///
  /// - Parameters:
  ///   - criticalSection: The critical section that protects the state the
  ///     condition describes, which the calling thread must hold once. See
  ///     ``wait(on:)-(Win32.CriticalSection)``.
  ///   - timeout: How long to wait. A positive duration rounds up to a
  ///     whole millisecond.
  /// - Returns: `false` if the time-out elapsed, or `true` if the wait ended
  ///   for another reason: a wake, or a spurious wake-up.
  ///
  /// A time-out longer than `SleepConditionVariableCS` takes, just under 50
  /// days, ends early, as a spurious wake-up.
  ///
  /// The corresponding C function is `SleepConditionVariableCS`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(
    on criticalSection: borrowing Win32.CriticalSection, timeout: Duration
  ) throws(Win32.Error) -> Bool {
    try _wait(criticalSection._address, timeout: timeout).get()
  }

  /// Wakes one of the threads waiting on the condition variable, if there
  /// are any.
  ///
  /// Call this method with or without the lock held.
  ///
  /// The corresponding C function is `WakeConditionVariable`.
  @_alwaysEmitIntoClient
  public func wake() {
    Win32.ConditionVariable._wake(_address, all: false)
  }

  /// Wakes all the threads waiting on the condition variable.
  ///
  /// The corresponding C function is `WakeAllConditionVariable`.
  @_alwaysEmitIntoClient
  public func wakeAll() {
    Win32.ConditionVariable._wake(_address, all: true)
  }

  /// The address of the C condition variable, for Win32 calls that
  /// `ConditionVariable` doesn't provide.
  ///
  /// The address is valid only while this condition variable is alive.
  @_alwaysEmitIntoClient
  @unsafe
  public var unsafeAddress: UnsafeMutablePointer<CONDITION_VARIABLE> { _address }
}

@available(System 199, *)
extension Win32.ConditionVariable {
  @usableFromInline
  internal static func _allocate() -> UnsafeMutablePointer<CONDITION_VARIABLE> {
    let address = UnsafeMutablePointer<CONDITION_VARIABLE>.allocate(capacity: 1)
    address.initialize(to: CONDITION_VARIABLE())
    system_InitializeConditionVariable(address)
    return address
  }

  @usableFromInline
  internal func _wait(
    _ lock: UnsafeMutablePointer<SRWLOCK>, shared: Bool, timeout: Duration
  ) -> Result<Bool, Win32.Error> {
    let milliseconds = _win32Milliseconds(roundingUp: timeout)
    // INFINITE is DWORD.max, so a bounded wait takes one less at most, and a
    // longer one reports its early end as a spurious wake-up.
    guard milliseconds <= UInt64(_INFINITE - 1) else {
      return _wait(lock, shared: shared, milliseconds: _INFINITE - 1).map { _ in true }
    }
    return _wait(lock, shared: shared, milliseconds: DWORD(milliseconds))
  }

  @usableFromInline
  internal func _wait(
    _ lock: UnsafeMutablePointer<SRWLOCK>, shared: Bool, milliseconds: DWORD
  ) -> Result<Bool, Win32.Error> {
    guard system_SleepConditionVariableSRW(
      _address, lock, milliseconds, shared ? _CONDITION_VARIABLE_LOCKMODE_SHARED : 0
    ) else {
      let error = Win32.Error(GetLastError())
      // The lock is held again either way.
      guard error.rawValue != _ERROR_TIMEOUT else { return .success(false) }
      return .failure(error)
    }
    return .success(true)
  }

  @usableFromInline
  internal func _wait(
    _ criticalSection: UnsafeMutablePointer<CRITICAL_SECTION>, timeout: Duration
  ) -> Result<Bool, Win32.Error> {
    let milliseconds = _win32Milliseconds(roundingUp: timeout)
    // As for an SRW lock's wait.
    guard milliseconds <= UInt64(_INFINITE - 1) else {
      return _wait(criticalSection, milliseconds: _INFINITE - 1).map { _ in true }
    }
    return _wait(criticalSection, milliseconds: DWORD(milliseconds))
  }

  @usableFromInline
  internal func _wait(
    _ criticalSection: UnsafeMutablePointer<CRITICAL_SECTION>, milliseconds: DWORD
  ) -> Result<Bool, Win32.Error> {
    guard system_SleepConditionVariableCS(_address, criticalSection, milliseconds) else {
      let error = Win32.Error(GetLastError())
      // The critical section is held again either way.
      guard error.rawValue != _ERROR_TIMEOUT else { return .success(false) }
      return .failure(error)
    }
    return .success(true)
  }

  @usableFromInline
  internal static func _wake(_ address: UnsafeMutablePointer<CONDITION_VARIABLE>, all: Bool) {
    if all {
      system_WakeAllConditionVariable(address)
    } else {
      system_WakeConditionVariable(address)
    }
  }
}

#endif // os(Windows)
