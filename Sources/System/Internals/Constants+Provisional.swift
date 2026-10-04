/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library constants that System's provisional API uses (see
// Sources/System/Provisional): stdio's buffering modes and standard streams,
// and on Darwin, Linux and Android the locale categories, which on Darwin
// come from CSystem's Darwin header (see Syscalls+ProvisionalLocale.swift).

#if !os(Windows)

#if os(Linux) || os(Android)
import CSystem
#endif

// glibc, Musl and Bionic declare stdin, stdout and stderr as mutable
// globals, which Swift 6 rejects reading unless the module is imported
// @preconcurrency.
#if SYSTEM_PACKAGE_DARWIN
import CSystem
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
@preconcurrency import Android
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var __IOFBF: CInt { _IOFBF }

@_alwaysEmitIntoClient
internal var __IOLBF: CInt { _IOLBF }

@_alwaysEmitIntoClient
internal var __IONBF: CInt { _IONBF }

// The standard streams, which only Darwin declares as non-optional. On
// OpenBSD, whose streams nothing here has built, they convert implicitly
// either way.
@_alwaysEmitIntoClient
internal var _stdin: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
  stdin
#else
  stdin!
#endif
}

@_alwaysEmitIntoClient
internal var _stdout: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
  stdout
#else
  stdout!
#endif
}

@_alwaysEmitIntoClient
internal var _stderr: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
  stderr
#else
  stderr!
#endif
}

#endif // !os(Windows)

// The locale categories and their masks, for Provisional+Locale.swift.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
@_alwaysEmitIntoClient
internal var _LC_ALL: CInt { LC_ALL }

@_alwaysEmitIntoClient
internal var _LC_COLLATE: CInt { LC_COLLATE }

@_alwaysEmitIntoClient
internal var _LC_CTYPE: CInt { LC_CTYPE }

@_alwaysEmitIntoClient
internal var _LC_MESSAGES: CInt { LC_MESSAGES }

@_alwaysEmitIntoClient
internal var _LC_MONETARY: CInt { LC_MONETARY }

@_alwaysEmitIntoClient
internal var _LC_NUMERIC: CInt { LC_NUMERIC }

@_alwaysEmitIntoClient
internal var _LC_TIME: CInt { LC_TIME }

@_alwaysEmitIntoClient
internal var _LC_COLLATE_MASK: CInt { LC_COLLATE_MASK }

@_alwaysEmitIntoClient
internal var _LC_CTYPE_MASK: CInt { LC_CTYPE_MASK }

@_alwaysEmitIntoClient
internal var _LC_MESSAGES_MASK: CInt { LC_MESSAGES_MASK }

@_alwaysEmitIntoClient
internal var _LC_MONETARY_MASK: CInt { LC_MONETARY_MASK }

@_alwaysEmitIntoClient
internal var _LC_NUMERIC_MASK: CInt { LC_NUMERIC_MASK }

@_alwaysEmitIntoClient
internal var _LC_TIME_MASK: CInt { LC_TIME_MASK }

#if os(Linux) || os(Android)
// glibc's and Bionic's LC_ALL_MASK ORs their twelve categories' masks, which
// Swift can't import; see shims.c.
@_alwaysEmitIntoClient
internal var _LC_ALL_MASK: CInt { _system_get_LC_ALL_MASK() }
#elseif os(WASI)
@_alwaysEmitIntoClient
internal var _LC_ALL_MASK: CInt { LC_ALL_MASK }
#endif

// The items that CLocale.information(_:) returns. glibc declares them in an
// anonymous enum, whose constants import as Int, and the others as macros.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _CODESET: nl_item { nl_item(CODESET) }

@_alwaysEmitIntoClient
internal var _D_T_FMT: nl_item { nl_item(D_T_FMT) }

@_alwaysEmitIntoClient
internal var _D_FMT: nl_item { nl_item(D_FMT) }

@_alwaysEmitIntoClient
internal var _T_FMT: nl_item { nl_item(T_FMT) }

@_alwaysEmitIntoClient
internal var _T_FMT_AMPM: nl_item { nl_item(T_FMT_AMPM) }

@_alwaysEmitIntoClient
internal var _AM_STR: nl_item { nl_item(AM_STR) }

@_alwaysEmitIntoClient
internal var _PM_STR: nl_item { nl_item(PM_STR) }

@_alwaysEmitIntoClient
internal var _DAY_1: nl_item { nl_item(DAY_1) }

@_alwaysEmitIntoClient
internal var _ABDAY_1: nl_item { nl_item(ABDAY_1) }

@_alwaysEmitIntoClient
internal var _MON_1: nl_item { nl_item(MON_1) }

@_alwaysEmitIntoClient
internal var _ABMON_1: nl_item { nl_item(ABMON_1) }

@_alwaysEmitIntoClient
internal var _RADIXCHAR: nl_item { nl_item(RADIXCHAR) }

@_alwaysEmitIntoClient
internal var _THOUSEP: nl_item { nl_item(THOUSEP) }

#if os(Linux) && canImport(Glibc)
// glibc's YESEXPR, NOEXPR and CRNCYSTR are macros for these enum constants,
// which Swift doesn't import under the macros' names.
@_alwaysEmitIntoClient
internal var _YESEXPR: nl_item { nl_item(__YESEXPR) }

@_alwaysEmitIntoClient
internal var _NOEXPR: nl_item { nl_item(__NOEXPR) }

@_alwaysEmitIntoClient
internal var _CRNCYSTR: nl_item { nl_item(_NL_MONETARY_CRNCYSTR) }
#else
@_alwaysEmitIntoClient
internal var _YESEXPR: nl_item { nl_item(YESEXPR) }

@_alwaysEmitIntoClient
internal var _NOEXPR: nl_item { nl_item(NOEXPR) }

@_alwaysEmitIntoClient
internal var _CRNCYSTR: nl_item { nl_item(CRNCYSTR) }
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _D_MD_ORDER: nl_item { nl_item(D_MD_ORDER) }
#endif
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD)
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
