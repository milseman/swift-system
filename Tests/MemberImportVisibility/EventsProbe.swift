/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MemberImportVisibility canary for the event notification types; see
// Probe.swift.
//
// glibc's module doesn't include <sys/epoll.h>, so on glibc only CSystem's
// header declares epoll_event, and a client can't see its C members without
// importing CSystem. The Swift properties of EventPoll.Event cover every
// member, so clients don't need them. CSystem's header also includes
// <sys/timerfd.h>, which includes <time.h>, the pattern behind #320, so
// itimerspec may be attributed to CSystem too. The epoll and timerfd probes
// therefore run on musl and Bionic only, whose modules include those
// headers. Nothing here has run on Linux.

#if canImport(Glibc) || canImport(Musl) || canImport(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import SystemPackage

func _mivProbe(_ p: CInterop.PollFD) {
  _ = p.fd
  _ = p.events
  _ = p.revents
}

// FreeBSD's and OpenBSD's overlays are also named Glibc.
#if os(FreeBSD) || os(OpenBSD)
func _mivProbe(_ k: CInterop.KEvent) {
  _ = k.ident
  _ = k.filter
  _ = k.flags
  _ = k.fflags
  _ = k.data
  _ = k.udata
}
#endif

#if canImport(Musl) || canImport(Android)
func _mivProbe(_ e: CInterop.EPollEvent) {
  _ = e.events
  _ = e.data
  _ = e.data.u64
}

func _mivProbe(_ t: CInterop.ITimerSpec) {
  _ = t.it_interval
  _ = t.it_value
}
#endif
#endif
