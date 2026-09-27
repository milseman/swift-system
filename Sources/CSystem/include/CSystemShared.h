/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !defined(_WIN32)
extern int csystem_posix_pipe2(int fildes[2], int flag);
#endif

extern int csystem_posix_dup3(int fildes, int fildes2, int flag);

#if !defined(_WIN32) && !defined(__wasi__)
// Processes and signals, for Sources/System/Processes; see shims.c. The C
// types are untyped here, so that this header needn't include <signal.h> or
// <spawn.h>: members of a C type defined through a CSystem header can be
// attributed to CSystem, which clients don't import (#320).

// The calling process's environment: environ, or _NSGetEnviron() on Darwin.
extern char **csystem_environ(void);

// The wait status macros, which Swift can't import. Their encoding differs
// between platforms, most of all for a continued process.
extern int csystem_wifexited(int status);
extern int csystem_wexitstatus(int status);
extern int csystem_wifsignaled(int status);
extern int csystem_wtermsig(int status);
extern int csystem_wcoredump(int status);
extern int csystem_wifstopped(int status);
extern int csystem_wstopsig(int status);
extern int csystem_wifcontinued(int status);

// Members of a siginfo_t that glibc, Musl, Bionic, and OpenBSD keep in
// unions, whose names are macros that Swift can't import. `info` points to
// a siginfo_t.
extern int csystem_siginfo_pid(const void *info);
extern unsigned int csystem_siginfo_uid(const void *info);
extern int csystem_siginfo_status(const void *info);
extern void *csystem_siginfo_addr(const void *info);

// The handler of a struct sigaction, which each C library keeps in a union
// of a different name. `action` points to a struct sigaction. The handler
// is sa_handler's bits, which are sa_sigaction's.
extern void *csystem_sigaction_handler(const void *action);
extern void csystem_sigaction_set_handler(void *action, void *handler);

// Changing the child's working directory, and closing its descriptors, in
// posix_spawn's file actions. They're _np functions, or new in POSIX.1-2024,
// and not every C library or OS version has them, so these return ENOSYS
// where they're missing. `actions` points to a posix_spawn_file_actions_t.
extern int csystem_posix_spawn_file_actions_addchdir(void *actions, const char *path);
extern int csystem_posix_spawn_file_actions_addfchdir(void *actions, int fd);
extern int csystem_posix_spawn_file_actions_addclosefrom(void *actions, int from);
#endif // !defined(_WIN32) && !defined(__wasi__)
