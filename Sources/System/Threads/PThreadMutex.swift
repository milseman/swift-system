/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

@available(System 199, *)
extension PThread {
  /// A mutual exclusion lock.
  ///
  /// A mutex lets one thread at a time into a critical section:
  ///
  ///     let mutex = try PThread.Mutex()
  ///     try mutex.withLock {
  ///       queue.append(job)
  ///     }
  ///
  /// To protect a value within one process,
  /// prefer the standard library's `Synchronization.Mutex`,
  /// which needs no error handling.
  /// Use this type where you need a pthread mutex specifically:
  /// to wait on a ``PThread/Condition``,
  /// for a recursive, error-checking, robust, or process-shared mutex,
  /// or to share a mutex with C code.
  ///
  /// `Mutex` can't be copied. It keeps the C mutex at one address
  /// from its creation until its destruction, as POSIX requires,
  /// so moving a `Mutex` doesn't move the C mutex.
  /// Destroying a `Mutex` destroys the C mutex.
  /// Destroying a locked mutex is a programming error,
  /// which this type doesn't detect.
  ///
  /// The corresponding C type is `pthread_mutex_t`.
  @frozen
  public struct Mutex: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<CInterop.PThreadMutex>

    // Whether the storage was allocated by this type, rather than provided
    // by the caller of init(unsafeUninitializedAddress:attributes:).
    @usableFromInline
    internal let _deallocates: Bool

    /// Creates a mutex.
    ///
    /// - Parameter attributes: The kind of mutex to create.
    ///   The default attributes create a mutex of the ``Kind-swift.struct/default`` kind,
    ///   private to this process.
    ///
    /// The corresponding C function is `pthread_mutex_init`.
    @_alwaysEmitIntoClient
    public init(attributes: Attributes = Attributes()) throws(Errno) {
      self._address = try Mutex._allocate(attributes).get()
      self._deallocates = true
    }

    /// Creates a mutex in memory that the caller provides,
    /// such as memory shared with other processes.
    ///
    /// - Parameters:
    ///   - address: The memory for the C mutex.
    ///     It must be uninitialized, or hold a destroyed mutex,
    ///     and must stay allocated at this address,
    ///     without being moved or reused,
    ///     until the `Mutex` instance is destroyed.
    ///   - attributes: The kind of mutex to create.
    ///
    /// Destroying the `Mutex` destroys the C mutex,
    /// but doesn't deallocate the memory.
    ///
    /// The corresponding C function is `pthread_mutex_init`.
    @_alwaysEmitIntoClient
    public init(
      unsafeUninitializedAddress address: UnsafeMutablePointer<CInterop.PThreadMutex>,
      attributes: Attributes = Attributes()
    ) throws(Errno) {
      try Mutex._initialize(address, attributes).get()
      self._address = address
      self._deallocates = false
    }

    // A mutex that another owner, such as C code, initialized and destroys.
    @_alwaysEmitIntoClient
    internal init(_borrowing address: UnsafeMutablePointer<CInterop.PThreadMutex>) {
      self._address = address
      self._deallocates = false
    }

    deinit {
      // deinit can't throw, so an error is dropped. The only one is EBUSY,
      // for a mutex that's still locked, which is a programming error.
      _ = system_pthread_mutex_destroy(_address)
      if _deallocates {
        _address.deallocate()
      }
    }
  }
}

// MARK: - Locking

