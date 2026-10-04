/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library's locale calls, which System wraps provisionally
// (Provisional+Locale.swift). The <xlocale.h> calls come from CSystem's
// Darwin header, since the Darwin module doesn't export them. On Linux,
// glibc and Musl declare strtod_l and strtof_l only with _GNU_SOURCE, so
// they're CSystem shims. On Android, Bionic's strtod_l, strtof_l and
// strncasecmp_l, which it declares only from API levels 26, 26 and 23, are
// strtod, strtof and strncasecmp, ignoring the locale, so these call those.
// FreeBSD's locale calls are Darwin's (its xlocale is the same code), but
// its <stdlib.h> and <strings.h> declare the *_l calls only after
// <xlocale.h>, so these are CSystem shims there. OpenBSD has no strtod_l or
// strtof_l, and its LC_NUMERIC is always the POSIX locale's, so these call
// strtod and strtof there; its strncasecmp_l ignores the locale, so this
// calls strncasecmp, as on Android. wasi-libc's are Musl's, which ignore the
// locale (its numbers are always the POSIX locale's), and it declares
// strtod_l and strtof_l only with _GNU_SOURCE, so these call strtod, strtof
// and strncasecmp there too.
//
// In a mock test, a locale that newlocale "created" is a placeholder
// address, so freelocale is mocked too, and neither touches it.

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

#if ENABLE_MOCKING
// What a mocked newlocale returns: an address no locale is at.
internal var _mockLocale: locale_t { locale_t(bitPattern: 0x10C0)! }
#endif

// newlocale
internal func system_newlocale(
  _ mask: CInt, _ name: UnsafePointer<CChar>, _ base: locale_t?
) -> locale_t? {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(mask, String(cString: name), base.map { Int(bitPattern: $0) } ?? 0) == -1 ? nil : _mockLocale
  }
#endif
  return newlocale(mask, name, base)
}

// freelocale
internal func system_freelocale(_ locale: locale_t) {
#if ENABLE_MOCKING
  if mockingEnabled {
    _ = _mock(Int(bitPattern: locale))
    return
  }
#endif
  freelocale(locale)
}

#if os(Linux)
// Linux has no LC_C_LOCALE, and glibc's *_l calls take neither a null
// locale nor LC_GLOBAL_LOCALE. So for the POSIX locale (nil), these calls
// pass one that newlocale makes once, which nothing frees; and for the
// global locale, they call the functions without a locale, which follow the
// calling thread's locale: the global one, unless the thread set its own
// with uselocale.
nonisolated(unsafe) internal let _posixLocale: locale_t = {
  guard let locale = newlocale(_LC_ALL_MASK, "C", nil) else {
    fatalError("newlocale couldn't create the POSIX locale: \(Errno.current)")
  }
  return locale
}()

internal func _isGlobalLocale(_ locale: locale_t?) -> Bool {
  locale.map { Int(bitPattern: $0) == -1 } ?? false
}
#endif

// The calls that don't report errors through errno have no mock hooks.

// setlocale
internal func system_setlocale(
  _ category: CInt, _ name: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>? {
  setlocale(category, name)
}

// strtod_l
internal func system_strtod_l(
  _ string: UnsafePointer<CChar>,
  _ end: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
  _ locale: locale_t?
) -> Double {
#if SYSTEM_PACKAGE_DARWIN
  strtod_l(string, end, locale)
#elseif os(FreeBSD)
  csystem_strtod_l(string, end, UnsafeMutableRawPointer(locale))
#elseif os(Android) || os(OpenBSD) || os(WASI)
  strtod(string, end)
#else
  if _isGlobalLocale(locale) { return strtod(string, end) }
  return csystem_strtod_l(string, end, UnsafeMutableRawPointer(locale ?? _posixLocale))
#endif
}

// strtof_l
internal func system_strtof_l(
  _ string: UnsafePointer<CChar>,
  _ end: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
  _ locale: locale_t?
) -> Float {
#if SYSTEM_PACKAGE_DARWIN
  strtof_l(string, end, locale)
#elseif os(FreeBSD)
  csystem_strtof_l(string, end, UnsafeMutableRawPointer(locale))
#elseif os(Android) || os(OpenBSD) || os(WASI)
  strtof(string, end)
#else
  if _isGlobalLocale(locale) { return strtof(string, end) }
  return csystem_strtof_l(string, end, UnsafeMutableRawPointer(locale ?? _posixLocale))
#endif
}

// strncasecmp_l
internal func system_strncasecmp_l(
  _ a: UnsafePointer<CChar>, _ b: UnsafePointer<CChar>, _ count: Int, _ locale: locale_t?
) -> CInt {
#if SYSTEM_PACKAGE_DARWIN
  strncasecmp_l(a, b, count, locale)
#elseif os(FreeBSD)
  csystem_strncasecmp_l(a, b, count, UnsafeMutableRawPointer(locale))
#elseif os(Android) || os(OpenBSD) || os(WASI)
  strncasecmp(a, b, count)
#else
  if _isGlobalLocale(locale) { return strncasecmp(a, b, count) }
  return strncasecmp_l(a, b, count, locale ?? _posixLocale)
#endif
}

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
// nl_langinfo_l. Darwin's and FreeBSD's take LC_GLOBAL_LOCALE, and a null
// locale as the POSIX locale; glibc's and Musl's take neither, so on Linux
// the global locale's is nl_langinfo, and the POSIX locale's _posixLocale.
internal func system_nl_langinfo_l(
  _ item: nl_item, _ locale: locale_t?
) -> UnsafeMutablePointer<CChar>? {
#if SYSTEM_PACKAGE_DARWIN
  nl_langinfo_l(item, locale)
#elseif os(FreeBSD)
  csystem_nl_langinfo_l(item, UnsafeMutableRawPointer(locale))
#else
  if _isGlobalLocale(locale) { return nl_langinfo(item) }
  return nl_langinfo_l(item, locale ?? _posixLocale)
#endif
}
#endif

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
