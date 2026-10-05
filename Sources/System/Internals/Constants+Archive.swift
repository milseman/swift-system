/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The constants of the archive format, from <ar.h>, that System's
// provisional API uses (Provisional/Provisional+Ar.swift). glibc's, the
// BSDs' and WASI's Swift modules don't include <ar.h>, so there they come
// from CSystem's headers.

#if !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
import Darwin.ar
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import CSystem
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var _ARMAG: String { ARMAG }

@_alwaysEmitIntoClient
internal var _SARMAG: CInt { CInt(SARMAG) }

@_alwaysEmitIntoClient
internal var _ARFMAG: String { ARFMAG }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _AR_EFMT1: String { AR_EFMT1 }
#endif

#endif // !os(Windows)
