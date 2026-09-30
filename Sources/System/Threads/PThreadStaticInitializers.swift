/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C pthread objects' static initializers, as values: C code that keeps
// a mutex, condition variable or read-write lock in its own storage, such as
// a field of a structure it shares with Swift, can start it out initialized
// without a call. Swift can't import the C macros, which are structure
// initializers. On Linux and Android the default ones are all zero bytes
// in glibc, Musl and Bionic. The error-checking and recursive mutexes'
// are Darwin's only: glibc and Bionic spell them with _NP and a kind field,
// and Musl has none.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
extension CInterop.PThreadMutex {
  /// A statically initialized mutex, with the default attributes.
  ///
  /// Storage that holds it is a mutex that's ready to lock,
  /// with no call to `pthread_mutex_init`;
  /// ``PThread/Mutex`` makes one with a call instead.
  /// Like any mutex, it mustn't be copied or moved once it's used.
  ///
  /// The corresponding C macro is `PTHREAD_MUTEX_INITIALIZER`.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
  @_alwaysEmitIntoClient
  public static var initializer: Self {
    #if SYSTEM_PACKAGE_DARWIN
    _initialized(signature: Int(_PTHREAD_MUTEX_SIG_init))
    #else
    Self()
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// A statically initialized error-checking mutex,
  /// which reports a relock by its owner or an unlock by another thread
  /// rather than deadlock or misbehave.
  ///
  /// See ``initializer``.
  ///
  /// The corresponding C macro is `PTHREAD_ERRORCHECK_MUTEX_INITIALIZER`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var errorCheckingInitializer: Self {
    _initialized(signature: Int(_PTHREAD_ERRORCHECK_MUTEX_SIG_init))
  }

  /// A statically initialized recursive mutex,
  /// which its owner can lock again.
  ///
  /// See ``initializer``.
  ///
  /// The corresponding C macro is `PTHREAD_RECURSIVE_MUTEX_INITIALIZER`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var recursiveInitializer: Self {
    _initialized(signature: Int(_PTHREAD_RECURSIVE_MUTEX_SIG_init))
  }

  // The C macros are the signature, with the rest zero.
  @_alwaysEmitIntoClient
  internal static func _initialized(signature: Int) -> Self {
    var mutex = pthread_mutex_t()
    mutex.__sig = signature
    return mutex
  }
  #endif
}

@available(System 199, *)
extension CInterop.PThreadCondition {
  /// A statically initialized condition variable, with the default attributes.
  ///
  /// Storage that holds it is a condition variable that's ready to wait on,
  /// with no call to `pthread_cond_init`;
  /// ``PThread/Condition`` makes one with a call instead.
  ///
  /// The corresponding C macro is `PTHREAD_COND_INITIALIZER`.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
  @_alwaysEmitIntoClient
  public static var initializer: Self {
    #if SYSTEM_PACKAGE_DARWIN
    var condition = pthread_cond_t()
    condition.__sig = Int(_PTHREAD_COND_SIG_init)
    return condition
    #else
    Self()
    #endif
  }
}

@available(System 199, *)
extension CInterop.PThreadReadWriteLock {
  /// A statically initialized read-write lock, with the default attributes.
  ///
  /// Storage that holds it is a lock that's ready to use,
  /// with no call to `pthread_rwlock_init`;
  /// ``PThread/ReadWriteLock`` makes one with a call instead.
  ///
  /// The corresponding C macro is `PTHREAD_RWLOCK_INITIALIZER`.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
  @_alwaysEmitIntoClient
  public static var initializer: Self {
    #if SYSTEM_PACKAGE_DARWIN
    var lock = pthread_rwlock_t()
    lock.__sig = Int(_PTHREAD_RWLOCK_SIG_init)
    return lock
    #else
    Self()
    #endif
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
