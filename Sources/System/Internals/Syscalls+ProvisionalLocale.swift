/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library's locale calls, which System wraps provisionally
// (Provisional+Locale.swift). The <xlocale.h> calls come from CSystem's
// Darwin header, since the Darwin module doesn't export them.
//
// In a mock test, a locale that newlocale "created" is a placeholder
// address, so freelocale is mocked too, and neither touches it.

#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin

#if ENABLE_MOCKING
// What a mocked newlocale returns: an address no locale is at.
internal var _mockLocale: OpaquePointer { OpaquePointer(bitPattern: 0x10C0)! }
#endif

// newlocale
internal func system_newlocale(
  _ mask: CInt, _ name: UnsafePointer<CChar>, _ base: OpaquePointer?
) -> OpaquePointer? {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(mask, String(cString: name), base.map { Int(bitPattern: $0) } ?? 0) == -1 ? nil : _mockLocale
  }
#endif
  return newlocale(mask, name, base)
}

// freelocale
internal func system_freelocale(_ locale: OpaquePointer) {
#if ENABLE_MOCKING
  if mockingEnabled {
    _ = _mock(Int(bitPattern: locale))
    return
  }
#endif
  freelocale(locale)
}

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
  _ locale: OpaquePointer?
) -> Double {
  strtod_l(string, end, locale)
}

// strtof_l
internal func system_strtof_l(
  _ string: UnsafePointer<CChar>,
  _ end: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
  _ locale: OpaquePointer?
) -> Float {
  strtof_l(string, end, locale)
}

// strncasecmp_l
internal func system_strncasecmp_l(
  _ a: UnsafePointer<CChar>, _ b: UnsafePointer<CChar>, _ count: Int, _ locale: OpaquePointer?
) -> CInt {
  strncasecmp_l(a, b, count, locale)
}

#endif // SYSTEM_PACKAGE_DARWIN
