/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Wrappers for the pthread functions behind Sources/System/Threads.
//
// Except for `pthread_setname_np` on Darwin, these functions return an error
// number rather than setting errno, so the mockable ones use
// `_mockReturningErrno`. None of them return EINTR. The attribute functions
// only fill in a local structure, so they aren't mockable, and neither are
// the calls that can't fail.
//
// WASI has pthreads only with threads (wasm32-wasip1-threads), and its
// wasi-libc has no pthread_exit, no scheduling, no guard size and no
// priority ceilings: it declares some of those without defining them, so
// they're left out here, where a call would fail only at an executable's
// link (wasi-libc's expected/wasm32-wasip1-threads/defined-symbols.txt).

#if !os(Windows) && (!os(WASI) || _runtime(_multithreaded))

import CSystem
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

// MARK: - Storage types

// On FreeBSD and OpenBSD, the pthread object types are pointers to objects
// that the C library allocates, and Swift imports pointers to them as
// pointers to optionals. Elsewhere they're structures.
#if os(FreeBSD) || os(OpenBSD)
@usableFromInline internal typealias _PThreadAttrStorage = pthread_attr_t?
@usableFromInline internal typealias _PThreadMutexStorage = pthread_mutex_t?
@usableFromInline internal typealias _PThreadMutexAttrStorage = pthread_mutexattr_t?
@usableFromInline internal typealias _PThreadCondStorage = pthread_cond_t?
@usableFromInline internal typealias _PThreadCondAttrStorage = pthread_condattr_t?
@usableFromInline internal typealias _PThreadRWLockStorage = pthread_rwlock_t?
@usableFromInline internal typealias _PThreadRWLockAttrStorage = pthread_rwlockattr_t?

internal var _pthreadAttrZero: _PThreadAttrStorage { nil }
internal var _pthreadMutexAttrZero: _PThreadMutexAttrStorage { nil }
internal var _pthreadCondAttrZero: _PThreadCondAttrStorage { nil }
internal var _pthreadRWLockAttrZero: _PThreadRWLockAttrStorage { nil }
#else
@usableFromInline internal typealias _PThreadAttrStorage = pthread_attr_t
@usableFromInline internal typealias _PThreadMutexStorage = pthread_mutex_t
@usableFromInline internal typealias _PThreadMutexAttrStorage = pthread_mutexattr_t
@usableFromInline internal typealias _PThreadCondStorage = pthread_cond_t
@usableFromInline internal typealias _PThreadCondAttrStorage = pthread_condattr_t
@usableFromInline internal typealias _PThreadRWLockStorage = pthread_rwlock_t
@usableFromInline internal typealias _PThreadRWLockAttrStorage = pthread_rwlockattr_t

internal var _pthreadAttrZero: _PThreadAttrStorage { pthread_attr_t() }
internal var _pthreadMutexAttrZero: _PThreadMutexAttrStorage { pthread_mutexattr_t() }
internal var _pthreadCondAttrZero: _PThreadCondAttrStorage { pthread_condattr_t() }
internal var _pthreadRWLockAttrZero: _PThreadRWLockAttrStorage { pthread_rwlockattr_t() }
#endif

// `pthread_create` stores the new thread through a pointer to an optional
// where `pthread_t` is a pointer (Darwin, Musl, WASI, and the BSDs), and
// through a pointer to the integer elsewhere (Glibc and Bionic).
#if SYSTEM_PACKAGE_DARWIN || canImport(Musl) || os(WASI) || os(FreeBSD) || os(OpenBSD)
internal typealias _PThreadCreateStorage = pthread_t?
internal var _pthreadCreateZero: _PThreadCreateStorage { nil }
internal func _pthreadCreated(_ storage: _PThreadCreateStorage) -> pthread_t { storage! }
#else
internal typealias _PThreadCreateStorage = pthread_t
internal var _pthreadCreateZero: _PThreadCreateStorage { pthread_t() }
internal func _pthreadCreated(_ storage: _PThreadCreateStorage) -> pthread_t { storage }
#endif

// MARK: - Threads

// Runs the body of a thread that `system_pthread_create` started. Defined in
// Threads/PThread.swift.
//   internal func _pthreadStart(_ context: UnsafeMutableRawPointer?)

