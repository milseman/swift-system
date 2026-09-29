/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension PThread {
  /// A lock that any number of readers can hold at once,
  /// or one writer alone.
  ///
  ///     let lock = try PThread.ReadWriteLock()
  ///     let value = try lock.withLockForReading { table[key] }
  ///     try lock.withLockForWriting { table[key] = newValue }
  ///
  /// Whether a waiting writer keeps new readers out
  /// depends on the platform.
  ///
  /// `ReadWriteLock` can't be copied. It keeps the C lock at one address
  /// from its creation until its destruction, as POSIX requires.
  /// Destroying a `ReadWriteLock` destroys the C lock;
  /// the corresponding C function is `pthread_rwlock_destroy`.
  /// Destroying a lock that a thread holds is a programming error,
  /// which this type doesn't detect.
  ///
  /// The corresponding C type is `pthread_rwlock_t`.
  @frozen
  public struct ReadWriteLock: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<CInterop.PThreadReadWriteLock>

    @usableFromInline
    internal let _deallocates: Bool

    /// Creates a read-write lock.
    ///
    /// - Parameter attributes: How the lock is shared.
    ///
    /// The corresponding C function is `pthread_rwlock_init`.
    @_alwaysEmitIntoClient
    public init(attributes: Attributes = Attributes()) throws(Errno) {
      self._address = try ReadWriteLock._allocate(attributes).get()
      self._deallocates = true
    }

    /// Creates a read-write lock in memory that the caller provides,
    /// such as memory shared with other processes.
    ///
    /// - Parameters:
    ///   - address: The memory for the C lock.
    ///     It must be uninitialized, or hold a destroyed lock,
    ///     and must stay allocated at this address,
    ///     without being moved or reused,
    ///     until the `ReadWriteLock` instance is destroyed.
    ///   - attributes: How the lock is shared.
    ///
    /// Destroying the `ReadWriteLock` destroys the C lock,
    /// but doesn't deallocate the memory.
    ///
    /// The corresponding C function is `pthread_rwlock_init`.
    @_alwaysEmitIntoClient
    public init(
      unsafeUninitializedAddress address: UnsafeMutablePointer<CInterop.PThreadReadWriteLock>,
      attributes: Attributes = Attributes()
    ) throws(Errno) {
      try ReadWriteLock._initialize(address, attributes).get()
      self._address = address
      self._deallocates = false
    }

    @_alwaysEmitIntoClient
    internal init(_borrowing address: UnsafeMutablePointer<CInterop.PThreadReadWriteLock>) {
      self._address = address
      self._deallocates = false
    }

    deinit {
      // deinit can't throw, so an error is dropped. The only one is EBUSY,
      // for a lock that a thread holds.
      _ = system_pthread_rwlock_destroy(_address)
      if _deallocates {
        _address.deallocate()
      }
    }
  }
}

// MARK: - Locking

@available(System 199, *)
extension PThread.ReadWriteLock {
  /// Locks the lock for reading, waiting while a writer holds it.
  ///
  /// A thread that already holds the lock for writing
  /// can't also lock it for reading:
  /// this method waits forever or throws ``Errno/deadlock``,
  /// depending on the platform.
  ///
  /// The corresponding C function is `pthread_rwlock_rdlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLockForReading(_:), which can't hold the lock across a suspension point")
  public func lockForReading() throws(Errno) {
    try _lockForReading().get()
  }

