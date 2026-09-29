/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's typed allocation: Memory's and Memory.Zone's allocations, with
// a TypeDescriptor of what the block will hold. A typed block is freed as
// any other: C compilers that describe allocations don't rewrite free, so
// malloc_type_free and malloc_type_zone_free, which take a type too, aren't
// wrapped.

#if SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)

import Darwin

@available(System 199, *)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension Memory {
  /// Allocates memory for values of a described type,
  /// whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// Free the block with ``free(_:)``.
  /// See ``allocate(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_malloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func allocate(
    byteCount: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal static func _allocate(
    byteCount: Int, type: TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_malloc_type_malloc(_requestSize(byteCount), type.rawValue))
  }

  /// Allocates memory for values of a described type, filled with zeros.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// See ``allocateZeroed(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_calloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func allocateZeroed(
    byteCount: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: 1, stride: byteCount, type: type).get()
  }

  /// Allocates memory for a number of values of a described type,
  /// filled with zeros.
  ///
  /// - Parameters:
  ///   - count: The number of elements, which can't be negative.
  ///   - stride: The number of bytes from one element to the next,
  ///     which can't be negative, such as `MemoryLayout<T>.stride`.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// See ``allocateZeroed(count:stride:)``.
  ///
  /// The corresponding C function is `malloc_type_calloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func allocateZeroed(
    count: Int, stride: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: count, stride: stride, type: type).get()
  }

  @usableFromInline
  internal static func _allocateZeroed(
    count: Int, stride: Int, type: TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    let (count, stride) = _requestSizes(count, stride)
    return _allocated(system_malloc_type_calloc(count, stride, type.rawValue))
  }

  /// Allocates memory for values of a described type,
  /// at an address that's a multiple of an alignment,
  /// whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - alignment: The alignment, in bytes, which must be a power of two.
  ///     An alignment smaller than a pointer's size is raised to it.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block.
  ///
  /// See ``allocate(byteCount:alignment:)``,
  /// which also covers `malloc_type_aligned_alloc`.
  ///
  /// The corresponding C function is `malloc_type_posix_memalign`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func allocate(
    byteCount: Int, alignment: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, alignment: alignment, type: type).get()
  }

  @usableFromInline
  internal static func _allocate(
    byteCount: Int, alignment: Int, type: TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    let size = _requestSize(byteCount)
    guard let alignment = _requestAlignment(alignment) else { return .failure(.invalidArgument) }
    var start: UnsafeMutableRawPointer? = nil
    let error = system_malloc_type_posix_memalign(&start, alignment, size, type.rawValue)
    guard error == 0 else { return .failure(Errno(rawValue: error)) }
    return _allocated(start)
  }

  /// Allocates memory for values of a described type,
  /// that starts at a page boundary, whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block.
  ///
  /// See ``allocatePageAligned(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_valloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func allocatePageAligned(
    byteCount: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocatePageAligned(byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal static func _allocatePageAligned(
    byteCount: Int, type: TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_malloc_type_valloc(_requestSize(byteCount), type.rawValue))
  }

  /// Resizes a block of values of a described type,
  /// moving it if it can't grow in place.
  ///
  /// - Parameters:
  ///   - pointer: The start of a block that the C allocator allocated,
  ///     or `nil` to allocate a new one.
  ///   - byteCount: The block's new size, which can't be negative.
  ///     Zero resizes the block to one byte.
  ///   - type: What the block holds.
  /// - Returns: The start of the resized block, which can differ from `pointer`:
  ///   when this method returns, use only the returned pointer.
  ///
  /// If this method throws, the original block is unchanged,
  /// and still yours to free.
  /// See ``reallocate(_:byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_realloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public static func reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int, type: TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _reallocate(pointer, byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal static func _reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int, type: TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_malloc_type_realloc(pointer, _requestSize(byteCount), type.rawValue))
  }
}

// MARK: - Zones

@available(System 199, *)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension Memory.Zone {
  /// Allocates memory in the zone for values of a described type,
  /// whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// See ``allocate(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_malloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func allocate(
    byteCount: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal func _allocate(
    byteCount: Int, type: Memory.TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(
      system_malloc_type_zone_malloc(rawValue, Memory._requestSize(byteCount), type.rawValue))
  }

  /// Allocates memory in the zone for values of a described type,
  /// filled with zeros.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// See ``allocateZeroed(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_calloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func allocateZeroed(
    byteCount: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: 1, stride: byteCount, type: type).get()
  }

  /// Allocates memory in the zone for a number of values
  /// of a described type, filled with zeros.
  ///
  /// - Parameters:
  ///   - count: The number of elements, which can't be negative.
  ///   - stride: The number of bytes from one element to the next,
  ///     which can't be negative, such as `MemoryLayout<T>.stride`.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// See ``allocateZeroed(count:stride:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_calloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func allocateZeroed(
    count: Int, stride: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: count, stride: stride, type: type).get()
  }

  @usableFromInline
  internal func _allocateZeroed(
    count: Int, stride: Int, type: Memory.TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    let (count, stride) = Memory._requestSizes(count, stride)
    return Memory._allocated(system_malloc_type_zone_calloc(rawValue, count, stride, type.rawValue))
  }

  /// Allocates memory in the zone for values of a described type,
  /// at an address that's a multiple of an alignment,
  /// whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - alignment: The alignment, in bytes, which must be a power of two.
  ///     An alignment smaller than a pointer's size is raised to it.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block.
  ///
  /// See ``allocate(byteCount:alignment:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_memalign`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func allocate(
    byteCount: Int, alignment: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, alignment: alignment, type: type).get()
  }

  @usableFromInline
  internal func _allocate(
    byteCount: Int, alignment: Int, type: Memory.TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    let size = Memory._requestSize(byteCount)
    guard let alignment = Memory._requestAlignment(alignment) else {
      return .failure(.invalidArgument)
    }
    return Memory._allocated(
      system_malloc_type_zone_memalign(rawValue, alignment, size, type.rawValue))
  }

  /// Allocates memory in the zone for values of a described type,
  /// that starts at a page boundary.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - type: What the block will hold.
  /// - Returns: The start of the new block.
  ///
  /// See ``allocatePageAligned(byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_valloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func allocatePageAligned(
    byteCount: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocatePageAligned(byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal func _allocatePageAligned(
    byteCount: Int, type: Memory.TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(
      system_malloc_type_zone_valloc(rawValue, Memory._requestSize(byteCount), type.rawValue))
  }

  /// Resizes a block of the zone that holds values of a described type,
  /// moving it if it can't grow in place.
  ///
  /// - Parameters:
  ///   - pointer: The start of a block of this zone,
  ///     or `nil` to allocate a new one.
  ///   - byteCount: The block's new size, which can't be negative.
  ///     Zero resizes the block to one byte.
  ///   - type: What the block holds.
  /// - Returns: The start of the resized block, which can differ from `pointer`:
  ///   when this method returns, use only the returned pointer.
  ///
  /// If this method throws, the original block is unchanged,
  /// and still yours to free.
  /// See ``reallocate(_:byteCount:)``.
  ///
  /// The corresponding C function is `malloc_type_zone_realloc`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @_alwaysEmitIntoClient
  public func reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int, type: Memory.TypeDescriptor
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _reallocate(pointer, byteCount: byteCount, type: type).get()
  }

  @usableFromInline
  internal func _reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int, type: Memory.TypeDescriptor
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    Memory._allocated(
      system_malloc_type_zone_realloc(
        rawValue, pointer, Memory._requestSize(byteCount), type.rawValue))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)
