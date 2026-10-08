/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The names of the configurable system strings that confstr reads.

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// Bionic has no confstr.
#if !os(Windows) && !os(WASI) && !os(Android)
// These are macros on some platforms and enumerations on others.
@_alwaysEmitIntoClient
internal var __CS_PATH: CInt { CInt(_CS_PATH) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var __CS_DARWIN_USER_DIR: CInt { CInt(_CS_DARWIN_USER_DIR) }

@_alwaysEmitIntoClient
internal var __CS_DARWIN_USER_TEMP_DIR: CInt { CInt(_CS_DARWIN_USER_TEMP_DIR) }

@_alwaysEmitIntoClient
internal var __CS_DARWIN_USER_CACHE_DIR: CInt { CInt(_CS_DARWIN_USER_CACHE_DIR) }
#endif // SYSTEM_PACKAGE_DARWIN

#if os(Linux) && canImport(Glibc)
@_alwaysEmitIntoClient
internal var __CS_GNU_LIBC_VERSION: CInt { CInt(_CS_GNU_LIBC_VERSION) }
#endif
#endif // !os(Windows) && !os(WASI) && !os(Android)
