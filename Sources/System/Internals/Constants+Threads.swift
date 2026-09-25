/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The pthread and scheduling constants behind Sources/System/Threads.
//
// Their C types differ: glibc and Bionic declare many of these in anonymous
// enums, which Swift imports as `Int`, and FreeBSD and OpenBSD declare the
// mutex types in a named enum, which Swift imports as a structure.

#if !os(Windows) && !os(WASI)

import CSystem
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

// MARK: - Mutex types

#if os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_NORMAL: CInt { CInt(PTHREAD_MUTEX_NORMAL.rawValue) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_ERRORCHECK: CInt { CInt(PTHREAD_MUTEX_ERRORCHECK.rawValue) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_RECURSIVE: CInt { CInt(PTHREAD_MUTEX_RECURSIVE.rawValue) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_DEFAULT: CInt { CInt(PTHREAD_MUTEX_DEFAULT.rawValue) }
#else
@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_NORMAL: CInt { CInt(PTHREAD_MUTEX_NORMAL) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_ERRORCHECK: CInt { CInt(PTHREAD_MUTEX_ERRORCHECK) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_RECURSIVE: CInt { CInt(PTHREAD_MUTEX_RECURSIVE) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_DEFAULT: CInt { CInt(PTHREAD_MUTEX_DEFAULT) }
#endif

// MARK: - Process sharing

@_alwaysEmitIntoClient
internal var _PTHREAD_PROCESS_PRIVATE: CInt { CInt(PTHREAD_PROCESS_PRIVATE) }

@_alwaysEmitIntoClient
internal var _PTHREAD_PROCESS_SHARED: CInt { CInt(PTHREAD_PROCESS_SHARED) }

// MARK: - Mutex priority protocols

#if !os(Android)
@_alwaysEmitIntoClient
internal var _PTHREAD_PRIO_NONE: CInt { CInt(PTHREAD_PRIO_NONE) }

@_alwaysEmitIntoClient
internal var _PTHREAD_PRIO_INHERIT: CInt { CInt(PTHREAD_PRIO_INHERIT) }

@_alwaysEmitIntoClient
internal var _PTHREAD_PRIO_PROTECT: CInt { CInt(PTHREAD_PRIO_PROTECT) }
#endif

// MARK: - Robust mutexes

#if os(Linux) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_STALLED: CInt { CInt(PTHREAD_MUTEX_STALLED) }

@_alwaysEmitIntoClient
internal var _PTHREAD_MUTEX_ROBUST: CInt { CInt(PTHREAD_MUTEX_ROBUST) }
#endif

// MARK: - Scheduling

@_alwaysEmitIntoClient
internal var _PTHREAD_INHERIT_SCHED: CInt { CInt(PTHREAD_INHERIT_SCHED) }

@_alwaysEmitIntoClient
internal var _PTHREAD_EXPLICIT_SCHED: CInt { CInt(PTHREAD_EXPLICIT_SCHED) }

@_alwaysEmitIntoClient
internal var _SCHED_OTHER: CInt { CInt(SCHED_OTHER) }

@_alwaysEmitIntoClient
internal var _SCHED_FIFO: CInt { CInt(SCHED_FIFO) }

@_alwaysEmitIntoClient
internal var _SCHED_RR: CInt { CInt(SCHED_RR) }

// MARK: - Clocks for condition variables

#if !SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME: clockid_t { clockid_t(CLOCK_REALTIME) }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC: clockid_t { clockid_t(CLOCK_MONOTONIC) }
#endif

// MARK: - Quality of service

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _QOS_CLASS_USER_INTERACTIVE: qos_class_t { QOS_CLASS_USER_INTERACTIVE }

@_alwaysEmitIntoClient
internal var _QOS_CLASS_USER_INITIATED: qos_class_t { QOS_CLASS_USER_INITIATED }

@_alwaysEmitIntoClient
internal var _QOS_CLASS_DEFAULT: qos_class_t { QOS_CLASS_DEFAULT }

@_alwaysEmitIntoClient
internal var _QOS_CLASS_UTILITY: qos_class_t { QOS_CLASS_UTILITY }

@_alwaysEmitIntoClient
internal var _QOS_CLASS_BACKGROUND: qos_class_t { QOS_CLASS_BACKGROUND }

@_alwaysEmitIntoClient
internal var _QOS_CLASS_UNSPECIFIED: qos_class_t { QOS_CLASS_UNSPECIFIED }
#endif

#endif // !os(Windows) && !os(WASI)
