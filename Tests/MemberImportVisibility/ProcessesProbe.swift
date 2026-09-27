/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MemberImportVisibility canary for the process and signal types; see
// Probe.swift.
//
// CSystemLinux.h includes io_uring.h, which includes <signal.h>, the pattern
// behind #320, so struct sigaction's and siginfo_t's members may be
// attributed to CSystem on glibc. That would break a handler that reads its
// siginfo_t directly; Signal.Information's properties read every member
// that its API exposes, so a client doesn't need them. rlimit comes from
// <sys/resource.h>, which no CSystem header includes. siginfo_t's other
// members, such as si_pid, are macros for union members on Linux, which
// Swift can't import, so only the direct ones are here. sigset_t has no
// members that clients use. Nothing here has run on Linux.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ a: CInterop.SignalAction) {
  _ = a.sa_mask
  _ = a.sa_flags
}

func _mivProbe(_ i: CInterop.SignalInfo) {
  _ = i.si_signo
  _ = i.si_errno
  _ = i.si_code
}

func _mivProbe(_ l: CInterop.ResourceLimit) -> CInterop.ResourceLimit {
  _ = l.rlim_cur
  _ = l.rlim_max
  return CInterop.ResourceLimit(rlim_cur: l.rlim_cur, rlim_max: l.rlim_max)
}
#endif
