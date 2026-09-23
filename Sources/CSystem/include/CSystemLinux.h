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

// The flags for renameat2. glibc only declares them, and renameat2 itself,
// with _GNU_SOURCE, which can't be defined here; see shims.c.
#define CSYSTEM_RENAME_NOREPLACE (1 << 0)
#define CSYSTEM_RENAME_EXCHANGE (1 << 1)

extern int csystem_renameat2(int olddirfd, const char *oldpath,
                             int newdirfd, const char *newpath,
                             unsigned int flags);
#endif

