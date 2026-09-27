/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if defined(__FreeBSD__)
#define __BSD_VISIBLE
#endif
#if defined(__FreeBSD__) || defined(__OpenBSD__)
#include <unistd.h>
#endif

#if defined(__FreeBSD__)
#include <CSystemFreeBSD.h>
#endif

#ifdef __linux__
#define _GNU_SOURCE
#include <CSystemLinux.h>
#include <sys/ioctl.h>

// Terminal ioctl shims for Linux
int _system_ioctl_TIOCGWINSZ(int fd, void *ws) {
  return ioctl(fd, TIOCGWINSZ, ws);
}

int _system_ioctl_TIOCSWINSZ(int fd, const void *ws) {
  return ioctl(fd, TIOCSWINSZ, ws);
}

#endif

#if defined(__APPLE__)

#include <CSystemDarwin.h>

// Terminal ioctl shims for Darwin
int _system_ioctl_TIOCGWINSZ(int fd, struct winsize *ws) {
  return ioctl(fd, TIOCGWINSZ, ws);
}

int _system_ioctl_TIOCSWINSZ(int fd, const struct winsize *ws) {
  return ioctl(fd, TIOCSWINSZ, ws);
}

#endif

#if defined(_WIN32)
#include <CSystemWindows.h>
#endif

#include <errno.h>

#if !defined(_WIN32) && !defined(__wasi__) && !defined(__APPLE__)
#define HAVE_PIPE2_DUP3
#endif

#if defined(__APPLE__)
#include <Availability.h>
#if defined(__MAC_27_0)
#include <unistd.h>
#define HAVE_PIPE2_DUP3
#endif
#endif // defined(__APPLE__)

// Wrappers are required because _GNU_SOURCE causes a conflict with other imports when defined in CSystemLinux.h

#if !defined(_WIN32)
extern int csystem_posix_pipe2(int fildes[2], int flag) {
  #if defined(__APPLE__) && defined(HAVE_PIPE2_DUP3)
  if (__builtin_available(macOS 27, iOS 27, tvOS 27, watchOS 27, visionOS 27, *))
    return pipe2(fildes, flag);
  __builtin_trap();
  #elif defined(HAVE_PIPE2_DUP3)
  return pipe2(fildes, flag);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}
#endif // !defined(_WIN32)

extern int csystem_posix_dup3(int fildes, int fildes2, int flag) {
  #if defined(__APPLE__) && defined(HAVE_PIPE2_DUP3)
  if (__builtin_available(macOS 27, iOS 27, tvOS 27, watchOS 27, visionOS 27, *))
    return dup3(fildes, fildes2, flag);
  __builtin_trap();
  #elif defined(HAVE_PIPE2_DUP3)
  return dup3(fildes, fildes2, flag);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}

#ifdef __linux__
#include <sys/syscall.h>

extern int csystem_renameat2(int olddirfd, const char *oldpath,
                             int newdirfd, const char *newpath,
                             unsigned int flags) {
  // Call the kernel directly, since not every libc declares renameat2:
  // glibc only added it in 2.28, and older Android releases lack it.
  #ifdef SYS_renameat2
  return (int)syscall(SYS_renameat2, olddirfd, oldpath, newdirfd, newpath, flags);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}
#endif // __linux__

#ifdef __linux__
#include <stdlib.h>

// With _GNU_SOURCE, which this file defines on Linux, <stdlib.h> declares these.

extern int csystem_posix_openpt(int flags) {
  return posix_openpt(flags);
}

extern int csystem_grantpt(int fd) {
  return grantpt(fd);
}

extern int csystem_unlockpt(int fd) {
  return unlockpt(fd);
}

extern int csystem_ptsname_r(int fd, char *buffer, size_t length) {
  return ptsname_r(fd, buffer, length);
}
#endif // __linux__

#ifdef __linux__
#include <sys/stat.h>

_Static_assert(CSYSTEM_UTIME_NOW == UTIME_NOW, "CSYSTEM_UTIME_NOW");
_Static_assert(CSYSTEM_UTIME_OMIT == UTIME_OMIT, "CSYSTEM_UTIME_OMIT");
#endif // __linux__

#ifdef __linux__
#include <sys/timerfd.h>

extern int csystem_timerfd_create(int clockid, int flags) {
  return timerfd_create(clockid, flags);
}

extern int csystem_timerfd_settime(int fd, int flags,
                                   const void *new_value, void *old_value) {
  return timerfd_settime(fd, flags, (const struct itimerspec *)new_value,
                         (struct itimerspec *)old_value);
}

extern int csystem_timerfd_gettime(int fd, void *curr_value) {
  return timerfd_gettime(fd, (struct itimerspec *)curr_value);
}
#endif // __linux__

#ifdef __linux__
#include <termios.h>

extern int csystem_tcgetsid(int fd) {
  return tcgetsid(fd);
}
#endif // __linux__

#ifdef __linux__
#include <pthread.h>
#include <sched.h>

// With _GNU_SOURCE, which this file defines on Linux, <pthread.h> and
// <sched.h> declare these.

extern int csystem_pthread_setname_np(pthread_t thread, const char *name) {
  return pthread_setname_np(thread, name);
}

extern int csystem_pthread_getname_np(pthread_t thread, char *name, size_t length) {
  #if defined(__ANDROID__) && __ANDROID_API__ < 26
  return ENOSYS;
  #else
  return pthread_getname_np(thread, name, length);
  #endif
}

extern int csystem_sched_setaffinity(pid_t pid, size_t size, const void *mask) {
  return sched_setaffinity(pid, size, (const cpu_set_t *)mask);
}

extern int csystem_sched_getaffinity(pid_t pid, size_t size, void *mask) {
  return sched_getaffinity(pid, size, (cpu_set_t *)mask);
}

#ifndef __ANDROID__
extern int csystem_pthread_setaffinity_np(pthread_t thread, size_t size, const void *mask) {
  return pthread_setaffinity_np(thread, size, (const cpu_set_t *)mask);
}

extern int csystem_pthread_getaffinity_np(pthread_t thread, size_t size, void *mask) {
  return pthread_getaffinity_np(thread, size, (cpu_set_t *)mask);
}
#endif // !__ANDROID__
#endif // __linux__
