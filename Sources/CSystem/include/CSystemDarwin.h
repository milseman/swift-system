/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if defined(__APPLE__)

#include <fcntl.h>

#ifdef O_CLOFORK
#define COMPATIBILITY_O_CLOFORK O_CLOFORK
#else
#define COMPATIBILITY_O_CLOFORK 0
#endif

#include <removefile.h>
#include <sys/ioctl.h>
#include <sys/random.h>
#include <termios.h>

// <removefile.h> is for removefile and its state, and <sys/random.h> for
// getentropy, which the Darwin module doesn't export.

// Terminal ioctl shims
int _system_ioctl_TIOCGWINSZ(int fd, struct winsize *ws);
int _system_ioctl_TIOCSWINSZ(int fd, const struct winsize *ws);

#endif // defined(__APPLE__)
