/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The libproc constants beyond RUSAGE_INFO_V6 and PROC_PIDTASKINFO, which
// are in Constants.swift: proc_listpids's kinds of lists, proc_pidinfo's
// flavors, and the values in the information those return.

// libproc is only in the macOS SDK.
#if os(macOS)
import Darwin

// MARK: proc_listpids types

@_alwaysEmitIntoClient
internal var _PROC_ALL_PIDS: UInt32 { UInt32(PROC_ALL_PIDS) }

@_alwaysEmitIntoClient
internal var _PROC_PGRP_ONLY: UInt32 { UInt32(PROC_PGRP_ONLY) }

@_alwaysEmitIntoClient
internal var _PROC_TTY_ONLY: UInt32 { UInt32(PROC_TTY_ONLY) }

@_alwaysEmitIntoClient
internal var _PROC_UID_ONLY: UInt32 { UInt32(PROC_UID_ONLY) }

@_alwaysEmitIntoClient
internal var _PROC_RUID_ONLY: UInt32 { UInt32(PROC_RUID_ONLY) }

@_alwaysEmitIntoClient
internal var _PROC_PPID_ONLY: UInt32 { UInt32(PROC_PPID_ONLY) }

// MARK: proc_pidinfo flavors

@_alwaysEmitIntoClient
internal var _PROC_PIDTBSDINFO: CInt { PROC_PIDTBSDINFO }

@_alwaysEmitIntoClient
internal var _PROC_PIDVNODEPATHINFO: CInt { PROC_PIDVNODEPATHINFO }

// The macro is an expression, which Swift doesn't import.
@_alwaysEmitIntoClient
internal var _PROC_PIDPATHINFO_MAXSIZE: Int { 4 * Int(MAXPATHLEN) }

// MARK: Process status (p_stat)

@_alwaysEmitIntoClient
internal var _SIDL: UInt32 { UInt32(SIDL) }

@_alwaysEmitIntoClient
internal var _SRUN: UInt32 { UInt32(SRUN) }

@_alwaysEmitIntoClient
internal var _SSLEEP: UInt32 { UInt32(SSLEEP) }

@_alwaysEmitIntoClient
internal var _SSTOP: UInt32 { UInt32(SSTOP) }

@_alwaysEmitIntoClient
internal var _SZOMB: UInt32 { UInt32(SZOMB) }

// MARK: proc_bsdinfo flags

@_alwaysEmitIntoClient
internal var _PROC_FLAG_SYSTEM: UInt32 { UInt32(PROC_FLAG_SYSTEM) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_TRACED: UInt32 { UInt32(PROC_FLAG_TRACED) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_INEXIT: UInt32 { UInt32(PROC_FLAG_INEXIT) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_PPWAIT: UInt32 { UInt32(PROC_FLAG_PPWAIT) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_LP64: UInt32 { UInt32(PROC_FLAG_LP64) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_SLEADER: UInt32 { UInt32(PROC_FLAG_SLEADER) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_CTTY: UInt32 { UInt32(PROC_FLAG_CTTY) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_CONTROLT: UInt32 { UInt32(PROC_FLAG_CONTROLT) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_THCWD: UInt32 { UInt32(PROC_FLAG_THCWD) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_PSUGID: UInt32 { UInt32(PROC_FLAG_PSUGID) }

@_alwaysEmitIntoClient
internal var _PROC_FLAG_EXEC: UInt32 { UInt32(PROC_FLAG_EXEC) }

// MARK: proc_fdinfo types

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_ATALK: UInt32 { UInt32(PROX_FDTYPE_ATALK) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_VNODE: UInt32 { UInt32(PROX_FDTYPE_VNODE) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_SOCKET: UInt32 { UInt32(PROX_FDTYPE_SOCKET) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_PSHM: UInt32 { UInt32(PROX_FDTYPE_PSHM) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_PSEM: UInt32 { UInt32(PROX_FDTYPE_PSEM) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_KQUEUE: UInt32 { UInt32(PROX_FDTYPE_KQUEUE) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_PIPE: UInt32 { UInt32(PROX_FDTYPE_PIPE) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_FSEVENTS: UInt32 { UInt32(PROX_FDTYPE_FSEVENTS) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_NETPOLICY: UInt32 { UInt32(PROX_FDTYPE_NETPOLICY) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_CHANNEL: UInt32 { UInt32(PROX_FDTYPE_CHANNEL) }

@_alwaysEmitIntoClient
internal var _PROX_FDTYPE_NEXUS: UInt32 { UInt32(PROX_FDTYPE_NEXUS) }

#endif // os(macOS)
