/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the C library overlays' POSIXErrorCode.
//
// POSIXErrorCode is the Darwin overlay's Swift enum of error numbers, and
// Foundation's public API (and ABI) is made of it: POSIXError.Code is
// POSIXErrorCode. System's Errno can't stand in for it there, so System
// names it, for code that doesn't import Darwin. The Glibc, Musl and
// Android overlays each declare their own, with their C library's values,
// which Foundation's POSIXError.Code is there; so do the FreeBSD and OpenBSD
// overlays, which are named Glibc, and WASILibc. It's the overlays' type, so
// its lasting home may be the standard library.

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#endif
#endif

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
@available(System 199, *)
extension CInterop {
  #if SYSTEM_PACKAGE_DARWIN
  /// The Darwin overlay's Swift enumeration of error numbers,
  /// which Foundation's `POSIXError.Code` is.
  ///
  /// ``Errno`` is System's type for error numbers;
  /// convert between them with their raw values:
  /// `Errno(rawValue: code.rawValue)`.
  ///
  /// The corresponding C type is `POSIXErrorCode`,
  /// the Darwin overlay's.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD, and WASI.
  public typealias POSIXErrorCode = Darwin.POSIXErrorCode
  #elseif canImport(Glibc)
  /// The Glibc overlay's Swift enumeration of error numbers,
  /// which Foundation's `POSIXError.Code` is.
  ///
  /// ``Errno`` is System's type for error numbers;
  /// convert between them with their raw values:
  /// `Errno(rawValue: code.rawValue)`.
  ///
  /// The corresponding C type is `POSIXErrorCode`,
  /// the Glibc overlay's.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD, and WASI.
  public typealias POSIXErrorCode = Glibc.POSIXErrorCode
  #elseif canImport(Musl)
  /// The Musl overlay's Swift enumeration of error numbers,
  /// which Foundation's `POSIXError.Code` is.
  ///
  /// ``Errno`` is System's type for error numbers;
  /// convert between them with their raw values:
  /// `Errno(rawValue: code.rawValue)`.
  ///
  /// The corresponding C type is `POSIXErrorCode`,
  /// the Musl overlay's.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD, and WASI.
  public typealias POSIXErrorCode = Musl.POSIXErrorCode
  #elseif canImport(WASILibc)
  /// The WASILibc overlay's Swift enumeration of error numbers,
  /// which Foundation's `POSIXError.Code` is.
  ///
  /// ``Errno`` is System's type for error numbers;
  /// convert between them with their raw values:
  /// `Errno(rawValue: code.rawValue)`.
  ///
  /// The corresponding C type is `POSIXErrorCode`,
  /// the WASILibc overlay's.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD, and WASI.
  public typealias POSIXErrorCode = WASILibc.POSIXErrorCode
  #elseif canImport(Android)
  /// The Android overlay's Swift enumeration of error numbers,
  /// which Foundation's `POSIXError.Code` is.
  ///
  /// ``Errno`` is System's type for error numbers;
  /// convert between them with their raw values:
  /// `Errno(rawValue: code.rawValue)`.
  ///
  /// The corresponding C type is `POSIXErrorCode`,
  /// the Android overlay's.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, OpenBSD, and WASI.
  public typealias POSIXErrorCode = Android.POSIXErrorCode
  #endif
}

// Under MemberImportVisibility, the enumeration's own cases, `rawValue`, and
// `init(rawValue:)` need the module that declares them, so code that doesn't
// import the overlay converts through Errno with these, which are System's.
@available(System 199, *)
extension CInterop.POSIXErrorCode {
  /// Creates the code for an error number,
  /// or returns `nil` if the overlay has no case for it.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public init?(_ errno: Errno) {
    self.init(rawValue: errno.rawValue)
  }

  /// The code's error number.
  ///
  /// - Note: Provisional: the overlay's types may move to the Swift standard library.
  @_alwaysEmitIntoClient
  public var errno: Errno { Errno(rawValue: rawValue) }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