// Starts a thread that runs `_pthreadStart(context)`. The start routine is
// fixed, rather than a parameter, because its C signature differs between
// platforms and Android NDK versions, and a closure literal adapts to each.
internal func system_pthread_create(
  _ thread: UnsafeMutablePointer<_PThreadCreateStorage>,
  _ attributes: UnsafePointer<_PThreadAttrStorage>?,
  _ context: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(thread, attributes, context)
    if result == 0 {
      // No thread starts, so release the context the thread would have
      // consumed, and report the calling thread as the new one, so that the
      // caller holds a valid ID. Mock tests must join or detach it while
      // mocking is still enabled.
      _pthreadDiscardContext(context)
      thread.pointee = pthread_self()
    }
    return result
  }
#endif
  return pthread_create(thread, attributes, { context in
    _pthreadStart(context)
    #if os(Android)
    // The thread's result, which `join()` ignores. Returning the argument
    // satisfies both NDK signatures: the result is non-optional in NDK 27.
    return context
    #else
    return nil
    #endif
  }, context)
}

internal func system_pthread_join(_ thread: pthread_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread) }
#endif
  return pthread_join(thread, nil)
}

internal func system_pthread_detach(_ thread: pthread_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread) }
#endif
  return pthread_detach(thread)
}

// Not mockable: these can't fail.
internal func system_pthread_self() -> pthread_t {
  pthread_self()
}

internal func system_pthread_equal(_ lhs: pthread_t, _ rhs: pthread_t) -> Bool {
  pthread_equal(lhs, rhs) != 0
}

internal func system_sched_yield() -> CInt {
  sched_yield()
}

#if !os(WASI)
internal func system_pthread_exit() -> Never {
  pthread_exit(nil)
}
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
internal func system_pthread_main_np() -> CInt {
  pthread_main_np()
}
#endif

// MARK: - Thread names

#if SYSTEM_PACKAGE_DARWIN
// Darwin can only name the calling thread, and unlike the other pthread
// functions, this one returns -1 and sets errno.
internal func system_pthread_setname_np(_ name: UnsafePointer<CChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: name) }
#endif
  return pthread_setname_np(name)
}
#elseif os(Linux) || os(Android) || os(FreeBSD)
// glibc declares these only with _GNU_SOURCE; see CSystemLinux.h.
internal func system_pthread_setname_np(
  _ thread: pthread_t, _ name: UnsafePointer<CChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(thread, String(_errorCorrectingPlatformString: name))
  }
#endif
  #if os(FreeBSD)
  return pthread_setname_np(thread, name)
  #else
  return csystem_pthread_setname_np(thread, name)
  #endif
}
#endif

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
internal func system_pthread_getname_np(
  _ thread: pthread_t, _ buffer: UnsafeMutablePointer<CChar>, _ length: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, buffer, length) }
#endif
  #if os(Linux) || os(Android)
  return csystem_pthread_getname_np(thread, buffer, length)
  #else
  return pthread_getname_np(thread, buffer, length)
  #endif
}
#endif

// MARK: - Thread attributes

internal func system_pthread_attr_init(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>
) -> CInt {
  pthread_attr_init(attributes)
}

internal func system_pthread_attr_destroy(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>
) -> CInt {
  pthread_attr_destroy(attributes)
}

internal func system_pthread_attr_setstacksize(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>, _ size: Int
) -> CInt {
  pthread_attr_setstacksize(attributes, size)
}

internal func system_pthread_attr_getstacksize(
  _ attributes: UnsafePointer<_PThreadAttrStorage>, _ size: UnsafeMutablePointer<Int>
) -> CInt {
  pthread_attr_getstacksize(attributes, size)
}

#if !os(WASI)
internal func system_pthread_attr_setguardsize(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>, _ size: Int
) -> CInt {
  pthread_attr_setguardsize(attributes, size)
}

internal func system_pthread_attr_setinheritsched(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>, _ inherit: CInt
) -> CInt {
  pthread_attr_setinheritsched(attributes, inherit)
}

internal func system_pthread_attr_setschedpolicy(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>, _ policy: CInt
) -> CInt {
  pthread_attr_setschedpolicy(attributes, policy)
}

