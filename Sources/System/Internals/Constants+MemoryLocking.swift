/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// mlockall's flags: MCL_*. Darwin declares them, but its mlockall always
// fails with ENOSYS, so System has no mlockall there.

#if !os(Windows) && !os(WASI) && !SYSTEM_PACKAGE_DARWIN

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var _MCL_CURRENT: CInt { CInt(MCL_CURRENT) }

@_alwaysEmitIntoClient
internal var _MCL_FUTURE: CInt { CInt(MCL_FUTURE) }

#if os(Linux) || os(Android)
// Linux 4.4.
@_alwaysEmitIntoClient
internal var _MCL_ONFAULT: CInt { 4 }
#endif

#endif // !os(Windows) && !os(WASI) && !SYSTEM_PACKAGE_DARWIN
