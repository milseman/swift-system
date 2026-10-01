/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && (!os(WASI) || _runtime(_multithreaded))

@available(System 199, *)
extension PThread {
  /// A key to thread-specific storage:
  /// a variable with a separate value for each thread.
  ///
  ///     static let requestID = try! PThread.Key<UInt64>()
  ///
  ///     try requestID.setValue(42)
  ///     requestID.value()     // 42 on this thread, nil on the others
  ///
  /// Each thread starts with no value.
  /// When a thread finishes, the system destroys the thread's value.
  /// It doesn't do so for a thread that ends because the process exits,
  /// such as the main thread when `main` returns.
  ///
  /// `Key` can't be copied. Destroying a `Key` deletes the C key,
  /// and destroys the calling thread's value;
  /// the corresponding C function is `pthread_key_delete`.
  /// POSIX doesn't destroy the values of the other threads
  /// when a key is deleted, so they leak.
  /// A key that lasts as long as the process,
  /// such as a `static let`, never leaks them.
  /// The system limits the number of keys per process
  /// (`PTHREAD_KEYS_MAX`, 512 on Darwin).
  ///
  /// Thread-specific values belong to threads, not tasks.
  /// In asynchronous code, which can move between threads, use task-local values.
  ///
  /// The corresponding C type is `pthread_key_t`.
  @frozen
  public struct Key<Value>: ~Copyable {
    @usableFromInline
    internal let _rawValue: CInterop.PThreadKey

    /// Creates a key.
    ///
    /// The corresponding C function is `pthread_key_create`.
    @_alwaysEmitIntoClient
    public init() throws(Errno) {
      self._rawValue = try Key._create().get()
    }

    deinit {
      if let value = system_pthread_getspecific(_rawValue) {
        _ = system_pthread_setspecific(_rawValue, nil)
        _pthreadKeyDestructor(value)
      }
      // deinit can't throw, so an error is dropped. The only one is EINVAL,
      // for a key that isn't valid.
      _ = system_pthread_key_delete(_rawValue)
    }
  }
}

@available(System 199, *)
extension PThread.Key: Sendable where Value: Sendable {}

@available(System 199, *)
extension PThread.Key {
  /// The calling thread's value, or `nil` if it has none.
  ///
  /// The corresponding C function is `pthread_getspecific`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "A task can move between threads; use task-local values")
  public func value() -> Value? {
    _value()
  }

  @usableFromInline
  internal func _value() -> Value? {
    guard let value = system_pthread_getspecific(_rawValue) else { return nil }
    return Unmanaged<_PThreadKeyBox<Value>>.fromOpaque(value).takeUnretainedValue().value
  }

  /// Sets or removes the calling thread's value.
  ///
  /// - Parameter newValue: The new value,
  ///   or `nil` to remove the calling thread's value.
  ///
  /// The previous value is destroyed after the new one is in place.
  ///
  /// The corresponding C function is `pthread_setspecific`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "A task can move between threads; use task-local values")
  public func setValue(_ newValue: Value?) throws(Errno) {
    try _setValue(newValue).get()
  }

  @usableFromInline
  internal func _setValue(_ newValue: Value?) -> Result<(), Errno> {
    let oldValue = system_pthread_getspecific(_rawValue)
    let value = newValue.map {
      Unmanaged.passRetained(_PThreadKeyBox($0)).toOpaque()
    }
    if let error = _pthreadError(system_pthread_setspecific(_rawValue, value)) {
      if let value { _pthreadKeyDestructor(value) }
      return .failure(error)
    }
    if let oldValue { _pthreadKeyDestructor(oldValue) }
    return .success(())
  }

  @usableFromInline
  internal static func _create() -> Result<CInterop.PThreadKey, Errno> {
    var key = CInterop.PThreadKey()
    return nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_key_create(&key)
    }.map { key }
  }
}

// A thread's value for a key. The key's C destructor knows only this base
// class, since a C function can't be generic.
internal class _PThreadKeyBoxBase {}

internal final class _PThreadKeyBox<Value>: _PThreadKeyBoxBase {
  internal let value: Value

  internal init(_ value: Value) {
    self.value = value
  }
}

// The destructor of every key that `PThread.Key` creates: releases the
// thread's value. See system_pthread_key_create.
internal func _pthreadKeyDestructor(_ value: UnsafeMutableRawPointer?) {
  // POSIX calls a destructor only for a value that isn't NULL.
  Unmanaged<_PThreadKeyBoxBase>.fromOpaque(value!).release()
}

#endif // !os(Windows) && (!os(WASI) || _runtime(_multithreaded))
