/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library's locales.
//
// System wraps C's locale machinery (locale.h and xlocale.h) provisionally.
// A C locale is the C library's rules for formatting and parsing, not an
// operating-system interface, and Swift's locales are Foundation's; the
// standard library may be where locale-independent parsing belongs. Until
// then, a package that needs the POSIX locale's rules, as Foundation's
// number parsing does, or that sets the process's C locale, as its tests
// do, can do so without importing the C library.
//
// On Darwin, Linux (glibc and Musl), Android, FreeBSD, OpenBSD and WASI,
// which have these calls, though Linux declares strtod_l and strtof_l only
// with _GNU_SOURCE, and has no LC_C_LOCALE, Bionic's and wasi-libc's *_l
// calls ignore the locale, and OpenBSD has no strtod_l or strtof_l (see
// Syscalls+ProvisionalLocale.swift).

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WASILibc)
import WASILibc
#endif

@available(System 199, *)
extension CInterop {
  /// A C library locale.
  ///
  /// The corresponding C type is `locale_t`.
  ///
  /// - Note: Provisional: C locales may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD and WASI.
  public typealias Locale = locale_t
}

/// A C library locale:
/// the rules for numbers, money, times, character classes, collation,
/// and messages that the C library's locale-dependent calls follow.
///
/// This is the C library's locale, for code that calls C;
/// Swift code that formats for people uses Foundation's `Locale`.
/// A `CLocale` is most often ``posix``, whose rules don't depend on
/// the user's settings, to parse and compare text written for programs:
///
///     let (value, byteCount) = CLocale.posix.parseDouble(text)
///
/// A locale that ``named(_:categories:base:)`` creates is a handle,
/// as ``FileDescriptor`` is: copying one doesn't copy the locale,
/// and ``free()`` frees it for every copy.
/// The ``posix`` and ``global`` locales aren't created, and aren't freed.
///
/// Android's C library has only the POSIX locale's rules.
/// Of the names it accepts, `"C"` and `"POSIX"` are the POSIX locale,
/// and `"C.UTF-8"` and `"en_US.UTF-8"` the same with UTF-8 characters,
/// which ``globalName(for:)`` names `"C.UTF-8"`;
/// and its calls that take a locale ignore it.
/// OpenBSD's locales differ only in their character types,
/// so its numbers and case are the POSIX locale's in every locale.
/// WASI's C library, Musl's, has no locales but the POSIX locale
/// and `"C.UTF-8"`, though it accepts any name,
/// and its calls that take a locale ignore it.
///
/// - Note: Provisional: C locales may move to the Swift standard library.
/// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD and WASI.
@frozen
@available(System 199, *)
public struct CLocale: RawRepresentable, Hashable, @unchecked Sendable {
  /// The C locale, which is `nil` for the POSIX locale.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.Locale?

  /// Creates a locale from a C locale.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.Locale?) { self.rawValue = rawValue }
}

// MARK: - Categories

@available(System 199, *)
extension CLocale {
  /// A kind of rule that a locale has.
  ///
  /// - Note: Provisional: C locales may move to the Swift standard library.
  @frozen
  public struct Category: RawRepresentable, Hashable, Sendable {
    /// The raw C category.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed category from a raw C category.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Every category.
    ///
    /// The corresponding C constant is `LC_ALL`.
    @_alwaysEmitIntoClient
    public static var all: Category { Category(rawValue: _LC_ALL) }

    /// How text sorts.
    ///
    /// The corresponding C constant is `LC_COLLATE`.
    @_alwaysEmitIntoClient
    public static var collation: Category { Category(rawValue: _LC_COLLATE) }

    /// Which characters are letters, digits, spaces, and so on,
    /// and the character encoding.
    ///
    /// The corresponding C constant is `LC_CTYPE`.
    @_alwaysEmitIntoClient
    public static var characterTypes: Category { Category(rawValue: _LC_CTYPE) }

    /// The language of messages, and of yes and no answers.
    ///
    /// The corresponding C constant is `LC_MESSAGES`.
    @_alwaysEmitIntoClient
    public static var messages: Category { Category(rawValue: _LC_MESSAGES) }

    /// How amounts of money are written.
    ///
    /// The corresponding C constant is `LC_MONETARY`.
    @_alwaysEmitIntoClient
    public static var monetary: Category { Category(rawValue: _LC_MONETARY) }

    /// How numbers are written, such as the decimal point.
    ///
    /// The corresponding C constant is `LC_NUMERIC`.
    @_alwaysEmitIntoClient
    public static var numeric: Category { Category(rawValue: _LC_NUMERIC) }

    /// How dates and times are written.
    ///
    /// The corresponding C constant is `LC_TIME`.
    @_alwaysEmitIntoClient
    public static var time: Category { Category(rawValue: _LC_TIME) }
  }

