/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Probes for the C types that PThread's API makes clients build or read.
// See Probe.swift.
//
// PThread.Condition.wait(on:until:) and PThread.Mutex.lock(until:) take a
// timespec deadline, whose members could be attributed to CSystem, since
// CSystem's headers declare timespec too (see TimespecProbe.swift).
// CSystemLinux.h no longer includes <pthread.h> or <sched.h>, which also
// declared sched_param there. The other C types that PThread vends are
// integers, pointers, or structures that clients only pass by address.

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
func _mivProbeThreads(_ deadline: timespec, _ id: PThread.ID) -> timespec {
  _ = deadline.tv_sec
  _ = deadline.tv_nsec
  let raw: CInterop.PThread = id.rawValue
  _ = raw
  return timespec(tv_sec: deadline.tv_sec + 1, tv_nsec: deadline.tv_nsec)
}
#endif
