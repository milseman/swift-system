/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

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

/// A namespace for the C library's memory allocator,
/// and for its calls that compare, search, and clear memory.
///
///     let buffer = try Memory.allocate(byteCount: 4096)
///     defer { Memory.free(buffer) }
///
/// This is the allocator of C's `malloc` and `free`,
/// so C code can free a block that these methods allocate,
/// and ``free(_:)`` frees a block that C code allocated with `malloc`.
/// The standard library's allocation,
/// such as `UnsafeMutableRawPointer.allocate(byteCount:alignment:)`,
/// isn't guaranteed to be the same allocator:
/// don't free one's memory with the other's call.
///
/// The methods that allocate throw ``Errno/noMemory``
/// when there isn't enough memory, and trap for a negative size.
/// A size of zero allocates one byte,
/// so that on every platform an allocation returns a block to free.
@available(System 199, *)
public enum Memory {}

// MARK: - Allocation

@available(System 199, *)
extension Memory {
  /// Allocates memory, whose contents are uninitialized.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// Free the block with ``free(_:)``.
  ///
  /// The corresponding C function is `malloc`.
  @_alwaysEmitIntoClient
  public static func allocate(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _allocate(byteCount: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_malloc(_requestSize(byteCount)))
  }

  /// Allocates memory filled with zeros.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// This can be faster than allocating and then zeroing the memory:
  /// memory that comes fresh from the system is zeros already.
  ///
  /// The corresponding C function is `calloc`.
  @_alwaysEmitIntoClient
  public static func allocateZeroed(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: 1, stride: byteCount).get()
  }

  /// Allocates memory filled with zeros, for a number of elements.
  ///
  /// - Parameters:
  ///   - count: The number of elements, which can't be negative.
  ///   - stride: The number of bytes from one element to the next,
  ///     which can't be negative, such as `MemoryLayout<T>.stride`.
  /// - Returns: The start of the new block,
  ///   aligned for any of C's types.
  ///
  /// A total size too large to represent throws ``Errno/noMemory``,
  /// where multiplying `count` by `stride` yourself would trap.
  /// A total of zero allocates one byte.
  ///
  /// The corresponding C function is `calloc`.
  @_alwaysEmitIntoClient
  public static func allocateZeroed(count: Int, stride: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocateZeroed(count: count, stride: stride).get()
  }

  @usableFromInline
  internal static func _allocateZeroed(count: Int, stride: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    let (count, stride) = _requestSizes(count, stride)
    return _allocated(system_calloc(count, stride))
  }

  /// Allocates memory at an address that's a multiple of an alignment,
  /// whose contents are uninitialized.
  ///
  /// - Parameters:
  ///   - byteCount: The number of bytes to allocate,
  ///     which can't be negative. Zero allocates one byte.
  ///   - alignment: The alignment, in bytes, which must be a power of two.
  ///     An alignment smaller than a pointer's size is raised to it,
  ///     which `posix_memalign` requires.
  /// - Returns: The start of the new block.
  ///
  /// An alignment that isn't a power of two
  /// throws ``Errno/invalidArgument``.
  /// ``reallocate(_:byteCount:)`` can move the block
  /// to an address without the alignment.
  ///
  /// This covers C's other aligned allocators, `aligned_alloc` and
  /// `memalign`, whose rules for sizes and small alignments differ by platform:
  /// Darwin's `aligned_alloc` rejects a size that isn't a multiple of
  /// the alignment.
  ///
  /// The corresponding C function is `posix_memalign`.
  @_alwaysEmitIntoClient
  public static func allocate(byteCount: Int, alignment: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocate(byteCount: byteCount, alignment: alignment).get()
  }

  @usableFromInline
  internal static func _allocate(
    byteCount: Int, alignment: Int
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    let size = _requestSize(byteCount)
    guard let alignment = _requestAlignment(alignment) else { return .failure(.invalidArgument) }
    var start: UnsafeMutableRawPointer? = nil
    let error = system_posix_memalign(&start, alignment, size)
    guard error == 0 else { return .failure(Errno(rawValue: error)) }
    return _allocated(start)
  }

  /// Resizes a block, moving it if it can't grow in place.
  ///
  /// - Parameters:
  ///   - pointer: The start of a block that the C allocator allocated,
  ///     or `nil` to allocate a new one.
  ///   - byteCount: The block's new size, which can't be negative.
  ///     Zero resizes the block to one byte.
  /// - Returns: The start of the resized block, which can differ from `pointer`:
  ///   when this method returns, use only the returned pointer.
  ///
  /// The block keeps its contents, up to the smaller of its old and new sizes;
  /// the bytes it gains are uninitialized, even in a block that
  /// ``allocateZeroed(byteCount:)`` allocated.
  ///
  /// If this method throws, the original block is unchanged,
  /// and still yours to free.
  ///
  /// The corresponding C function is `realloc`.
  @_alwaysEmitIntoClient
  public static func reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _reallocate(pointer, byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _reallocate(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_realloc(pointer, _requestSize(byteCount)))
  }

  /// Frees a block that the C allocator allocated.
  ///
  /// - Parameter pointer: The start of the block,
  ///   or `nil`, which does nothing.
  ///
  /// Freeing a block twice, or memory that the C allocator didn't allocate,
  /// is undefined behavior, which usually crashes the process.
  /// On Darwin, this frees a block of any zone.
  ///
  /// The corresponding C function is `free`.
  @_alwaysEmitIntoClient
  public static func free(_ pointer: UnsafeMutableRawPointer?) {
    _free(pointer)
  }

  @usableFromInline
  internal static func _free(_ pointer: UnsafeMutableRawPointer?) {
    system_free(pointer)
  }
}

