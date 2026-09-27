/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Memory mapping: mmap, munmap, mprotect, msync, madvise and mincore.

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

// Returns nil for MAP_FAILED, which every platform defines as -1, and which
// Bionic's non-optional result can't express as nil.
internal func system_mmap(
  _ length: Int, _ protection: CInt, _ flags: CInt, _ fd: CInt, _ offset: off_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  // A mocked success returns an address that the caller must not touch.
  if mockingEnabled {
    return _mock(length, protection, flags, fd, offset) == 0
      ? UnsafeMutableRawPointer(bitPattern: 0x1000) : nil
  }
#endif
  let result: UnsafeMutableRawPointer? = mmap(nil, length, protection, flags, fd, offset)
  return result == UnsafeMutableRawPointer(bitPattern: -1) ? nil : result
}

internal func system_munmap(_ start: UnsafeMutableRawPointer, _ length: Int) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start, length) }
#endif
  return munmap(start, length)
}

internal func system_mprotect(
  _ start: UnsafeMutableRawPointer, _ length: Int, _ protection: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start, length, protection) }
#endif
  return mprotect(start, length, protection)
}

internal func system_msync(
  _ start: UnsafeMutableRawPointer, _ length: Int, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start, length, flags) }
#endif
  return msync(start, length, flags)
}

internal func system_madvise(
  _ start: UnsafeMutableRawPointer, _ length: Int, _ advice: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start, length, advice) }
#endif
  return madvise(start, length, advice)
}

#if !os(OpenBSD)
// The vector has a byte for each page. Darwin and FreeBSD type it as
// char, and Linux as unsigned char.
internal func system_mincore(
  _ start: UnsafeMutableRawPointer, _ length: Int, _ vector: UnsafeMutableRawPointer
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(start, length, vector) }
#endif
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  return mincore(start, length, vector.assumingMemoryBound(to: CChar.self))
#else
  return mincore(start, length, vector.assumingMemoryBound(to: UInt8.self))
#endif
}
#endif

#endif // !os(Windows) && !os(WASI)
