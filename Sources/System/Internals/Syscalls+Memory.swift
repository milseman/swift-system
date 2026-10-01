/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C allocator: malloc and its variants, Darwin's zones and glibc's
// extensions; and memcmp, memchr, and secure zeroing. free is system_free,
// in Syscalls+PathsAndFiles.swift, which has no mock hook.
//
// A mocked allocation records its arguments and fails if an error is
// forced; otherwise it allocates for real, so that the caller can use the
// block and free it, as system_realpath's mock returns real memory.

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

// MARK: - Allocation

internal func system_malloc(_ size: Int) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(size) != 0 { return nil }
#endif
  return malloc(size)
}

internal func system_calloc(_ count: Int, _ size: Int) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(count, size) != 0 { return nil }
#endif
  return calloc(count, size)
}

internal func system_realloc(
  _ pointer: UnsafeMutableRawPointer?, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(pointer, size) != 0 { return nil }
#endif
  return realloc(pointer, size)
}

// Returns an error number, and sets `result` only on success.
internal func system_posix_memalign(
  _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>, _ alignment: Int, _ size: Int
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let error = _mockReturningErrno(alignment, size)
    if error != 0 { return error }
  }
#endif
  return posix_memalign(result, alignment, size)
}

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
// Frees the block when it fails.
internal func system_reallocf(
  _ pointer: UnsafeMutableRawPointer?, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  // A forced failure frees the block too, as the real call would.
  if mockingEnabled, _mock(pointer, size) != 0 {
    system_free(pointer)
    return nil
  }
#endif
  return reallocf(pointer, size)
}
#endif

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
internal func system_valloc(_ size: Int) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(size) != 0 { return nil }
#endif
  return valloc(size)
}
#endif

#if os(Linux) && canImport(Glibc)
// glibc declares pvalloc in <malloc.h>, which its Swift module doesn't
// include, so it's a CSystem shim.
internal func system_pvalloc(_ size: Int) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(size) != 0 { return nil }
#endif
  return csystem_pvalloc(size)
}
#endif

// MARK: - Block sizes

#if SYSTEM_PACKAGE_DARWIN
// 0 for a pointer that no zone allocated.
internal func system_malloc_size(_ pointer: UnsafeRawPointer) -> Int {
  malloc_size(pointer)
}

internal func system_malloc_good_size(_ size: Int) -> Int {
  malloc_good_size(size)
}
#elseif os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
// glibc and wasi-libc declare malloc_usable_size in <malloc.h>, and
// FreeBSD in <malloc_np.h>, which their Swift modules don't include;
// Musl's and Bionic's modules include <malloc.h>.
internal func system_malloc_usable_size(_ pointer: UnsafeRawPointer) -> Int {
#if (os(Linux) && canImport(Glibc)) || os(FreeBSD) || os(WASI)
  return csystem_malloc_usable_size(pointer)
#elseif canImport(Musl)
  // Musl's takes a mutable pointer, which it doesn't write through.
  return malloc_usable_size(UnsafeMutableRawPointer(mutating: pointer))
#else
  return malloc_usable_size(pointer)
#endif
}
#endif

// MARK: - Darwin zones

#if SYSTEM_PACKAGE_DARWIN
internal func system_malloc_default_zone() -> UnsafeMutablePointer<malloc_zone_t> {
  malloc_default_zone()
}

// malloc_create_zone ignores its size, and its flags are libmalloc's own.
internal func system_malloc_create_zone() -> UnsafeMutablePointer<malloc_zone_t>? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock() != 0 { return nil }
#endif
  return malloc_create_zone(0, 0)
}

internal func system_malloc_destroy_zone(_ zone: UnsafeMutablePointer<malloc_zone_t>) {
#if ENABLE_MOCKING
  if mockingEnabled { _ = _mock(zone) }
#endif
  malloc_destroy_zone(zone)
}

internal func system_malloc_zone_malloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, size) != 0 { return nil }
#endif
  return malloc_zone_malloc(zone, size)
}

internal func system_malloc_zone_calloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ count: Int, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, count, size) != 0 { return nil }
#endif
  return malloc_zone_calloc(zone, count, size)
}

internal func system_malloc_zone_realloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ pointer: UnsafeMutableRawPointer?, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, pointer, size) != 0 { return nil }
#endif
  return malloc_zone_realloc(zone, pointer, size)
}

