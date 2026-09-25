/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The event notification calls: kqueue on Darwin, FreeBSD, and OpenBSD;
// epoll, eventfd, and timerfd on Linux and Android; and poll on every Unix
// platform.

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

#if os(Linux) || os(Android)
// epoll_create1
internal func system_epoll_create1(_ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(flags) }
#endif
  return epoll_create1(flags)
}

// epoll_ctl
internal func system_epoll_ctl(
  _ epfd: CInt, _ op: CInt, _ fd: CInt,
  _ event: UnsafeMutablePointer<epoll_event>?
) -> CInt {
#if ENABLE_MOCKING
  // Records the event's value, or 0 and 0 for no event.
  if mockingEnabled {
    return _mock(
      epfd, op, fd,
      event.map { $0.pointee.events } ?? 0,
      event.map { $0.pointee.data.u64 } ?? 0)
  }
#endif
  return epoll_ctl(epfd, op, fd, event)
}

// epoll_wait. Bionic declares the event list _Nonnull.
internal func system_epoll_wait(
  _ epfd: CInt, _ events: UnsafeMutablePointer<epoll_event>,
  _ maxevents: CInt, _ timeout: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(epfd, maxevents, timeout) }
#endif
  return epoll_wait(epfd, events, maxevents, timeout)
}

// epoll_pwait. Bionic declares the event list _Nonnull.
internal func system_epoll_pwait(
  _ epfd: CInt, _ events: UnsafeMutablePointer<epoll_event>,
  _ maxevents: CInt, _ timeout: CInt,
  _ sigmask: UnsafePointer<sigset_t>?
) -> CInt {
#if ENABLE_MOCKING
  // Records the signal mask as a pointer, which tests don't check.
  if mockingEnabled { return _mock(epfd, maxevents, timeout, sigmask) }
#endif
  return epoll_pwait(epfd, events, maxevents, timeout, sigmask)
}

// eventfd
internal func system_eventfd(_ initval: CUnsignedInt, _ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(initval, flags) }
#endif
  // Older C libraries declare the initial value as an int,
  // so let the parameter's type decide the conversion.
  return eventfd(.init(initval), flags)
}

// timerfd_create
internal func system_timerfd_create(_ clockid: CInt, _ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(clockid, flags) }
#endif
  return timerfd_create(.init(clockid), flags)
}

// timerfd_settime
internal func system_timerfd_settime(
  _ fd: CInt, _ flags: CInt,
  _ new: UnsafePointer<itimerspec>,
  _ old: UnsafeMutablePointer<itimerspec>?
) -> CInt {
#if ENABLE_MOCKING
  // Records the new schedule's value.
  if mockingEnabled {
    return _mock(
      fd, flags,
      Int(new.pointee.it_value.tv_sec), Int(new.pointee.it_value.tv_nsec),
      Int(new.pointee.it_interval.tv_sec), Int(new.pointee.it_interval.tv_nsec))
  }
#endif
  return timerfd_settime(fd, flags, new, old)
}

// timerfd_gettime
internal func system_timerfd_gettime(
  _ fd: CInt, _ current: UnsafeMutablePointer<itimerspec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return timerfd_gettime(fd, current)
}
#endif // os(Linux) || os(Android)

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
