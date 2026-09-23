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

// tcgetsid, which not every C library declares without feature macros
// such as _GNU_SOURCE, which can't be defined here; see shims.c.
extern int csystem_tcgetsid(int fd);
#endif