internal func system_pthread_attr_setschedparam(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>,
  _ parameters: UnsafePointer<sched_param>
) -> CInt {
  pthread_attr_setschedparam(attributes, parameters)
}
#endif // !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
internal func system_pthread_attr_set_qos_class_np(
  _ attributes: UnsafeMutablePointer<_PThreadAttrStorage>,
  _ qosClass: qos_class_t, _ relativePriority: CInt
) -> CInt {
  pthread_attr_set_qos_class_np(attributes, qosClass, relativePriority)
}
#endif

// MARK: - Scheduling

#if !os(WASI)
internal func system_pthread_getschedparam(
  _ thread: pthread_t,
  _ policy: UnsafeMutablePointer<CInt>,
  _ parameters: UnsafeMutablePointer<sched_param>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, policy, parameters) }
#endif
  return pthread_getschedparam(thread, policy, parameters)
}

internal func system_pthread_setschedparam(
  _ thread: pthread_t, _ policy: CInt, _ parameters: UnsafePointer<sched_param>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(thread, policy, parameters.pointee.sched_priority)
  }
#endif
  return pthread_setschedparam(thread, policy, parameters)
}

// These two return -1 and set errno.
internal func system_sched_get_priority_min(_ policy: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(policy) }
#endif
  return sched_get_priority_min(policy)
}

internal func system_sched_get_priority_max(_ policy: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(policy) }
#endif
  return sched_get_priority_max(policy)
}
#endif // !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
internal func system_pthread_set_qos_class_self_np(
  _ qosClass: qos_class_t, _ relativePriority: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(qosClass.rawValue, relativePriority) }
#endif
  return pthread_set_qos_class_self_np(qosClass, relativePriority)
}

internal func system_pthread_get_qos_class_np(
  _ thread: pthread_t,
  _ qosClass: UnsafeMutablePointer<qos_class_t>,
  _ relativePriority: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, qosClass, relativePriority) }
#endif
  return pthread_get_qos_class_np(thread, qosClass, relativePriority)
}

// Not mockable: these can't fail.
internal func system_qos_class_self() -> qos_class_t {
  qos_class_self()
}

internal func system_qos_class_main() -> qos_class_t {
  qos_class_main()
}
#endif // SYSTEM_PACKAGE_DARWIN

// MARK: - CPU affinity

#if os(Linux) || os(Android)
// glibc, Musl, and Bionic declare these only with _GNU_SOURCE; see
// CSystemLinux.h. They return -1 and set errno. The mask is a `cpu_set_t`
// of `size` bytes.
internal func system_sched_setaffinity(
  _ pid: pid_t, _ size: Int, _ mask: UnsafeRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, size, mask) }
#endif
  return csystem_sched_setaffinity(pid, size, mask)
}

internal func system_sched_getaffinity(
  _ pid: pid_t, _ size: Int, _ mask: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, size, mask) }
#endif
  return csystem_sched_getaffinity(pid, size, mask)
}
#endif // os(Linux) || os(Android)

#if os(Linux)
// Bionic has no pthread affinity functions. These return an error number.
internal func system_pthread_setaffinity_np(
  _ thread: pthread_t, _ size: Int, _ mask: UnsafeRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, size, mask) }
#endif
  return csystem_pthread_setaffinity_np(thread, size, mask)
}

internal func system_pthread_getaffinity_np(
  _ thread: pthread_t, _ size: Int, _ mask: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, size, mask) }
#endif
  return csystem_pthread_getaffinity_np(thread, size, mask)
}
#endif // os(Linux)

// MARK: - Mutexes

internal func system_pthread_mutex_init(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ attributes: UnsafePointer<_PThreadMutexAttrStorage>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex, attributes) }
#endif
  return pthread_mutex_init(mutex, attributes)
}

internal func system_pthread_mutex_destroy(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex) }
#endif
  return pthread_mutex_destroy(mutex)
}

internal func system_pthread_mutex_lock(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex) }
#endif
  return pthread_mutex_lock(mutex)
}

internal func system_pthread_mutex_trylock(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex) }
#endif
  return pthread_mutex_trylock(mutex)
}

internal func system_pthread_mutex_unlock(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex) }
#endif
  return pthread_mutex_unlock(mutex)
}

