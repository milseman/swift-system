/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Interval timers and scheduling priorities: getitimer, setitimer, alarm,
// nice, getpriority and setpriority.

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

internal func system_getitimer(
  _ which: CInt, _ value: UnsafeMutablePointer<itimerval>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(which) }
#endif
  return getitimer(numericCast(which), value)
}

// Records the new value by value: its expiration's seconds and
// microseconds, then its interval's.
internal func system_setitimer(
  _ which: CInt, _ value: UnsafePointer<itimerval>,
  _ oldValue: UnsafeMutablePointer<itimerval>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let v = value.pointee
    return _mock(
      which, Int64(v.it_value.tv_sec), Int64(v.it_value.tv_usec),
      Int64(v.it_interval.tv_sec), Int64(v.it_interval.tv_usec))
  }
#endif
  return setitimer(numericCast(which), value, oldValue)
}

// alarm can't fail, so it has no mock hook.
internal func system_alarm(_ seconds: CUnsignedInt) -> CUnsignedInt {
  alarm(seconds)
}

// Returns the new nice value, which can be -1; errno says whether it failed.
internal func system_nice(_ increment: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(increment) }
#endif
  return nice(increment)
}

// Returns the nice value, which can be -1; errno says whether it failed.
internal func system_getpriority(_ which: CInt, _ who: id_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(which, who) }
#endif
  return getpriority(numericCast(which), who)
}

internal func system_setpriority(_ which: CInt, _ who: id_t, _ priority: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(which, who, priority) }
#endif
  return setpriority(numericCast(which), who, priority)
}

#endif // !os(Windows) && !os(WASI)
