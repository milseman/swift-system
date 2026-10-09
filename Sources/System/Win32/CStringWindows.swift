/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library's string functions on null-terminated C
// strings, on Windows. Provisional+StringH.swift declares them for the
// other platforms; this is the part the Universal C Runtime has, which
// spells strdup `_strdup` and has no strndup, strlcpy or strcasecmp, and
// the measure of a wide string, which Windows' own strings are.

#if os(Windows)

// Must import here to call strcmp and strncmp in @_alwaysEmitIntoClient code.
import ucrt
import WinSDK

/// A namespace for the C library's functions on null-terminated C strings:
/// measuring, duplicating, and comparing them.
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

  /// Returns the number of UTF-16 code units in a wide C string,
  /// before its null terminator.
  ///
  /// - Parameter string: A null-terminated wide C string,
  ///   such as a path or a name that a Win32 function returns.
  ///
  /// To make a `String` of a wide C string,
  /// use `String(decodingCString:as:)` with `UTF16.self`.
  ///
  /// The corresponding C function is `wcslen`.
  ///
  /// - Note: Provisional: C string functions may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func length(of string: UnsafePointer<WCHAR>) -> Int {
    _length(of: string)
  }

  @usableFromInline
  internal static func _length(of string: UnsafePointer<WCHAR>) -> Int {
    system_platform_strlen(string)
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
  /// The corresponding C function is `strdup`, or on Windows `_strdup`.
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
    guard let copy = system__strdup(string) else { return .failure(.current) }
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

  // Emitted into the client with its strcmp call, as on the other platforms
  // (Provisional+StringH.swift).
  @_alwaysEmitIntoClient
  internal static func _compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>
  ) -> Int {
    Int(strcmp(string, other))
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

  // Emitted into the client with its strncmp call, as _compare(_:_:) is.
  @_alwaysEmitIntoClient
  internal static func _compare(
    _ string: UnsafePointer<CChar>, _ other: UnsafePointer<CChar>, maxLength: Int
  ) -> Int {
    precondition(maxLength >= 0, "CString.compare(_:_:maxLength:): 'maxLength' must not be negative")
    return Int(strncmp(string, other, maxLength))
  }
}

#endif // os(Windows)
