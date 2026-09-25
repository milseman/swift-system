/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The event notification constants: for kqueue, epoll, eventfd, timerfd,
// and poll. Each is typed as the C field or argument that it goes in.

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

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
// MARK: kevent flags

@_alwaysEmitIntoClient
internal var _EV_ADD: UInt16 { UInt16(EV_ADD) }

@_alwaysEmitIntoClient
internal var _EV_DELETE: UInt16 { UInt16(EV_DELETE) }

@_alwaysEmitIntoClient
internal var _EV_ENABLE: UInt16 { UInt16(EV_ENABLE) }

@_alwaysEmitIntoClient
internal var _EV_DISABLE: UInt16 { UInt16(EV_DISABLE) }

@_alwaysEmitIntoClient
internal var _EV_ONESHOT: UInt16 { UInt16(EV_ONESHOT) }

@_alwaysEmitIntoClient
internal var _EV_CLEAR: UInt16 { UInt16(EV_CLEAR) }

@_alwaysEmitIntoClient
internal var _EV_RECEIPT: UInt16 { UInt16(EV_RECEIPT) }

@_alwaysEmitIntoClient
internal var _EV_DISPATCH: UInt16 { UInt16(EV_DISPATCH) }

@_alwaysEmitIntoClient
internal var _EV_EOF: UInt16 { UInt16(EV_EOF) }

