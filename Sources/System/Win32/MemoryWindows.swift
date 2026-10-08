/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Memory on Windows: the C runtime's allocator, and its calls that compare,
// search, and clear memory. Memory.swift and MemoryBytes.swift declare the
// namespace for the other platforms; this is the part of it that the
// Universal C Runtime has. It has no posix_memalign: its _aligned_malloc
// returns blocks that only _aligned_free can free, which free(_:) couldn't
// promise, so there's no aligned allocation here. It has no memmem either.

#if os(Windows)

// Must import here to call memcmp in @_alwaysEmitIntoClient code.
import ucrt
import WinSDK

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
/// On Windows, this is the C runtime's heap.
/// Memory that a Win32 function allocates,
/// such as `FormatMessageW`'s buffer or a `CoTaskMemAlloc` block,
/// comes from other heaps, with frees of their own.
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

// MARK: - Requests

@available(System 199, *)
extension Memory {
  /// The size to ask the C allocator for: zero is one byte, as on the
  /// other platforms (Memory.swift).
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

  /// The block an allocation returned, or `noMemory` for NULL.
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
  /// This is C's function, with C's rules:
  /// it returns `nil` when it fails, and never traps.
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
  /// and never traps.
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
    // qualified name such as `ucrt.free` can't form a C function value.
    { pointer in ucrt.free(pointer) }
  }
}

// MARK: - Comparing, searching and clearing

@available(System 199, *)
extension Memory {
  /// Compares two buffers' bytes, in order, as unsigned numbers.
  ///
  /// - Returns: -1 if `lhs` orders first, 0 if the buffers are equal,
  ///   or 1 if `rhs` orders first.
  ///   A buffer that begins the other orders first.
  ///
  /// C's `memcmp` compares one count of bytes, which both buffers must have;
  /// this compares the bytes that both buffers have, and then their counts.
  ///
  /// The corresponding C function is `memcmp`.
  @_alwaysEmitIntoClient
  @inline(__always)
  public static func compare(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Int {
    _compare(lhs, rhs)
  }

  // Emitted into the client with its memcmp call, as on the other platforms
  // (MemoryBytes.swift), so that the client's optimizer sees the count.
  @_alwaysEmitIntoClient
  @inline(__always)
  internal static func _compare(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Int {
    // memcmp's pointers must be valid even for a count of zero, which an
    // empty buffer's nil start isn't.
    let count = min(lhs.count, rhs.count)
    if count > 0 {
      let order = memcmp(lhs.baseAddress!, rhs.baseAddress!, count)
      if order != 0 { return order < 0 ? -1 : 1 }
    }
    return lhs.count == rhs.count ? 0 : (lhs.count < rhs.count ? -1 : 1)
  }

  /// Compares two spans' bytes, in order, as unsigned numbers.
  ///
  /// - Returns: -1 if `lhs` orders first, 0 if the spans are equal,
  ///   or 1 if `rhs` orders first.
  ///   A span that begins the other orders first.
  ///
  /// The corresponding C function is `memcmp`.
  @_alwaysEmitIntoClient
  @inline(__always)
  public static func compare(_ lhs: RawSpan, _ rhs: RawSpan) -> Int {
    lhs.withUnsafeBytes { lhs in rhs.withUnsafeBytes { rhs in _compare(lhs, rhs) } }
  }

  /// Returns the offset of a byte's first appearance in a buffer.
  ///
  /// - Parameters:
  ///   - byte: The byte to look for.
  ///   - buffer: The buffer to look in.
  /// - Returns: The byte's offset from the start of `buffer`,
  ///   or `nil` if `buffer` doesn't contain it.
  ///
  /// The C library's search is typically faster than
  /// a loop over the buffer's bytes, such as `firstIndex(of:)`.
  ///
  /// The corresponding C function is `memchr`.
  @_alwaysEmitIntoClient
  public static func firstIndex(of byte: UInt8, in buffer: UnsafeRawBufferPointer) -> Int? {
    _firstIndex(of: byte, in: buffer)
  }

  /// Returns the offset of a byte's first appearance in a span.
  ///
  /// - Parameters:
  ///   - byte: The byte to look for.
  ///   - bytes: The bytes to look in.
  /// - Returns: The byte's offset from the start of `bytes`,
  ///   or `nil` if `bytes` doesn't contain it.
  ///
  /// The corresponding C function is `memchr`.
  @_alwaysEmitIntoClient
  public static func firstIndex(of byte: UInt8, in bytes: RawSpan) -> Int? {
    bytes.withUnsafeBytes { _firstIndex(of: byte, in: $0) }
  }

  @usableFromInline
  internal static func _firstIndex(of byte: UInt8, in buffer: UnsafeRawBufferPointer) -> Int? {
    guard let start = buffer.baseAddress, buffer.count > 0 else { return nil }
    guard let found = system_memchr(start, CInt(byte), buffer.count) else { return nil }
    return UnsafeRawPointer(found) - start
  }

  /// Overwrites a buffer with zeros, with stores that the compiler
  /// can't remove.
  ///
  /// - Parameter buffer: The bytes to overwrite.
  ///
  /// Clear a secret, such as a key, with this before its memory is freed,
  /// or goes out of scope. The compiler can remove ordinary stores that
  /// nothing reads afterward, and so leave the secret in memory.
  /// Copies of the secret elsewhere, such as in registers, other buffers,
  /// or swapped-out pages, aren't cleared.
  ///
  /// The corresponding C function is `memset_s`, or on Windows
  /// `RtlSecureZeroMemory`, also known as `SecureZeroMemory`.
  @_alwaysEmitIntoClient
  public static func secureZero(_ buffer: UnsafeMutableRawBufferPointer) {
    _secureZero(buffer)
  }

  /// Overwrites a span's bytes with zeros, with stores that the compiler
  /// can't remove.
  ///
  /// - Parameter bytes: The bytes to overwrite.
  ///
  /// The corresponding C function is `memset_s`, or on Windows
  /// `RtlSecureZeroMemory`, also known as `SecureZeroMemory`.
  @_alwaysEmitIntoClient
  public static func secureZero(_ bytes: inout MutableRawSpan) {
    bytes.withUnsafeMutableBytes { _secureZero($0) }
  }

  @usableFromInline
  internal static func _secureZero(_ buffer: UnsafeMutableRawBufferPointer) {
    guard let start = buffer.baseAddress, buffer.count > 0 else { return }
    system_RtlSecureZeroMemory(start, buffer.count)
  }
}

#endif // os(Windows)
