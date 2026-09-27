/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Probes timespec's members, read through a SystemPackage API that vends a
// timespec: Stat's time properties. See Probe.swift.
//
// On glibc, CSystem's headers declare timespec too, through <sys/types.h>
// and <sys/epoll.h>, and Swift attributes the type to the module whose copy
// it loads first. If SystemPackage's module refers to CSystem's copy, a
// client that reads st_mtim.tv_sec loads that copy, and can't see its
// members without importing CSystem. That happened while CSystemLinux.h
// declared timerfd_settime, whose itimerspec holds a timespec. Nothing else
// in this file names timespec, so that Stat's properties load it here.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

// This target has no availability macros, and Linux has no availability.
func _mivProbeTimespec(_ s: Stat) {
  _ = s.st_atim.tv_sec
  _ = s.st_mtim.tv_nsec
  _ = s.st_ctim.tv_sec
}
#endif