@available(System 199, *)
extension PThread.Mutex {
  /// Locks the mutex, waiting until it's available.
  ///
  /// Locking a mutex that the calling thread already holds
  /// waits forever for a ``Kind-swift.struct/normal`` mutex,
  /// throws ``Errno/deadlock`` for an ``Kind-swift.struct/errorChecking`` one,
  /// and succeeds for a ``Kind-swift.struct/recursive`` one,
  /// which must then be unlocked once for each lock.
  ///
  /// A robust mutex whose previous owner ended without unlocking it
  /// throws ``Errno/previousOwnerDied``,
  /// with the mutex locked by the calling thread.
  /// Repair the state that the mutex protects,
  /// then call ``markConsistent()`` before unlocking it.
  ///
  /// The corresponding C function is `pthread_mutex_lock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock() throws(Errno) {
    try _lock().get()
  }

  @usableFromInline
  internal func _lock() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_mutex_lock(_address)
    }
  }

  /// Locks the mutex if it's available, without waiting.
  ///
  /// - Returns: `true` if the calling thread locked the mutex,
  ///   or `false` if another thread holds it.
  ///
  /// The corresponding C function is `pthread_mutex_trylock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func tryLock() throws(Errno) -> Bool {
    try _tryLock().get()
  }

  @usableFromInline
  internal func _tryLock() -> Result<Bool, Errno> {
    switch nothingOrReturnedErrno(retryOnInterrupt: false, {
      system_pthread_mutex_trylock(_address)
    }) {
    case .success: return .success(true)
    case .failure(.resourceBusy): return .success(false)
    case .failure(let error): return .failure(error)
    }
  }

  /// Unlocks the mutex.
  ///
  /// Only the thread that locked the mutex can unlock it.
  /// Unlocking a mutex that the calling thread doesn't hold
  /// throws ``Errno/notPermitted`` for an error-checking, recursive,
  /// or robust mutex, and is undefined behavior otherwise.
  ///
  /// The corresponding C function is `pthread_mutex_unlock`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func unlock() throws(Errno) {
    try _unlock().get()
  }

  @usableFromInline
  internal func _unlock() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_mutex_unlock(_address)
    }
  }

  /// Locks the mutex, calls a closure, and then unlocks the mutex,
  /// even if the closure throws.
  ///
  /// - Parameter body: The closure to call with the mutex locked.
  /// - Returns: The value that `body` returns.
  ///
  /// If locking the mutex throws, this method doesn't call `body`.
  /// If `body` throws, this method unlocks the mutex and rethrows the error,
  /// dropping any error from unlocking.
  /// Otherwise it throws any error from unlocking.
  ///
  /// The corresponding C functions are `pthread_mutex_lock`
  /// and `pthread_mutex_unlock`.
  @_alwaysEmitIntoClient
  public func withLock<R: ~Copyable>(_ body: () throws -> R) throws -> R {
    try _lock().get()
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

  #if !SYSTEM_PACKAGE_DARWIN
  /// Locks the mutex, waiting until it's available or a deadline passes.
  ///
  /// - Parameter deadline: The time to stop waiting,
  ///   as a time since the Epoch on the `CLOCK_REALTIME` clock.
  /// - Returns: `true` if the calling thread locked the mutex,
  ///   or `false` if the deadline passed first.
  ///
  /// The corresponding C function is `pthread_mutex_timedlock`.
  /// - Note: Not available on Darwin.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use withLock(_:), which can't hold the lock across a suspension point")
  public func lock(until deadline: timespec) throws(Errno) -> Bool {
    try _lock(until: deadline).get()
  }

  @usableFromInline
  internal func _lock(until deadline: timespec) -> Result<Bool, Errno> {
    var deadline = deadline
    switch nothingOrReturnedErrno(retryOnInterrupt: false, {
      system_pthread_mutex_timedlock(_address, &deadline)
    }) {
    case .success: return .success(true)
    case .failure(.timedOut): return .success(false)
    case .failure(let error): return .failure(error)
    }
  }
  #endif // !SYSTEM_PACKAGE_DARWIN

  #if os(Linux) || os(FreeBSD)
  /// Marks the state that a robust mutex protects as consistent again,
  /// after its previous owner ended without unlocking it.
  ///
  /// Call this method while holding the mutex,
  /// after ``lock()`` throws ``Errno/previousOwnerDied``.
  /// If the mutex is unlocked without it,
  /// the mutex can never be locked again,
  /// and locking it throws ``Errno/notRecoverable``.
  ///
  /// The corresponding C function is `pthread_mutex_consistent`.
  /// - Note: Only available on Linux and FreeBSD.
  @_alwaysEmitIntoClient
  public func markConsistent() throws(Errno) {
    try _markConsistent().get()
  }

  @usableFromInline
  internal func _markConsistent() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_mutex_consistent(_address)
    }
  }
  #endif // os(Linux) || os(FreeBSD)

  #if !os(Android)
  /// The priority ceiling of a mutex
  /// with the ``PriorityProtocol-swift.struct/protect`` protocol.
  ///
  /// The corresponding C function is `pthread_mutex_getprioceiling`.
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public func priorityCeiling() throws(Errno) -> CInt {
    try _priorityCeiling().get()
  }

  @usableFromInline
  internal func _priorityCeiling() -> Result<CInt, Errno> {
    var ceiling: CInt = 0
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_mutex_getprioceiling(_address, &ceiling)
    }.map { ceiling }
  }

  /// Changes the priority ceiling of a mutex
  /// with the ``PriorityProtocol-swift.struct/protect`` protocol,
  /// locking it to do so.
  ///
  /// - Parameter ceiling: The new priority ceiling.
  /// - Returns: The previous priority ceiling.
  ///
  /// The corresponding C function is `pthread_mutex_setprioceiling`.
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  @discardableResult
  @available(*, noasync, message: "Changing the priority ceiling locks the mutex")
  public func setPriorityCeiling(_ ceiling: CInt) throws(Errno) -> CInt {
    try _setPriorityCeiling(ceiling).get()
  }

  @usableFromInline
  internal func _setPriorityCeiling(_ ceiling: CInt) -> Result<CInt, Errno> {
    var oldCeiling: CInt = 0
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_mutex_setprioceiling(_address, ceiling, &oldCeiling)
    }.map { oldCeiling }
  }
  #endif // !os(Android)
}