internal func system_malloc_zone_memalign(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ alignment: Int, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, alignment, size) != 0 { return nil }
#endif
  return malloc_zone_memalign(zone, alignment, size)
}

internal func system_malloc_zone_valloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ size: Int
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, size) != 0 { return nil }
#endif
  return malloc_zone_valloc(zone, size)
}

internal func system_malloc_zone_free(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ pointer: UnsafeMutableRawPointer?
) {
#if ENABLE_MOCKING
  if mockingEnabled { _ = _mock(zone, pointer) }
#endif
  malloc_zone_free(zone, pointer)
}

internal func system_malloc_zone_from_ptr(
  _ pointer: UnsafeRawPointer
) -> UnsafeMutablePointer<malloc_zone_t>? {
  malloc_zone_from_ptr(pointer)
}

// The zone copies the name.
internal func system_malloc_set_zone_name(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ name: UnsafePointer<CChar>?
) {
#if ENABLE_MOCKING
  if mockingEnabled {
    _ = _mock(zone, name.map { String(cString: $0) })
  }
#endif
  malloc_set_zone_name(zone, name)
}

internal func system_malloc_get_zone_name(
  _ zone: UnsafeMutablePointer<malloc_zone_t>
) -> UnsafePointer<CChar>? {
  malloc_get_zone_name(zone)
}

// A nil zone relieves every zone.
internal func system_malloc_zone_pressure_relief(
  _ zone: UnsafeMutablePointer<malloc_zone_t>?, _ goal: Int
) -> Int {
  malloc_zone_pressure_relief(zone, goal)
}

// A nil zone sums every zone.
internal func system_malloc_zone_statistics(
  _ zone: UnsafeMutablePointer<malloc_zone_t>?,
  _ statistics: UnsafeMutablePointer<malloc_statistics_t>
) {
  malloc_zone_statistics(zone, statistics)
}
#endif // SYSTEM_PACKAGE_DARWIN

// MARK: - glibc extensions

#if os(Linux) && canImport(Glibc)
// These are CSystem shims, since glibc declares them in <malloc.h>.

// 1 if memory was released, else 0.
internal func system_malloc_trim(_ pad: Int) -> CInt {
  csystem_malloc_trim(pad)
}

// 1 on success, else 0, without setting errno.
internal func system_mallopt(_ parameter: CInt, _ value: CInt) -> CInt {
  csystem_mallopt(parameter, value)
}

internal func system_mallinfo2() -> csystem_mallinfo2 {
  var info = csystem_mallinfo2()
  csystem_get_mallinfo2(&info)
  return info
}

internal func system_malloc_info(_ options: CInt, _ stream: UnsafeMutableRawPointer) -> CInt {
  csystem_malloc_info(options, stream)
}

internal func system_malloc_stats() {
  csystem_malloc_stats()
}

// For malloc_info, which writes to a stream. The text, which the caller
// frees, is complete once the stream is closed.
internal func system_open_memstream(
  _ text: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, _ length: UnsafeMutablePointer<Int>
) -> UnsafeMutablePointer<FILE>? {
  open_memstream(text, length)
}
// The stream closes with Syscalls+Provisional.swift's system_fclose.
#endif // os(Linux) && canImport(Glibc)

// MARK: - Memory functions

internal func system_memcmp(
  _ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer, _ count: Int
) -> CInt {
  memcmp(lhs, rhs, count)
}

internal func system_memchr(
  _ start: UnsafeRawPointer, _ byte: CInt, _ count: Int
) -> UnsafeMutableRawPointer? {
  memchr(start, byte, count)
}

// Stores that the compiler can't remove, as it can a memset of memory that
// isn't read again.
#if SYSTEM_PACKAGE_DARWIN
// Fails only for a null pointer, or a count over RSIZE_MAX or `size`.
internal func system_memset_s(
  _ start: UnsafeMutableRawPointer, _ size: Int, _ byte: CInt, _ count: Int
) -> CInt {
  memset_s(start, size, byte, count)
}
#else
// Bionic's explicit_bzero isn't at every API level, so on Android this is
// a CSystem shim.
internal func system_explicit_bzero(_ start: UnsafeMutableRawPointer, _ count: Int) {
#if os(Android)
  csystem_explicit_bzero(start, count)
#else
  explicit_bzero(start, count)
#endif
}
#endif

#endif // !os(Windows)
