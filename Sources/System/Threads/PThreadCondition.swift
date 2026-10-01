/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && (!os(WASI) || _runtime(_multithreaded))

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
import wasi_pthread
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension PThread {
  /// A condition variable, which threads wait on for a change
  /// to state that a mutex protects.
  ///
  /// A thread waits while holding the mutex,
  /// and the wait releases it until the condition is signaled.
  /// Waits can end without a signal, so wait in a loop
  /// that checks the state:
  ///
  ///     try mutex.withLock {
  ///       while queue.isEmpty {
  ///         try workAvailable.wait(on: mutex)
  ///       }
  ///       job = queue.removeFirst()
  ///     }
  ///
  /// `Condition` can't be copied. It keeps the C condition variable
  /// at one address from its creation until its destruction,
  /// as POSIX requires.
  /// Destroying a `Condition` destroys the C condition variable;
  /// the corresponding C function is `pthread_cond_destroy`.
  /// Destroying a condition variable that threads are waiting on
  /// is a programming error, which this type doesn't detect.
  ///
  /// The corresponding C type is `pthread_cond_t`.
  @frozen
  public struct Condition: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _address: UnsafeMutablePointer<CInterop.PThreadCondition>

    @usableFromInline
    internal let _deallocates: Bool

    /// Creates a condition variable.
    ///
    /// - Parameter attributes: How the condition variable is shared,
    ///   and on platforms other than Darwin,
    ///   which clock its deadlines use.
    ///
    /// The corresponding C function is `pthread_cond_init`.
    @_alwaysEmitIntoClient
    public init(attributes: Attributes = Attributes()) throws(Errno) {
      self._address = try Condition._allocate(attributes).get()
      self._deallocates = true
    }

    /// Creates a condition variable in memory that the caller provides,
    /// such as memory shared with other processes.
    ///
    /// - Parameters:
    ///   - address: The memory for the C condition variable.
    ///     It must be uninitialized, or hold a destroyed condition variable,
    ///     and must stay allocated at this address,
    ///     without being moved or reused,
    ///     until the `Condition` instance is destroyed.
    ///   - attributes: How the condition variable is shared.
    ///
    /// Destroying the `Condition` destroys the C condition variable,
    /// but doesn't deallocate the memory.
    ///
    /// The corresponding C function is `pthread_cond_init`.
    @_alwaysEmitIntoClient
    public init(
      unsafeUninitializedAddress address: UnsafeMutablePointer<CInterop.PThreadCondition>,
      attributes: Attributes = Attributes()
    ) throws(Errno) {
      try Condition._initialize(address, attributes).get()
      self._address = address
      self._deallocates = false
    }

    @_alwaysEmitIntoClient
    internal init(_borrowing address: UnsafeMutablePointer<CInterop.PThreadCondition>) {
      self._address = address
      self._deallocates = false
    }

    deinit {
      // deinit can't throw, so an error is dropped. The only one is EBUSY,
      // for a condition variable that threads are waiting on.
      _ = system_pthread_cond_destroy(_address)
      if _deallocates {
        _address.deallocate()
      }
    }
  }
}

// MARK: - Waiting and signaling

@available(System 199, *)
extension PThread.Condition {
  /// Waits for the condition to be signaled.
  ///
  /// - Parameter mutex: The mutex that protects the state
  ///   that the condition describes.
  ///   The calling thread must hold it.
  ///
  /// This method unlocks the mutex while it waits,
  /// and locks it again before returning or throwing.
  /// The wait can end without a signal,
  /// so check the state again after it returns.
  ///
  /// Every thread waiting on the condition at the same time
  /// must pass the same mutex.
  ///
  /// The corresponding C function is `pthread_cond_wait`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(on mutex: borrowing PThread.Mutex) throws(Errno) {
    try _wait(on: mutex).get()
  }

  @usableFromInline
  internal func _wait(on mutex: borrowing PThread.Mutex) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_cond_wait(_address, mutex._address)
    }
  }

  /// Waits for the condition to be signaled or a deadline to pass.
  ///
  /// - Parameters:
  ///   - mutex: The mutex that protects the state
  ///     that the condition describes.
  ///     The calling thread must hold it.
  ///   - deadline: The time to stop waiting, as a time since the Epoch
  ///     on the condition variable's clock.
  ///     On Darwin the clock is always `CLOCK_REALTIME`;
  ///     elsewhere it's ``Attributes-swift.struct/clock``.
  /// - Returns: `false` if the deadline passed,
  ///   or `true` if the wait ended for another reason,
  ///   which can be a signal or a spurious wakeup.
  ///
  /// This method unlocks the mutex while it waits,
  /// and locks it again before returning or throwing.
  ///
  /// The corresponding C function is `pthread_cond_timedwait`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(
    on mutex: borrowing PThread.Mutex, until deadline: timespec
  ) throws(Errno) -> Bool {
    try _wait(on: mutex, until: deadline).get()
  }

  @usableFromInline
  internal func _wait(
    on mutex: borrowing PThread.Mutex, until deadline: timespec
  ) -> Result<Bool, Errno> {
    var deadline = deadline
    return PThread.Condition._timedOutAsFalse(
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_cond_timedwait(_address, mutex._address, &deadline)
      })
  }

  /// Wakes one of the threads waiting on the condition, if there are any.
  ///
  /// Call this method with or without the mutex held.
  ///
  /// The corresponding C function is `pthread_cond_signal`.
  @_alwaysEmitIntoClient
  public func signal() throws(Errno) {
    try _signal().get()
  }

  @usableFromInline
  internal func _signal() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_cond_signal(_address)
    }
  }

  /// Wakes all the threads waiting on the condition.
  ///
  /// The corresponding C function is `pthread_cond_broadcast`.
  @_alwaysEmitIntoClient
  public func broadcast() throws(Errno) {
    try _broadcast().get()
  }

  @usableFromInline
  internal func _broadcast() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_cond_broadcast(_address)
    }
  }

  @usableFromInline
  internal static func _timedOutAsFalse(_ result: Result<(), Errno>) -> Result<Bool, Errno> {
    switch result {
    case .success: return .success(true)
    case .failure(.timedOut): return .success(false)
    case .failure(let error): return .failure(error)
    }
  }
}

