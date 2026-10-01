/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// A key to fiber-local storage: a variable with a separate value for
  /// each fiber, which, on a thread that runs no fibers, is a value for each
  /// thread.
  ///
  ///     static let requestID = try! Win32.FiberLocalKey<UInt64>()
  ///
  ///     try requestID.setValue(42)
  ///     requestID.value()     // 42 on this thread, nil on the others
  ///
  /// Each thread starts with no value. Windows destroys a thread's value
  /// when the thread exits, and a fiber's when the fiber is deleted.
  ///
  /// `FiberLocalKey` can't be copied. Destroying one frees the C index and
  /// destroys every thread's value, on the destroying thread, where POSIX's
  /// `pthread_key_delete` leaks the values of the other threads; the
  /// corresponding C function is `FlsFree`. Windows limits the number of
  /// keys per process (`FLS_MAXIMUM_AVAILABLE`), so a key that lasts as
  /// long as the process, such as a `static let`, suits most uses.
  ///
  /// Fiber-local values belong to threads, not tasks. In asynchronous code,
  /// which can move between threads, use task-local values.
  ///
  /// The corresponding C type is the `DWORD` index that `FlsAlloc` returns.
  @frozen
  public struct FiberLocalKey<Value>: ~Copyable {
    @usableFromInline
    internal let _index: DWORD

    /// Creates a key.
    ///
    /// The corresponding C function is `FlsAlloc`.
    @_alwaysEmitIntoClient
    public init() throws(Win32.Error) {
      self._index = try Win32._allocateFiberLocalIndex().get()
    }

    deinit {
      // FlsFree destroys each thread's value. A deinit can't throw, so an
      // error is dropped: the only one is for an index that isn't valid.
      _ = system_FlsFree(_index)
    }
  }
}

@available(System 199, *)
extension Win32.FiberLocalKey: Sendable where Value: Sendable {}

@available(System 199, *)
extension Win32.FiberLocalKey {
  /// The calling thread's value, or `nil` if it has none.
  ///
  /// The corresponding C function is `FlsGetValue`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "A task can move between threads; use task-local values")
  public func value() -> Value? {
    _value()
  }

  @usableFromInline
  internal func _value() -> Value? {
    // An index from FlsAlloc is valid, so NULL is always "no value".
    guard let value = system_FlsGetValue(_index) else { return nil }
    return Unmanaged<_Win32FiberLocalBox<Value>>.fromOpaque(value).takeUnretainedValue().value
  }

  /// Sets or removes the calling thread's value.
  ///
  /// - Parameter newValue: The new value, or `nil` to remove the calling
  ///   thread's value.
  ///
  /// The previous value is destroyed after the new one is in place. Since
  /// the key's index is valid, this fails only for want of memory.
  ///
  /// The corresponding C function is `FlsSetValue`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "A task can move between threads; use task-local values")
  public func setValue(_ newValue: Value?) throws(Win32.Error) {
    try _setValue(newValue).get()
  }

  @usableFromInline
  internal func _setValue(_ newValue: Value?) -> Result<Void, Win32.Error> {
    let oldValue = system_FlsGetValue(_index)
    let value = newValue.map {
      Unmanaged.passRetained(_Win32FiberLocalBox($0)).toOpaque()
    }
    guard system_FlsSetValue(_index, value) else {
      let error = Win32.Error(GetLastError())
      if let value { _win32FiberLocalDestructor(value) }
      return .failure(error)
    }
    if let oldValue { _win32FiberLocalDestructor(oldValue) }
    return .success(())
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _allocateFiberLocalIndex() -> Result<DWORD, Win32.Error> {
    let index = system_FlsAlloc()
    guard index != _FLS_OUT_OF_INDEXES else { return .failure(Win32.Error(GetLastError())) }
    return .success(index)
  }
}

// A thread's value for a key. The key's C callback knows only this base
// class, since a C function can't be generic.
internal class _Win32FiberLocalBoxBase {}

internal final class _Win32FiberLocalBox<Value>: _Win32FiberLocalBoxBase {
  internal let value: Value

  internal init(_ value: Value) {
    self.value = value
  }
}

// The callback of every index that `Win32.FiberLocalKey` allocates, which
// Windows calls with a value when its thread exits, its fiber is deleted, or
// its index is freed: releases the value. See system_FlsAlloc.
internal func _win32FiberLocalDestructor(_ value: UnsafeMutableRawPointer?) {
  guard let value else { return }
  Unmanaged<_Win32FiberLocalBoxBase>.fromOpaque(value).release()
}

#endif // os(Windows)
