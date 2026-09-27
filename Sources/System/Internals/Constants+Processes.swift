/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The signal, wait, spawn, and resource limit constants behind
// Sources/System/Processes.
//
// Their C types differ between platforms: glibc and Bionic declare some in
// anonymous enums, which Swift imports as `Int`, and some flags are unsigned
// hexadecimal literals, which Swift imports as `UInt32`. So each constant
// converts to the type its C function takes. Where glibc declares a constant
// only with _GNU_SOURCE, or declares it in a named enum whose values differ
// from its type, the Linux value is spelled out: these are the kernel's
// values, the same on every architecture Swift supports.

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

// MARK: - Signals

@_alwaysEmitIntoClient
internal var _SIGHUP: CInt { SIGHUP }

@_alwaysEmitIntoClient
internal var _SIGINT: CInt { SIGINT }

@_alwaysEmitIntoClient
internal var _SIGQUIT: CInt { SIGQUIT }

@_alwaysEmitIntoClient
internal var _SIGILL: CInt { SIGILL }

@_alwaysEmitIntoClient
internal var _SIGTRAP: CInt { SIGTRAP }

@_alwaysEmitIntoClient
internal var _SIGABRT: CInt { SIGABRT }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _SIGEMT: CInt { SIGEMT }
#endif

@_alwaysEmitIntoClient
internal var _SIGFPE: CInt { SIGFPE }

@_alwaysEmitIntoClient
internal var _SIGKILL: CInt { SIGKILL }

@_alwaysEmitIntoClient
internal var _SIGBUS: CInt { SIGBUS }

@_alwaysEmitIntoClient
internal var _SIGSEGV: CInt { SIGSEGV }

@_alwaysEmitIntoClient
internal var _SIGSYS: CInt { SIGSYS }

@_alwaysEmitIntoClient
internal var _SIGPIPE: CInt { SIGPIPE }

@_alwaysEmitIntoClient
internal var _SIGALRM: CInt { SIGALRM }

@_alwaysEmitIntoClient
internal var _SIGTERM: CInt { SIGTERM }

@_alwaysEmitIntoClient
internal var _SIGURG: CInt { SIGURG }

@_alwaysEmitIntoClient
internal var _SIGSTOP: CInt { SIGSTOP }

@_alwaysEmitIntoClient
internal var _SIGTSTP: CInt { SIGTSTP }

@_alwaysEmitIntoClient
internal var _SIGCONT: CInt { SIGCONT }

@_alwaysEmitIntoClient
internal var _SIGCHLD: CInt { SIGCHLD }

@_alwaysEmitIntoClient
internal var _SIGTTIN: CInt { SIGTTIN }

@_alwaysEmitIntoClient
internal var _SIGTTOU: CInt { SIGTTOU }

@_alwaysEmitIntoClient
internal var _SIGIO: CInt { SIGIO }

@_alwaysEmitIntoClient
internal var _SIGXCPU: CInt { SIGXCPU }

@_alwaysEmitIntoClient
internal var _SIGXFSZ: CInt { SIGXFSZ }

@_alwaysEmitIntoClient
internal var _SIGVTALRM: CInt { SIGVTALRM }

@_alwaysEmitIntoClient
internal var _SIGPROF: CInt { SIGPROF }

@_alwaysEmitIntoClient
internal var _SIGWINCH: CInt { SIGWINCH }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@_alwaysEmitIntoClient
internal var _SIGINFO: CInt { SIGINFO }
#endif

@_alwaysEmitIntoClient
internal var _SIGUSR1: CInt { SIGUSR1 }

@_alwaysEmitIntoClient
internal var _SIGUSR2: CInt { SIGUSR2 }

#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _SIGPWR: CInt { SIGPWR }
#endif

// One more than the highest signal number: the numbers that a signal set
// can hold are 1 through _NSIG - 1. It's NSIG on Darwin (32) and OpenBSD
// (33), 65 on Linux, whose sigset_t has room for 1024 but whose kernel has
// 64 signals, and _SIG_MAXSIG + 1 (129) on FreeBSD.
#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _NSIG: CInt { 65 }
#elseif os(FreeBSD)
@_alwaysEmitIntoClient
internal var _NSIG: CInt { CInt(_SIG_MAXSIG) + 1 }
#else
@_alwaysEmitIntoClient
internal var _NSIG: CInt { CInt(NSIG) }
#endif

// MARK: - Signal masks

@_alwaysEmitIntoClient
internal var _SIG_BLOCK: CInt { CInt(SIG_BLOCK) }

@_alwaysEmitIntoClient
internal var _SIG_UNBLOCK: CInt { CInt(SIG_UNBLOCK) }

@_alwaysEmitIntoClient
internal var _SIG_SETMASK: CInt { CInt(SIG_SETMASK) }

// MARK: - Signal action flags

@_alwaysEmitIntoClient
internal var _SA_ONSTACK: CInt { CInt(truncatingIfNeeded: SA_ONSTACK) }

