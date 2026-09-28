/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's typed allocation: malloc_type_malloc and its variants, and the
// zones', which take a malloc_type_id_t that describes what the block will
// hold. The SDK declares them only for 64-bit processes.
//
// As in Syscalls+Memory.swift, a mocked allocation records its arguments
// and fails if an error is forced; otherwise it allocates for real, so
// that the caller can use the block and free it.

#if SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)

import Darwin

// MARK: - Allocation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_malloc(
  _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(size, type) != 0 { return nil }
#endif
  return malloc_type_malloc(size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_calloc(
  _ count: Int, _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(count, size, type) != 0 { return nil }
#endif
  return malloc_type_calloc(count, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_realloc(
  _ pointer: UnsafeMutableRawPointer?, _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(pointer, size, type) != 0 { return nil }
#endif
  return malloc_type_realloc(pointer, size, type)
}

// Returns an error number, and sets `result` only on success.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_posix_memalign(
  _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
  _ alignment: Int, _ size: Int, _ type: malloc_type_id_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let error = _mockReturningErrno(alignment, size, type)
    if error != 0 { return error }
  }
#endif
  return malloc_type_posix_memalign(result, alignment, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_valloc(
  _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(size, type) != 0 { return nil }
#endif
  return malloc_type_valloc(size, type)
}

// MARK: - Zones

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_zone_malloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, size, type) != 0 { return nil }
#endif
  return malloc_type_zone_malloc(zone, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_zone_calloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ count: Int, _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, count, size, type) != 0 { return nil }
#endif
  return malloc_type_zone_calloc(zone, count, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_zone_realloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ pointer: UnsafeMutableRawPointer?,
  _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, pointer, size, type) != 0 { return nil }
#endif
  return malloc_type_zone_realloc(zone, pointer, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_zone_memalign(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ alignment: Int, _ size: Int,
  _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, alignment, size, type) != 0 { return nil }
#endif
  return malloc_type_zone_memalign(zone, alignment, size, type)
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
internal func system_malloc_type_zone_valloc(
  _ zone: UnsafeMutablePointer<malloc_zone_t>, _ size: Int, _ type: malloc_type_id_t
) -> UnsafeMutableRawPointer? {
#if ENABLE_MOCKING
  if mockingEnabled, _mock(zone, size, type) != 0 { return nil }
#endif
  return malloc_type_zone_valloc(zone, size, type)
}

#endif // SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)
