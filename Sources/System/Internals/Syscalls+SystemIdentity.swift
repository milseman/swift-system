/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The system's names: uname, gethostname, and getlogin_r.

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

internal func system_uname(_ names: UnsafeMutablePointer<utsname>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(names) }
#endif
  return uname(names)
}

// Bionic declares gethostname only from API level 23, and implements it
// with uname, which SystemIdentity.hostName() calls there instead.
#if !os(Android)
internal func system_gethostname(
  _ name: UnsafeMutablePointer<CChar>, _ length: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(name, length) }
#endif
  return gethostname(name, numericCast(length))
}
#endif

#if os(Android)
// Bionic declares getlogin_r only from API level 28.
internal func system_getlogin() -> UnsafeMutablePointer<CChar>? {
  getlogin()
}
#else
// getlogin_r returns an error number, rather than setting errno.
internal func system_getlogin_r(
  _ name: UnsafeMutablePointer<CChar>, _ length: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(name, length) }
#endif
  return getlogin_r(name, numericCast(length))
}
#endif

#endif // !os(Windows) && !os(WASI)