@_alwaysEmitIntoClient
internal var _SA_RESTART: CInt { CInt(truncatingIfNeeded: SA_RESTART) }

@_alwaysEmitIntoClient
internal var _SA_RESETHAND: CInt { CInt(truncatingIfNeeded: SA_RESETHAND) }

@_alwaysEmitIntoClient
internal var _SA_NOCLDSTOP: CInt { CInt(truncatingIfNeeded: SA_NOCLDSTOP) }

@_alwaysEmitIntoClient
internal var _SA_NODEFER: CInt { CInt(truncatingIfNeeded: SA_NODEFER) }

@_alwaysEmitIntoClient
internal var _SA_NOCLDWAIT: CInt { CInt(truncatingIfNeeded: SA_NOCLDWAIT) }

@_alwaysEmitIntoClient
internal var _SA_SIGINFO: CInt { CInt(truncatingIfNeeded: SA_SIGINFO) }

// MARK: - Wait options

@_alwaysEmitIntoClient
internal var _WNOHANG: CInt { CInt(WNOHANG) }

@_alwaysEmitIntoClient
internal var _WUNTRACED: CInt { CInt(WUNTRACED) }

@_alwaysEmitIntoClient
internal var _WEXITED: CInt { CInt(WEXITED) }

// Darwin's <sys/wait.h> redefines WSTOPPED as waitpid's status value (0177)
// outside UNIX03 mode. This is waitid's option.
#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _WSTOPPED: CInt { 0x00000008 }
#else
@_alwaysEmitIntoClient
internal var _WSTOPPED: CInt { CInt(WSTOPPED) }
#endif

@_alwaysEmitIntoClient
internal var _WCONTINUED: CInt { CInt(WCONTINUED) }

@_alwaysEmitIntoClient
internal var _WNOWAIT: CInt { CInt(truncatingIfNeeded: WNOWAIT) }

// MARK: - Child status codes (si_code for SIGCHLD and waitid)

@_alwaysEmitIntoClient
internal var _CLD_EXITED: CInt { CInt(CLD_EXITED) }

@_alwaysEmitIntoClient
internal var _CLD_KILLED: CInt { CInt(CLD_KILLED) }

@_alwaysEmitIntoClient
internal var _CLD_DUMPED: CInt { CInt(CLD_DUMPED) }

@_alwaysEmitIntoClient
internal var _CLD_TRAPPED: CInt { CInt(CLD_TRAPPED) }

@_alwaysEmitIntoClient
internal var _CLD_STOPPED: CInt { CInt(CLD_STOPPED) }

@_alwaysEmitIntoClient
internal var _CLD_CONTINUED: CInt { CInt(CLD_CONTINUED) }

// MARK: - waitid identifier types
//
// idtype_t is an enum everywhere but Bionic, where it's an int, and its
// values differ: P_PID is 1 on Darwin and Linux, 0 on FreeBSD, and 2 on
// OpenBSD. So these use the names.

@_alwaysEmitIntoClient
internal var _P_ALL: idtype_t { P_ALL }

@_alwaysEmitIntoClient
internal var _P_PID: idtype_t { P_PID }

@_alwaysEmitIntoClient
internal var _P_PGID: idtype_t { P_PGID }

#if os(Linux)
// glibc declares P_PIDFD only from 2.36 on.
@_alwaysEmitIntoClient
internal var _P_PIDFD: idtype_t { idtype_t(rawValue: 3) }
#elseif os(Android)
@_alwaysEmitIntoClient
internal var _P_PIDFD: idtype_t { 3 }
#endif

// MARK: - posix_spawn flags
//
// posix_spawn is wrapped where Syscalls+Processes.swift wraps it.

