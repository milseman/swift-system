/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library's character classes and case conversions, on
// bytes.
//
// System wraps <ctype.h> provisionally. Its functions are the C library's,
// not operating-system interfaces, and the standard library, whose
// `Character` has Unicode's classes, is where byte forms would belong.
// Until it has them, code that scans bytes as C does, such as a property
// list scanner or a header map's case-insensitive hash, can classify them
// without importing the C library. They take a `UInt8`, so the C functions'
// undefined behavior for a negative `char` can't arise.

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

/// A namespace for the C library's character classes and case conversions,
/// on bytes.
///
/// Each follows the C library's current locale, which is the C locale
/// unless the program changes it: there, the classes are ASCII's,
/// and a byte above 127 is in none of them.
///
///     if CType.isSpace(byte) { continue }
///
/// For a Unicode character's classes, use `Character`'s properties,
/// such as `isWhitespace`.
///
/// - Note: Provisional: character classes may move to the Swift standard library.
@available(System 199, *)
public enum CType {}

@available(System 199, *)
extension CType {
  /// Returns whether a byte is white space:
  /// in the C locale, a space, tab, newline, vertical tab, form feed,
  /// or carriage return.
  ///
  /// The corresponding C function is `isspace`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isSpace(_ byte: UInt8) -> Bool { _isSpace(byte) }

  @usableFromInline
  internal static func _isSpace(_ byte: UInt8) -> Bool { system_isspace(CInt(byte)) != 0 }

  /// Returns whether a byte is a space or a tab.
  ///
  /// The corresponding C function is `isblank`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isBlank(_ byte: UInt8) -> Bool { _isBlank(byte) }

  @usableFromInline
  internal static func _isBlank(_ byte: UInt8) -> Bool { system_isblank(CInt(byte)) != 0 }

  /// Returns whether a byte is a decimal digit.
  ///
  /// The corresponding C function is `isdigit`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isDigit(_ byte: UInt8) -> Bool { _isDigit(byte) }

  @usableFromInline
  internal static func _isDigit(_ byte: UInt8) -> Bool { system_isdigit(CInt(byte)) != 0 }

  /// Returns whether a byte is a hexadecimal digit.
  ///
  /// The corresponding C function is `isxdigit`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isHexDigit(_ byte: UInt8) -> Bool { _isHexDigit(byte) }

  @usableFromInline
  internal static func _isHexDigit(_ byte: UInt8) -> Bool { system_isxdigit(CInt(byte)) != 0 }

  /// Returns whether a byte is a letter.
  ///
  /// The corresponding C function is `isalpha`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isLetter(_ byte: UInt8) -> Bool { _isLetter(byte) }

  @usableFromInline
  internal static func _isLetter(_ byte: UInt8) -> Bool { system_isalpha(CInt(byte)) != 0 }

  /// Returns whether a byte is a letter or a decimal digit.
  ///
  /// The corresponding C function is `isalnum`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isLetterOrDigit(_ byte: UInt8) -> Bool { _isLetterOrDigit(byte) }

  @usableFromInline
  internal static func _isLetterOrDigit(_ byte: UInt8) -> Bool { system_isalnum(CInt(byte)) != 0 }

  /// Returns whether a byte is an uppercase letter.
  ///
  /// The corresponding C function is `isupper`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isUppercase(_ byte: UInt8) -> Bool { _isUppercase(byte) }

  @usableFromInline
  internal static func _isUppercase(_ byte: UInt8) -> Bool { system_isupper(CInt(byte)) != 0 }

  /// Returns whether a byte is a lowercase letter.
  ///
  /// The corresponding C function is `islower`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isLowercase(_ byte: UInt8) -> Bool { _isLowercase(byte) }

  @usableFromInline
  internal static func _isLowercase(_ byte: UInt8) -> Bool { system_islower(CInt(byte)) != 0 }

  /// Returns whether a byte is punctuation:
  /// printable, but neither a letter, a digit, nor a space.
  ///
  /// The corresponding C function is `ispunct`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isPunctuation(_ byte: UInt8) -> Bool { _isPunctuation(byte) }

  @usableFromInline
  internal static func _isPunctuation(_ byte: UInt8) -> Bool { system_ispunct(CInt(byte)) != 0 }

  /// Returns whether a byte is printable, including the space.
  ///
  /// The corresponding C function is `isprint`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isPrintable(_ byte: UInt8) -> Bool { _isPrintable(byte) }

  @usableFromInline
  internal static func _isPrintable(_ byte: UInt8) -> Bool { system_isprint(CInt(byte)) != 0 }

  /// Returns whether a byte is printable and not a space.
  ///
  /// The corresponding C function is `isgraph`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isGraphic(_ byte: UInt8) -> Bool { _isGraphic(byte) }

  @usableFromInline
  internal static func _isGraphic(_ byte: UInt8) -> Bool { system_isgraph(CInt(byte)) != 0 }

  /// Returns whether a byte is a control character.
  ///
  /// The corresponding C function is `iscntrl`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func isControl(_ byte: UInt8) -> Bool { _isControl(byte) }

  @usableFromInline
  internal static func _isControl(_ byte: UInt8) -> Bool { system_iscntrl(CInt(byte)) != 0 }

  /// Returns a byte's lowercase letter if it's an uppercase letter,
  /// and the byte itself otherwise.
  ///
  /// The corresponding C function is `tolower`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func lowercased(_ byte: UInt8) -> UInt8 { _lowercased(byte) }

  @usableFromInline
  internal static func _lowercased(_ byte: UInt8) -> UInt8 { UInt8(truncatingIfNeeded: system_tolower(CInt(byte))) }

  /// Returns a byte's uppercase letter if it's a lowercase letter,
  /// and the byte itself otherwise.
  ///
  /// The corresponding C function is `toupper`.
  ///
  /// - Note: Provisional: character classes may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public static func uppercased(_ byte: UInt8) -> UInt8 { _uppercased(byte) }

  @usableFromInline
  internal static func _uppercased(_ byte: UInt8) -> UInt8 { UInt8(truncatingIfNeeded: system_toupper(CInt(byte))) }
}

#endif // !os(Windows)
