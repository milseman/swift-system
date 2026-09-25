/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The event notification calls: kqueue on Darwin, FreeBSD, and OpenBSD,
// and poll on every Unix platform.

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
// kqueue
internal func system_kqueue() -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return kqueue()
}

// kevent
internal func system_kevent(
  _ kq: CInt,
  _ changelist: UnsafePointer<kevent>?, _ nchanges: CInt,
  _ eventlist: UnsafeMutablePointer<kevent>?, _ nevents: CInt,
  _ timeout: UnsafePointer<timespec>?
) -> CInt {
#if ENABLE_MOCKING
  // Records the timeout's value, or -1 and -1 for no timeout.
  if mockingEnabled {
    return _mock(
      kq, nchanges, nevents,
      timeout.map { Int($0.pointee.tv_sec) } ?? -1,
      timeout.map { Int($0.pointee.tv_nsec) } ?? -1)
  }
#endif
  return kevent(kq, changelist, nchanges, eventlist, nevents, timeout)
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if !os(Windows) && !os(WASI)
// poll
internal func system_poll(
  _ fds: UnsafeMutablePointer<pollfd>?, _ nfds: Int, _ timeout: CInt
) -> CInt {
#if ENABLE_MOCKING
  // Records each entry's descriptor and requested events.
  if mockingEnabled {
    let entries = UnsafeBufferPointer(start: fds, count: nfds)
    return _mock(entries.map(\.fd), entries.map(\.events), timeout)
  }
#endif
  return poll(fds, nfds_t(nfds), timeout)
}
#endif // !os(Windows) && !os(WASI)