  /// The categories a new locale takes from its name.
  ///
  /// - Note: Provisional: C locales may move to the Swift standard library.
  @frozen
  public struct Categories: OptionSet, Hashable, Sendable {
    /// The raw C mask.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed mask from a raw C mask.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The corresponding C constant is `LC_COLLATE_MASK`.
    @_alwaysEmitIntoClient
    public static var collation: Categories { Categories(rawValue: _LC_COLLATE_MASK) }

    /// The corresponding C constant is `LC_CTYPE_MASK`.
    @_alwaysEmitIntoClient
    public static var characterTypes: Categories { Categories(rawValue: _LC_CTYPE_MASK) }

    /// The corresponding C constant is `LC_MESSAGES_MASK`.
    @_alwaysEmitIntoClient
    public static var messages: Categories { Categories(rawValue: _LC_MESSAGES_MASK) }

    /// The corresponding C constant is `LC_MONETARY_MASK`.
    @_alwaysEmitIntoClient
    public static var monetary: Categories { Categories(rawValue: _LC_MONETARY_MASK) }

    /// The corresponding C constant is `LC_NUMERIC_MASK`.
    @_alwaysEmitIntoClient
    public static var numeric: Categories { Categories(rawValue: _LC_NUMERIC_MASK) }

    /// The corresponding C constant is `LC_TIME_MASK`.
    @_alwaysEmitIntoClient
    public static var time: Categories { Categories(rawValue: _LC_TIME_MASK) }

    /// Every category.
    ///
    /// On Linux it includes the categories that glibc adds,
    /// such as `LC_PAPER`, which have no ``Categories`` of their own.
    ///
    /// The corresponding C constant is `LC_ALL_MASK`.
    @_alwaysEmitIntoClient
    public static var all: Categories {
      // FreeBSD's LC_ALL_MASK is Darwin's, and OpenBSD's the same six.
      #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
      [.collation, .characterTypes, .messages, .monetary, .numeric, .time]
      #else
      Categories(rawValue: _LC_ALL_MASK)
      #endif
    }
  }
}

// MARK: - Locales

@available(System 199, *)
extension CLocale {
  /// The POSIX locale, also named "C",
  /// whose rules are the same everywhere, whatever the user's settings.
  ///
  /// On Linux, which has no `LC_C_LOCALE`,
  /// its calls pass a POSIX locale that `newlocale` creates once.
  ///
  /// The corresponding C constant is `LC_C_LOCALE`.
  @_alwaysEmitIntoClient
  public static var posix: CLocale { CLocale(rawValue: nil) }

  /// The process's global locale, which ``setGlobal(_:for:)`` changes.
  ///
  /// On Linux, whose `*_l` calls don't take `LC_GLOBAL_LOCALE`,
  /// its calls are the ones without a locale argument,
  /// such as `strtod` for ``parseDouble(_:)``,
  /// which follow the calling thread's locale:
  /// the global one, unless the thread set its own with `uselocale`.
  ///
  /// The corresponding C constant is `LC_GLOBAL_LOCALE`.
  @_alwaysEmitIntoClient
  public static var global: CLocale { CLocale(rawValue: CInterop.Locale(bitPattern: -1)) }

  /// Creates a locale from the named locale's rules
  /// for some categories, and another locale's for the rest.
  ///
  /// - Parameters:
  ///   - name: The locale's name, such as `"fr_FR.UTF-8"`, or `"C"`.
  ///     An empty name is the locale that the environment names,
  ///     with `LANG` and the `LC_*` variables.
  ///   - categories: The categories to take from `name`.
  ///     The default is all of them.
  ///   - base: The locale to take the other categories from,
  ///     which the new locale replaces:
  ///     don't use or free it afterward, unless it's ``posix``.
  ///     The default is ``posix``.
  ///     On Android, which ignores it, it isn't freed either.
  /// - Returns: The new locale, which ``free()`` frees.
  ///
  /// A name that has no locale throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `newlocale`.
  @_alwaysEmitIntoClient
  public static func named(
    _ name: String, categories: Categories = .all, base: CLocale = .posix
  ) throws(Errno) -> CLocale {
    try _named(name, categories: categories, base: base).get()
  }

  @usableFromInline
  internal static func _named(
    _ name: String, categories: Categories, base: CLocale
  ) -> Result<CLocale, Errno> {
    name.withCString { name in
      guard let locale = system_newlocale(categories.rawValue, name, base.rawValue) else {
        return .failure(.current)
      }
      return .success(CLocale(rawValue: locale))
    }
  }

  /// Frees a locale that ``named(_:categories:base:)`` created.
  ///
  /// The locale can't be used afterward.
  /// Freeing ``posix`` or ``global`` is a programming error.
  ///
  /// The corresponding C function is `freelocale`.
  @_alwaysEmitIntoClient
  public func free() {
    _free()
  }

  @usableFromInline
  internal func _free() {
    guard let rawValue else { return }
    system_freelocale(rawValue)
  }
}

