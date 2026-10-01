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

#if defined(__FreeBSD__) || defined(__OpenBSD__)
// Terminal ioctl shims, as CSystemLinux.h and CSystemDarwin.h declare them.
// `ws` points to a struct winsize, untyped so that this header needn't
// include <sys/ioctl.h>, as CSystemLinux.h explains.
extern int _system_ioctl_TIOCGWINSZ(int fd, void *ws);
extern int _system_ioctl_TIOCSWINSZ(int fd, const void *ws);

// MAXSYMLINKS, from <sys/param.h>, as CSystemLinux.h declares it.
extern int _system_get_MAXSYMLINKS(void);
#endif

#if !defined(_WIN32) && !defined(__wasi__) && !defined(__ANDROID__)
// shm_open, which is variadic, so Swift can't import it.
extern int csystem_shm_open(const char *name, int oflag, unsigned int mode);
#endif

#if !defined(_WIN32)
// The process's environ array. Darwin's is _NSGetEnviron's, since a library
// can't link to environ there, WASI's is filled in on first use, and not
// every other C library declares environ without feature macros.
extern char **csystem_environ(void);
#endif

#if !defined(_WIN32) && !defined(__wasi__)
// Processes and signals, for Sources/System/Processes; see shims.c. The C
// types are untyped here, so that this header needn't include <signal.h> or
// <spawn.h>: members of a C type defined through a CSystem header can be
// attributed to CSystem, which clients don't import (#320).

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

#if defined(__ANDROID__)
// posix_spawn, posix_spawnp, and the attribute and file action calls that
// Sources/System/Processes makes, which Bionic has from API level 28 (and
// declares only from it, with nullability that has changed between NDK
// releases); below it, these return ENOSYS. `attributes` points to a
// posix_spawnattr_t, `actions` to a posix_spawn_file_actions_t, and `mask`
// to a sigset_t.
extern int csystem_posix_spawn(int *pid, const char *path, const void *actions,
                               const void *attributes, char *const arguments[],
                               char *const environment[]);
extern int csystem_posix_spawnp(int *pid, const char *file, const void *actions,
                                const void *attributes, char *const arguments[],
                                char *const environment[]);
extern int csystem_posix_spawnattr_init(void *attributes);
extern int csystem_posix_spawnattr_destroy(void *attributes);
extern int csystem_posix_spawnattr_getflags(const void *attributes, short *flags);
extern int csystem_posix_spawnattr_setflags(void *attributes, short flags);
extern int csystem_posix_spawnattr_setpgroup(void *attributes, int group);
extern int csystem_posix_spawnattr_setsigmask(void *attributes, const void *mask);
extern int csystem_posix_spawnattr_setsigdefault(void *attributes, const void *mask);
extern int csystem_posix_spawn_file_actions_init(void *actions);
extern int csystem_posix_spawn_file_actions_destroy(void *actions);
extern int csystem_posix_spawn_file_actions_addopen(void *actions, int fd, const char *path,
                                                    int flags, unsigned int mode);
extern int csystem_posix_spawn_file_actions_adddup2(void *actions, int fd, int target);
extern int csystem_posix_spawn_file_actions_addclose(void *actions, int fd);
#endif // defined(__ANDROID__)
#endif // !defined(_WIN32) && !defined(__wasi__)