  @usableFromInline
  internal func _lockForReading() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_rwlock_rdlock(_address)
    }
  }

  /// Locks the lock for reading if no writer holds it, without waiting.
  ///
  /// - Returns: `true` if the calling thread locked the lock,
  ///   or `false` if a writer holds it.
  ///
  /// The corresponding C function is `pthread_rwlock_tryrdlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLockForReading(_:), which can't hold the lock across a suspension point")
  public func tryLockForReading() throws(Errno) -> Bool {
    try _tryLockForReading().get()
  }

  @usableFromInline
  internal func _tryLockForReading() -> Result<Bool, Errno> {
    PThread.ReadWriteLock._busyAsFalse(
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_rwlock_tryrdlock(_address)
      })
  }

  /// Locks the lock for writing, waiting while any thread holds it.
  ///
  /// The corresponding C function is `pthread_rwlock_wrlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLockForWriting(_:), which can't hold the lock across a suspension point")
  public func lockForWriting() throws(Errno) {
    try _lockForWriting().get()
  }

  @usableFromInline
  internal func _lockForWriting() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_rwlock_wrlock(_address)
    }
  }

  /// Locks the lock for writing if no thread holds it, without waiting.
  ///
  /// - Returns: `true` if the calling thread locked the lock,
  ///   or `false` if another thread holds it.
  ///
  /// The corresponding C function is `pthread_rwlock_trywrlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLockForWriting(_:), which can't hold the lock across a suspension point")
  public func tryLockForWriting() throws(Errno) -> Bool {
    try _tryLockForWriting().get()
  }

  @usableFromInline
  internal func _tryLockForWriting() -> Result<Bool, Errno> {
    PThread.ReadWriteLock._busyAsFalse(
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_rwlock_trywrlock(_address)
      })
  }

  /// Unlocks the lock, which the calling thread holds
  /// for reading or for writing.
  ///
  /// The corresponding C function is `pthread_rwlock_unlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLockForReading(_:) or withLockForWriting(_:), which can't hold the lock across a suspension point")
  public func unlock() throws(Errno) {
    try _unlock().get()
  }

  @usableFromInline
  internal func _unlock() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_rwlock_unlock(_address)
    }
  }

  /// Locks the lock for reading, calls a closure,
  /// and then unlocks the lock, even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the lock held for reading.
  /// - Returns: The value that `body` returns.
  ///
  /// Errors are handled as ``PThread/Mutex/withLock(_:)`` handles them.
  ///
  /// The corresponding C functions are `pthread_rwlock_rdlock`
  /// and `pthread_rwlock_unlock`.
  @_alwaysEmitIntoClient
  public func withLockForReading<R: ~Copyable>(_ body: () throws -> R) throws -> R {
    try _lockForReading().get()
    return try _unlocking(after: body)
  }

  /// Locks the lock for writing, calls a closure,
  /// and then unlocks the lock, even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the lock held for writing.
  /// - Returns: The value that `body` returns.
  ///
  /// Errors are handled as ``PThread/Mutex/withLock(_:)`` handles them.
  ///
  /// The corresponding C functions are `pthread_rwlock_wrlock`
  /// and `pthread_rwlock_unlock`.
  @_alwaysEmitIntoClient
  public func withLockForWriting<R: ~Copyable>(_ body: () throws -> R) throws -> R {
    try _lockForWriting().get()
    return try _unlocking(after: body)
  }

  @_alwaysEmitIntoClient
  internal func _unlocking<R: ~Copyable>(after body: () throws -> R) throws -> R {
    let result: R
    do {
      result = try body()
    } catch {
      _ = _unlock()
      throw error
    }
    try _unlock().get()
    return result
  }

  @usableFromInline
  internal static func _busyAsFalse(_ result: Result<(), Errno>) -> Result<Bool, Errno> {
    switch result {
    case .success: return .success(true)
    case .failure(.resourceBusy): return .success(false)
    case .failure(let error): return .failure(error)
    }
  }
}

// MARK: - C interoperation

@available(System 199, *)
extension PThread.ReadWriteLock {
  /// The address of the C lock, for passing to C functions.
  ///
  /// The address is valid while this `ReadWriteLock` instance is alive,
  /// and doesn't change when the instance moves.
  /// Don't destroy the C lock through it.
  @_alwaysEmitIntoClient
  public var unsafeAddress: UnsafeMutablePointer<CInterop.PThreadReadWriteLock> { _address }

