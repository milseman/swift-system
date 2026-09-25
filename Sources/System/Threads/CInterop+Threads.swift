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
extension CInterop {
  /// The C `pthread_t` type, which identifies a thread.
  public typealias PThread = pthread_t

  /// The C `pthread_key_t` type, which identifies thread-specific storage.
  public typealias PThreadKey = pthread_key_t

  #if os(FreeBSD) || os(OpenBSD)
  /// The storage of a C `pthread_mutex_t`.
  ///
  /// On FreeBSD and OpenBSD, `pthread_mutex_t` is a pointer
  /// to an object that the C library allocates,
  /// so the storage is an optional pointer.
  public typealias PThreadMutex = pthread_mutex_t?

  /// The storage of a C `pthread_cond_t`.
  public typealias PThreadCondition = pthread_cond_t?

  /// The storage of a C `pthread_rwlock_t`.
  public typealias PThreadReadWriteLock = pthread_rwlock_t?
  #else
  /// The C `pthread_mutex_t` type.
  public typealias PThreadMutex = pthread_mutex_t

  /// The C `pthread_cond_t` type.
  public typealias PThreadCondition = pthread_cond_t

  /// The C `pthread_rwlock_t` type.
  public typealias PThreadReadWriteLock = pthread_rwlock_t
  #endif
}

#endif // !os(Windows) && !os(WASI)
