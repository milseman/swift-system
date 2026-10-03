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

// The standard streams, which only Darwin declares as non-optional.
@_alwaysEmitIntoClient
internal var _stdin: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN
  stdin
#else
  stdin!
#endif
}

@_alwaysEmitIntoClient
internal var _stdout: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN
  stdout
#else
  stdout!
#endif
}

@_alwaysEmitIntoClient
internal var _stderr: _CFilePointer {
#if SYSTEM_PACKAGE_DARWIN
  stderr
#else
  stderr!
#endif
}

#endif // !os(Windows)

// The locale categories and their masks, for Provisional+Locale.swift.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
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
#endif
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
