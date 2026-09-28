/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: which of the C allocator's calls a buffer uses, and what its
// deinit checks. Not API; see Prototype/Memory/README.md.

import SystemPackage

@available(System 199, *)
extension Memory {
  /// The C allocator's calls for one buffer: the default allocator's or
  /// a zone's, aligned or not.
  @frozen
  @usableFromInline
  internal struct _Allocator {
    #if canImport(Darwin)
    /// The zone, or nil for the default allocator's calls.
    @usableFromInline
    internal var zone: Memory.Zone?
    #endif

    /// The alignment to keep, or 0 when the allocator's own is enough.
    @usableFromInline
    internal var alignment: Int

    /// The alignment every C allocation has: two words, which is 16 bytes
    /// on 64-bit platforms (Darwin, glibc, Musl, Bionic).
    @usableFromInline
    internal static var _fundamentalAlignment: Int { 2 * MemoryLayout<Int>.size }

    @inlinable
    internal init(alignment: Int) {
      #if canImport(Darwin)
      self.zone = nil
      #endif
      self.alignment = alignment <= Self._fundamentalAlignment ? 0 : alignment
    }

    #if canImport(Darwin)
    @inlinable
    internal init(zone: Memory.Zone, alignment: Int) {
      self.init(alignment: alignment)
      self.zone = zone
    }
    #endif

    @usableFromInline
    internal func allocate(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
      #if canImport(Darwin)
      if let zone {
        return alignment == 0
          ? try zone.allocate(byteCount: byteCount)
          : try zone.allocate(byteCount: byteCount, alignment: alignment)
      }
      #endif
      return alignment == 0
        ? try Memory.allocate(byteCount: byteCount)
        : try Memory.allocate(byteCount: byteCount, alignment: alignment)
    }

    @usableFromInline
    internal func allocateZeroed(count: Int, stride: Int) throws(Errno) -> UnsafeMutableRawPointer {
      if alignment != 0 {
        // No aligned calloc: allocate, then zero.
        let (byteCount, overflow) = count.multipliedReportingOverflow(by: stride)
        guard !overflow else { throw .noMemory }
        let start = try allocate(byteCount: byteCount)
        start.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)
        return start
      }
      #if canImport(Darwin)
      if let zone { return try zone.allocateZeroed(count: count, stride: stride) }
      #endif
      return try Memory.allocateZeroed(count: count, stride: stride)
    }

    /// Resizes a block, keeping its first `preserving` bytes, and its
    /// alignment, which realloc doesn't keep.
    @usableFromInline
    internal func reallocate(
      _ start: UnsafeMutableRawPointer, byteCount: Int, preserving: Int
    ) throws(Errno) -> UnsafeMutableRawPointer {
      if alignment != 0 {
        let moved = try allocate(byteCount: byteCount)
        moved.copyMemory(from: start, byteCount: Swift.min(preserving, byteCount))
        free(start)
        return moved
      }
      #if canImport(Darwin)
      if let zone { return try zone.reallocate(start, byteCount: byteCount) }
      #endif
      return try Memory.reallocate(start, byteCount: byteCount)
    }

    /// The size of the block the allocator would give a request,
    /// so that a buffer can ask for all of it.
    @usableFromInline
    internal func goodSize(for byteCount: Int) -> Int {
      #if canImport(Darwin)
      return Memory.goodSize(for: byteCount)
      #else
      return byteCount
      #endif
    }

    @usableFromInline
    internal func free(_ start: UnsafeMutableRawPointer) {
      #if canImport(Darwin)
      if let zone { return zone.free(start) }
      #endif
      Memory.free(start)
    }
  }
}

// MARK: - Deinit policies

// What a buffer's deinit does before it frees, which is OwnedFD's open
// question (decision 54) for an owner whose release can't fail. The
// prototype's default is FREE: the deinit frees, and has no error to
// drop. run.sh builds the scenarios under each:
//
// - MEMORY_POLICY_MUST_FREE traps when a deinit runs at all, so that every
//   buffer ends in free() or relinquish(), as the must-close policy does
//   for descriptors.
// - MEMORY_POLICY_CHECKED traps when the block isn't a live allocation
//   (Darwin's malloc_size of it is 0), catching memory adopted with
//   init(unsafeTaking:) that something else freed, before libmalloc's own
//   abort, as the EBADF policy does for descriptors.

@available(System 199, *)
@usableFromInline
internal func _deinitPolicy<Element>(
  _ start: UnsafeMutablePointer<Element>, allocator: Memory._Allocator
) {
  #if MEMORY_POLICY_MUST_FREE
  preconditionFailure("a buffer was dropped without free() or relinquish()")
  #elseif MEMORY_POLICY_CHECKED && canImport(Darwin)
  precondition(Memory.usableSize(of: start) > 0, "a buffer's memory was freed by something else")
  #endif
}
