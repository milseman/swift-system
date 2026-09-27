/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Clocks and sleeping: clock_gettime, clock_getres and nanosleep.

#if !os(Windows) && !os(WASI)

import CSystem
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

internal func system_clock_gettime(
  _ clock: clockid_t, _ time: UnsafeMutablePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(clock, time) }
#endif
  return clock_gettime(clock, time)
}

internal func system_clock_getres(
  _ clock: clockid_t, _ resolution: UnsafeMutablePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(clock, resolution) }
#endif
  return clock_getres(clock, resolution)
}

internal func system_nanosleep(
  _ request: UnsafePointer<timespec>, _ remaining: UnsafeMutablePointer<timespec>?
) -> CInt {
#if ENABLE_MOCKING
  // The request by value, so that a test can tell a sleep resumed with the
  // time that was left from one restarted from the beginning.
  if mockingEnabled {
    return _mock(Int64(request.pointee.tv_sec), Int64(request.pointee.tv_nsec))
  }
#endif
  return nanosleep(request, remaining)
}

#endif // !os(Windows) && !os(WASI)
