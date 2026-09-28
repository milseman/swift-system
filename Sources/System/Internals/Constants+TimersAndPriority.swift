/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Interval timers and scheduling priorities: ITIMER_* and PRIO_*.

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

#if os(Linux) || os(Android)
// glibc declares these in named enums, whose types aren't the calls'
// parameters' without _GNU_SOURCE, so they're spelled out, as the kernel's
// values, which are the same on every architecture.
@_alwaysEmitIntoClient
internal var _ITIMER_REAL: CInt { 0 }

@_alwaysEmitIntoClient
internal var _ITIMER_VIRTUAL: CInt { 1 }

@_alwaysEmitIntoClient
internal var _ITIMER_PROF: CInt { 2 }

@_alwaysEmitIntoClient
internal var _PRIO_PROCESS: CInt { 0 }

@_alwaysEmitIntoClient
internal var _PRIO_PGRP: CInt { 1 }

@_alwaysEmitIntoClient
internal var _PRIO_USER: CInt { 2 }
#else
@_alwaysEmitIntoClient
internal var _ITIMER_REAL: CInt { ITIMER_REAL }

@_alwaysEmitIntoClient
internal var _ITIMER_VIRTUAL: CInt { ITIMER_VIRTUAL }

@_alwaysEmitIntoClient
internal var _ITIMER_PROF: CInt { ITIMER_PROF }

@_alwaysEmitIntoClient
internal var _PRIO_PROCESS: CInt { PRIO_PROCESS }

@_alwaysEmitIntoClient
internal var _PRIO_PGRP: CInt { PRIO_PGRP }

@_alwaysEmitIntoClient
internal var _PRIO_USER: CInt { PRIO_USER }
#endif

#endif // !os(Windows) && !os(WASI)