// MARK: - Platform allocators

@available(System 199, *)
extension Memory {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  /// Resizes a block, moving it if it can't grow in place,
  /// and frees it if resizing fails.
  ///
  /// - Parameters:
  ///   - pointer: The start of a block that the C allocator allocated,
  ///     or `nil` to allocate a new one.
  ///   - byteCount: The block's new size, which can't be negative.
  ///     Zero resizes the block to one byte.
  /// - Returns: The start of the resized block, which can differ from `pointer`.
  ///
  /// If this method throws, it has freed the original block:
  /// don't use `pointer` again.
  /// Otherwise, it's ``reallocate(_:byteCount:)``.
  ///
  /// The corresponding C function is `reallocf`.
  /// - Note: Only available on Darwin and FreeBSD.
  @_alwaysEmitIntoClient
  public static func reallocateFreeingOnFailure(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) throws(Errno) -> UnsafeMutableRawPointer {
    try _reallocateFreeingOnFailure(pointer, byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _reallocateFreeingOnFailure(
    _ pointer: UnsafeMutableRawPointer?, byteCount: Int
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_reallocf(pointer, _requestSize(byteCount)))
  }
  #endif

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
  /// Allocates memory that starts at a page boundary,
  /// whose contents are uninitialized.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative. Zero allocates one byte.
  /// - Returns: The start of the new block.
  ///
  /// The page size is ``SystemConfig/Name/pageSize``'s value.
  /// On every platform, ``allocate(byteCount:alignment:)``
  /// with that alignment does the same.
  ///
  /// The corresponding C function is `valloc`.
  /// - Note: Only available on Darwin, Linux, and FreeBSD.
  @_alwaysEmitIntoClient
  public static func allocatePageAligned(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocatePageAligned(byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _allocatePageAligned(byteCount: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_valloc(_requestSize(byteCount)))
  }
  #endif

  #if os(Linux) && canImport(Glibc)
  /// Allocates whole pages: memory that starts at a page boundary,
  /// with its size rounded up to a multiple of the page size,
  /// whose contents are uninitialized.
  ///
  /// - Parameter byteCount: The number of bytes to allocate at least,
  ///   which can't be negative. Zero allocates one page.
  /// - Returns: The start of the new block.
  ///
  /// The corresponding C function is `pvalloc`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static func allocatePages(byteCount: Int) throws(Errno) -> UnsafeMutableRawPointer {
    try _allocatePages(byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _allocatePages(byteCount: Int) -> Result<UnsafeMutableRawPointer, Errno> {
    _allocated(system_pvalloc(_requestSize(byteCount)))
  }
  #endif
}

// MARK: - Requests

@available(System 199, *)
extension Memory {
  /// The size to ask the C allocator for.
  ///
  /// A negative size is the caller's error, which C would take as an
  /// enormous one. C lets an allocation of zero bytes return either a
  /// block or NULL, which couldn't then mean failure, and C23 makes
  /// `realloc` of zero bytes undefined, so zero is one byte.
  @usableFromInline
  internal static func _requestSize(_ byteCount: Int) -> Int {
    precondition(byteCount >= 0, "byteCount can't be negative")
    return max(byteCount, 1)
  }

  /// The element count and stride to ask `calloc` for, with a total of
  /// zero asked as one byte.
  @usableFromInline
  internal static func _requestSizes(_ count: Int, _ stride: Int) -> (Int, Int) {
    precondition(count >= 0 && stride >= 0, "count and stride can't be negative")
    return count == 0 || stride == 0 ? (1, 1) : (count, stride)
  }

  /// The alignment to ask the C allocator for, or nil if `alignment`
  /// isn't a power of two. Smaller alignments than a pointer's are raised
  /// to a pointer's, which posix_memalign and Darwin's zones require.
  @usableFromInline
  internal static func _requestAlignment(_ alignment: Int) -> Int? {
    guard alignment > 0 && alignment.nonzeroBitCount == 1 else { return nil }
    return max(alignment, MemoryLayout<UnsafeRawPointer>.size)
  }

  /// The block an allocation returned, or `noMemory` for NULL.
  ///
  /// The error isn't read from errno: C's allocators have no failure but
  /// running out of memory, since the arguments were checked first, and
  /// Darwin's zones needn't set errno at all.
  @usableFromInline
  internal static func _allocated(
    _ start: UnsafeMutableRawPointer?
  ) -> Result<UnsafeMutableRawPointer, Errno> {
    guard let start else { return .failure(.noMemory) }
    return .success(start)
  }
}

// MARK: - C function values

@available(System 199, *)
extension Memory {
  /// C's `malloc`, as a C function value,
  /// for a C library or a hook that takes an allocator's functions.
  ///
  ///     let allocator = ByteBufferAllocator(
  ///       allocate: Memory.allocateFunction,
  ///       reallocate: { Memory.reallocateFunction($0, $2) },
  ///       deallocate: { Memory.freeFunction($0) },
  ///       copy: { $0.copyMemory(from: $1, byteCount: $2) })
  ///
  /// This is C's function, with C's rules:
  /// it returns `nil` when it fails, and never traps,
  /// and what it does with a size of zero differs by platform.
  /// Swift code should call ``allocate(byteCount:)``.
  ///
  /// The corresponding C function is `malloc`.
  @_alwaysEmitIntoClient
  public static var allocateFunction: @convention(c) (Int) -> UnsafeMutableRawPointer? {
    malloc
  }

  /// C's `calloc`, as a C function value,
  /// for a C library or a hook that takes an allocator's functions.
  ///
  /// This is C's function, with C's rules:
  /// it returns `nil` when it fails, and never traps.
  /// Swift code should call ``allocateZeroed(count:stride:)``.
  ///
  /// The corresponding C function is `calloc`.
  @_alwaysEmitIntoClient
  public static var allocateZeroedFunction: @convention(c) (Int, Int) -> UnsafeMutableRawPointer? {
    calloc
  }

  /// C's `realloc`, as a C function value,
  /// for a C library or a hook that takes an allocator's functions.
  ///
  /// This is C's function, with C's rules:
  /// it returns `nil` when it fails, leaving the block as it was,
  /// and never traps; what it does with a size of zero differs by platform.
  /// Swift code should call ``reallocate(_:byteCount:)``.
  ///
  /// The corresponding C function is `realloc`.
  @_alwaysEmitIntoClient
  public static var reallocateFunction:
    @convention(c) (UnsafeMutableRawPointer?, Int) -> UnsafeMutableRawPointer?
  {
    realloc
  }

  /// C's `free`, as a C function value,
  /// for a C library or a hook that takes an allocator's functions.
  ///
  /// The corresponding C function is `free`.
  @_alwaysEmitIntoClient
  public static var freeFunction: @convention(c) (UnsafeMutableRawPointer?) -> Void {
    // A closure, since `free` alone is Memory.free(_:) here, and a
    // qualified name such as `Darwin.free` can't form a C function value.
    { pointer in
      #if SYSTEM_PACKAGE_DARWIN
      Darwin.free(pointer)
      #elseif canImport(Glibc)
      Glibc.free(pointer)
      #elseif canImport(Musl)
      Musl.free(pointer)
      #elseif canImport(WASILibc)
      WASILibc.free(pointer)
      #elseif canImport(Android)
      Android.free(pointer)
      #endif
    }
  }
}

// MARK: - C spellings

@available(System 199, *)
extension Memory {
  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "allocate(byteCount:alignment:)")
  public static func aligned_alloc() throws(Errno) -> UnsafeMutableRawPointer {
    fatalError("Not implemented")
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "allocate(byteCount:alignment:)")
  public static func memalign() throws(Errno) -> UnsafeMutableRawPointer {
    fatalError("Not implemented")
  }
}

#endif // !os(Windows)
