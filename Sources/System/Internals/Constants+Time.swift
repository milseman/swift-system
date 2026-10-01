/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Clock IDs. On platforms other than Darwin and WASI, _CLOCK_REALTIME and
// _CLOCK_MONOTONIC are in Constants+Threads.swift, and Linux's
// _CLOCK_BOOTTIME is in Constants+Events.swift; the rest are here.
//
// Darwin's C library declares its clocks as enumerators named
// _CLOCK_REALTIME and so on, but Swift renames those to the names of the
// CLOCK_ macros, so System defines its own _CLOCK_ names there.

#if !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
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

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME: clockid_t { CLOCK_REALTIME }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC: clockid_t { CLOCK_MONOTONIC }

@_alwaysEmitIntoClient
internal var _CLOCK_PROCESS_CPUTIME_ID: clockid_t { CLOCK_PROCESS_CPUTIME_ID }

@_alwaysEmitIntoClient
internal var _CLOCK_THREAD_CPUTIME_ID: clockid_t { CLOCK_THREAD_CPUTIME_ID }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC_RAW: clockid_t { CLOCK_MONOTONIC_RAW }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC_RAW_APPROX: clockid_t { CLOCK_MONOTONIC_RAW_APPROX }

@_alwaysEmitIntoClient
internal var _CLOCK_UPTIME_RAW: clockid_t { CLOCK_UPTIME_RAW }

@_alwaysEmitIntoClient
internal var _CLOCK_UPTIME_RAW_APPROX: clockid_t { CLOCK_UPTIME_RAW_APPROX }
#elseif os(WASI)
// wasi-libc's clocks are pointers to constants, whose CLOCK_ macros take an
// address, which Swift can't import. It has no processor-time clocks.
@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME: clockid_t { _getConst_CLOCK_REALTIME() }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC: clockid_t { _getConst_CLOCK_MONOTONIC() }
#else
@_alwaysEmitIntoClient
internal var _CLOCK_PROCESS_CPUTIME_ID: clockid_t { clockid_t(CLOCK_PROCESS_CPUTIME_ID) }

@_alwaysEmitIntoClient
internal var _CLOCK_THREAD_CPUTIME_ID: clockid_t { clockid_t(CLOCK_THREAD_CPUTIME_ID) }
#endif

#if os(Linux) || os(Android)
// Linux's clocks have these values on every architecture.
@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC_RAW: clockid_t { 4 }

@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME_COARSE: clockid_t { 5 }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC_COARSE: clockid_t { 6 }

@_alwaysEmitIntoClient
internal var _CLOCK_TAI: clockid_t { 11 }
#endif // os(Linux) || os(Android)

#endif // !os(Windows)
