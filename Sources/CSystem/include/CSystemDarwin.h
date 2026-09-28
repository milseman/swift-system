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

#include <locale.h>
#include <removefile.h>
#include <sys/ioctl.h>
#include <sys/random.h>
#include <termios.h>
#include <tzfile.h>
#include <xlocale.h>
#include <xlocale/_stdlib.h>
#include <xlocale/_string.h>

// <removefile.h> is for removefile and its state, <sys/random.h> for
// getentropy, <tzfile.h> for TZDIR and TZDEFAULT, and <locale.h> and the
// <xlocale.h> headers for the locale calls that System wraps provisionally
// (setlocale, newlocale, strtod_l, strncasecmp_l): the Darwin module doesn't
// export them, and in the macOS 26 SDK the locale calls are in explicit
// submodules that an `import Darwin` leaves out.

// Terminal ioctl shims
int _system_ioctl_TIOCGWINSZ(int fd, struct winsize *ws);
int _system_ioctl_TIOCSWINSZ(int fd, const struct winsize *ws);

#endif // defined(__APPLE__)
