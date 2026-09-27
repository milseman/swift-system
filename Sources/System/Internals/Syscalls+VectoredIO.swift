/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Vectored reads and writes: readv, writev, preadv and pwritev.

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

// Bionic's declarations take a nonnull array, so these do too, even when
// the count is zero.

internal func system_readv(
  _ fd: CInt, _ vectors: UnsafePointer<iovec>, _ count: CInt
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, vectors, count) }
#endif
  return readv(fd, vectors, count)
}

internal func system_writev(
  _ fd: CInt, _ vectors: UnsafePointer<iovec>, _ count: CInt
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, vectors, count) }
#endif
  return writev(fd, vectors, count)
}

// Darwin added preadv and pwritev in macOS 11, and Bionic in API level 24,
// below which CSystem's shims fail with ENOSYS.

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
internal func system_preadv(
  _ fd: CInt, _ vectors: UnsafePointer<iovec>, _ count: CInt, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, vectors, count, offset) }
#endif
#if os(Android)
  return csystem_preadv(fd, vectors, count, offset)
#else
  return preadv(fd, vectors, count, offset)
#endif
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
internal func system_pwritev(
  _ fd: CInt, _ vectors: UnsafePointer<iovec>, _ count: CInt, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, vectors, count, offset) }
#endif
#if os(Android)
  return csystem_pwritev(fd, vectors, count, offset)
#else
  return pwritev(fd, vectors, count, offset)
#endif
}

#endif // !os(Windows) && !os(WASI)
