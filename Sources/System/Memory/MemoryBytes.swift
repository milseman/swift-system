/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

// The C library's calls on memory that can't fail, and that Swift code
// otherwise imports the C library for. memcpy and memset aren't here: the
// standard library's copyMemory(from:byteCount:) and initializeMemory(as:
// repeating:) do what they do.

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
  public static func compare(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Int {
    _compare(lhs, rhs)
  }

  @usableFromInline
  internal static func _compare(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Int {
    // memcmp's pointers must be valid even for a count of zero, which an
    // empty buffer's nil start isn't.
    let count = min(lhs.count, rhs.count)
    if count > 0 {
      let order = system_memcmp(lhs.baseAddress!, rhs.baseAddress!, count)
      if order != 0 { return order < 0 ? -1 : 1 }
    }
    return lhs.count == rhs.count ? 0 : (lhs.count < rhs.count ? -1 : 1)
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
  /// The corresponding C function is `memset_s` on Darwin,
  /// and `explicit_bzero` elsewhere.
  @_alwaysEmitIntoClient
  public static func secureZero(_ buffer: UnsafeMutableRawBufferPointer) {
    _secureZero(buffer)
  }

  @usableFromInline
  internal static func _secureZero(_ buffer: UnsafeMutableRawBufferPointer) {
    guard let start = buffer.baseAddress, buffer.count > 0 else { return }
    #if SYSTEM_PACKAGE_DARWIN
    // memset_s fails only for a null pointer, or a count larger than
    // RSIZE_MAX or the buffer, which a buffer's own count can't be.
    let error = system_memset_s(start, buffer.count, 0, buffer.count)
    assert(error == 0, "memset_s failed")
    #else
    system_explicit_bzero(start, buffer.count)
    #endif
  }
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Memory {
  /// Compares two spans' bytes, in order, as unsigned numbers.
  ///
  /// - Returns: -1 if `lhs` orders first, 0 if the spans are equal,
  ///   or 1 if `rhs` orders first.
  ///   A span that begins the other orders first.
  ///
  /// The corresponding C function is `memcmp`.
  @_alwaysEmitIntoClient
  public static func compare(_ lhs: RawSpan, _ rhs: RawSpan) -> Int {
    lhs.withUnsafeBytes { lhs in rhs.withUnsafeBytes { rhs in _compare(lhs, rhs) } }
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

  /// Overwrites a span's bytes with zeros, with stores that the compiler
  /// can't remove.
  ///
  /// - Parameter bytes: The bytes to overwrite.
  ///
  /// The corresponding C function is `memset_s` on Darwin,
  /// and `explicit_bzero` elsewhere.
  @_alwaysEmitIntoClient
  public static func secureZero(_ bytes: inout MutableRawSpan) {
    bytes.withUnsafeMutableBytes { _secureZero($0) }
  }
}

#endif // !os(Windows)