@_alwaysEmitIntoClient
internal var _EV_ERROR: UInt16 { UInt16(EV_ERROR) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EV_UDATA_SPECIFIC: UInt16 { UInt16(EV_UDATA_SPECIFIC) }

@_alwaysEmitIntoClient
internal var _EV_OOBAND: UInt16 { UInt16(EV_OOBAND) }
#endif

// MARK: kevent filters

@_alwaysEmitIntoClient
internal var _EVFILT_READ: Int16 { Int16(EVFILT_READ) }

@_alwaysEmitIntoClient
internal var _EVFILT_WRITE: Int16 { Int16(EVFILT_WRITE) }

@_alwaysEmitIntoClient
internal var _EVFILT_VNODE: Int16 { Int16(EVFILT_VNODE) }

@_alwaysEmitIntoClient
internal var _EVFILT_PROC: Int16 { Int16(EVFILT_PROC) }

@_alwaysEmitIntoClient
internal var _EVFILT_SIGNAL: Int16 { Int16(EVFILT_SIGNAL) }

@_alwaysEmitIntoClient
internal var _EVFILT_TIMER: Int16 { Int16(EVFILT_TIMER) }

@_alwaysEmitIntoClient
internal var _EVFILT_USER: Int16 { Int16(EVFILT_USER) }

#if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _EVFILT_EXCEPT: Int16 { Int16(EVFILT_EXCEPT) }
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _EVFILT_FS: Int16 { Int16(EVFILT_FS) }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _EVFILT_MACHPORT: Int16 { Int16(EVFILT_MACHPORT) }
#endif

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _EVFILT_PROCDESC: Int16 { Int16(EVFILT_PROCDESC) }
#endif

// MARK: kevent filter flags
//
// Some of these are unsigned in C and some are signed, so each converts its
// bit pattern.

// EVFILT_READ, EVFILT_WRITE, and EVFILT_EXCEPT
@_alwaysEmitIntoClient
internal var _NOTE_LOWAT: UInt32 { UInt32(truncatingIfNeeded: NOTE_LOWAT) }

#if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _NOTE_OOB: UInt32 { UInt32(truncatingIfNeeded: NOTE_OOB) }
#endif

// EVFILT_VNODE
@_alwaysEmitIntoClient
internal var _NOTE_DELETE: UInt32 { UInt32(truncatingIfNeeded: NOTE_DELETE) }

@_alwaysEmitIntoClient
internal var _NOTE_WRITE: UInt32 { UInt32(truncatingIfNeeded: NOTE_WRITE) }

@_alwaysEmitIntoClient
internal var _NOTE_EXTEND: UInt32 { UInt32(truncatingIfNeeded: NOTE_EXTEND) }

@_alwaysEmitIntoClient
internal var _NOTE_ATTRIB: UInt32 { UInt32(truncatingIfNeeded: NOTE_ATTRIB) }

@_alwaysEmitIntoClient
internal var _NOTE_LINK: UInt32 { UInt32(truncatingIfNeeded: NOTE_LINK) }

@_alwaysEmitIntoClient
internal var _NOTE_RENAME: UInt32 { UInt32(truncatingIfNeeded: NOTE_RENAME) }

@_alwaysEmitIntoClient
internal var _NOTE_REVOKE: UInt32 { UInt32(truncatingIfNeeded: NOTE_REVOKE) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _NOTE_FUNLOCK: UInt32 { UInt32(truncatingIfNeeded: NOTE_FUNLOCK) }
#endif

// EVFILT_PROC
@_alwaysEmitIntoClient
internal var _NOTE_EXIT: UInt32 { UInt32(truncatingIfNeeded: NOTE_EXIT) }

@_alwaysEmitIntoClient
internal var _NOTE_FORK: UInt32 { UInt32(truncatingIfNeeded: NOTE_FORK) }

@_alwaysEmitIntoClient
internal var _NOTE_EXEC: UInt32 { UInt32(truncatingIfNeeded: NOTE_EXEC) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _NOTE_SIGNAL: UInt32 { UInt32(truncatingIfNeeded: NOTE_SIGNAL) }

@_alwaysEmitIntoClient
internal var _NOTE_EXITSTATUS: UInt32 { UInt32(truncatingIfNeeded: NOTE_EXITSTATUS) }
#endif

#if os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _NOTE_TRACK: UInt32 { UInt32(truncatingIfNeeded: NOTE_TRACK) }
#endif

// EVFILT_TIMER
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _NOTE_SECONDS: UInt32 { UInt32(truncatingIfNeeded: NOTE_SECONDS) }

@_alwaysEmitIntoClient
internal var _NOTE_USECONDS: UInt32 { UInt32(truncatingIfNeeded: NOTE_USECONDS) }

@_alwaysEmitIntoClient
internal var _NOTE_NSECONDS: UInt32 { UInt32(truncatingIfNeeded: NOTE_NSECONDS) }
#endif

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _NOTE_ABSOLUTE: UInt32 { UInt32(truncatingIfNeeded: NOTE_ABSOLUTE) }

@_alwaysEmitIntoClient
internal var _NOTE_LEEWAY: UInt32 { UInt32(truncatingIfNeeded: NOTE_LEEWAY) }

@_alwaysEmitIntoClient
internal var _NOTE_CRITICAL: UInt32 { UInt32(truncatingIfNeeded: NOTE_CRITICAL) }

@_alwaysEmitIntoClient
internal var _NOTE_BACKGROUND: UInt32 { UInt32(truncatingIfNeeded: NOTE_BACKGROUND) }

@_alwaysEmitIntoClient
internal var _NOTE_MACHTIME: UInt32 { UInt32(truncatingIfNeeded: NOTE_MACHTIME) }
#endif

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _NOTE_MSECONDS: UInt32 { UInt32(truncatingIfNeeded: NOTE_MSECONDS) }

@_alwaysEmitIntoClient
internal var _NOTE_ABSTIME: UInt32 { UInt32(truncatingIfNeeded: NOTE_ABSTIME) }
#endif

// EVFILT_USER
@_alwaysEmitIntoClient
internal var _NOTE_TRIGGER: UInt32 { UInt32(truncatingIfNeeded: NOTE_TRIGGER) }

@_alwaysEmitIntoClient
internal var _NOTE_FFNOP: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFNOP) }

@_alwaysEmitIntoClient
internal var _NOTE_FFAND: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFAND) }

@_alwaysEmitIntoClient
internal var _NOTE_FFOR: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFOR) }

@_alwaysEmitIntoClient
internal var _NOTE_FFCOPY: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFCOPY) }

@_alwaysEmitIntoClient
internal var _NOTE_FFCTRLMASK: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFCTRLMASK) }

@_alwaysEmitIntoClient
internal var _NOTE_FFLAGSMASK: UInt32 { UInt32(truncatingIfNeeded: NOTE_FFLAGSMASK) }
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if os(Linux) || os(Android)
// MARK: epoll, eventfd, and timerfd
//
// These have the same values on every architecture: they're part of the
// kernel's interface, and the flags that aren't are defined as O_CLOEXEC and
// O_NONBLOCK. The C libraries declare them in different ways: glibc declares
// the epoll events as an enumeration (so `EPOLLIN.rawValue`), musl and
// Bionic as macros, and Bionic's EPOLLET doesn't import. So they're spelled
// out here, once, for every C library.

