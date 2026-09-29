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

// mktemp, which the SDK deprecates, so that a call from Swift would warn.
// System makes a name with it and creates the file with O_EXCL itself, as
// mkstemp does.
char *csystem_mktemp(char *path);

// Starts a child that runs a program with other credentials, which
// posix_spawn can't set: forks, and in the child sets the supplementary
// groups (unless group_count is -1), the group and the user (unless NULL),
// clears close-on-exec on the descriptors, and runs the program with
// posix_spawn (or posix_spawnp) and POSIX_SPAWN_SETEXEC. Returns 0 and sets
// *pid, or returns the error number of the step that failed. file_actions
// points to a posix_spawn_file_actions_t, or is NULL; attributes points to
// a posix_spawnattr_t, and isn't NULL. See SpawnCredentials.swift.
int csystem_spawn_with_credentials(
    int *pid, const char *path, int search_path,
    const void *file_actions, const void *attributes,
    char *const arguments[], char *const environment[],
    const unsigned int *user, const unsigned int *group,
    int group_count, const unsigned int *groups,
    int descriptor_count, const int *descriptors);

#endif // defined(__APPLE__)
