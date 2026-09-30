/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Wrappers and constants for thread cancellation, behind
// Threads/PThreadCancellation.swift.
//
// pthread_cancel and pthread_setcancelstate return an error number rather
// than setting errno, so their mocks use `_mockReturningErrno`.
// pthread_testcancel can't fail, and isn't mockable. Android's Bionic has
// no thread cancellation.

#if !os(Windows) && !os(WASI) && !os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

// MARK: - Constants

// glibc declares these in an anonymous enum, which Swift imports as `Int`.
@_alwaysEmitIntoClient
internal var _PTHREAD_CANCEL_ENABLE: CInt { CInt(PTHREAD_CANCEL_ENABLE) }

@_alwaysEmitIntoClient
internal var _PTHREAD_CANCEL_DISABLE: CInt { CInt(PTHREAD_CANCEL_DISABLE) }

// MARK: - Calls

internal func system_pthread_cancel(_ thread: pthread_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread) }
#endif
  return pthread_cancel(thread)
}

internal func system_pthread_setcancelstate(
  _ state: CInt, _ previous: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(state, previous) }
#endif
  return pthread_setcancelstate(state, previous)
}

internal func system_pthread_testcancel() {
  pthread_testcancel()
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
