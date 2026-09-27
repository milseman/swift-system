/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The file system statistics calls behind StatFS: statfs and fstatfs on
// Darwin and BSD, and statvfs and fstatvfs elsewhere. The mocks record the
// buffer as a pointer.

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

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
internal func system_statfs(
  _ path: UnsafePointer<CChar>, _ buffer: UnsafeMutablePointer<statfs>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, buffer) }
#endif
  return statfs(path, buffer)
}

internal func system_fstatfs(
  _ fd: CInt, _ buffer: UnsafeMutablePointer<statfs>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, buffer) }
#endif
  return fstatfs(fd, buffer)
}
#else
internal func system_statvfs(
  _ path: UnsafePointer<CChar>, _ buffer: UnsafeMutablePointer<statvfs>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, buffer) }
#endif
  return statvfs(path, buffer)
}

internal func system_fstatvfs(
  _ fd: CInt, _ buffer: UnsafeMutablePointer<statvfs>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, buffer) }
#endif
  return fstatvfs(fd, buffer)
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#endif // !os(Windows)