#if !SYSTEM_PACKAGE_DARWIN
internal func system_pthread_mutex_timedlock(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ deadline: UnsafePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(mutex, deadline.pointee.tv_sec, deadline.pointee.tv_nsec)
  }
#endif
  return pthread_mutex_timedlock(mutex, deadline)
}
#endif

#if os(Linux) || os(FreeBSD)
internal func system_pthread_mutex_consistent(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex) }
#endif
  return pthread_mutex_consistent(mutex)
}
#endif

#if !os(Android) && !os(WASI)
internal func system_pthread_mutex_getprioceiling(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ ceiling: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex, ceiling) }
#endif
  return pthread_mutex_getprioceiling(mutex, ceiling)
}

internal func system_pthread_mutex_setprioceiling(
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ ceiling: CInt,
  _ oldCeiling: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(mutex, ceiling, oldCeiling) }
#endif
  return pthread_mutex_setprioceiling(mutex, ceiling, oldCeiling)
}
#endif

internal func system_pthread_mutexattr_init(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>
) -> CInt {
  pthread_mutexattr_init(attributes)
}

internal func system_pthread_mutexattr_destroy(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>
) -> CInt {
  pthread_mutexattr_destroy(attributes)
}

internal func system_pthread_mutexattr_settype(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>, _ type: CInt
) -> CInt {
  pthread_mutexattr_settype(attributes, type)
}

internal func system_pthread_mutexattr_setpshared(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>, _ shared: CInt
) -> CInt {
  pthread_mutexattr_setpshared(attributes, shared)
}

#if !os(Android) && !os(WASI)
internal func system_pthread_mutexattr_setprotocol(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>, _ priorityProtocol: CInt
) -> CInt {
  pthread_mutexattr_setprotocol(attributes, priorityProtocol)
}

internal func system_pthread_mutexattr_setprioceiling(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>, _ ceiling: CInt
) -> CInt {
#if canImport(Musl)
  // musl declares pthread_mutexattr_setprioceiling but doesn't define it,
  // so a call wouldn't link, and it doesn't support PTHREAD_PRIO_PROTECT,
  // the ceiling's protocol. (Its pthread_mutex_setprioceiling fails with
  // EINVAL, which could serve here too, or the property could go on Musl.)
  _ENOTSUP
#else
  pthread_mutexattr_setprioceiling(attributes, ceiling)
#endif
}
#endif

#if os(Linux) || os(FreeBSD)
internal func system_pthread_mutexattr_setrobust(
  _ attributes: UnsafeMutablePointer<_PThreadMutexAttrStorage>, _ robust: CInt
) -> CInt {
  pthread_mutexattr_setrobust(attributes, robust)
}
#endif

// MARK: - Condition variables

internal func system_pthread_cond_init(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>,
  _ attributes: UnsafePointer<_PThreadCondAttrStorage>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(condition, attributes) }
#endif
  return pthread_cond_init(condition, attributes)
}

internal func system_pthread_cond_destroy(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(condition) }
#endif
  return pthread_cond_destroy(condition)
}

internal func system_pthread_cond_wait(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>,
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(condition, mutex) }
#endif
  return pthread_cond_wait(condition, mutex)
}

internal func system_pthread_cond_timedwait(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>,
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ deadline: UnsafePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(
      condition, mutex, deadline.pointee.tv_sec, deadline.pointee.tv_nsec)
  }
#endif
  return pthread_cond_timedwait(condition, mutex, deadline)
}

#if SYSTEM_PACKAGE_DARWIN
internal func system_pthread_cond_timedwait_relative_np(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>,
  _ mutex: UnsafeMutablePointer<_PThreadMutexStorage>,
  _ timeout: UnsafePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(
      condition, mutex, timeout.pointee.tv_sec, timeout.pointee.tv_nsec)
  }
#endif
  return pthread_cond_timedwait_relative_np(condition, mutex, timeout)
}
#endif

internal func system_pthread_cond_signal(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(condition) }
#endif
  return pthread_cond_signal(condition)
}

internal func system_pthread_cond_broadcast(
  _ condition: UnsafeMutablePointer<_PThreadCondStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(condition) }
#endif
  return pthread_cond_broadcast(condition)
}