#if SYSTEM_PACKAGE_DARWIN
// The timeout uses Duration, which needs a newer OS than System 199 means in
// the default build, so this declaration carries both.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension PThread.Condition {
  /// Waits for the condition to be signaled, for at most a given time.
  ///
  /// - Parameters:
  ///   - mutex: The mutex that protects the state
  ///     that the condition describes.
  ///     The calling thread must hold it.
  ///   - timeout: The longest time to wait.
  ///     The system measures it independently of the time of day,
  ///     so changing the clock doesn't shorten or lengthen the wait.
  ///     A timeout that isn't positive times out at once.
  /// - Returns: `false` if the timeout elapsed,
  ///   or `true` if the wait ended for another reason,
  ///   which can be a signal or a spurious wakeup.
  ///
  /// To wait until a time of day, call ``wait(on:until:)``.
  ///
  /// The corresponding C function is `pthread_cond_timedwait_relative_np`.
  /// - Note: Only available on Darwin. Elsewhere,
  ///   create the condition variable with the `CLOCK_MONOTONIC` clock,
  ///   and wait until a deadline on that clock.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public func wait(
    on mutex: borrowing PThread.Mutex, timeout: Duration
  ) throws(Errno) -> Bool {
    try _wait(on: mutex, timeout: timeout).get()
  }

  @usableFromInline
  internal func _wait(
    on mutex: borrowing PThread.Mutex, timeout: Duration
  ) -> Result<Bool, Errno> {
    // A negative timeout would wait forever: Darwin 26 doesn't time out a
    // relative wait whose tv_sec is negative. A zero timeout times out at
    // once.
    let (seconds, attoseconds) = max(timeout, .zero).components
    var timeout = timespec(
      tv_sec: Int(seconds), tv_nsec: Int(attoseconds / 1_000_000_000))
    return PThread.Condition._timedOutAsFalse(
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_cond_timedwait_relative_np(_address, mutex._address, &timeout)
      })
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

// MARK: - C interoperation

@available(System 199, *)
extension PThread.Condition {
  /// The address of the C condition variable, for passing to C functions.
  ///
  /// The address is valid while this `Condition` instance is alive,
  /// and doesn't change when the instance moves.
  /// Don't destroy the C condition variable through it.
  @_alwaysEmitIntoClient
  public var unsafeAddress: UnsafeMutablePointer<CInterop.PThreadCondition> { _address }

