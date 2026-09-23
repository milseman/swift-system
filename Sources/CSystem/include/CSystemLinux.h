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

#endif