#if !os(watchOS) && !os(tvOS) && !os(Android)
@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_RESETIDS: CShort { CShort(POSIX_SPAWN_RESETIDS) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETPGROUP: CShort { CShort(POSIX_SPAWN_SETPGROUP) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETSIGDEF: CShort { CShort(POSIX_SPAWN_SETSIGDEF) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETSIGMASK: CShort { CShort(POSIX_SPAWN_SETSIGMASK) }

#if SYSTEM_PACKAGE_DARWIN
@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETSID: CShort { CShort(POSIX_SPAWN_SETSID) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETEXEC: CShort { CShort(POSIX_SPAWN_SETEXEC) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_START_SUSPENDED: CShort { CShort(POSIX_SPAWN_START_SUSPENDED) }

@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_CLOEXEC_DEFAULT: CShort { CShort(POSIX_SPAWN_CLOEXEC_DEFAULT) }
#elseif os(Linux)
// glibc declares it only with _GNU_SOURCE.
@_alwaysEmitIntoClient
internal var _POSIX_SPAWN_SETSID: CShort { 0x80 }
#endif
#endif // !os(watchOS) && !os(tvOS) && !os(Android)

// MARK: - Resource limits

#if os(Linux) || os(Android)
// glibc declares these in a named enum, whose type isn't getrlimit's, so
// they're spelled out, as the kernel's asm-generic values.
@_alwaysEmitIntoClient
internal var _RLIMIT_CPU: CInt { 0 }

@_alwaysEmitIntoClient
internal var _RLIMIT_FSIZE: CInt { 1 }

@_alwaysEmitIntoClient
internal var _RLIMIT_DATA: CInt { 2 }

@_alwaysEmitIntoClient
internal var _RLIMIT_STACK: CInt { 3 }

@_alwaysEmitIntoClient
internal var _RLIMIT_CORE: CInt { 4 }

@_alwaysEmitIntoClient
internal var _RLIMIT_RSS: CInt { 5 }

@_alwaysEmitIntoClient
internal var _RLIMIT_NPROC: CInt { 6 }

@_alwaysEmitIntoClient
internal var _RLIMIT_NOFILE: CInt { 7 }

@_alwaysEmitIntoClient
internal var _RLIMIT_MEMLOCK: CInt { 8 }

@_alwaysEmitIntoClient
internal var _RLIMIT_AS: CInt { 9 }

@_alwaysEmitIntoClient
internal var _RLIMIT_LOCKS: CInt { 10 }

@_alwaysEmitIntoClient
internal var _RLIMIT_SIGPENDING: CInt { 11 }

@_alwaysEmitIntoClient
internal var _RLIMIT_MSGQUEUE: CInt { 12 }

@_alwaysEmitIntoClient
internal var _RLIMIT_NICE: CInt { 13 }

@_alwaysEmitIntoClient
internal var _RLIMIT_RTPRIO: CInt { 14 }

@_alwaysEmitIntoClient
internal var _RLIMIT_RTTIME: CInt { 15 }
#else
@_alwaysEmitIntoClient
internal var _RLIMIT_CPU: CInt { CInt(RLIMIT_CPU) }

@_alwaysEmitIntoClient
internal var _RLIMIT_FSIZE: CInt { CInt(RLIMIT_FSIZE) }

@_alwaysEmitIntoClient
internal var _RLIMIT_DATA: CInt { CInt(RLIMIT_DATA) }

@_alwaysEmitIntoClient
internal var _RLIMIT_STACK: CInt { CInt(RLIMIT_STACK) }

@_alwaysEmitIntoClient
internal var _RLIMIT_CORE: CInt { CInt(RLIMIT_CORE) }

@_alwaysEmitIntoClient
internal var _RLIMIT_RSS: CInt { CInt(RLIMIT_RSS) }

@_alwaysEmitIntoClient
internal var _RLIMIT_NPROC: CInt { CInt(RLIMIT_NPROC) }

@_alwaysEmitIntoClient
internal var _RLIMIT_NOFILE: CInt { CInt(RLIMIT_NOFILE) }

@_alwaysEmitIntoClient
internal var _RLIMIT_MEMLOCK: CInt { CInt(RLIMIT_MEMLOCK) }

@_alwaysEmitIntoClient
internal var _RLIMIT_AS: CInt { CInt(RLIMIT_AS) }
#endif

#if os(FreeBSD)
@_alwaysEmitIntoClient
internal var _RLIMIT_SBSIZE: CInt { CInt(RLIMIT_SBSIZE) }

@_alwaysEmitIntoClient
internal var _RLIMIT_NPTS: CInt { CInt(RLIMIT_NPTS) }

@_alwaysEmitIntoClient
internal var _RLIMIT_SWAP: CInt { CInt(RLIMIT_SWAP) }

@_alwaysEmitIntoClient
internal var _RLIMIT_KQUEUES: CInt { CInt(RLIMIT_KQUEUES) }
#endif

// No limit. It's the largest value on Linux, where rlim_t is unsigned and
// RLIM_INFINITY is (rlim_t)-1, and 2^63 - 1 on Darwin and the BSDs. Neither
// macro imports into Swift.
#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _RLIM_INFINITY: rlim_t { rlim_t.max }
#else
@_alwaysEmitIntoClient
internal var _RLIM_INFINITY: rlim_t { rlim_t(Int64.max) }
#endif

// MARK: - Process descriptors, signal descriptors, and closing ranges

#if os(Linux) || os(Android)
// PIDFD_NONBLOCK, SFD_NONBLOCK, and SFD_CLOEXEC are O_NONBLOCK and
// O_CLOEXEC.
@_alwaysEmitIntoClient
internal var _PIDFD_NONBLOCK: CUnsignedInt { CUnsignedInt(O_NONBLOCK) }

@_alwaysEmitIntoClient
internal var _SFD_NONBLOCK: CInt { O_NONBLOCK }

@_alwaysEmitIntoClient
internal var _SFD_CLOEXEC: CInt { O_CLOEXEC }
#endif

#if os(Linux) || os(Android) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _CLOSE_RANGE_CLOEXEC: CUnsignedInt { 1 << 2 }
#endif

#if os(macOS)
@_alwaysEmitIntoClient
internal var _PROC_PIDLISTFDS: CInt { PROC_PIDLISTFDS }
#endif

#endif // !os(Windows) && !os(WASI)