  /// Calls a closure with a read-write lock that other code,
  /// such as a C library, initialized and will destroy.
  ///
  /// - Parameters:
  ///   - address: The address of an initialized C lock.
  ///     It must stay initialized until `body` returns.
  ///   - body: A closure that uses the lock.
  ///     The lock is valid only for the duration of the call.
  /// - Returns: The value that `body` returns.
  ///
  /// The `ReadWriteLock` instance that `body` borrows doesn't own the C lock:
  /// when `body` returns, the C lock isn't destroyed.
  @_alwaysEmitIntoClient
  public static func withUnsafeReadWriteLock<R: ~Copyable>(
    at address: UnsafeMutablePointer<CInterop.PThreadReadWriteLock>,
    _ body: (borrowing PThread.ReadWriteLock) throws -> R
  ) rethrows -> R {
    let lock = PThread.ReadWriteLock(_borrowing: address)
    do {
      let result = try body(lock)
      lock._forget()
      return result
    } catch {
      lock._forget()
      throw error
    }
  }

  @_alwaysEmitIntoClient
  internal consuming func _forget() {
    discard self
  }
}

// MARK: - Implementation

@available(System 199, *)
extension PThread.ReadWriteLock {
  @usableFromInline
  internal static func _allocate(
    _ attributes: Attributes
  ) -> Result<UnsafeMutablePointer<CInterop.PThreadReadWriteLock>, Errno> {
    let address = UnsafeMutablePointer<CInterop.PThreadReadWriteLock>.allocate(capacity: 1)
    if case .failure(let error) = _initialize(address, attributes) {
      address.deallocate()
      return .failure(error)
    }
    return .success(address)
  }

  @usableFromInline
  internal static func _initialize(
    _ address: UnsafeMutablePointer<CInterop.PThreadReadWriteLock>, _ attributes: Attributes
  ) -> Result<(), Errno> {
    attributes._withUnsafeAttributes { attributes in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_rwlock_init(address, attributes)
      }
    }
  }
}

// MARK: - Attributes

@available(System 199, *)
extension PThread.ReadWriteLock {
  /// How a read-write lock is shared.
  ///
  /// Creating a read-write lock makes C attributes from these;
  /// the corresponding C functions are `pthread_rwlockattr_init`
  /// and `pthread_rwlockattr_destroy`.
  ///
  /// The corresponding C type is `pthread_rwlockattr_t`.
  @frozen
  public struct Attributes: Hashable, Sendable {
    /// Whether threads in other processes can use the lock,
    /// if it's in memory that they share.
    ///
    /// A process-shared lock must be created in shared memory, with
    /// ``PThread/ReadWriteLock/init(unsafeUninitializedAddress:attributes:)``.
    ///
    /// The corresponding C function is `pthread_rwlockattr_setpshared`,
    /// with `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.
    public var isProcessShared: Bool

    /// Creates read-write lock attributes.
    @_alwaysEmitIntoClient
    public init(isProcessShared: Bool = false) {
      self.isProcessShared = isProcessShared
    }
  }
}

@available(System 199, *)
extension PThread.ReadWriteLock.Attributes {
  internal func _withUnsafeAttributes<R>(
    _ body: (UnsafePointer<_PThreadRWLockAttrStorage>?) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    guard isProcessShared else { return body(nil) }
    var attributes = _pthreadRWLockAttrZero
    return withUnsafeMutablePointer(to: &attributes) { attributes in
      if let error = _pthreadError(system_pthread_rwlockattr_init(attributes)) {
        return .failure(error)
      }
      defer { _ = system_pthread_rwlockattr_destroy(attributes) }
      if let error = _pthreadError(
        system_pthread_rwlockattr_setpshared(attributes, _PTHREAD_PROCESS_SHARED)
      ) {
        return .failure(error)
      }
      return body(attributes)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
