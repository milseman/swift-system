/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// System call wrappers for the options of a new socket: accept4, and on
// Darwin, which has neither accept4 nor the SOCK_* flags, fcntl.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
@_implementationOnly import CSystem
import Glibc
#elseif canImport(Musl)
@_implementationOnly import CSystem
import Musl
#elseif canImport(Android)
@_implementationOnly import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

#if !SYSTEM_PACKAGE_DARWIN
// glibc and Musl declare accept4 only with _GNU_SOURCE, which CSystem's
// shims.c defines.
internal func system_accept4(
  _ socket: CInt,
  _ addr: UnsafeMutablePointer<sockaddr>?,
  _ len: UnsafeMutablePointer<socklen_t>?,
  _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(socket, addr, len, flags) }
#endif
  return csystem_accept4(socket, addr, len, flags)
}
#endif

#if SYSTEM_PACKAGE_DARWIN
internal func system_fcntl(_ fd: CInt, _ cmd: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, cmd) }
#endif
  return fcntl(fd, cmd)
}

internal func system_fcntl(_ fd: CInt, _ cmd: CInt, _ value: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, cmd, value) }
#endif
  return fcntl(fd, cmd, value)
}
#endif