@_alwaysEmitIntoClient
internal var _EPOLL_CLOEXEC: CInt { _O_CLOEXEC }

@_alwaysEmitIntoClient
internal var _EPOLL_CTL_ADD: CInt { 1 }

@_alwaysEmitIntoClient
internal var _EPOLL_CTL_DEL: CInt { 2 }

@_alwaysEmitIntoClient
internal var _EPOLL_CTL_MOD: CInt { 3 }

@_alwaysEmitIntoClient
internal var _EPOLLIN: UInt32 { 0x0000_0001 }

@_alwaysEmitIntoClient
internal var _EPOLLPRI: UInt32 { 0x0000_0002 }

@_alwaysEmitIntoClient
internal var _EPOLLOUT: UInt32 { 0x0000_0004 }

@_alwaysEmitIntoClient
internal var _EPOLLERR: UInt32 { 0x0000_0008 }

@_alwaysEmitIntoClient
internal var _EPOLLHUP: UInt32 { 0x0000_0010 }

@_alwaysEmitIntoClient
internal var _EPOLLRDHUP: UInt32 { 0x0000_2000 }

@_alwaysEmitIntoClient
internal var _EPOLLEXCLUSIVE: UInt32 { 1 << 28 }

@_alwaysEmitIntoClient
internal var _EPOLLWAKEUP: UInt32 { 1 << 29 }

@_alwaysEmitIntoClient
internal var _EPOLLONESHOT: UInt32 { 1 << 30 }

@_alwaysEmitIntoClient
internal var _EPOLLET: UInt32 { 1 << 31 }

@_alwaysEmitIntoClient
internal var _EFD_SEMAPHORE: CInt { 1 }

@_alwaysEmitIntoClient
internal var _EFD_CLOEXEC: CInt { _O_CLOEXEC }

@_alwaysEmitIntoClient
internal var _EFD_NONBLOCK: CInt { _O_NONBLOCK }

@_alwaysEmitIntoClient
internal var _TFD_CLOEXEC: CInt { _O_CLOEXEC }

@_alwaysEmitIntoClient
internal var _TFD_NONBLOCK: CInt { _O_NONBLOCK }

@_alwaysEmitIntoClient
internal var _TFD_TIMER_ABSTIME: CInt { 1 << 0 }

@_alwaysEmitIntoClient
internal var _TFD_TIMER_CANCEL_ON_SET: CInt { 1 << 1 }

// The clocks that timerfd accepts.
@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME: CInt { 0 }

@_alwaysEmitIntoClient
internal var _CLOCK_MONOTONIC: CInt { 1 }

@_alwaysEmitIntoClient
internal var _CLOCK_BOOTTIME: CInt { 7 }

@_alwaysEmitIntoClient
internal var _CLOCK_REALTIME_ALARM: CInt { 8 }

@_alwaysEmitIntoClient
internal var _CLOCK_BOOTTIME_ALARM: CInt { 9 }
#endif // os(Linux) || os(Android)

#if !os(Windows) && !os(WASI)
// MARK: poll

@_alwaysEmitIntoClient
internal var _POLLIN: CShort { CShort(POLLIN) }

@_alwaysEmitIntoClient
internal var _POLLPRI: CShort { CShort(POLLPRI) }

@_alwaysEmitIntoClient
internal var _POLLOUT: CShort { CShort(POLLOUT) }

@_alwaysEmitIntoClient
internal var _POLLRDNORM: CShort { CShort(POLLRDNORM) }

@_alwaysEmitIntoClient
internal var _POLLRDBAND: CShort { CShort(POLLRDBAND) }

@_alwaysEmitIntoClient
internal var _POLLWRNORM: CShort { CShort(POLLWRNORM) }

@_alwaysEmitIntoClient
internal var _POLLWRBAND: CShort { CShort(POLLWRBAND) }

@_alwaysEmitIntoClient
internal var _POLLERR: CShort { CShort(POLLERR) }

@_alwaysEmitIntoClient
internal var _POLLHUP: CShort { CShort(POLLHUP) }

@_alwaysEmitIntoClient
internal var _POLLNVAL: CShort { CShort(POLLNVAL) }

#if os(Linux) || os(Android)
// glibc declares POLLRDHUP only with _GNU_SOURCE. It has this value on
// every architecture that Swift supports.
@_alwaysEmitIntoClient
internal var _POLLRDHUP: CShort { 0x2000 }
#endif
#endif // !os(Windows) && !os(WASI)
