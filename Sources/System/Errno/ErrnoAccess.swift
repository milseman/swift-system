/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: public access to errno. Whether System should offer it at all
// is still open; see Prototype/PosixMore/README.md.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif os(Windows)
import ucrt
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// errno, for code that's emitted into clients: Errno.current and the
// helpers below. System's own code uses system_errno (Exports.swift),
// which does the same.
#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get { Darwin.errno }
  set { Darwin.errno = newValue }
}
#elseif os(Windows)
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get {
    var value: CInt = 0
    _ = ucrt._get_errno(&value)
    return value
  }
  set { _ = ucrt._set_errno(newValue) }
}
#elseif canImport(Glibc)
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get { Glibc.errno }
  set { Glibc.errno = newValue }
}
#elseif canImport(Musl)
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get { Musl.errno }
  set { Musl.errno = newValue }
}
#elseif canImport(WASILibc)
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get { WASILibc.errno }
  set { WASILibc.errno = newValue }
}
#elseif canImport(Android)
@_alwaysEmitIntoClient
internal var _errnoValue: CInt {
  get { Android.errno }
  set { Android.errno = newValue }
}
#endif

@available(System 199, *)
extension Errno {
  /// Calls a C function that reports failure by returning -1
  /// and setting `errno`, and throws that error.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to call again
  ///     if the call fails with ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///   - call: A closure that makes the C call and returns its result.
  /// - Returns: The call's result, which isn't -1.
  ///
  /// This method reads `errno` as soon as `call` returns,
  /// so that nothing else can change it first,
  /// which reading ``current`` after the call can't promise:
  ///
  ///     let fd = try Errno.check { open(path, O_RDONLY | O_CLOEXEC) }
  ///
  /// Make only the C call in `call`. Swift can release a value
  /// whose last use is in the call before `call` returns,
  /// and if the value's deinitializer makes a system call,
  /// that can change `errno`;
  /// to prevent it, use `withExtendedLifetime(_:_:)` outside this method.
  ///
  /// For a result type without a sign, such as `size_t`,
  /// the value that means failure is the one with every bit set,
  /// as for C's `(size_t)-1`.
  @_alwaysEmitIntoClient
  public static func check<Value: FixedWidthInteger>(
    retryOnInterrupt: Bool = true,
    _ call: () -> Value
  ) throws(Errno) -> Value {
    let failure = Value(truncatingIfNeeded: -1 as Int)
    while true {
      let value = call()
      guard value == failure else { return value }
      let error = Errno(rawValue: _errnoValue)
      guard retryOnInterrupt && error == .interrupted else { throw error }
    }
  }

  /// Calls a C function that reports failure by returning a null pointer,
  /// or another `nil` value, and setting `errno`, and throws that error.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to call again
  ///     if the call fails with ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///   - call: A closure that makes the C call and returns its result.
  /// - Returns: The call's result, which isn't `nil`.
  ///
  /// This method reads `errno` as soon as `call` returns,
  /// as the form for integer results does:
  ///
  ///     let directory = try Errno.check { opendir(path) }
  ///
  /// Only the null pointer means failure:
  /// for a call with another value for failure, such as `mmap`'s
  /// `MAP_FAILED`, compare the result, and then read ``current``.
  /// For a call that can return `nil` without failing, such as `readdir`,
  /// use ``checkOptional(retryOnInterrupt:_:)``.
  @_alwaysEmitIntoClient
  public static func check<Value>(
    retryOnInterrupt: Bool = true,
    _ call: () -> Value?
  ) throws(Errno) -> Value {
    while true {
      if let value = call() { return value }
      let error = Errno(rawValue: _errnoValue)
      guard retryOnInterrupt && error == .interrupted else { throw error }
    }
  }

  /// Calls a C function that returns a null pointer, or another `nil` value,
  /// both when it fails and when it has nothing to return,
  /// and tells the two apart by `errno`.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to call again
  ///     if the call fails with ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///   - call: A closure that makes the C call and returns its result.
  /// - Returns: The call's result, or `nil` if it had nothing to return.
  ///
  /// A function like `readdir` leaves `errno` alone when it returns `nil`
  /// for having nothing to return, and sets it when it fails,
  /// so this method sets `errno` to zero before the call,
  /// and throws if the call returns `nil` and `errno` isn't zero after it:
  ///
  ///     while let entry = try Errno.checkOptional({ readdir(directory) }) {
  ///       ...
  ///     }
  @_alwaysEmitIntoClient
  public static func checkOptional<Value>(
    retryOnInterrupt: Bool = true,
    _ call: () -> Value?
  ) throws(Errno) -> Value? {
    while true {
      _errnoValue = 0
      if let value = call() { return value }
      let error = Errno(rawValue: _errnoValue)
      guard error.rawValue != 0 else { return nil }
      guard retryOnInterrupt && error == .interrupted else { throw error }
    }
  }
}
