/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

// For platform constants redefined in Swift. We define them here so that
// they can be used anywhere without imports and without confusion to
// unavailable local decls.

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif os(Windows)
import ucrt
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

// MARK: errno
#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _ERRNO_NOT_USED: CInt { 0 }
#endif

@_alwaysEmitIntoClient
internal var _EPERM: CInt { EPERM }

@_alwaysEmitIntoClient
internal var _ENOENT: CInt { ENOENT }

@_alwaysEmitIntoClient
internal var _ESRCH: CInt { ESRCH }

@_alwaysEmitIntoClient
internal var _EINTR: CInt { EINTR }

@_alwaysEmitIntoClient
internal var _EIO: CInt { EIO }

@_alwaysEmitIntoClient
internal var _ENXIO: CInt { ENXIO }

@_alwaysEmitIntoClient
internal var _E2BIG: CInt { E2BIG }

@_alwaysEmitIntoClient
internal var _ENOEXEC: CInt { ENOEXEC }

@_alwaysEmitIntoClient
internal var _EBADF: CInt { EBADF }

@_alwaysEmitIntoClient
internal var _ECHILD: CInt { ECHILD }

@_alwaysEmitIntoClient
internal var _EDEADLK: CInt { EDEADLK }

@_alwaysEmitIntoClient
internal var _ENOMEM: CInt { ENOMEM }

@_alwaysEmitIntoClient
internal var _EACCES: CInt { EACCES }

@_alwaysEmitIntoClient
internal var _EFAULT: CInt { EFAULT }

#if !os(Windows) && !os(WASI)
@_alwaysEmitIntoClient
internal var _ENOTBLK: CInt { ENOTBLK }
#endif

@_alwaysEmitIntoClient
internal var _EBUSY: CInt { EBUSY }

@_alwaysEmitIntoClient
internal var _EEXIST: CInt { EEXIST }

@_alwaysEmitIntoClient
internal var _EXDEV: CInt { EXDEV }

@_alwaysEmitIntoClient
internal var _ENODEV: CInt { ENODEV }

@_alwaysEmitIntoClient
internal var _ENOTDIR: CInt { ENOTDIR }

@_alwaysEmitIntoClient
internal var _EISDIR: CInt { EISDIR }

@_alwaysEmitIntoClient
internal var _EINVAL: CInt { EINVAL }

@_alwaysEmitIntoClient
internal var _ENFILE: CInt { ENFILE }

@_alwaysEmitIntoClient
internal var _EMFILE: CInt { EMFILE }

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _ENOTTY: CInt { ENOTTY }

@_alwaysEmitIntoClient
internal var _ETXTBSY: CInt { ETXTBSY }
#endif

@_alwaysEmitIntoClient
internal var _EFBIG: CInt { EFBIG }

@_alwaysEmitIntoClient
internal var _ENOSPC: CInt { ENOSPC }

@_alwaysEmitIntoClient
internal var _ESPIPE: CInt { ESPIPE }

@_alwaysEmitIntoClient
internal var _EROFS: CInt { EROFS }

@_alwaysEmitIntoClient
internal var _EMLINK: CInt { EMLINK }

@_alwaysEmitIntoClient
internal var _EPIPE: CInt { EPIPE }

@_alwaysEmitIntoClient
internal var _EDOM: CInt { EDOM }

@_alwaysEmitIntoClient
internal var _ERANGE: CInt { ERANGE }

@_alwaysEmitIntoClient
internal var _EAGAIN: CInt { EAGAIN }

@_alwaysEmitIntoClient
internal var _EWOULDBLOCK: CInt {
#if os(WASI)
  _getConst_EWOULDBLOCK()
#else
  EWOULDBLOCK
#endif
}

@_alwaysEmitIntoClient
internal var _EINPROGRESS: CInt { EINPROGRESS }

@_alwaysEmitIntoClient
internal var _EALREADY: CInt { EALREADY }

@_alwaysEmitIntoClient
internal var _ENOTSOCK: CInt { ENOTSOCK }

@_alwaysEmitIntoClient
internal var _EDESTADDRREQ: CInt { EDESTADDRREQ }

@_alwaysEmitIntoClient
internal var _EMSGSIZE: CInt { EMSGSIZE }

@_alwaysEmitIntoClient
internal var _EPROTOTYPE: CInt { EPROTOTYPE }

@_alwaysEmitIntoClient
internal var _ENOPROTOOPT: CInt { ENOPROTOOPT }

