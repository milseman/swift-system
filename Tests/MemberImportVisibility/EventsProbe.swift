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
// member, so clients don't need them, and the epoll probe runs on musl and
// Bionic only, whose modules include that header. CSystem's header takes
// timerfd's itimerspec untyped, so glibc's <time.h> alone declares it, and
// its probe runs everywhere, as does sigset_t's, which EventPoll's
// wait(into:timeout:signalMask:retryOnInterrupt:) takes.

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
#endif

#if os(Linux) || os(Android)
func _mivProbe(_ t: CInterop.ITimerSpec) {
  _ = t.it_interval
  _ = t.it_value
  _ = t.it_value.tv_sec
  _ = t.it_value.tv_nsec
}

func _mivProbeSignalMask() -> sigset_t {
  var mask = sigset_t()
  sigemptyset(&mask)
  return mask
}
#endif
#endif
