/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library's string functions, on null-terminated C
// strings.
//
// System wraps <string.h>'s C-string functions provisionally. They're the C
// library's, not operating-system interfaces, and the standard library,
// which converts C strings to and from `String`, is where they'd belong.
// Until it has them, code that hands C strings to C APIs, such as an
// argument vector or strings a C library frees, can measure, copy and
// compare them without importing the C library; four of the toolchain's
// packages wrote their own strdup to stop importing it. The functions on
// raw memory (memcpy, memmove, memset) are the standard library's already,
// as `copyMemory(from:byteCount:)` and `initializeMemory(as:repeating:count:)`,
// and memcmp and memchr are ``Memory``'s.

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

/// A namespace for the C library's functions on null-terminated C strings:
/// measuring, duplicating, comparing, and copying them.
///
/// Each takes the C string as a pointer, so a Swift `String` argument
/// converts to a temporary C string, as it does for a C function:
///
///     let copy = try CString.duplicate("NAME=value")
///     defer { Memory.free(copy) }
///
/// - Note: Provisional: C string functions may move to the Swift standard library.
@available(System 199, *)
public enum CString {}

@available(System 199, *)
extension CString {
  /// Returns the number of bytes in a C string, before its null byte.
  ///
  /// - Parameter string: A null-terminated C string.
  ///
  /// The corresponding C function is `strlen`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func length(of string: UnsafePointer<CChar>) -> Int {
    _length(of: string)
  }

  @usableFromInline
  internal static func _length(of string: UnsafePointer<CChar>) -> Int {
    system_strlen(string)
  }

  /// Returns the number of bytes in a C string before its null byte,
  /// reading no more than a number of bytes.
  ///
  /// - Parameters:
  ///   - string: The start of the C string.
  ///   - maxLength: The most bytes to read.
  /// - Returns: The number of bytes before the first null byte,
  ///   or `maxLength` if none of the first `maxLength` bytes is null.
  ///
  /// This is for a C string in a fixed-size field,
  /// such as a socket path, which fills the field without a null byte.
  ///
  /// The corresponding C function is `strnlen`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func length(of string: UnsafePointer<CChar>, maxLength: Int) -> Int {
    _length(of: string, maxLength: maxLength)
  }

  @usableFromInline
  internal static func _length(of string: UnsafePointer<CChar>, maxLength: Int) -> Int {
    precondition(maxLength >= 0, "CString.length(of:maxLength:): 'maxLength' must not be negative")
    return system_strnlen(string, maxLength)
  }

  /// Returns a copy of a C string, in memory that the C allocator allocates.
  ///
  /// - Parameter string: A null-terminated C string.
  /// - Returns: The copy, null-terminated,
  ///   which the caller frees with ``Memory/free(_:)``
  ///   or hands to C code that frees it.
  ///
  /// If there isn't enough memory, this method throws
  /// ``Errno/noMemory``.
  ///
  /// The corresponding C function is `strdup`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func duplicate(
    _ string: UnsafePointer<CChar>
  ) throws(Errno) -> UnsafeMutablePointer<CChar> {
    try _duplicate(string).get()
  }

  @usableFromInline
  internal static func _duplicate(
    _ string: UnsafePointer<CChar>
  ) -> Result<UnsafeMutablePointer<CChar>, Errno> {
    guard let copy = system_strdup(string) else { return .failure(.current) }
    return .success(copy)
  }

  /// Returns a copy of at most a number of bytes of a C string,
  /// null-terminated, in memory that the C allocator allocates.
  ///
  /// - Parameters:
  ///   - string: The start of the C string.
  ///   - maxLength: The most bytes to copy, not counting the null byte
  ///     that the copy ends with.
  /// - Returns: The copy, which the caller frees with ``Memory/free(_:)``
  ///   or hands to C code that frees it.
  ///
  /// This method reads no more than `maxLength` bytes of `string`,
  /// so the bytes needn't end with a null byte.
  /// If there isn't enough memory, it throws ``Errno/noMemory``.
  ///
  /// The corresponding C function is `strndup`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func duplicate(
    _ string: UnsafePointer<CChar>, maxLength: Int
  ) throws(Errno) -> UnsafeMutablePointer<CChar> {
    try _duplicate(string, maxLength: maxLength).get()
  }

  @usableFromInline
  internal static func _duplicate(
    _ string: UnsafePointer<CChar>, maxLength: Int
  ) -> Result<UnsafeMutablePointer<CChar>, Errno> {
    precondition(maxLength >= 0, "CString.duplicate(_:maxLength:): 'maxLength' must not be negative")
    guard let copy = system_strndup(string, maxLength) else { return .failure(.current) }
    return .success(copy)
  }

  /// Compares two C strings by their bytes, as unsigned values.
  ///
  /// - Parameters:
  ///   - string: A null-terminated C string.
  ///   - other: Another null-terminated C string.
  /// - Returns: A negative number if `string` orders before `other`,
  ///   zero if they're equal, and a positive number if it orders after.
  ///
  /// The comparison is by bytes, whatever the locale.
  ///
  /// The corresponding C function is `strcmp`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>
  ) -> Int {
    _compare(string, other)
  }

  @usableFromInline
  internal static func _compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>
  ) -> Int {
    Int(system_strcmp(string, other))
  }

  /// Compares at most a number of bytes of two C strings,
  /// by their bytes, as unsigned values.
  ///
  /// - Parameters:
  ///   - string: The start of a C string.
  ///   - other: The start of another C string.
  ///   - maxLength: The most bytes to compare.
  /// - Returns: A negative number if `string` orders before `other`,
  ///   zero if their first `maxLength` bytes are equal,
  ///   or if they're equal up to a null byte,
  ///   and a positive number if it orders after.
  ///
  /// This method stops at a null byte,
  /// so a C string can be compared with a shorter prefix:
  /// `compare(buffer, "<?xml", maxLength: 5) == 0`
  /// says that `buffer` starts with `<?xml`.
  ///
  /// The corresponding C function is `strncmp`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>, maxLength: Int
  ) -> Int {
    _compare(string, other, maxLength: maxLength)
  }

  @usableFromInline
  internal static func _compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>, maxLength: Int
  ) -> Int {
    precondition(maxLength >= 0, "CString.compare(_:_:maxLength:): 'maxLength' must not be negative")
    return Int(system_strncmp(string, other, maxLength))
  }

  /// Copies a C string into a buffer, truncating it to fit,
  /// and ends the copy with a null byte.
  ///
  /// - Parameters:
  ///   - string: A null-terminated C string.
  ///   - buffer: The buffer to copy into.
  ///     Unless it's empty, the copy always ends with a null byte.
  /// - Returns: The length of `string`, not counting its null byte.
  ///   If it's `buffer.count` or more, the copy was truncated.
  ///
  /// The corresponding C function is `strlcpy`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func copy(
    _ string: UnsafePointer<CChar>, into buffer: UnsafeMutableBufferPointer<CChar>
  ) -> Int {
    _copy(string, into: buffer)
  }

  @usableFromInline
  internal static func _copy(
    _ string: UnsafePointer<CChar>, into buffer: UnsafeMutableBufferPointer<CChar>
  ) -> Int {
    guard let start = buffer.baseAddress else { return system_strlen(string) }
    return system_strlcpy(start, string, buffer.count)
  }
}

#endif // !os(Windows)