// MARK: - C interoperation

@available(System 199, *)
extension PThread.Mutex {
  /// The address of the C mutex, for passing to C functions.
  ///
  /// The address is valid while this `Mutex` instance is alive,
  /// and doesn't change when the instance moves.
  /// Don't destroy the C mutex through it.
  @_alwaysEmitIntoClient
  public var unsafeAddress: UnsafeMutablePointer<CInterop.PThreadMutex> { _address }

  /// Calls a closure with a mutex that other code, such as a C library,
  /// initialized and will destroy.
  ///
  /// - Parameters:
  ///   - address: The address of an initialized C mutex.
  ///     It must stay initialized until `body` returns.
  ///   - body: A closure that uses the mutex.
  ///     The mutex is valid only for the duration of the call.
  /// - Returns: The value that `body` returns.
  ///
  /// The `Mutex` instance that `body` borrows doesn't own the C mutex:
  /// when `body` returns, the C mutex isn't destroyed.
  @_alwaysEmitIntoClient
  public static func withUnsafeMutex<R: ~Copyable>(
    at address: UnsafeMutablePointer<CInterop.PThreadMutex>,
    _ body: (borrowing PThread.Mutex) throws -> R
  ) rethrows -> R {
    let mutex = PThread.Mutex(_borrowing: address)
    do {
      let result = try body(mutex)
      mutex._forget()
      return result
    } catch {
      mutex._forget()
      throw error
    }
  }

  // Ends a borrowed instance's lifetime without destroying the C mutex.
  @_alwaysEmitIntoClient
  internal consuming func _forget() {
    discard self
  }
}

// MARK: - Implementation

@available(System 199, *)
extension PThread.Mutex {
  @usableFromInline
  internal static func _allocate(
    _ attributes: Attributes
  ) -> Result<UnsafeMutablePointer<CInterop.PThreadMutex>, Errno> {
    let address = UnsafeMutablePointer<CInterop.PThreadMutex>.allocate(capacity: 1)
    if case .failure(let error) = _initialize(address, attributes) {
      address.deallocate()
      return .failure(error)
    }
    return .success(address)
  }

