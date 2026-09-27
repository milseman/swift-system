/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Pseudoterminals: posix_openpt, grantpt, unlockpt, and ptsname_r.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

// glibc declares posix_openpt and its companions only with _XOPEN_SOURCE or
// _GNU_SOURCE, which Swift's Glibc module doesn't define, so CSystem wraps
// them on Linux and Android.

internal func system_posix_openpt(_ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(flags) }
#endif
  #if os(Linux) || os(Android)
  return csystem_posix_openpt(flags)
  #else
  return posix_openpt(flags)
  #endif
}

internal func system_grantpt(_ fd: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  #if os(Linux) || os(Android)
  return csystem_grantpt(fd)
  #else
  return grantpt(fd)
  #endif
}

internal func system_unlockpt(_ fd: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  #if os(Linux) || os(Android)
  return csystem_unlockpt(fd)
  #else
  return unlockpt(fd)
  #endif
}

// Returns an error number, as the Linux C libraries' ptsname_r does. Darwin's
// returns -1 and sets errno, which this converts.
@available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
internal func system_ptsname_r(
  _ fd: CInt, _ buffer: UnsafeMutablePointer<CChar>, _ length: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(fd, length) }
#endif
  #if os(Linux) || os(Android)
  return csystem_ptsname_r(fd, buffer, length)
  #else
  return ptsname_r(fd, buffer, length) == 0 ? 0 : system_errno
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