  /// Calls a closure with a condition variable that other code,
  /// such as a C library, initialized and will destroy.
  ///
  /// - Parameters:
  ///   - address: The address of an initialized C condition variable.
  ///     It must stay initialized until `body` returns.
  ///   - body: A closure that uses the condition variable.
  ///     The condition variable is valid only for the duration of the call.
  /// - Returns: The value that `body` returns.
  ///
  /// The `Condition` instance that `body` borrows doesn't own
  /// the C condition variable: when `body` returns,
  /// the C condition variable isn't destroyed.
  @_alwaysEmitIntoClient
  public static func withUnsafeCondition<R: ~Copyable>(
    at address: UnsafeMutablePointer<CInterop.PThreadCondition>,
    _ body: (borrowing PThread.Condition) throws -> R
  ) rethrows -> R {
    let condition = PThread.Condition(_borrowing: address)
    do {
      let result = try body(condition)
      condition._forget()
      return result
    } catch {
      condition._forget()
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
extension PThread.Condition {
  @usableFromInline
  internal static func _allocate(
    _ attributes: Attributes
  ) -> Result<UnsafeMutablePointer<CInterop.PThreadCondition>, Errno> {
    let address = UnsafeMutablePointer<CInterop.PThreadCondition>.allocate(capacity: 1)
    if case .failure(let error) = _initialize(address, attributes) {
      address.deallocate()
      return .failure(error)
    }
    return .success(address)
  }

  @usableFromInline
  internal static func _initialize(
    _ address: UnsafeMutablePointer<CInterop.PThreadCondition>, _ attributes: Attributes
  ) -> Result<(), Errno> {
    attributes._withUnsafeAttributes { attributes in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_cond_init(address, attributes)
      }
    }
  }
}

// MARK: - Attributes

@available(System 199, *)
extension PThread.Condition {
  /// How a condition variable is shared,
  /// and on platforms other than Darwin, which clock its deadlines use.
  ///
  /// Creating a condition variable makes C attributes from these;
  /// the corresponding C functions are `pthread_condattr_init`
  /// and `pthread_condattr_destroy`.
  ///
  /// The corresponding C type is `pthread_condattr_t`.
  @frozen
  public struct Attributes: Hashable, Sendable {
    /// Whether threads in other processes can use the condition variable,
    /// if it's in memory that they share.
    ///
    /// A process-shared condition variable must be created in shared memory,
    /// with ``PThread/Condition/init(unsafeUninitializedAddress:attributes:)``,
    /// and used with a process-shared mutex.
    ///
    /// The corresponding C function is `pthread_condattr_setpshared`,
    /// with `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.
    public var isProcessShared: Bool

    #if !SYSTEM_PACKAGE_DARWIN
    /// The clock that ``PThread/Condition/wait(on:until:)`` measures
    /// its deadline on.
    ///
    /// The default is ``Clock-swift.struct/realtime``,
    /// the time of day, which can jump when the clock is set.
    /// A deadline on ``Clock-swift.struct/monotonic`` can't.
    ///
    /// The corresponding C function is `pthread_condattr_setclock`.
    /// - Note: Not available on Darwin,
    ///   where ``PThread/Condition/wait(on:timeout:)``
    ///   waits for a time that's independent of the clock.
    public var clock: Clock
    #endif

    /// Creates condition variable attributes.
    @_alwaysEmitIntoClient
    public init(isProcessShared: Bool = false) {
      self.isProcessShared = isProcessShared
      #if !SYSTEM_PACKAGE_DARWIN
      self.clock = .realtime
      #endif
    }
  }

  #if !SYSTEM_PACKAGE_DARWIN
  /// A clock that a condition variable's deadlines can use.
  ///
  /// The corresponding C type is `clockid_t`.
  /// - Note: Not available on Darwin.
  @frozen
  public struct Clock: RawRepresentable, Hashable {
    /// The raw C clock identifier.
    @_alwaysEmitIntoClient
    public var rawValue: clockid_t

    /// Creates a strongly-typed clock from a raw C clock identifier.
    @_alwaysEmitIntoClient
    public init(rawValue: clockid_t) { self.rawValue = rawValue }

    /// The time of day, which can jump when the clock is set.
    ///
    /// The corresponding C constant is `CLOCK_REALTIME`.
    @_alwaysEmitIntoClient
    public static var realtime: Self { Self(rawValue: _CLOCK_REALTIME) }

    /// A clock that only moves forward, from an unspecified starting point.
    ///
    /// The corresponding C constant is `CLOCK_MONOTONIC`.
    @_alwaysEmitIntoClient
    public static var monotonic: Self { Self(rawValue: _CLOCK_MONOTONIC) }
  }
  #endif // !SYSTEM_PACKAGE_DARWIN
}

// WASI's clockid_t is a pointer, which isn't Sendable, to a constant.
#if os(WASI)
@available(System 199, *)
extension PThread.Condition.Clock: @unchecked Sendable {}
#elseif !SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension PThread.Condition.Clock: Sendable {}
#endif

@available(System 199, *)
extension PThread.Condition.Attributes {
  internal func _withUnsafeAttributes<R>(
    _ body: (UnsafePointer<_PThreadCondAttrStorage>?) -> Result<R, Errno>
  ) -> Result<R, Errno> {
    guard self != PThread.Condition.Attributes() else { return body(nil) }
    var attributes = _pthreadCondAttrZero
    return withUnsafeMutablePointer(to: &attributes) { attributes in
      if let error = _pthreadError(system_pthread_condattr_init(attributes)) {
        return .failure(error)
      }
      defer { _ = system_pthread_condattr_destroy(attributes) }
      let shared = isProcessShared ? _PTHREAD_PROCESS_SHARED : _PTHREAD_PROCESS_PRIVATE
      if let error = _pthreadError(system_pthread_condattr_setpshared(attributes, shared)) {
        return .failure(error)
      }
      #if !SYSTEM_PACKAGE_DARWIN
      if let error = _pthreadError(
        system_pthread_condattr_setclock(attributes, clock.rawValue)
      ) {
        return .failure(error)
      }
      #endif
      return body(attributes)
    }
  }
}

#endif // !os(Windows) && (!os(WASI) || _runtime(_multithreaded))