  @usableFromInline
  internal static func _initialize(
    _ address: UnsafeMutablePointer<CInterop.PThreadMutex>, _ attributes: Attributes
  ) -> Result<(), Errno> {
    attributes._withUnsafeAttributes { attributes in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_mutex_init(address, attributes)
      }
    }
  }
}

// MARK: - Attributes

@available(System 199, *)
extension PThread.Mutex {
  /// The kind of a mutex, and how it's shared.
  ///
  /// The default attributes describe a mutex
  /// of the ``Kind-swift.struct/default`` kind,
  /// with no priority protocol,
  /// that's private to the process.
  ///
  /// The corresponding C type is `pthread_mutexattr_t`.
  @frozen
  public struct Attributes: Hashable, Sendable {
    /// How the mutex treats relocking and unlocking errors.
    ///
    /// The corresponding C function is `pthread_mutexattr_settype`.
    public var kind: Kind

    /// Whether threads in other processes can use the mutex,
    /// if it's in memory that they share.
    ///
    /// A process-shared mutex must be created in shared memory,
    /// with ``PThread/Mutex/init(unsafeUninitializedAddress:attributes:)``.
    ///
    /// The corresponding C function is `pthread_mutexattr_setpshared`,
    /// with `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.
    public var isProcessShared: Bool

    #if !os(Android)
    /// How holding the mutex affects the priority of the thread that holds it.
    ///
    /// The corresponding C function is `pthread_mutexattr_setprotocol`.
    /// - Note: Not available on Android.
    public var priorityProtocol: PriorityProtocol

    /// The priority that a thread holding the mutex runs at,
    /// for the ``PriorityProtocol-swift.struct/protect`` protocol,
    /// or `nil` for the system's default.
    ///
    /// The corresponding C function is `pthread_mutexattr_setprioceiling`.
    /// - Note: Not available on Android.
    public var priorityCeiling: CInt?
    #endif

    #if os(Linux) || os(FreeBSD)
    /// Whether the mutex is robust:
    /// whether the next thread to lock it learns
    /// that its previous owner ended while holding it,
    /// rather than waiting forever.
    ///
    /// See ``PThread/Mutex/lock()`` and ``PThread/Mutex/markConsistent()``.
    ///
    /// The corresponding C function is `pthread_mutexattr_setrobust`,
    /// with `PTHREAD_MUTEX_ROBUST` or `PTHREAD_MUTEX_STALLED`.
    /// - Note: Only available on Linux and FreeBSD.
    public var isRobust: Bool
    #endif

    /// Creates mutex attributes.
    @_alwaysEmitIntoClient
    public init(kind: Kind = .default, isProcessShared: Bool = false) {
      self.kind = kind
      self.isProcessShared = isProcessShared
      #if !os(Android)
      self.priorityProtocol = .none
      self.priorityCeiling = nil
      #endif
      #if os(Linux) || os(FreeBSD)
      self.isRobust = false
      #endif
    }
  }

  /// How a mutex treats relocking and unlocking errors.
  @frozen
  public struct Kind: RawRepresentable, Hashable, Sendable {
    /// The raw C mutex type.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed mutex kind from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// A mutex that doesn't check for errors.
    ///
    /// Relocking it from the thread that holds it waits forever,
    /// and unlocking it from another thread is undefined behavior.
    ///
    /// The corresponding C constant is `PTHREAD_MUTEX_NORMAL`.
    @_alwaysEmitIntoClient
    public static var normal: Self { Self(rawValue: _PTHREAD_MUTEX_NORMAL) }

    /// A mutex that reports relocking and unlocking errors.
    ///
    /// Relocking it from the thread that holds it throws
    /// ``Errno/deadlock``, and unlocking it from a thread that doesn't hold it
    /// throws ``Errno/notPermitted``.
    ///
    /// The corresponding C constant is `PTHREAD_MUTEX_ERRORCHECK`.
    @_alwaysEmitIntoClient
    public static var errorChecking: Self { Self(rawValue: _PTHREAD_MUTEX_ERRORCHECK) }