// MARK: - The global locale

@available(System 199, *)
extension CLocale {
  /// Returns the name of the process's global locale for a category.
  ///
  /// - Parameter category: The category. The default is all of them,
  ///   whose name lists each category's when they differ.
  ///
  /// A process starts in the POSIX locale, named `"C"`,
  /// until something calls ``setGlobal(_:for:)``.
  ///
  /// The corresponding C function is `setlocale`, with a null name.
  @_alwaysEmitIntoClient
  public static func globalName(for category: Category = .all) -> String {
    _globalName(for: category)
  }

  @usableFromInline
  internal static func _globalName(for category: Category) -> String {
    system_setlocale(category.rawValue, nil).map { String(cString: $0) } ?? "C"
  }

  /// Sets the process's global locale for a category.
  ///
  /// - Parameters:
  ///   - name: The locale's name, such as `"fr_FR.UTF-8"`, or `"C"`.
  ///     An empty name is the locale that the environment names.
  ///   - category: The category to set. The default is all of them.
  /// - Returns: The new locale's name,
  ///   or `nil` if `name` has no locale,
  ///   which leaves the global locale unchanged.
  ///
  /// The global locale belongs to the whole process:
  /// every thread's locale-dependent C calls follow it,
  /// including `printf`'s and `strtod`'s,
  /// unless a thread sets a locale of its own.
  /// Set it early, before other threads use it.
  ///
  /// The corresponding C function is `setlocale`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func setGlobal(_ name: String, for category: Category = .all) -> String? {
    _setGlobal(name, for: category)
  }

  @usableFromInline
  internal static func _setGlobal(_ name: String, for category: Category) -> String? {
    name.withCString { system_setlocale(category.rawValue, $0).map { String(cString: $0) } }
  }
}

// MARK: - Parsing and comparing

@available(System 199, *)
extension CLocale {
  /// Parses a number at the start of a C string, with this locale's rules.
  ///
  /// - Parameter string: The text, which can start with spaces.
  /// - Returns: The number, and how many bytes of `string` it took,
  ///   which is 0 if the string doesn't start with a number
  ///   (and then the number is 0).
  ///
  /// The text can be a decimal number with an exponent, a hexadecimal one
  /// (`0x1.8p3`), `inf`, `infinity`, or `nan`, in any case.
  /// A number too large for `Double` is infinity,
  /// and one too small is zero or a subnormal value.
  ///
  /// The corresponding C function is `strtod_l`.
  @_alwaysEmitIntoClient
  public func parseDouble(_ string: UnsafePointer<CChar>) -> (value: Double, byteCount: Int) {
    _parseDouble(string)
  }

  @usableFromInline
  internal func _parseDouble(_ string: UnsafePointer<CChar>) -> (value: Double, byteCount: Int) {
    var end: UnsafeMutablePointer<CChar>? = nil
    let value = system_strtod_l(string, &end, rawValue)
    return (value, end.map { UnsafePointer($0) - string } ?? 0)
  }

  /// Parses a number at the start of a C string, with this locale's rules.
  ///
  /// See ``parseDouble(_:)``.
  ///
  /// The corresponding C function is `strtof_l`.
  @_alwaysEmitIntoClient
  public func parseFloat(_ string: UnsafePointer<CChar>) -> (value: Float, byteCount: Int) {
    _parseFloat(string)
  }

  @usableFromInline
  internal func _parseFloat(_ string: UnsafePointer<CChar>) -> (value: Float, byteCount: Int) {
    var end: UnsafeMutablePointer<CChar>? = nil
    let value = system_strtof_l(string, &end, rawValue)
    return (value, end.map { UnsafePointer($0) - string } ?? 0)
  }

  /// Compares at most a number of bytes of two C strings,
  /// ignoring case with this locale's rules.
  ///
  /// - Parameters:
  ///   - lhs: A string.
  ///   - rhs: Another string.
  ///   - maxByteCount: The most bytes to compare,
  ///     which stops early at the end of either string.
  /// - Returns: A negative number if `lhs` orders first,
  ///   0 if the bytes compared are the same but for case,
  ///   and a positive number if `rhs` orders first.
  ///
  /// The corresponding C function is `strncasecmp_l`.
  @_alwaysEmitIntoClient
  public func compareIgnoringCase(
    _ lhs: UnsafePointer<CChar>, _ rhs: UnsafePointer<CChar>, maxByteCount: Int
  ) -> Int {
    _compareIgnoringCase(lhs, rhs, maxByteCount: maxByteCount)
  }

  @usableFromInline
  internal func _compareIgnoringCase(
    _ lhs: UnsafePointer<CChar>, _ rhs: UnsafePointer<CChar>, maxByteCount: Int
  ) -> Int {
    Int(system_strncasecmp_l(lhs, rhs, maxByteCount, rawValue))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
