/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Probes sigset_t's initializer, reached only through SystemPackage's names:
// CInterop.SignalSet, and EventPoll's wait(into:timeout:signalMask:). See
// Probe.swift.
//
// CSystem's headers declare sigset_t too, through <sys/types.h> and
// <sys/epoll.h>, and Swift attributes the type to the module whose copy it
// loads first. When SystemPackage's module refers to CSystem's copy, a
// client that builds a mask this way can't see the initializer without
// importing CSystem. Nothing else in this file names sigset_t, so that
// SystemPackage's names load it here, as TimespecProbe.swift does timespec.

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
func _mivProbeSignalSet() -> CInterop.SignalSet {
  CInterop.SignalSet()
}

#if os(Linux) || os(Android)
func _mivProbeWaitSignalMask(
  _ poll: borrowing EventPoll, _ events: inout OutputSpan<EventPoll.Event>
) throws {
  try poll.wait(into: &events, signalMask: .init())
}
#endif
#endif