internal func system_pthread_condattr_init(
  _ attributes: UnsafeMutablePointer<_PThreadCondAttrStorage>
) -> CInt {
  pthread_condattr_init(attributes)
}

internal func system_pthread_condattr_destroy(
  _ attributes: UnsafeMutablePointer<_PThreadCondAttrStorage>
) -> CInt {
  pthread_condattr_destroy(attributes)
}

internal func system_pthread_condattr_setpshared(
  _ attributes: UnsafeMutablePointer<_PThreadCondAttrStorage>, _ shared: CInt
) -> CInt {
  pthread_condattr_setpshared(attributes, shared)
}

#if !SYSTEM_PACKAGE_DARWIN
internal func system_pthread_condattr_setclock(
  _ attributes: UnsafeMutablePointer<_PThreadCondAttrStorage>, _ clock: clockid_t
) -> CInt {
  pthread_condattr_setclock(attributes, clock)
}
#endif

// MARK: - Read-write locks

internal func system_pthread_rwlock_init(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>,
  _ attributes: UnsafePointer<_PThreadRWLockAttrStorage>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock, attributes) }
#endif
  return pthread_rwlock_init(lock, attributes)
}

internal func system_pthread_rwlock_destroy(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_destroy(lock)
}

internal func system_pthread_rwlock_rdlock(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_rdlock(lock)
}

internal func system_pthread_rwlock_tryrdlock(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_tryrdlock(lock)
}

internal func system_pthread_rwlock_wrlock(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_wrlock(lock)
}

internal func system_pthread_rwlock_trywrlock(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_trywrlock(lock)
}

internal func system_pthread_rwlock_unlock(
  _ lock: UnsafeMutablePointer<_PThreadRWLockStorage>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(lock) }
#endif
  return pthread_rwlock_unlock(lock)
}

internal func system_pthread_rwlockattr_init(
  _ attributes: UnsafeMutablePointer<_PThreadRWLockAttrStorage>
) -> CInt {
  pthread_rwlockattr_init(attributes)
}

internal func system_pthread_rwlockattr_destroy(
  _ attributes: UnsafeMutablePointer<_PThreadRWLockAttrStorage>
) -> CInt {
  pthread_rwlockattr_destroy(attributes)
}

internal func system_pthread_rwlockattr_setpshared(
  _ attributes: UnsafeMutablePointer<_PThreadRWLockAttrStorage>, _ shared: CInt
) -> CInt {
  pthread_rwlockattr_setpshared(attributes, shared)
}

// MARK: - Thread-specific storage

// Releases a value that `PThread.Key` stored. Defined in
// Threads/PThreadKey.swift.
//   internal func _pthreadKeyDestructor(_ value: UnsafeMutableRawPointer?)

// Creates a key whose destructor is `_pthreadKeyDestructor`. The destructor
// is fixed, rather than a parameter, because its C signature differs between
// platforms, and a closure literal adapts to each.
internal func system_pthread_key_create(
  _ key: UnsafeMutablePointer<pthread_key_t>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(key)
    if result == 0 {
      // Report a real key that never has a value, since the owner's
      // pthread_getspecific calls aren't mocked. On Darwin, reading a key
      // that doesn't exist can read the system's own thread-specific data.
      key.pointee = _mockPThreadKey
    }
    return result
  }
#endif
  return pthread_key_create(key, { value in _pthreadKeyDestructor(value) })
}

#if ENABLE_MOCKING
private let _mockPThreadKey: pthread_key_t = {
  var key = pthread_key_t()
  guard pthread_key_create(&key, nil) == 0 else { fatalError("Unable to create key") }
  return key
}()
#endif

internal func system_pthread_key_delete(_ key: pthread_key_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(key) }
#endif
  return pthread_key_delete(key)
}

// Not mockable: this can't fail. The mocking driver itself keeps its state in
// thread-specific storage (Exports.swift), through its own unmocked calls.
internal func system_pthread_getspecific(_ key: pthread_key_t) -> UnsafeMutableRawPointer? {
  pthread_getspecific(key)
}

internal func system_pthread_setspecific(
  _ key: pthread_key_t, _ value: UnsafeRawPointer?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(key, value) }
#endif
  return pthread_setspecific(key, value)
}

#endif // !os(Windows) && (!os(WASI) || _runtime(_multithreaded))