    /// A mutex that the thread holding it can lock again.
    ///
    /// The mutex is released when the thread unlocks it
    /// once for each time it locked it.
    ///
    /// The corresponding C constant is `PTHREAD_MUTEX_RECURSIVE`.
    @_alwaysEmitIntoClient
    public static var recursive: Self { Self(rawValue: _PTHREAD_MUTEX_RECURSIVE) }

    /// The system's default kind of mutex,
    /// which is ``normal`` on Darwin and Linux.
    ///
    /// The corresponding C constant is `PTHREAD_MUTEX_DEFAULT`.
    @_alwaysEmitIntoClient
    public static var `default`: Self { Self(rawValue: _PTHREAD_MUTEX_DEFAULT) }
  }

  #if !os(Android)
  /// How holding a mutex affects the priority of the thread that holds it.
  @frozen
  public struct PriorityProtocol: RawRepresentable, Hashable, Sendable {
    /// The raw C priority protocol.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed priority protocol from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Holding the mutex doesn't change the thread's priority.
    ///
    /// The corresponding C constant is `PTHREAD_PRIO_NONE`.
    @_alwaysEmitIntoClient
    public static var none: Self { Self(rawValue: _PTHREAD_PRIO_NONE) }

    /// A thread holding the mutex runs at the highest priority
    /// of the threads waiting for it.
    ///
    /// The corresponding C constant is `PTHREAD_PRIO_INHERIT`.
    @_alwaysEmitIntoClient
    public static var inherit: Self { Self(rawValue: _PTHREAD_PRIO_INHERIT) }

    /// A thread holding the mutex runs at the mutex's priority ceiling.
    ///
    /// The corresponding C constant is `PTHREAD_PRIO_PROTECT`.
    @_alwaysEmitIntoClient
    public static var protect: Self { Self(rawValue: _PTHREAD_PRIO_PROTECT) }
  }
  #endif // !os(Android)
}

@available(System 199, *)
extension PThread.Mutex.Attributes {
  // Calls `body` with the C attributes, or with nil for the default
  // attributes, so that pthread_mutex_init applies its own defaults.
  internal func _withUnsafeAttributes<R>(
    _ body: (UnsafePointer<_PThreadMutexAttrStorage>?) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    guard self != PThread.Mutex.Attributes() else { return body(nil) }
    var attributes = _pthreadMutexAttrZero
    return withUnsafeMutablePointer(to: &attributes) { attributes in
      if let error = _pthreadError(system_pthread_mutexattr_init(attributes)) {
        return .failure(error)
      }
      defer { _ = system_pthread_mutexattr_destroy(attributes) }
      if let error = _apply(to: attributes) {
        return .failure(error)
      }
      return body(attributes)
    }
  }

  private func _apply(to attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>) -> Errno? {
    if let error = _pthreadError(system_pthread_mutexattr_settype(attributes, kind.rawValue)) {
      return error
    }
    let shared = isProcessShared ? _PTHREAD_PROCESS_SHARED : _PTHREAD_PROCESS_PRIVATE
    if let error = _pthreadError(system_pthread_mutexattr_setpshared(attributes, shared)) {
      return error
    }
    #if !os(Android)
    if priorityProtocol != .none {
      if let error = _pthreadError(
        system_pthread_mutexattr_setprotocol(attributes, priorityProtocol.rawValue)
      ) {
        return error
      }
    }
    if let priorityCeiling {
      if let error = _pthreadError(
        system_pthread_mutexattr_setprioceiling(attributes, priorityCeiling)
      ) {
        return error
      }
    }
    #endif
    #if os(Linux) || os(FreeBSD)
    if isRobust {
      if let error = _pthreadError(
        system_pthread_mutexattr_setrobust(attributes, _PTHREAD_MUTEX_ROBUST)
      ) {
        return error
      }
    }
    #endif
    return nil
  }
}

#endif // !os(Windows) && !os(WASI)