@_alwaysEmitIntoClient
internal var _EPROTONOSUPPORT: CInt { EPROTONOSUPPORT }

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _ESOCKTNOSUPPORT: CInt {
#if os(Windows)
  return WSAESOCKTNOSUPPORT
#else
  return ESOCKTNOSUPPORT
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _ENOTSUP: CInt {
#if os(Windows)
  return WSAEOPNOTSUPP
#else
  return ENOTSUP
#endif
}

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _EPFNOSUPPORT: CInt {
#if os(Windows)
  return WSAEPFNOSUPPORT
#else
  return EPFNOSUPPORT
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _EAFNOSUPPORT: CInt { EAFNOSUPPORT }

@_alwaysEmitIntoClient
internal var _EADDRINUSE: CInt { EADDRINUSE }

@_alwaysEmitIntoClient
internal var _EADDRNOTAVAIL: CInt { EADDRNOTAVAIL }

@_alwaysEmitIntoClient
internal var _ENETDOWN: CInt { ENETDOWN }

@_alwaysEmitIntoClient
internal var _ENETUNREACH: CInt { ENETUNREACH }

@_alwaysEmitIntoClient
internal var _ENETRESET: CInt { ENETRESET }

@_alwaysEmitIntoClient
internal var _ECONNABORTED: CInt { ECONNABORTED }

@_alwaysEmitIntoClient
internal var _ECONNRESET: CInt { ECONNRESET }

@_alwaysEmitIntoClient
internal var _ENOBUFS: CInt { ENOBUFS }

@_alwaysEmitIntoClient
internal var _EISCONN: CInt { EISCONN }

@_alwaysEmitIntoClient
internal var _ENOTCONN: CInt { ENOTCONN }

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _ESHUTDOWN: CInt {
#if os(Windows)
  return WSAESHUTDOWN
#else
  return ESHUTDOWN
#endif
}

@_alwaysEmitIntoClient
internal var _ETOOMANYREFS: CInt {
#if os(Windows)
  return WSAETOOMANYREFS
#else
  return ETOOMANYREFS
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _ETIMEDOUT: CInt { ETIMEDOUT }

@_alwaysEmitIntoClient
internal var _ECONNREFUSED: CInt { ECONNREFUSED }

@_alwaysEmitIntoClient
internal var _ELOOP: CInt { ELOOP }

@_alwaysEmitIntoClient
internal var _ENAMETOOLONG: CInt { ENAMETOOLONG }

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _EHOSTDOWN: CInt {
#if os(Windows)
  return WSAEHOSTDOWN
#else
  return EHOSTDOWN
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _EHOSTUNREACH: CInt { EHOSTUNREACH }

@_alwaysEmitIntoClient
internal var _ENOTEMPTY: CInt { ENOTEMPTY }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EPROCLIM: CInt { EPROCLIM }
#endif

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _EUSERS: CInt {
#if os(Windows)
  return WSAEUSERS
#else
  return EUSERS
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _EDQUOT: CInt {
#if os(Windows)
  return WSAEDQUOT
#else
  return EDQUOT
#endif
}

@_alwaysEmitIntoClient
internal var _ESTALE: CInt {
#if os(Windows)
  return WSAESTALE
#else
  return ESTALE
#endif
}

#if !os(WASI)
@_alwaysEmitIntoClient
internal var _EREMOTE: CInt {
#if os(Windows)
  return WSAEREMOTE
#else
  return EREMOTE
#endif
}
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EBADRPC: CInt { EBADRPC }

@_alwaysEmitIntoClient
internal var _ERPCMISMATCH: CInt { ERPCMISMATCH }

@_alwaysEmitIntoClient
internal var _EPROGUNAVAIL: CInt { EPROGUNAVAIL }

@_alwaysEmitIntoClient
internal var _EPROGMISMATCH: CInt { EPROGMISMATCH }

@_alwaysEmitIntoClient
internal var _EPROCUNAVAIL: CInt { EPROCUNAVAIL }
#endif

@_alwaysEmitIntoClient
internal var _ENOLCK: CInt { ENOLCK }

@_alwaysEmitIntoClient
internal var _ENOSYS: CInt { ENOSYS }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _EFTYPE: CInt { EFTYPE }

@_alwaysEmitIntoClient
internal var _EAUTH: CInt { EAUTH }

@_alwaysEmitIntoClient
internal var _ENEEDAUTH: CInt { ENEEDAUTH }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EPWROFF: CInt { EPWROFF }

@_alwaysEmitIntoClient
internal var _EDEVERR: CInt { EDEVERR }
#endif

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _EOVERFLOW: CInt { EOVERFLOW }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EBADEXEC: CInt { EBADEXEC }

@_alwaysEmitIntoClient
internal var _EBADARCH: CInt { EBADARCH }

@_alwaysEmitIntoClient
internal var _ESHLIBVERS: CInt { ESHLIBVERS }

@_alwaysEmitIntoClient
internal var _EBADMACHO: CInt { EBADMACHO }
#endif

@_alwaysEmitIntoClient
internal var _ECANCELED: CInt { ECANCELED }

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _EIDRM: CInt { EIDRM }

@_alwaysEmitIntoClient
internal var _ENOMSG: CInt { ENOMSG }
#endif

@_alwaysEmitIntoClient
internal var _EILSEQ: CInt { EILSEQ }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ENOATTR: CInt { ENOATTR }
#endif

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _EBADMSG: CInt { EBADMSG }

#if !os(OpenBSD)
@_alwaysEmitIntoClient
internal var _EMULTIHOP: CInt { EMULTIHOP }

#if !os(WASI) && !os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ENODATA: CInt { ENODATA }
#endif

@_alwaysEmitIntoClient
internal var _ENOLINK: CInt { ENOLINK }

#if !os(WASI) && !os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ENOSR: CInt { ENOSR }

@_alwaysEmitIntoClient
internal var _ENOSTR: CInt { ENOSTR }
#endif
#endif

@_alwaysEmitIntoClient
internal var _EPROTO: CInt { EPROTO }

#if !os(OpenBSD) && !os(WASI) && !os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ETIME: CInt { ETIME }
#endif
#endif


@_alwaysEmitIntoClient
internal var _EOPNOTSUPP: CInt {
#if os(WASI)
  _getConst_EOPNOTSUPP()
#else
  EOPNOTSUPP
#endif
}

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _ENOPOLICY: CInt { ENOPOLICY }
#endif

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _ENOTRECOVERABLE: CInt { ENOTRECOVERABLE }

@_alwaysEmitIntoClient
internal var _EOWNERDEAD: CInt { EOWNERDEAD }
#endif

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ENOTCAPABLE: CInt { ENOTCAPABLE }

@_alwaysEmitIntoClient
internal var _ECAPMODE: CInt { ECAPMODE }

@_alwaysEmitIntoClient
internal var _EINTEGRITY: CInt { EINTEGRITY }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EQFULL: CInt { EQFULL }
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _ELAST: CInt { ELAST }
#endif

// MARK: File Operations

@_alwaysEmitIntoClient
internal var _O_RDONLY: CInt { O_RDONLY }

@_alwaysEmitIntoClient
internal var _O_WRONLY: CInt { O_WRONLY }

@_alwaysEmitIntoClient
internal var _O_RDWR: CInt { O_RDWR }

#if !os(Windows)
#if canImport(Musl)
internal var _O_ACCMODE: CInt { 0x03|O_SEARCH }
#else
// TODO: API?
@_alwaysEmitIntoClient
internal var _O_ACCMODE: CInt {
#if os(WASI)
  _getConst_O_ACCMODE()
#else
  O_ACCMODE
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _O_NONBLOCK: CInt {
#if os(WASI)
  _getConst_O_NONBLOCK()
#else
  O_NONBLOCK
#endif
}
#endif

@_alwaysEmitIntoClient
internal var _O_APPEND: CInt {
#if os(WASI)
  _getConst_O_APPEND()
#else
  O_APPEND
#endif
}

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _O_SHLOCK: CInt { O_SHLOCK }

@_alwaysEmitIntoClient
internal var _O_EXLOCK: CInt { O_EXLOCK }
#endif

#if !os(Windows)
#if !os(WASI)
// TODO: API?
@_alwaysEmitIntoClient
internal var _O_ASYNC: CInt { O_ASYNC }
#endif

@_alwaysEmitIntoClient
internal var _O_NOFOLLOW: CInt { O_NOFOLLOW }
#endif

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _O_FSYNC: CInt { O_FSYNC }

@_alwaysEmitIntoClient
internal var _O_SYNC: CInt { O_SYNC }
#endif

@_alwaysEmitIntoClient
internal var _O_CREAT: CInt {
#if os(WASI)
  _getConst_O_CREAT()
#else
  O_CREAT
#endif
}

@_alwaysEmitIntoClient
internal var _O_TRUNC: CInt {
#if os(WASI)
  _getConst_O_TRUNC()
#else
  O_TRUNC
#endif
}

@_alwaysEmitIntoClient
internal var _O_EXCL: CInt {
#if os(WASI)
  _getConst_O_EXCL()
#else
  O_EXCL
#endif
}

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _O_EVTONLY: CInt { O_EVTONLY }
#endif

#if !os(Windows)
// TODO: API?
@_alwaysEmitIntoClient
internal var _O_NOCTTY: CInt { O_NOCTTY }

@_alwaysEmitIntoClient
internal var _O_DIRECTORY: CInt {
#if os(WASI)
  _getConst_O_DIRECTORY()
#else
  O_DIRECTORY
#endif
}
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _O_SYMLINK: CInt { O_SYMLINK }
#endif

@_alwaysEmitIntoClient
internal var _O_CLOEXEC: CInt {
  #if os(Windows)
  O_NOINHERIT
  #else
  O_CLOEXEC
  #endif
}

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _O_CLOFORK: CInt {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  COMPATIBILITY_O_CLOFORK
  #elseif !os(WASI) && !os(Linux) && !os(Android)
  O_CLOFORK
  #else
  0
  #endif
}
#endif

@_alwaysEmitIntoClient
internal var _SEEK_SET: CInt { SEEK_SET }

@_alwaysEmitIntoClient
internal var _SEEK_CUR: CInt { SEEK_CUR }

@_alwaysEmitIntoClient
internal var _SEEK_END: CInt { SEEK_END }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _SEEK_HOLE: CInt { SEEK_HOLE }

@_alwaysEmitIntoClient
internal var _SEEK_DATA: CInt { SEEK_DATA }
#endif

// MARK: - fcntl

#if !os(Windows)
@_alwaysEmitIntoClient
internal var _F_GETFD: CInt { F_GETFD }

@_alwaysEmitIntoClient
internal var _F_SETFD: CInt { F_SETFD }

@_alwaysEmitIntoClient
internal var _F_GETFL: CInt { F_GETFL }

@_alwaysEmitIntoClient
internal var _F_SETFL: CInt { F_SETFL }

@_alwaysEmitIntoClient
internal var _FD_CLOEXEC: CInt { FD_CLOEXEC }
#endif

#if !os(Windows) && !os(WASI)
@_alwaysEmitIntoClient
internal var _F_DUPFD: CInt { F_DUPFD }

@_alwaysEmitIntoClient
internal var _F_DUPFD_CLOEXEC: CInt { F_DUPFD_CLOEXEC }
#endif

// MARK: - flock

#if !os(Windows) && !os(WASI)
@_alwaysEmitIntoClient
internal var _LOCK_SH: CInt { LOCK_SH }

@_alwaysEmitIntoClient
internal var _LOCK_EX: CInt { LOCK_EX }

@_alwaysEmitIntoClient
internal var _LOCK_NB: CInt { LOCK_NB }

@_alwaysEmitIntoClient
internal var _LOCK_UN: CInt { LOCK_UN }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _F_FULLFSYNC: CInt { F_FULLFSYNC }

@_alwaysEmitIntoClient
internal var _F_BARRIERFSYNC: CInt { F_BARRIERFSYNC }
#endif

// MARK: - Record locks

#if !os(Windows) && !os(WASI)
// `l_type` is a `short`.
@_alwaysEmitIntoClient
internal var _F_RDLCK: CShort { CShort(F_RDLCK) }

@_alwaysEmitIntoClient
internal var _F_WRLCK: CShort { CShort(F_WRLCK) }

@_alwaysEmitIntoClient
internal var _F_UNLCK: CShort { CShort(F_UNLCK) }
#endif

// glibc declares the OFD commands only with _GNU_SOURCE, so on Linux they
// come from CSystemLinux.h.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _F_OFD_GETLK: CInt {
#if SYSTEM_PACKAGE_DARWIN
  F_OFD_GETLK
#else
  CSYSTEM_F_OFD_GETLK
#endif
}

@_alwaysEmitIntoClient
internal var _F_OFD_SETLK: CInt {
#if SYSTEM_PACKAGE_DARWIN
  F_OFD_SETLK
#else
  CSYSTEM_F_OFD_SETLK
#endif
}

@_alwaysEmitIntoClient
internal var _F_OFD_SETLKW: CInt {
#if SYSTEM_PACKAGE_DARWIN
  F_OFD_SETLKW
#else
  CSYSTEM_F_OFD_SETLKW
#endif
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _F_OFD_SETLKWTIMEOUT: CInt { F_OFD_SETLKWTIMEOUT }
#endif

// MARK: - fcntl commands

#if !os(Windows) && !os(WASI)
@_alwaysEmitIntoClient
internal var _F_GETOWN: CInt { F_GETOWN }

@_alwaysEmitIntoClient
internal var _F_SETOWN: CInt { F_SETOWN }

@_alwaysEmitIntoClient
internal var _F_GETLK: CInt { F_GETLK }

@_alwaysEmitIntoClient
internal var _F_SETLK: CInt { F_SETLK }

@_alwaysEmitIntoClient
internal var _F_SETLKW: CInt { F_SETLKW }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _F_SETLKWTIMEOUT: CInt { F_SETLKWTIMEOUT }

@_alwaysEmitIntoClient
internal var _F_FLUSH_DATA: CInt { F_FLUSH_DATA }

@_alwaysEmitIntoClient
internal var _F_CHKCLEAN: CInt { F_CHKCLEAN }

@_alwaysEmitIntoClient
internal var _F_PREALLOCATE: CInt { F_PREALLOCATE }

@_alwaysEmitIntoClient
internal var _F_SETSIZE: CInt { F_SETSIZE }

@_alwaysEmitIntoClient
internal var _F_RDADVISE: CInt { F_RDADVISE }

@_alwaysEmitIntoClient
internal var _F_RDAHEAD: CInt { F_RDAHEAD }

@_alwaysEmitIntoClient
internal var _F_NOCACHE: CInt { F_NOCACHE }

@_alwaysEmitIntoClient
internal var _F_LOG2PHYS: CInt { F_LOG2PHYS }

@_alwaysEmitIntoClient
internal var _F_GETPATH: CInt { F_GETPATH }

@_alwaysEmitIntoClient
internal var _F_PATHPKG_CHECK: CInt { F_PATHPKG_CHECK }

@_alwaysEmitIntoClient
internal var _F_FREEZE_FS: CInt { F_FREEZE_FS }

@_alwaysEmitIntoClient
internal var _F_THAW_FS: CInt { F_THAW_FS }

@_alwaysEmitIntoClient
internal var _F_GLOBAL_NOCACHE: CInt { F_GLOBAL_NOCACHE }

@_alwaysEmitIntoClient
internal var _F_ADDSIGS: CInt { F_ADDSIGS }

@_alwaysEmitIntoClient
internal var _F_ADDFILESIGS: CInt { F_ADDFILESIGS }

@_alwaysEmitIntoClient
internal var _F_NODIRECT: CInt { F_NODIRECT }

@_alwaysEmitIntoClient
internal var _F_GETPROTECTIONCLASS: CInt { F_GETPROTECTIONCLASS }

@_alwaysEmitIntoClient
internal var _F_SETPROTECTIONCLASS: CInt { F_SETPROTECTIONCLASS }

@_alwaysEmitIntoClient
internal var _F_LOG2PHYS_EXT: CInt { F_LOG2PHYS_EXT }

@_alwaysEmitIntoClient
internal var _F_GETLKPID: CInt { F_GETLKPID }

@_alwaysEmitIntoClient
internal var _F_SETBACKINGSTORE: CInt { F_SETBACKINGSTORE }

@_alwaysEmitIntoClient
internal var _F_GETPATH_MTMINFO: CInt { F_GETPATH_MTMINFO }

@_alwaysEmitIntoClient
internal var _F_GETCODEDIR: CInt { F_GETCODEDIR }

@_alwaysEmitIntoClient
internal var _F_SETNOSIGPIPE: CInt { F_SETNOSIGPIPE }

@_alwaysEmitIntoClient
internal var _F_GETNOSIGPIPE: CInt { F_GETNOSIGPIPE }

@_alwaysEmitIntoClient
internal var _F_TRANSCODEKEY: CInt { F_TRANSCODEKEY }

@_alwaysEmitIntoClient
internal var _F_SINGLE_WRITER: CInt { F_SINGLE_WRITER }

@_alwaysEmitIntoClient
internal var _F_GETPROTECTIONLEVEL: CInt { F_GETPROTECTIONLEVEL }

@_alwaysEmitIntoClient
internal var _F_FINDSIGS: CInt { F_FINDSIGS }

@_alwaysEmitIntoClient
internal var _F_ADDFILESIGS_FOR_DYLD_SIM: CInt { F_ADDFILESIGS_FOR_DYLD_SIM }

@_alwaysEmitIntoClient
internal var _F_ADDFILESIGS_RETURN: CInt { F_ADDFILESIGS_RETURN }

@_alwaysEmitIntoClient
internal var _F_CHECK_LV: CInt { F_CHECK_LV }

@_alwaysEmitIntoClient
internal var _F_PUNCHHOLE: CInt { F_PUNCHHOLE }

@_alwaysEmitIntoClient
internal var _F_TRIM_ACTIVE_FILE: CInt { F_TRIM_ACTIVE_FILE }

@_alwaysEmitIntoClient
internal var _F_SPECULATIVE_READ: CInt { F_SPECULATIVE_READ }

@_alwaysEmitIntoClient
internal var _F_GETPATH_NOFIRMLINK: CInt { F_GETPATH_NOFIRMLINK }

@_alwaysEmitIntoClient
internal var _F_ADDFILESIGS_INFO: CInt { F_ADDFILESIGS_INFO }

@_alwaysEmitIntoClient
internal var _F_ADDFILESUPPL: CInt { F_ADDFILESUPPL }

@_alwaysEmitIntoClient
internal var _F_GETSIGSINFO: CInt { F_GETSIGSINFO }

// `fst_flags` is an `unsigned int`.
@_alwaysEmitIntoClient
internal var _F_ALLOCATECONTIG: UInt32 { UInt32(F_ALLOCATECONTIG) }

@_alwaysEmitIntoClient
internal var _F_ALLOCATEALL: UInt32 { UInt32(F_ALLOCATEALL) }

@_alwaysEmitIntoClient
internal var _F_ALLOCATEPERSIST: UInt32 { UInt32(F_ALLOCATEPERSIST) }

@_alwaysEmitIntoClient
internal var _F_PEOFPOSMODE: CInt { F_PEOFPOSMODE }

@_alwaysEmitIntoClient
internal var _F_VOLPOSMODE: CInt { F_VOLPOSMODE }

// The size of the buffer that F_GETPATH fills.
@_alwaysEmitIntoClient
internal var _MAXPATHLEN: Int { Int(MAXPATHLEN) }
#endif

// glibc declares these only with _GNU_SOURCE, and Bionic defines them with
// an expression Swift can't import, so they come from CSystemLinux.h.
#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _F_GETPIPE_SZ: CInt { CSYSTEM_F_GETPIPE_SZ }

@_alwaysEmitIntoClient
internal var _F_SETPIPE_SZ: CInt { CSYSTEM_F_SETPIPE_SZ }
#endif

// MARK: - sysconf and pathconf

#if !os(Windows) && !os(WASI)
// These are macros on some platforms and enumerations on others.
@_alwaysEmitIntoClient
internal var __SC_ARG_MAX: CInt { CInt(_SC_ARG_MAX) }

@_alwaysEmitIntoClient
internal var __SC_CHILD_MAX: CInt { CInt(_SC_CHILD_MAX) }

@_alwaysEmitIntoClient
internal var __SC_CLK_TCK: CInt { CInt(_SC_CLK_TCK) }

@_alwaysEmitIntoClient
internal var __SC_IOV_MAX: CInt { CInt(_SC_IOV_MAX) }

@_alwaysEmitIntoClient
internal var __SC_NGROUPS_MAX: CInt { CInt(_SC_NGROUPS_MAX) }

@_alwaysEmitIntoClient
internal var __SC_NPROCESSORS_CONF: CInt { CInt(_SC_NPROCESSORS_CONF) }

@_alwaysEmitIntoClient
internal var __SC_NPROCESSORS_ONLN: CInt { CInt(_SC_NPROCESSORS_ONLN) }

@_alwaysEmitIntoClient
internal var __SC_OPEN_MAX: CInt { CInt(_SC_OPEN_MAX) }

@_alwaysEmitIntoClient
internal var __SC_PAGESIZE: CInt { CInt(_SC_PAGESIZE) }

@_alwaysEmitIntoClient
internal var __SC_STREAM_MAX: CInt { CInt(_SC_STREAM_MAX) }

@_alwaysEmitIntoClient
internal var __SC_TZNAME_MAX: CInt { CInt(_SC_TZNAME_MAX) }

@_alwaysEmitIntoClient
internal var __SC_JOB_CONTROL: CInt { CInt(_SC_JOB_CONTROL) }

@_alwaysEmitIntoClient
internal var __SC_SAVED_IDS: CInt { CInt(_SC_SAVED_IDS) }

@_alwaysEmitIntoClient
internal var __SC_VERSION: CInt { CInt(_SC_VERSION) }

@_alwaysEmitIntoClient
internal var __SC_BC_BASE_MAX: CInt { CInt(_SC_BC_BASE_MAX) }

@_alwaysEmitIntoClient
internal var __SC_BC_DIM_MAX: CInt { CInt(_SC_BC_DIM_MAX) }

@_alwaysEmitIntoClient
internal var __SC_BC_SCALE_MAX: CInt { CInt(_SC_BC_SCALE_MAX) }

@_alwaysEmitIntoClient
internal var __SC_BC_STRING_MAX: CInt { CInt(_SC_BC_STRING_MAX) }

@_alwaysEmitIntoClient
internal var __SC_COLL_WEIGHTS_MAX: CInt { CInt(_SC_COLL_WEIGHTS_MAX) }

@_alwaysEmitIntoClient
internal var __SC_EXPR_NEST_MAX: CInt { CInt(_SC_EXPR_NEST_MAX) }

@_alwaysEmitIntoClient
internal var __SC_LINE_MAX: CInt { CInt(_SC_LINE_MAX) }

@_alwaysEmitIntoClient
internal var __SC_RE_DUP_MAX: CInt { CInt(_SC_RE_DUP_MAX) }

@_alwaysEmitIntoClient
internal var __SC_2_VERSION: CInt { CInt(_SC_2_VERSION) }

@_alwaysEmitIntoClient
internal var __SC_2_C_BIND: CInt { CInt(_SC_2_C_BIND) }

@_alwaysEmitIntoClient
internal var __SC_2_C_DEV: CInt { CInt(_SC_2_C_DEV) }

@_alwaysEmitIntoClient
internal var __SC_2_CHAR_TERM: CInt { CInt(_SC_2_CHAR_TERM) }

@_alwaysEmitIntoClient
internal var __SC_2_FORT_DEV: CInt { CInt(_SC_2_FORT_DEV) }

@_alwaysEmitIntoClient
internal var __SC_2_FORT_RUN: CInt { CInt(_SC_2_FORT_RUN) }

@_alwaysEmitIntoClient
internal var __SC_2_LOCALEDEF: CInt { CInt(_SC_2_LOCALEDEF) }

@_alwaysEmitIntoClient
internal var __SC_2_SW_DEV: CInt { CInt(_SC_2_SW_DEV) }

@_alwaysEmitIntoClient
internal var __SC_2_UPE: CInt { CInt(_SC_2_UPE) }

@_alwaysEmitIntoClient
internal var __SC_PHYS_PAGES: CInt { CInt(_SC_PHYS_PAGES) }

@_alwaysEmitIntoClient
internal var __SC_GETPW_R_SIZE_MAX: CInt { CInt(_SC_GETPW_R_SIZE_MAX) }

@_alwaysEmitIntoClient
internal var __SC_GETGR_R_SIZE_MAX: CInt { CInt(_SC_GETGR_R_SIZE_MAX) }

@_alwaysEmitIntoClient
internal var __SC_HOST_NAME_MAX: CInt { CInt(_SC_HOST_NAME_MAX) }

@_alwaysEmitIntoClient
internal var __PC_LINK_MAX: CInt { CInt(_PC_LINK_MAX) }

@_alwaysEmitIntoClient
internal var __PC_MAX_CANON: CInt { CInt(_PC_MAX_CANON) }

@_alwaysEmitIntoClient
internal var __PC_MAX_INPUT: CInt { CInt(_PC_MAX_INPUT) }

@_alwaysEmitIntoClient
internal var __PC_NAME_MAX: CInt { CInt(_PC_NAME_MAX) }

@_alwaysEmitIntoClient
internal var __PC_PATH_MAX: CInt { CInt(_PC_PATH_MAX) }

@_alwaysEmitIntoClient
internal var __PC_PIPE_BUF: CInt { CInt(_PC_PIPE_BUF) }

@_alwaysEmitIntoClient
internal var __PC_CHOWN_RESTRICTED: CInt { CInt(_PC_CHOWN_RESTRICTED) }

@_alwaysEmitIntoClient
internal var __PC_NO_TRUNC: CInt { CInt(_PC_NO_TRUNC) }

@_alwaysEmitIntoClient
internal var __PC_VDISABLE: CInt { CInt(_PC_VDISABLE) }

@_alwaysEmitIntoClient
internal var __PC_FILESIZEBITS: CInt { CInt(_PC_FILESIZEBITS) }

@_alwaysEmitIntoClient
internal var __PC_SYMLINK_MAX: CInt { CInt(_PC_SYMLINK_MAX) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var __PC_XATTR_SIZE_BITS: CInt { CInt(_PC_XATTR_SIZE_BITS) }
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var __PC_MIN_HOLE_SIZE: CInt { CInt(_PC_MIN_HOLE_SIZE) }
#endif
#endif // !os(Windows) && !os(WASI)

// MARK: - Process information

// libproc is only in the macOS SDK.
#if os(macOS)
@_alwaysEmitIntoClient
internal var _RUSAGE_INFO_V6: CInt { RUSAGE_INFO_V6 }

@_alwaysEmitIntoClient
internal var _PROC_PIDTASKINFO: CInt { PROC_PIDTASKINFO }
#endif

// MARK: - posix_fadvise

#if os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
@_alwaysEmitIntoClient
internal var _POSIX_FADV_NORMAL: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_NORMAL()
#else
  POSIX_FADV_NORMAL
#endif
}

@_alwaysEmitIntoClient
internal var _POSIX_FADV_SEQUENTIAL: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_SEQUENTIAL()
#else
  POSIX_FADV_SEQUENTIAL
#endif
}

@_alwaysEmitIntoClient
internal var _POSIX_FADV_RANDOM: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_RANDOM()
#else
  POSIX_FADV_RANDOM
#endif
}

@_alwaysEmitIntoClient
internal var _POSIX_FADV_WILLNEED: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_WILLNEED()
#else
  POSIX_FADV_WILLNEED
#endif
}

@_alwaysEmitIntoClient
internal var _POSIX_FADV_DONTNEED: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_DONTNEED()
#else
  POSIX_FADV_DONTNEED
#endif
}

@_alwaysEmitIntoClient
internal var _POSIX_FADV_NOREUSE: CInt {
#if os(WASI)
  _getConst_POSIX_FADV_NOREUSE()
#else
  POSIX_FADV_NOREUSE
#endif
}
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(WASI)

// MARK: - File System

#if !os(Windows)

@_alwaysEmitIntoClient
internal var _AT_FDCWD: CInt { AT_FDCWD }

// MARK: - *at Flags

@_alwaysEmitIntoClient
internal var _AT_SYMLINK_NOFOLLOW: CInt { AT_SYMLINK_NOFOLLOW }

@_alwaysEmitIntoClient
internal var _AT_SYMLINK_FOLLOW: CInt { AT_SYMLINK_FOLLOW }

@_alwaysEmitIntoClient
internal var _AT_REMOVEDIR: CInt { AT_REMOVEDIR }

@_alwaysEmitIntoClient
internal var _AT_EACCESS: CInt { AT_EACCESS }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _AT_SYMLINK_NOFOLLOW_ANY: CInt { AT_SYMLINK_NOFOLLOW_ANY }
#endif

#if canImport(Darwin, _version: 346) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _AT_RESOLVE_BENEATH: CInt { AT_RESOLVE_BENEATH }
#endif

// MARK: - access Modes

@_alwaysEmitIntoClient
internal var _R_OK: CInt { R_OK }

@_alwaysEmitIntoClient
internal var _W_OK: CInt { W_OK }

@_alwaysEmitIntoClient
internal var _X_OK: CInt { X_OK }

// MARK: - File Times

#if os(Linux) || os(Android)
// glibc and Bionic define these as expressions that Swift can't import.
@_alwaysEmitIntoClient
internal var _UTIME_NOW: Int { Int(CSYSTEM_UTIME_NOW) }

@_alwaysEmitIntoClient
internal var _UTIME_OMIT: Int { Int(CSYSTEM_UTIME_OMIT) }
#else
@_alwaysEmitIntoClient
internal var _UTIME_NOW: Int { Int(UTIME_NOW) }

@_alwaysEmitIntoClient
internal var _UTIME_OMIT: Int { Int(UTIME_OMIT) }
#endif

// MARK: - Rename Flags

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _RENAME_EXCL: CUnsignedInt { CUnsignedInt(RENAME_EXCL) }

@_alwaysEmitIntoClient
internal var _RENAME_SWAP: CUnsignedInt { CUnsignedInt(RENAME_SWAP) }
#elseif os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _RENAME_NOREPLACE: CUnsignedInt { CUnsignedInt(CSYSTEM_RENAME_NOREPLACE) }

@_alwaysEmitIntoClient
internal var _RENAME_EXCHANGE: CUnsignedInt { CUnsignedInt(CSYSTEM_RENAME_EXCHANGE) }
#endif

// MARK: - File Mode / File Type

@_alwaysEmitIntoClient
internal var _MODE_FILETYPE_MASK: mode_t { S_IFMT }

@_alwaysEmitIntoClient
internal var _MODE_PERMISSIONS_MASK: mode_t { 0o7777 }

@_alwaysEmitIntoClient
internal var _S_IFDIR: mode_t { S_IFDIR }

@_alwaysEmitIntoClient
internal var _S_IFCHR: mode_t { S_IFCHR }

@_alwaysEmitIntoClient
internal var _S_IFBLK: mode_t { S_IFBLK }

@_alwaysEmitIntoClient
internal var _S_IFREG: mode_t { S_IFREG }

@_alwaysEmitIntoClient
internal var _S_IFIFO: mode_t { S_IFIFO }

@_alwaysEmitIntoClient
internal var _S_IFLNK: mode_t { S_IFLNK }

@_alwaysEmitIntoClient
internal var _S_IFSOCK: mode_t { S_IFSOCK }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
// `S_IFWHT` is `Int32` on FreeBSD.
@_alwaysEmitIntoClient
internal var _S_IFWHT: mode_t { .init(S_IFWHT) }
#endif

// MARK: - stat/chflags File Flags

// MARK: Flags Available on Darwin, FreeBSD, and OpenBSD

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _UF_NODUMP: UInt32 { UInt32(bitPattern: UF_NODUMP) }

@_alwaysEmitIntoClient
internal var _UF_IMMUTABLE: UInt32 { UInt32(bitPattern: UF_IMMUTABLE) }

@_alwaysEmitIntoClient
internal var _UF_APPEND: UInt32 { UInt32(bitPattern: UF_APPEND) }

@_alwaysEmitIntoClient
internal var _SF_ARCHIVED: UInt32 { UInt32(bitPattern: SF_ARCHIVED) }

@_alwaysEmitIntoClient
internal var _SF_IMMUTABLE: UInt32 { UInt32(bitPattern: SF_IMMUTABLE) }

@_alwaysEmitIntoClient
internal var _SF_APPEND: UInt32 { UInt32(bitPattern: SF_APPEND) }
#endif

// MARK: Flags Available on Darwin and FreeBSD

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _UF_OPAQUE: UInt32 { UInt32(bitPattern: UF_OPAQUE) }

@_alwaysEmitIntoClient
internal var _UF_HIDDEN: UInt32 { UInt32(bitPattern: UF_HIDDEN) }

@_alwaysEmitIntoClient
internal var _SF_NOUNLINK: UInt32 { UInt32(bitPattern: SF_NOUNLINK) }
#endif

// MARK: Flags Available on Darwin Only

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _UF_COMPRESSED: UInt32 { UInt32(bitPattern: UF_COMPRESSED) }

@_alwaysEmitIntoClient
internal var _UF_TRACKED: UInt32 { UInt32(bitPattern: UF_TRACKED) }

@_alwaysEmitIntoClient
internal var _UF_DATAVAULT: UInt32 { UInt32(bitPattern: UF_DATAVAULT) }

@_alwaysEmitIntoClient
internal var _SF_RESTRICTED: UInt32 { UInt32(bitPattern: SF_RESTRICTED) }

@_alwaysEmitIntoClient
internal var _SF_FIRMLINK: UInt32 { UInt32(bitPattern: SF_FIRMLINK) }

@_alwaysEmitIntoClient
internal var _SF_DATALESS: UInt32 { UInt32(bitPattern: SF_DATALESS) }
#endif

// MARK: Flags Available on FreeBSD Only

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _UF_NOUNLINK: UInt32 { UInt32(bitPattern: UF_NOUNLINK) }

@_alwaysEmitIntoClient
internal var _UF_OFFLINE: UInt32 { UInt32(bitPattern: UF_OFFLINE) }

@_alwaysEmitIntoClient
internal var _UF_READONLY: UInt32 { UInt32(bitPattern: UF_READONLY) }

@_alwaysEmitIntoClient
internal var _UF_REPARSE: UInt32 { UInt32(bitPattern: UF_REPARSE) }

@_alwaysEmitIntoClient
internal var _UF_SPARSE: UInt32 { UInt32(bitPattern: UF_SPARSE) }

@_alwaysEmitIntoClient
internal var _UF_SYSTEM: UInt32 { UInt32(bitPattern: UF_SYSTEM) }

@_alwaysEmitIntoClient
internal var _SF_SNAPSHOT: UInt32 { UInt32(bitPattern: SF_SNAPSHOT) }
#endif

// MARK: - Terminal Control (termios)

#if !os(WASI)
// Special values
@_alwaysEmitIntoClient
internal var _NCCS: CInt { CInt(NCCS) }

@_alwaysEmitIntoClient
internal var __POSIX_VDISABLE: cc_t {
#if SYSTEM_PACKAGE_DARWIN
  // <sys/_types/_posix_vdisable.h> defines _POSIX_VDISABLE as
  // ((unsigned char)'\377'), which Swift doesn't import.
  0xFF
#elseif os(Linux) && canImport(Glibc)
  // glibc's <bits/posix_opt.h> defines it as '\0', which Swift doesn't import.
  0
#elseif os(Android)
  // Bionic's <bits/posix_limits.h> defines it as '\0', which Swift doesn't import.
  0
#else
  // musl's <unistd.h> defines it as 0, FreeBSD's <sys/_termios.h> as 0xff,
  // and OpenBSD's <sys/termios.h> as (0377), which Swift imports.
  cc_t(_POSIX_VDISABLE)
#endif
}

// Input flags (c_iflag)
@_alwaysEmitIntoClient
internal var _BRKINT: tcflag_t { tcflag_t(BRKINT) }

@_alwaysEmitIntoClient
internal var _ICRNL: tcflag_t { tcflag_t(ICRNL) }

@_alwaysEmitIntoClient
internal var _IGNBRK: tcflag_t { tcflag_t(IGNBRK) }

@_alwaysEmitIntoClient
internal var _IGNCR: tcflag_t { tcflag_t(IGNCR) }

@_alwaysEmitIntoClient
internal var _IGNPAR: tcflag_t { tcflag_t(IGNPAR) }

@_alwaysEmitIntoClient
internal var _INLCR: tcflag_t { tcflag_t(INLCR) }

@_alwaysEmitIntoClient
internal var _INPCK: tcflag_t { tcflag_t(INPCK) }

@_alwaysEmitIntoClient
internal var _ISTRIP: tcflag_t { tcflag_t(ISTRIP) }

@_alwaysEmitIntoClient
internal var _IXANY: tcflag_t { tcflag_t(IXANY) }

@_alwaysEmitIntoClient
internal var _IXOFF: tcflag_t { tcflag_t(IXOFF) }

@_alwaysEmitIntoClient
internal var _IXON: tcflag_t { tcflag_t(IXON) }

@_alwaysEmitIntoClient
internal var _PARMRK: tcflag_t { tcflag_t(PARMRK) }

@_alwaysEmitIntoClient
internal var _IMAXBEL: tcflag_t { tcflag_t(IMAXBEL) }

@_alwaysEmitIntoClient
internal var _IUTF8: tcflag_t { tcflag_t(IUTF8) }

#if os(Linux)
@_alwaysEmitIntoClient
internal var _IUCLC: tcflag_t { tcflag_t(IUCLC) }
#endif

// Output flags (c_oflag)
@_alwaysEmitIntoClient
internal var _OPOST: tcflag_t { tcflag_t(OPOST) }

@_alwaysEmitIntoClient
internal var _ONLCR: tcflag_t { tcflag_t(ONLCR) }

@_alwaysEmitIntoClient
internal var _OCRNL: tcflag_t { tcflag_t(OCRNL) }

@_alwaysEmitIntoClient
internal var _ONOCR: tcflag_t { tcflag_t(ONOCR) }

@_alwaysEmitIntoClient
internal var _ONLRET: tcflag_t { tcflag_t(ONLRET) }

@_alwaysEmitIntoClient
internal var _OFILL: tcflag_t { tcflag_t(OFILL) }

@_alwaysEmitIntoClient
internal var _OFDEL: tcflag_t { tcflag_t(OFDEL) }

@_alwaysEmitIntoClient
internal var _NLDLY: tcflag_t { tcflag_t(NLDLY) }

@_alwaysEmitIntoClient
internal var _NL0: tcflag_t { tcflag_t(NL0) }

@_alwaysEmitIntoClient
internal var _NL1: tcflag_t { tcflag_t(NL1) }

@_alwaysEmitIntoClient
internal var _CRDLY: tcflag_t { tcflag_t(CRDLY) }

@_alwaysEmitIntoClient
internal var _CR0: tcflag_t { tcflag_t(CR0) }

@_alwaysEmitIntoClient
internal var _CR1: tcflag_t { tcflag_t(CR1) }

@_alwaysEmitIntoClient
internal var _CR2: tcflag_t { tcflag_t(CR2) }

@_alwaysEmitIntoClient
internal var _CR3: tcflag_t { tcflag_t(CR3) }

@_alwaysEmitIntoClient
internal var _TABDLY: tcflag_t { tcflag_t(TABDLY) }

@_alwaysEmitIntoClient
internal var _TAB0: tcflag_t { tcflag_t(TAB0) }

@_alwaysEmitIntoClient
internal var _TAB1: tcflag_t { tcflag_t(TAB1) }

@_alwaysEmitIntoClient
internal var _TAB2: tcflag_t { tcflag_t(TAB2) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _TAB3: tcflag_t { tcflag_t(TAB3) }
#elseif os(Linux)
@_alwaysEmitIntoClient
internal var _XTABS: tcflag_t { tcflag_t(XTABS) }
#endif

@_alwaysEmitIntoClient
internal var _BSDLY: tcflag_t { tcflag_t(BSDLY) }

@_alwaysEmitIntoClient
internal var _BS0: tcflag_t { tcflag_t(BS0) }

@_alwaysEmitIntoClient
internal var _BS1: tcflag_t { tcflag_t(BS1) }

@_alwaysEmitIntoClient
internal var _VTDLY: tcflag_t { tcflag_t(VTDLY) }

@_alwaysEmitIntoClient
internal var _VT0: tcflag_t { tcflag_t(VT0) }

@_alwaysEmitIntoClient
internal var _VT1: tcflag_t { tcflag_t(VT1) }

@_alwaysEmitIntoClient
internal var _FFDLY: tcflag_t { tcflag_t(FFDLY) }

@_alwaysEmitIntoClient
internal var _FF0: tcflag_t { tcflag_t(FF0) }

@_alwaysEmitIntoClient
internal var _FF1: tcflag_t { tcflag_t(FF1) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _OXTABS: tcflag_t { tcflag_t(OXTABS) }

@_alwaysEmitIntoClient
internal var _ONOEOT: tcflag_t { tcflag_t(ONOEOT) }
#endif

#if os(Linux)
@_alwaysEmitIntoClient
internal var _OLCUC: tcflag_t { tcflag_t(OLCUC) }
#endif

// Control flags (c_cflag)
@_alwaysEmitIntoClient
internal var _CREAD: tcflag_t { tcflag_t(CREAD) }

@_alwaysEmitIntoClient
internal var _CSTOPB: tcflag_t { tcflag_t(CSTOPB) }

@_alwaysEmitIntoClient
internal var _HUPCL: tcflag_t { tcflag_t(HUPCL) }

@_alwaysEmitIntoClient
internal var _CLOCAL: tcflag_t { tcflag_t(CLOCAL) }

@_alwaysEmitIntoClient
internal var _PARENB: tcflag_t { tcflag_t(PARENB) }

@_alwaysEmitIntoClient
internal var _PARODD: tcflag_t { tcflag_t(PARODD) }

@_alwaysEmitIntoClient
internal var _CSIZE: tcflag_t { tcflag_t(CSIZE) }

@_alwaysEmitIntoClient
internal var _CS5: tcflag_t { tcflag_t(CS5) }

@_alwaysEmitIntoClient
internal var _CS6: tcflag_t { tcflag_t(CS6) }

@_alwaysEmitIntoClient
internal var _CS7: tcflag_t { tcflag_t(CS7) }

@_alwaysEmitIntoClient
internal var _CS8: tcflag_t { tcflag_t(CS8) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _CCTS_OFLOW: tcflag_t { tcflag_t(CCTS_OFLOW) }

@_alwaysEmitIntoClient
internal var _CRTS_IFLOW: tcflag_t { tcflag_t(CRTS_IFLOW) }

@_alwaysEmitIntoClient
internal var _CDTR_IFLOW: tcflag_t { tcflag_t(CDTR_IFLOW) }

@_alwaysEmitIntoClient
internal var _CDSR_OFLOW: tcflag_t { tcflag_t(CDSR_OFLOW) }

@_alwaysEmitIntoClient
internal var _CCAR_OFLOW: tcflag_t { tcflag_t(CCAR_OFLOW) }

@_alwaysEmitIntoClient
internal var _CRTSCTS: tcflag_t { tcflag_t(CRTSCTS) }
#endif

#if os(Linux)
@_alwaysEmitIntoClient
internal var _CRTSCTS: tcflag_t { tcflag_t(CRTSCTS) }

@_alwaysEmitIntoClient
internal var _CMSPAR: tcflag_t { tcflag_t(CMSPAR) }
#endif

// Local flags (c_lflag)
@_alwaysEmitIntoClient
internal var _ECHO: tcflag_t { tcflag_t(ECHO) }

@_alwaysEmitIntoClient
internal var _ECHOE: tcflag_t { tcflag_t(ECHOE) }

@_alwaysEmitIntoClient
internal var _ECHOK: tcflag_t { tcflag_t(ECHOK) }

@_alwaysEmitIntoClient
internal var _ECHONL: tcflag_t { tcflag_t(ECHONL) }

@_alwaysEmitIntoClient
internal var _ICANON: tcflag_t { tcflag_t(ICANON) }

@_alwaysEmitIntoClient
internal var _IEXTEN: tcflag_t { tcflag_t(IEXTEN) }

@_alwaysEmitIntoClient
internal var _ISIG: tcflag_t { tcflag_t(ISIG) }

@_alwaysEmitIntoClient
internal var _NOFLSH: tcflag_t { tcflag_t(NOFLSH) }

@_alwaysEmitIntoClient
internal var _TOSTOP: tcflag_t { tcflag_t(TOSTOP) }

@_alwaysEmitIntoClient
internal var _ECHOCTL: tcflag_t { tcflag_t(ECHOCTL) }

@_alwaysEmitIntoClient
internal var _ECHOKE: tcflag_t { tcflag_t(ECHOKE) }

@_alwaysEmitIntoClient
internal var _ECHOPRT: tcflag_t { tcflag_t(ECHOPRT) }

@_alwaysEmitIntoClient
internal var _FLUSHO: tcflag_t { tcflag_t(FLUSHO) }

@_alwaysEmitIntoClient
internal var _PENDIN: tcflag_t { tcflag_t(PENDIN) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _ALTWERASE: tcflag_t { tcflag_t(ALTWERASE) }

@_alwaysEmitIntoClient
internal var _EXTPROC: tcflag_t { tcflag_t(EXTPROC) }

@_alwaysEmitIntoClient
internal var _NOKERNINFO: tcflag_t { tcflag_t(NOKERNINFO) }
#endif

#if os(Linux)
@_alwaysEmitIntoClient
internal var _EXTPROC: tcflag_t { tcflag_t(EXTPROC) }
#endif

// Control characters (c_cc indices)
@_alwaysEmitIntoClient
internal var _VEOF: CInt { CInt(VEOF) }

@_alwaysEmitIntoClient
internal var _VEOL: CInt { CInt(VEOL) }

@_alwaysEmitIntoClient
internal var _VERASE: CInt { CInt(VERASE) }

@_alwaysEmitIntoClient
internal var _VINTR: CInt { CInt(VINTR) }

@_alwaysEmitIntoClient
internal var _VKILL: CInt { CInt(VKILL) }

@_alwaysEmitIntoClient
internal var _VMIN: CInt { CInt(VMIN) }

@_alwaysEmitIntoClient
internal var _VQUIT: CInt { CInt(VQUIT) }

@_alwaysEmitIntoClient
internal var _VSTART: CInt { CInt(VSTART) }

@_alwaysEmitIntoClient
internal var _VSTOP: CInt { CInt(VSTOP) }

@_alwaysEmitIntoClient
internal var _VSUSP: CInt { CInt(VSUSP) }

@_alwaysEmitIntoClient
internal var _VTIME: CInt { CInt(VTIME) }

@_alwaysEmitIntoClient
internal var _VEOL2: CInt { CInt(VEOL2) }

@_alwaysEmitIntoClient
internal var _VWERASE: CInt { CInt(VWERASE) }

@_alwaysEmitIntoClient
internal var _VREPRINT: CInt { CInt(VREPRINT) }

@_alwaysEmitIntoClient
internal var _VDISCARD: CInt { CInt(VDISCARD) }

@_alwaysEmitIntoClient
internal var _VLNEXT: CInt { CInt(VLNEXT) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _VSTATUS: CInt { CInt(VSTATUS) }

@_alwaysEmitIntoClient
internal var _VDSUSP: CInt { CInt(VDSUSP) }
#endif

#if os(Linux)
@_alwaysEmitIntoClient
internal var _VSWTC: CInt { CInt(VSWTC) }
#endif

// Baud rates
@_alwaysEmitIntoClient
internal var _B0: speed_t { speed_t(B0) }

@_alwaysEmitIntoClient
internal var _B50: speed_t { speed_t(B50) }

@_alwaysEmitIntoClient
internal var _B75: speed_t { speed_t(B75) }

@_alwaysEmitIntoClient
internal var _B110: speed_t { speed_t(B110) }

@_alwaysEmitIntoClient
internal var _B134: speed_t { speed_t(B134) }

@_alwaysEmitIntoClient
internal var _B150: speed_t { speed_t(B150) }

@_alwaysEmitIntoClient
internal var _B200: speed_t { speed_t(B200) }

@_alwaysEmitIntoClient
internal var _B300: speed_t { speed_t(B300) }

@_alwaysEmitIntoClient
internal var _B600: speed_t { speed_t(B600) }

@_alwaysEmitIntoClient
internal var _B1200: speed_t { speed_t(B1200) }

@_alwaysEmitIntoClient
internal var _B1800: speed_t { speed_t(B1800) }

@_alwaysEmitIntoClient
internal var _B2400: speed_t { speed_t(B2400) }

@_alwaysEmitIntoClient
internal var _B4800: speed_t { speed_t(B4800) }

@_alwaysEmitIntoClient
internal var _B9600: speed_t { speed_t(B9600) }

@_alwaysEmitIntoClient
internal var _B19200: speed_t { speed_t(B19200) }

@_alwaysEmitIntoClient
internal var _B38400: speed_t { speed_t(B38400) }

@_alwaysEmitIntoClient
internal var _B57600: speed_t { speed_t(B57600) }

@_alwaysEmitIntoClient
internal var _B115200: speed_t { speed_t(B115200) }

@_alwaysEmitIntoClient
internal var _B230400: speed_t { speed_t(B230400) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _B7200: speed_t { speed_t(B7200) }

@_alwaysEmitIntoClient
internal var _B14400: speed_t { speed_t(B14400) }

@_alwaysEmitIntoClient
internal var _B28800: speed_t { speed_t(B28800) }

@_alwaysEmitIntoClient
internal var _B76800: speed_t { speed_t(B76800) }
#endif

#if os(Linux)
@_alwaysEmitIntoClient
internal var _B460800: speed_t { speed_t(B460800) }

@_alwaysEmitIntoClient
internal var _B500000: speed_t { speed_t(B500000) }

@_alwaysEmitIntoClient
internal var _B576000: speed_t { speed_t(B576000) }

@_alwaysEmitIntoClient
internal var _B921600: speed_t { speed_t(B921600) }

@_alwaysEmitIntoClient
internal var _B1000000: speed_t { speed_t(B1000000) }

@_alwaysEmitIntoClient
internal var _B1152000: speed_t { speed_t(B1152000) }

@_alwaysEmitIntoClient
internal var _B1500000: speed_t { speed_t(B1500000) }

@_alwaysEmitIntoClient
internal var _B2000000: speed_t { speed_t(B2000000) }

@_alwaysEmitIntoClient
internal var _B2500000: speed_t { speed_t(B2500000) }

@_alwaysEmitIntoClient
internal var _B3000000: speed_t { speed_t(B3000000) }

@_alwaysEmitIntoClient
internal var _B3500000: speed_t { speed_t(B3500000) }

@_alwaysEmitIntoClient
internal var _B4000000: speed_t { speed_t(B4000000) }
#endif

// SetAction constants
@_alwaysEmitIntoClient
internal var _TCSANOW: CInt { CInt(TCSANOW) }

@_alwaysEmitIntoClient
internal var _TCSADRAIN: CInt { CInt(TCSADRAIN) }

@_alwaysEmitIntoClient
internal var _TCSAFLUSH: CInt { CInt(TCSAFLUSH) }

#if canImport(Darwin)
@_alwaysEmitIntoClient
internal var _TCSASOFT: CInt { CInt(TCSASOFT) }
#endif

// Queue constants
@_alwaysEmitIntoClient
internal var _TCIFLUSH: CInt { CInt(TCIFLUSH) }

@_alwaysEmitIntoClient
internal var _TCOFLUSH: CInt { CInt(TCOFLUSH) }

@_alwaysEmitIntoClient
internal var _TCIOFLUSH: CInt { CInt(TCIOFLUSH) }

// Flow action constants
@_alwaysEmitIntoClient
internal var _TCOOFF: CInt { CInt(TCOOFF) }

@_alwaysEmitIntoClient
internal var _TCOON: CInt { CInt(TCOON) }

@_alwaysEmitIntoClient
internal var _TCIOFF: CInt { CInt(TCIOFF) }

@_alwaysEmitIntoClient
internal var _TCION: CInt { CInt(TCION) }
#endif // !os(WASI)

#endif // !os(Windows)
