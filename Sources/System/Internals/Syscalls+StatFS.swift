/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The file system statistics calls behind StatFS: statfs, fstatfs and
// getfsstat on Darwin and BSD, and statvfs and fstatvfs elsewhere, plus
// statfs and fstatfs on Linux and Android for FileSystemType, and quotactl
// on Darwin for DiskQuota. The mocks record the buffer as a pointer.

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

// Records the buffer as a pointer, which is nil when counting.
internal func system_getfsstat(
  _ buffer: UnsafeMutablePointer<statfs>?, _ byteCount: Int, _ mode: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(buffer, byteCount, mode) }
#endif
  // The byte count is an int on Darwin, a long on FreeBSD, and a size_t on
  // OpenBSD.
  return getfsstat(buffer, numericCast(byteCount), mode)
}

#if SYSTEM_PACKAGE_DARWIN
// Records the buffer as a pointer.
internal func system_quotactl(
  _ path: UnsafePointer<CChar>, _ command: CInt, _ id: CInt,
  _ buffer: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, command, id, buffer) }
#endif
  return quotactl(path, command, id, buffer.assumingMemoryBound(to: CChar.self))
}
#endif // SYSTEM_PACKAGE_DARWIN
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

#if os(Linux) || os(Android)
// statfs and fstatfs, for FileSystemType: the f_type field, which statvfs
// doesn't have. The shims return only that field; see CSystemLinux.h.
internal func system_statfs(
  _ path: UnsafePointer<CChar>, _ type: UnsafeMutablePointer<CUnsignedLong>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, type) }
#endif
  return csystem_statfs_type(path, type)
}

internal func system_fstatfs(
  _ fd: CInt, _ type: UnsafeMutablePointer<CUnsignedLong>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, type) }
#endif
  return csystem_fstatfs_type(fd, type)
}
#endif // os(Linux) || os(Android)

#endif // !os(Windows)
