/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The C library's compile-time limits on names, paths and arguments.

#if !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var _NAME_MAX: CInt { NAME_MAX }

@_alwaysEmitIntoClient
internal var _PATH_MAX: CInt { PATH_MAX }

@_alwaysEmitIntoClient
internal var __POSIX_ARG_MAX: CInt { _POSIX_ARG_MAX }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _IOV_MAX: CInt { IOV_MAX }
#elseif os(Linux) || os(Android)
// glibc declares IOV_MAX only with _XOPEN_SOURCE. UIO_MAXIOV, in every Linux
// C library's <sys/uio.h>, is the same limit.
@_alwaysEmitIntoClient
internal var _IOV_MAX: CInt { CInt(UIO_MAXIOV) }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _MAXSYMLINKS: CInt { MAXSYMLINKS }

@_alwaysEmitIntoClient
internal var _XATTR_MAXNAMELEN: CInt { XATTR_MAXNAMELEN }
#endif

#endif // !os(Windows) && !os(WASI)
