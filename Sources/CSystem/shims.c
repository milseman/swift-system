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

// The `ST_*` mount-flag constants in <sys/statvfs.h> require _GNU_SOURCE.
// Define it here, in a dedicated translation unit, not in CSystemLinux.h,
// since defining it there changes libc types like `fd_set` for every file
// that imports CSystem and conflicts with SwiftGlibc.
#define _GNU_SOURCE
#include <sys/statvfs.h>
#include <stdint.h>

uint64_t _system_get_ST_RDONLY(void) { return ST_RDONLY; }
uint64_t _system_get_ST_NOSUID(void) { return ST_NOSUID; }
uint64_t _system_get_ST_NODEV(void) { return ST_NODEV; }
uint64_t _system_get_ST_NOEXEC(void) { return ST_NOEXEC; }
uint64_t _system_get_ST_SYNCHRONOUS(void) { return ST_SYNCHRONOUS; }
uint64_t _system_get_ST_MANDLOCK(void) { return ST_MANDLOCK; }
uint64_t _system_get_ST_NOATIME(void) { return ST_NOATIME; }
uint64_t _system_get_ST_NODIRATIME(void) { return ST_NODIRATIME; }
uint64_t _system_get_ST_RELATIME(void) { return ST_RELATIME; }

// ST_NOSYMFOLLOW was added to glibc's <sys/statvfs.h> in Linux 5.10. For
// older versions, fall back to the fixed kernel UAPI bit (<linux/statfs.h>),
// which is the same value a newer glibc header defines.
#ifndef ST_NOSYMFOLLOW
#define ST_NOSYMFOLLOW 0x2000
#endif
uint64_t _system_get_ST_NOSYMFOLLOW(void) { return ST_NOSYMFOLLOW; }

#if !defined(__ANDROID__)
uint64_t _system_get_ST_WRITE(void) { return ST_WRITE; }
uint64_t _system_get_ST_APPEND(void) { return ST_APPEND; }
uint64_t _system_get_ST_IMMUTABLE(void) { return ST_IMMUTABLE; }
#endif

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
#include <sys/vfs.h>

// f_type is a long on glibc, an unsigned long on Musl, and a uint64_t or
// uint32_t on Bionic. The magic numbers it holds all fit in 32 bits.

extern int csystem_statfs_type(const char *path, unsigned long *type) {
  struct statfs buffer;
  int result = statfs(path, &buffer);
  if (result == 0) {
    *type = (unsigned long)buffer.f_type;
  }
  return result;
}

