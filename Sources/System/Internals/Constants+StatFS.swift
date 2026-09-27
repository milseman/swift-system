/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The constants behind StatFS and MountFlags.

#if !os(Windows)

import CSystem
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

// MARK: - statfs/statvfs Mount Flags

// Darwin and BSD (`statfs`) and other platforms (`statvfs`) use different C
// names (`MNT_*` vs `ST_*`) for the flags they share, so flags are exposed
// here under general `_MOUNT_*` names that resolve per platform.

// MARK: Flags Available on All Platforms

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_RDONLY: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_RDONLY)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_RDONLY())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_RDONLY)
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_SYNCHRONOUS: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_SYNCHRONOUS)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_SYNCHRONOUS())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_SYNCHRONOUS)
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_NOEXEC: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_NOEXEC)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NOEXEC())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_NOEXEC)
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_NOSUID: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_NOSUID)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NOSUID())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_NOSUID)
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_NOATIME: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_NOATIME)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NOATIME())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_NOATIME)
  #endif
}

// MARK: Flags Available on All Platforms Except FreeBSD

#if !os(FreeBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_NODEV: CInterop.MountFlags {
  #if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_NODEV)
  #elseif os(Linux) || os(Android)
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NODEV())
  #else
  CInterop.MountFlags(truncatingIfNeeded: ST_NODEV)
  #endif
}
#endif

// MARK: Flags Available on Linux, WASI, and Android

#if os(Linux) || os(WASI) || os(Android)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_MANDLOCK: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_MANDLOCK)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_MANDLOCK())
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_NODIRATIME: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_NODIRATIME)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NODIRATIME())
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_RELATIME: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_RELATIME)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_RELATIME())
  #endif
}
#endif

// MARK: Flags Available on Linux and WASI Only

#if os(Linux) || os(WASI)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_WRITE: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_WRITE)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_WRITE())
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_APPEND: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_APPEND)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_APPEND())
  #endif
}

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _ST_IMMUTABLE: CInterop.MountFlags {
  #if os(WASI)
  CInterop.MountFlags(truncatingIfNeeded: ST_IMMUTABLE)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_IMMUTABLE())
  #endif
}
#endif

// MARK: Flags Available on Linux, Android, and FreeBSD

#if os(Linux) || os(Android) || os(FreeBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MOUNT_NOSYMFOLLOW: CInterop.MountFlags {
  #if os(FreeBSD)
  CInterop.MountFlags(truncatingIfNeeded: MNT_NOSYMFOLLOW)
  #else
  CInterop.MountFlags(truncatingIfNeeded: _system_get_ST_NOSYMFOLLOW())
  #endif
}
#endif

// MARK: Flags Available on Darwin, FreeBSD, and OpenBSD

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_ASYNC: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_ASYNC) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_EXPORTED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_EXPORTED) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_LOCAL: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_LOCAL) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_QUOTA: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_QUOTA) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_ROOTFS: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_ROOTFS) }
#endif

// MARK: Flags Available on Darwin and FreeBSD

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_UNION: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_UNION) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_AUTOMOUNTED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_AUTOMOUNTED) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_MULTILABEL: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_MULTILABEL) }
#endif

// MARK: Flags Available on FreeBSD and OpenBSD

#if os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_EXRDONLY: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_EXRDONLY) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_DEFEXPORTED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_DEFEXPORTED) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_EXPORTANON: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_EXPORTANON) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_SOFTDEP: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_SOFTDEP) }
#endif

// MARK: Flags Available on Darwin Only

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_CPROTECT: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_CPROTECT) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_REMOVABLE: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_REMOVABLE) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_QUARANTINE: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_QUARANTINE) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_DOVOLFS: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_DOVOLFS) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_DONTBROWSE: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_DONTBROWSE) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_IGNORE_OWNERSHIP: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_IGNORE_OWNERSHIP) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_JOURNALED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_JOURNALED) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NOUSERXATTR: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NOUSERXATTR) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_DEFWRITE: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_DEFWRITE) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NOFOLLOW: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NOFOLLOW) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_SNAPSHOT: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_SNAPSHOT) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_STRICTATIME: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_STRICTATIME) }
#endif

// MARK: Flags Available on FreeBSD Only

#if os(FreeBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_EXKERB: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_EXKERB) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_EXPUBLIC: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_EXPUBLIC) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_ACLS: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_ACLS) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_GJOURNAL: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_GJOURNAL) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_IGNORE: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_IGNORE) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NFS4ACLS: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NFS4ACLS) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NOCLUSTERR: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NOCLUSTERR) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NOCLUSTERW: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NOCLUSTERW) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_SUIDDIR: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_SUIDDIR) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_SUJ: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_SUJ) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_UNTRUSTED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_UNTRUSTED) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_USER: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_USER) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_VERIFIED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_VERIFIED) }
#endif

// MARK: Flags Available on OpenBSD Only

#if os(OpenBSD)
@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_NOPERM: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_NOPERM) }

@available(System 199, *)
@_alwaysEmitIntoClient
internal var _MNT_WXALLOWED: CInterop.MountFlags { CInterop.MountFlags(truncatingIfNeeded: MNT_WXALLOWED) }
#endif

#endif // !os(Windows)
