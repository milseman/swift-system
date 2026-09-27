/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#ifdef __linux__

#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/socket.h>
#include <sys/sysinfo.h>
#include <sys/timerfd.h>
#include <sys/types.h>
#include <errno.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>
#include "io_uring.h"

// Terminal ioctl shims. `ws` points to a struct winsize. It's untyped so that
// this header needn't include <sys/ioctl.h>: members of a C type defined
// through a CSystem header can be attributed to CSystem, which clients don't
// import, so MemberImportVisibility hides those members from them (#320).
int _system_ioctl_TIOCGWINSZ(int fd, void *ws);
int _system_ioctl_TIOCSWINSZ(int fd, const void *ws);

// The flags for renameat2. glibc only declares them, and renameat2 itself,
// with _GNU_SOURCE, which can't be defined here; see shims.c.
#define CSYSTEM_RENAME_NOREPLACE (1 << 0)
#define CSYSTEM_RENAME_EXCHANGE (1 << 1)

extern int csystem_renameat2(int olddirfd, const char *oldpath,
                             int newdirfd, const char *newpath,
                             unsigned int flags);

// The open file description lock commands for fcntl. glibc only declares
// them with _GNU_SOURCE, which can't be defined here; see shims.c. They have
// these values on every architecture.
#define CSYSTEM_F_OFD_GETLK 36
#define CSYSTEM_F_OFD_SETLK 37
#define CSYSTEM_F_OFD_SETLKW 38

// The pipe capacity commands for fcntl, which glibc also declares only with
// _GNU_SOURCE, and Bionic defines as F_LINUX_SPECIFIC_BASE + 7 and + 8.
#define CSYSTEM_F_SETPIPE_SZ 1031
#define CSYSTEM_F_GETPIPE_SZ 1032

// The special times for futimens and utimensat, which glibc and Bionic define
// as expressions that Swift can't import. They have these values on every
// architecture; shims.c checks them against <sys/stat.h>.
#define CSYSTEM_UTIME_NOW 0x3fffffff
#define CSYSTEM_UTIME_OMIT 0x3ffffffe

// tcgetsid, which not every C library declares without feature macros
// such as _GNU_SOURCE, which can't be defined here; see shims.c.
extern int csystem_tcgetsid(int fd);
#endif

#ifdef __linux__
// Pseudoterminal functions. glibc declares them only with _XOPEN_SOURCE or
// _GNU_SOURCE, which can't be defined here; see shims.c.
extern int csystem_posix_openpt(int flags);
extern int csystem_grantpt(int fd);
extern int csystem_unlockpt(int fd);
extern int csystem_ptsname_r(int fd, char *buffer, size_t length);
#endif // __linux__

#ifdef __linux__
// Thread names and CPU affinity. glibc declares these only with _GNU_SOURCE,
// and Musl and Bionic declare the affinity functions only with it; see
// shims.c. Each mask is a cpu_set_t of `size` bytes, untyped because Musl
// declares cpu_set_t itself only with _GNU_SOURCE.
extern int csystem_pthread_setname_np(pthread_t thread, const char *name);
extern int csystem_pthread_getname_np(pthread_t thread, char *name, size_t length);
extern int csystem_sched_setaffinity(pid_t pid, size_t size, const void *mask);
extern int csystem_sched_getaffinity(pid_t pid, size_t size, void *mask);
#ifndef __ANDROID__
// Bionic has no pthread affinity functions.
extern int csystem_pthread_setaffinity_np(pthread_t thread, size_t size, const void *mask);
extern int csystem_pthread_getaffinity_np(pthread_t thread, size_t size, void *mask);
#endif // !__ANDROID__
#endif // __linux__
