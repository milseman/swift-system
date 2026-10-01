/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Broken-down time: gmtime_r, localtime_r, timegm, mktime, strftime and
// tzset.

#if !os(Windows)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
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

internal func system_gmtime_r(
  _ time: UnsafePointer<time_t>, _ result: UnsafeMutablePointer<tm>
) -> UnsafeMutablePointer<tm>? {
#if ENABLE_MOCKING
  // The time by value. A mocked success leaves the result as it was.
  if mockingEnabled { return _mock(Int(time.pointee)) == 0 ? result : nil }
#endif
  return gmtime_r(time, result)
}

internal func system_localtime_r(
  _ time: UnsafePointer<time_t>, _ result: UnsafeMutablePointer<tm>
) -> UnsafeMutablePointer<tm>? {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(Int(time.pointee)) == 0 ? result : nil }
#endif
  return localtime_r(time, result)
}

#if ENABLE_MOCKING
// The fields that timegm and mktime read, by value.
private func _mockFields(
  name: String = #function, _ time: UnsafeMutablePointer<tm>
) -> time_t {
  let t = time.pointee
  return time_t(_mock(
    name: name, t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec,
    t.tm_isdst))
}
#endif

internal func system_timegm(_ time: UnsafeMutablePointer<tm>) -> time_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockFields(time) }
#endif
  return timegm(time)
}

internal func system_mktime(_ time: UnsafeMutablePointer<tm>) -> time_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockFields(time) }
#endif
  return mktime(time)
}

// strftime reports no errors, only a result that doesn't fit, so it has no
// mock hook; nor does tzset, which can't fail.
internal func system_strftime(
  _ buffer: UnsafeMutablePointer<CChar>, _ capacity: Int,
  _ format: UnsafePointer<CChar>, _ time: UnsafePointer<tm>
) -> Int {
  strftime(buffer, capacity, format, time)
}

// wasi-libc has no time zones, and no tzset: its local time is UTC.
internal func system_tzset() {
#if !os(WASI)
  tzset()
#endif
}

#endif // !os(Windows)