extern int csystem_fstatfs_type(int fd, unsigned long *type) {
  struct statfs buffer;
  int result = fstatfs(fd, &buffer);
  if (result == 0) {
    *type = (unsigned long)buffer.f_type;
  }
  return result;
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

#ifdef __ANDROID__
#include <sys/uio.h>

extern ssize_t csystem_preadv(int fd, const void *iov, int iovcnt, off_t offset) {
  #if __ANDROID_API__ >= 24
  return preadv(fd, (const struct iovec *)iov, iovcnt, offset);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}

extern ssize_t csystem_pwritev(int fd, const void *iov, int iovcnt, off_t offset) {
  #if __ANDROID_API__ >= 24
  return pwritev(fd, (const struct iovec *)iov, iovcnt, offset);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}
#endif // __ANDROID__

#if !defined(_WIN32) && !defined(__wasi__)
#if defined(__APPLE__)
#include <crt_externs.h>
#endif

extern char **csystem_environ(void) {
  #if defined(__APPLE__)
  return *_NSGetEnviron();
  #else
  extern char **environ;
  return environ;
  #endif
}
#endif // !defined(_WIN32) && !defined(__wasi__)

// MARK: - Processes and signals

#if !defined(_WIN32) && !defined(__wasi__)
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <Availability.h>
#include <TargetConditionals.h>
#endif

extern int csystem_wifexited(int status) { return WIFEXITED(status); }
extern int csystem_wexitstatus(int status) { return WEXITSTATUS(status); }
extern int csystem_wifsignaled(int status) { return WIFSIGNALED(status); }
extern int csystem_wtermsig(int status) { return WTERMSIG(status); }
extern int csystem_wcoredump(int status) {
  #ifdef WCOREDUMP
  return WCOREDUMP(status) != 0;
  #else
  return 0;
  #endif
}
extern int csystem_wifstopped(int status) { return WIFSTOPPED(status); }
extern int csystem_wstopsig(int status) { return WSTOPSIG(status); }
extern int csystem_wifcontinued(int status) { return WIFCONTINUED(status); }

extern int csystem_siginfo_pid(const void *info) {
  return ((const siginfo_t *)info)->si_pid;
}

extern unsigned int csystem_siginfo_uid(const void *info) {
  return ((const siginfo_t *)info)->si_uid;
}

extern int csystem_siginfo_status(const void *info) {
  return ((const siginfo_t *)info)->si_status;
}

extern void *csystem_siginfo_addr(const void *info) {
  return ((const siginfo_t *)info)->si_addr;
}

// POSIX requires a function pointer to survive a round trip through void *,
// as dlsym's does.
extern void *csystem_sigaction_handler(const void *action) {
  return (void *)((const struct sigaction *)action)->sa_handler;
}

extern void csystem_sigaction_set_handler(void *action, void *handler) {
  ((struct sigaction *)action)->sa_handler = (void (*)(int))handler;
}

// Darwin has the _np forms from macOS 10.15, and the POSIX forms from macOS
// 26 (in SDKs that declare them), on macOS only. glibc has the _np forms from 2.29, Bionic from API
// level 34, and Musl and FreeBSD have them; OpenBSD has neither.
#if defined(__APPLE__)
#if TARGET_OS_OSX
#define CSYSTEM_HAVE_SPAWN_CHDIR_NP 1
#endif
#elif defined(__GLIBC__)
#if __GLIBC_PREREQ(2, 29)
#define CSYSTEM_HAVE_SPAWN_CHDIR_NP 1
#endif
#elif defined(__ANDROID__)
#if __ANDROID_API__ >= 34
#define CSYSTEM_HAVE_SPAWN_CHDIR_NP 1
#endif
#elif defined(__linux__) || defined(__FreeBSD__)
#define CSYSTEM_HAVE_SPAWN_CHDIR_NP 1
#endif

#if defined(__APPLE__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif

extern int csystem_posix_spawn_file_actions_addchdir(void *actions, const char *path) {
  #if defined(__APPLE__) && defined(CSYSTEM_HAVE_SPAWN_CHDIR_NP)
  #if defined(__MAC_26_0)
  if (__builtin_available(macOS 26.0, *)) {
    return posix_spawn_file_actions_addchdir(actions, path);
  }
  #endif
  if (__builtin_available(macOS 10.15, *)) {
    return posix_spawn_file_actions_addchdir_np(actions, path);
  }
  return ENOSYS;
  #elif defined(CSYSTEM_HAVE_SPAWN_CHDIR_NP)
  return posix_spawn_file_actions_addchdir_np(actions, path);
  #else
  return ENOSYS;
  #endif
}

extern int csystem_posix_spawn_file_actions_addfchdir(void *actions, int fd) {
  #if defined(__APPLE__) && defined(CSYSTEM_HAVE_SPAWN_CHDIR_NP)
  #if defined(__MAC_26_0)
  if (__builtin_available(macOS 26.0, *)) {
    return posix_spawn_file_actions_addfchdir(actions, fd);
  }
  #endif
  if (__builtin_available(macOS 10.15, *)) {
    return posix_spawn_file_actions_addfchdir_np(actions, fd);
  }
  return ENOSYS;
  #elif defined(CSYSTEM_HAVE_SPAWN_CHDIR_NP)
  return posix_spawn_file_actions_addfchdir_np(actions, fd);
  #else
  return ENOSYS;
  #endif
}

#if defined(__APPLE__)
#pragma clang diagnostic pop
#endif

// glibc has addclosefrom_np from 2.34, and FreeBSD from 13.1.
#if defined(__GLIBC__)
#if __GLIBC_PREREQ(2, 34)
#define CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP 1
#endif
#elif defined(__FreeBSD__)
#include <sys/param.h>
#if __FreeBSD_version >= 1301000
#define CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP 1
#endif
#endif

extern int csystem_posix_spawn_file_actions_addclosefrom(void *actions, int from) {
  #if defined(CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP)
  return posix_spawn_file_actions_addclosefrom_np(actions, from);
  #else
  (void)actions;
  (void)from;
  return ENOSYS;
  #endif
}
#endif // !defined(_WIN32) && !defined(__wasi__)

#ifdef __linux__
#include <sys/signalfd.h>
#include <sys/syscall.h>

// These system calls have the same numbers on every architecture that Swift
// supports, and older kernel headers lack them.
#ifndef SYS_pidfd_send_signal
#define SYS_pidfd_send_signal 424
#endif
#ifndef SYS_pidfd_open
#define SYS_pidfd_open 434
#endif
#ifndef SYS_close_range
#define SYS_close_range 436
#endif

_Static_assert(sizeof(struct csystem_signalfd_siginfo) == sizeof(struct signalfd_siginfo),
               "csystem_signalfd_siginfo must match signalfd_siginfo");

extern int csystem_pidfd_open(int pid, unsigned int flags) {
  return (int)syscall(SYS_pidfd_open, pid, flags);
}

extern int csystem_pidfd_send_signal(int pidfd, int sig, void *info, unsigned int flags) {
  return (int)syscall(SYS_pidfd_send_signal, pidfd, sig, info, flags);
}

extern int csystem_close_range(unsigned int first, unsigned int last, unsigned int flags) {
  return (int)syscall(SYS_close_range, first, last, flags);
}

extern int csystem_signalfd(int fd, const void *mask, int flags) {
  return signalfd(fd, (const sigset_t *)mask, flags);
}
#endif // __linux__

#ifdef __linux__
#include <sys/socket.h>

// With _GNU_SOURCE, which this file defines on Linux, <sys/socket.h>
// declares accept4.
extern int csystem_accept4(int fd, void *addr, void *addrlen, int flags) {
  return accept4(fd, (struct sockaddr *)addr, (socklen_t *)addrlen, flags);
}
#endif // __linux__
