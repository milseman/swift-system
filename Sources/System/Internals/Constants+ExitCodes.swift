/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Exit codes: the C standard's EXIT_SUCCESS and EXIT_FAILURE, and
// <sysexits.h>'s EX_*.

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

@_alwaysEmitIntoClient
internal var _EXIT_SUCCESS: CInt { EXIT_SUCCESS }

@_alwaysEmitIntoClient
internal var _EXIT_FAILURE: CInt { EXIT_FAILURE }

@_alwaysEmitIntoClient
internal var _EX_USAGE: CInt { EX_USAGE }

@_alwaysEmitIntoClient
internal var _EX_DATAERR: CInt { EX_DATAERR }

@_alwaysEmitIntoClient
internal var _EX_NOINPUT: CInt { EX_NOINPUT }

@_alwaysEmitIntoClient
internal var _EX_NOUSER: CInt { EX_NOUSER }

@_alwaysEmitIntoClient
internal var _EX_NOHOST: CInt { EX_NOHOST }

@_alwaysEmitIntoClient
internal var _EX_UNAVAILABLE: CInt { EX_UNAVAILABLE }

@_alwaysEmitIntoClient
internal var _EX_SOFTWARE: CInt { EX_SOFTWARE }

@_alwaysEmitIntoClient
internal var _EX_OSERR: CInt { EX_OSERR }

@_alwaysEmitIntoClient
internal var _EX_OSFILE: CInt { EX_OSFILE }

@_alwaysEmitIntoClient
internal var _EX_CANTCREAT: CInt { EX_CANTCREAT }

@_alwaysEmitIntoClient
internal var _EX_IOERR: CInt { EX_IOERR }

@_alwaysEmitIntoClient
internal var _EX_TEMPFAIL: CInt { EX_TEMPFAIL }

@_alwaysEmitIntoClient
internal var _EX_PROTOCOL: CInt { EX_PROTOCOL }

@_alwaysEmitIntoClient
internal var _EX_NOPERM: CInt { EX_NOPERM }

@_alwaysEmitIntoClient
internal var _EX_CONFIG: CInt { EX_CONFIG }

#endif // !os(Windows)
