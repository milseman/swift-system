/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

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

// MARK: - dlopen modes

@_alwaysEmitIntoClient
internal var _RTLD_LAZY: CInt { RTLD_LAZY }

@_alwaysEmitIntoClient
internal var _RTLD_NOW: CInt { RTLD_NOW }

@_alwaysEmitIntoClient
internal var _RTLD_GLOBAL: CInt { RTLD_GLOBAL }

// Zero on Linux, where it's the default, and not on Darwin, where it isn't.
@_alwaysEmitIntoClient
internal var _RTLD_LOCAL: CInt { RTLD_LOCAL }

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _RTLD_NOLOAD: CInt { RTLD_NOLOAD }

@_alwaysEmitIntoClient
internal var _RTLD_NODELETE: CInt { RTLD_NODELETE }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _RTLD_FIRST: CInt { RTLD_FIRST }
#endif

#endif // !os(Windows) && !os(WASI)
