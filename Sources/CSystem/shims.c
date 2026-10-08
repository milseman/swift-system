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

// O_PATH, O_TMPFILE and AT_EMPTY_PATH, which <fcntl.h> declares only with
// _GNU_SOURCE in glibc, as Musl's does the last two.
#include <fcntl.h>
int _system_get_AT_EMPTY_PATH(void) { return AT_EMPTY_PATH; }
int _system_get_O_PATH(void) { return O_PATH; }
int _system_get_O_TMPFILE(void) { return O_TMPFILE; }

// MAXSYMLINKS, and XATTR_NAME_MAX, which Musl's <limits.h> doesn't define:
// there it's the kernel's value, which hasn't changed.
#include <limits.h>
#include <sys/param.h>
#ifndef XATTR_NAME_MAX
#define XATTR_NAME_MAX 255
#endif
int _system_get_MAXSYMLINKS(void) { return MAXSYMLINKS; }
int _system_get_XATTR_NAME_MAX(void) { return XATTR_NAME_MAX; }

#include <CSystemLinux.h>
#include <sys/ioctl.h>

// Terminal ioctl shims for Linux
int _system_ioctl_TIOCGWINSZ(int fd, void *ws) {
  return ioctl(fd, TIOCGWINSZ, ws);
}

int _system_ioctl_TIOCSWINSZ(int fd, const void *ws) {
  return ioctl(fd, TIOCSWINSZ, ws);
}

// <linux/fs.h>'s definition. That header includes <linux/mount.h>, which
// some glibc versions' <sys/mount.h> conflicts with, so it isn't included.
#ifndef FICLONE
#define FICLONE _IOW(0x94, 9, int)
#endif
int _system_ioctl_FICLONE(int fd, int source) {
  return ioctl(fd, FICLONE, source);
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

#include <stdlib.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
char *csystem_mktemp(char *path) {
  return mktemp(path);
}
#pragma clang diagnostic pop

#endif

#if defined(__FreeBSD__) || defined(__OpenBSD__)

#include <CSystemShared.h>
#include <sys/ioctl.h>
#include <sys/param.h>

// Terminal ioctl shims for FreeBSD and OpenBSD
int _system_ioctl_TIOCGWINSZ(int fd, void *ws) {
  return ioctl(fd, TIOCGWINSZ, ws);
}

int _system_ioctl_TIOCSWINSZ(int fd, const void *ws) {
  return ioctl(fd, TIOCSWINSZ, ws);
}

// 32 on both: FreeBSD's is a literal, OpenBSD's its SYMLOOP_MAX.
int _system_get_MAXSYMLINKS(void) { return MAXSYMLINKS; }

#include <readpassphrase.h>

// TerminalDescriptor.PassphraseOptions spells the flags as these values,
// which Darwin's, the BSDs' and libbsd's headers share.
_Static_assert(RPP_ECHO_ON == 0x01 && RPP_REQUIRE_TTY == 0x02 &&
                   RPP_FORCELOWER == 0x04 && RPP_FORCEUPPER == 0x08 &&
                   RPP_SEVENBIT == 0x10 && RPP_STDIN == 0x20,
               "TerminalDescriptor.PassphraseOptions");

char *csystem_readpassphrase(const char *prompt, char *buffer,
                             unsigned long size, int flags) {
  return readpassphrase(prompt, buffer, size, flags);
}

#endif

#if defined(__OpenBSD__)
#include <pthread_np.h>

// OpenBSD names threads with these; neither reports an error.
void csystem_pthread_set_name_np(void *thread, const char *name) {
  pthread_set_name_np((pthread_t)thread, name);
}

void csystem_pthread_get_name_np(void *thread, char *name, unsigned long length) {
  pthread_get_name_np((pthread_t)thread, name, length);
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
#include <signal.h>
#include <sys/stat.h>

_Static_assert(CSYSTEM_UTIME_NOW == UTIME_NOW, "CSYSTEM_UTIME_NOW");
_Static_assert(CSYSTEM_UTIME_OMIT == UTIME_OMIT, "CSYSTEM_UTIME_OMIT");
_Static_assert(CSYSTEM_KERNEL_SIGSET_SIZE == _NSIG / 8, "CSYSTEM_KERNEL_SIGSET_SIZE");
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

#include <ifaddrs.h>

extern int csystem_getifaddrs(void **list) {
  #if __ANDROID_API__ >= 24
  return getifaddrs((struct ifaddrs **)list);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}

extern void csystem_freeifaddrs(void *list) {
  #if __ANDROID_API__ >= 24
  freeifaddrs((struct ifaddrs *)list);
  #endif
}

#include <sys/random.h>

extern int csystem_getentropy(void *buffer, size_t length) {
  #if __ANDROID_API__ >= 28
  return getentropy(buffer, length);
  #else
  errno = ENOSYS;
  return -1;
  #endif
}
#endif // __ANDROID__

#if !defined(_WIN32) && !defined(__wasi__) && !defined(__ANDROID__)
#include <sys/mman.h>

extern int csystem_shm_open(const char *name, int oflag, unsigned int mode) {
  return shm_open(name, oflag, (mode_t)mode);
}
#endif

#if !defined(_WIN32)
#if defined(__APPLE__)
#include <crt_externs.h>
#elif defined(__wasi__)
#include <wasi/libc-environ.h>
#endif

extern char **csystem_environ(void) {
  #if defined(__APPLE__)
  return *_NSGetEnviron();
  #elif defined(__wasi__)
  // wasi-libc reads the environment into environ on first use, which this
  // does, where reading environ itself wouldn't.
  return __wasilibc_get_environ();
  #else
  extern char **environ;
  return environ;
  #endif
}
#endif // !defined(_WIN32)

#ifdef __linux__
#include <stdlib.h>
#include <sys/auxv.h>

extern int csystem_mkostemp(char *path_template, int flags) {
  #if defined(__ANDROID__) && __ANDROID_API__ < 23
  if (flags == 0) return mkstemp(path_template);
  errno = ENOSYS;
  return -1;
  #else
  return mkostemp(path_template, flags);
  #endif
}

extern int csystem_mkostemps(char *path_template, int suffix_length, int flags) {
  #if defined(__ANDROID__) && __ANDROID_API__ < 23
  if (flags == 0) return mkstemps(path_template, suffix_length);
  errno = ENOSYS;
  return -1;
  #else
  return mkostemps(path_template, suffix_length, flags);
  #endif
}

extern int csystem_is_secure_execution(void) {
  return getauxval(AT_SECURE) != 0;
}
#endif // __linux__

#ifdef __linux__
#include <dlfcn.h>

extern int csystem_dladdr(const void *address, const char **path, void **base,
                          const char **symbol, void **symbol_address) {
  Dl_info info;
  int result = dladdr(address, &info);
  if (result != 0) {
    *path = info.dli_fname;
    *base = info.dli_fbase;
    *symbol = info.dli_sname;
    *symbol_address = info.dli_saddr;
  }
  return result;
}
#endif // __linux__

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

// glibc has addclosefrom_np from 2.34, and FreeBSD from 13.1. glibc's is
// looked up when it's needed, so that a System built against an older glibc
// uses it where the running glibc has it, and one built against a newer
// glibc still loads where it doesn't.
#if defined(__GLIBC__)
typedef int (*csystem_addclosefrom_np)(posix_spawn_file_actions_t *, int);

static csystem_addclosefrom_np csystem_find_addclosefrom_np(void) {
  return (csystem_addclosefrom_np)dlsym(RTLD_DEFAULT, "posix_spawn_file_actions_addclosefrom_np");
}
#elif defined(__FreeBSD__)
#include <sys/param.h>
#if __FreeBSD_version >= 1301000
#define CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP 1
#endif
#endif

extern int csystem_posix_spawn_file_actions_addclosefrom(void *actions, int from) {
  #if defined(__GLIBC__)
  csystem_addclosefrom_np addclosefrom = csystem_find_addclosefrom_np();
  if (addclosefrom) {
    return addclosefrom(actions, from);
  }
  return ENOSYS;
  #elif defined(CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP)
  return posix_spawn_file_actions_addclosefrom_np(actions, from);
  #else
  (void)actions;
  (void)from;
  return ENOSYS;
  #endif
}

extern int csystem_posix_spawn_file_actions_has_addclosefrom(void) {
  #if defined(__GLIBC__)
  return csystem_find_addclosefrom_np() != 0;
  #elif defined(CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP)
  return 1;
  #else
  return 0;
  #endif
}

#if defined(__GLIBC__)
// sigabbrev_np, from glibc 2.32, looked up as it's called, as
// addclosefrom_np is.
typedef const char *(*csystem_sigabbrev_np_t)(int);

static csystem_sigabbrev_np_t csystem_find_sigabbrev_np(void) {
  return (csystem_sigabbrev_np_t)dlsym(RTLD_DEFAULT, "sigabbrev_np");
}

extern const char *csystem_sigabbrev_np(int signal) {
  csystem_sigabbrev_np_t sigabbrev = csystem_find_sigabbrev_np();
  return sigabbrev ? sigabbrev(signal) : 0;
}

extern int csystem_has_sigabbrev_np(void) {
  return csystem_find_sigabbrev_np() != 0;
}
#endif

#if defined(__ANDROID__)
// Bionic has these from API level 28, and below it doesn't declare them.
#if __ANDROID_API__ >= 28
#define CSYSTEM_SPAWN_API_28(call) return call
#else
#define CSYSTEM_SPAWN_API_28(call) return ENOSYS
#endif

extern int csystem_posix_spawn(int *pid, const char *path, const void *actions,
                               const void *attributes, char *const arguments[],
                               char *const environment[]) {
  CSYSTEM_SPAWN_API_28(posix_spawn(pid, path, actions, attributes, arguments, environment));
}

extern int csystem_posix_spawnp(int *pid, const char *file, const void *actions,
                                const void *attributes, char *const arguments[],
                                char *const environment[]) {
  CSYSTEM_SPAWN_API_28(posix_spawnp(pid, file, actions, attributes, arguments, environment));
}

extern int csystem_posix_spawnattr_init(void *attributes) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_init(attributes));
}

extern int csystem_posix_spawnattr_destroy(void *attributes) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_destroy(attributes));
}

extern int csystem_posix_spawnattr_getflags(const void *attributes, short *flags) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_getflags(attributes, flags));
}

extern int csystem_posix_spawnattr_setflags(void *attributes, short flags) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_setflags(attributes, flags));
}

extern int csystem_posix_spawnattr_setpgroup(void *attributes, int group) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_setpgroup(attributes, group));
}

extern int csystem_posix_spawnattr_setsigmask(void *attributes, const void *mask) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_setsigmask(attributes, mask));
}

extern int csystem_posix_spawnattr_setsigdefault(void *attributes, const void *mask) {
  CSYSTEM_SPAWN_API_28(posix_spawnattr_setsigdefault(attributes, mask));
}

extern int csystem_posix_spawn_file_actions_init(void *actions) {
  CSYSTEM_SPAWN_API_28(posix_spawn_file_actions_init(actions));
}

extern int csystem_posix_spawn_file_actions_destroy(void *actions) {
  CSYSTEM_SPAWN_API_28(posix_spawn_file_actions_destroy(actions));
}

extern int csystem_posix_spawn_file_actions_addopen(void *actions, int fd, const char *path,
                                                    int flags, unsigned int mode) {
  CSYSTEM_SPAWN_API_28(posix_spawn_file_actions_addopen(actions, fd, path, flags, (mode_t)mode));
}

extern int csystem_posix_spawn_file_actions_adddup2(void *actions, int fd, int target) {
  CSYSTEM_SPAWN_API_28(posix_spawn_file_actions_adddup2(actions, fd, target));
}

extern int csystem_posix_spawn_file_actions_addclose(void *actions, int fd) {
  CSYSTEM_SPAWN_API_28(posix_spawn_file_actions_addclose(actions, fd));
}

#undef CSYSTEM_SPAWN_API_28
#endif // defined(__ANDROID__)
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

#include <stddef.h>
#include <time.h>

// CInterop.MMsgHdr, in Swift, is a struct msghdr and an unsigned int, laid
// out as C lays out these two fields.
struct csystem_mmsghdr_layout {
  struct msghdr msg_hdr;
  unsigned int msg_len;
};
_Static_assert(sizeof(struct mmsghdr) == sizeof(struct csystem_mmsghdr_layout),
               "CInterop.MMsgHdr must match struct mmsghdr");
_Static_assert(offsetof(struct mmsghdr, msg_len) ==
                   offsetof(struct csystem_mmsghdr_layout, msg_len),
               "CInterop.MMsgHdr must match struct mmsghdr");

extern int csystem_sendmmsg(int fd, void *msgvec, unsigned int vlen, int flags) {
  return sendmmsg(fd, (struct mmsghdr *)msgvec, vlen, flags);
}

extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout) {
  return recvmmsg(fd, (struct mmsghdr *)msgvec, vlen, flags, (struct timespec *)timeout);
}

// UDP_SEGMENT and UDP_GRO, which SystemSockets' UDPOption spells as the
// kernel's numbers, since glibc's and Bionic's Swift modules don't include
// <netinet/udp.h>; a C library older than the options doesn't define them.
#include <netinet/udp.h>
#ifdef UDP_SEGMENT
_Static_assert(UDP_SEGMENT == 103, "SocketDescriptor.UDPOption.segmentSize");
#endif
#ifdef UDP_GRO
_Static_assert(UDP_GRO == 104, "SocketDescriptor.UDPOption.receiveOffload");
#endif

// VM sockets. <linux/vm_sockets.h> needs struct sockaddr, from
// <sys/socket.h>, first.
#if __has_include(<linux/vm_sockets.h>)
#include <linux/vm_sockets.h>

// CInterop.SockAddrVM, in Swift, is these fields, laid out as C lays them
// out; Linux 5.11 took svm_flags from the start of svm_zero. And the
// context IDs that VMSocketAddress.ContextID spells as numbers.
struct csystem_sockaddr_vm_layout {
  sa_family_t svm_family;
  unsigned short svm_reserved1;
  unsigned int svm_port;
  unsigned int svm_cid;
  unsigned char svm_flags;
  unsigned char svm_zero[3];
};
_Static_assert(sizeof(struct sockaddr_vm) == sizeof(struct csystem_sockaddr_vm_layout),
               "CInterop.SockAddrVM must match struct sockaddr_vm");
_Static_assert(offsetof(struct sockaddr_vm, svm_port) ==
                   offsetof(struct csystem_sockaddr_vm_layout, svm_port),
               "CInterop.SockAddrVM must match struct sockaddr_vm");
_Static_assert(offsetof(struct sockaddr_vm, svm_cid) ==
                   offsetof(struct csystem_sockaddr_vm_layout, svm_cid),
               "CInterop.SockAddrVM must match struct sockaddr_vm");
_Static_assert(VMADDR_CID_HYPERVISOR == 0, "VMADDR_CID_HYPERVISOR");
_Static_assert(VMADDR_CID_HOST == 2, "VMADDR_CID_HOST");
_Static_assert(VMADDR_CID_ANY == -1U, "VMADDR_CID_ANY");
_Static_assert(VMADDR_PORT_ANY == -1U, "VMADDR_PORT_ANY");
#ifdef VMADDR_CID_LOCAL
_Static_assert(VMADDR_CID_LOCAL == 1, "VMADDR_CID_LOCAL");
#endif
#endif // __has_include(<linux/vm_sockets.h>)

#ifndef IOCTL_VM_SOCKETS_GET_LOCAL_CID
// The kernel's value, for a C library without the header.
#define IOCTL_VM_SOCKETS_GET_LOCAL_CID _IO(7, 0xb9)
#endif

unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void) {
  return IOCTL_VM_SOCKETS_GET_LOCAL_CID;
}
#endif // __linux__

// MARK: - Locales

#ifdef __linux__
#include <locale.h>

int _system_get_LC_ALL_MASK(void) { return LC_ALL_MASK; }
#endif // __linux__

#if defined(__linux__) && !defined(__ANDROID__)
#include <stdlib.h>

// With _GNU_SOURCE, which this file defines on Linux, <stdlib.h> declares
// strtod_l and strtof_l.
extern double csystem_strtod_l(const char *string, char **end, void *locale) {
  return strtod_l(string, end, (locale_t)locale);
}

extern float csystem_strtof_l(const char *string, char **end, void *locale) {
  return strtof_l(string, end, (locale_t)locale);
}

// MARK: - Time zone files

#if __has_include(<tzfile.h>)
#include <tzfile.h>
#endif
#ifndef TZDIR
#define TZDIR "/usr/share/zoneinfo"
#endif
#ifndef TZDEFAULT
#define TZDEFAULT "/etc/localtime"
#endif

const char *_system_get_TZDEFAULT(void) { return TZDEFAULT; }
const char *_system_get_TZDIR(void) { return TZDIR; }
#endif // defined(__linux__) && !defined(__ANDROID__)

// MARK: - The allocator

#if defined(__linux__) && defined(__GLIBC__)
#include <malloc.h>

_Static_assert(CSYSTEM_M_MXFAST == M_MXFAST, "M_MXFAST");
_Static_assert(CSYSTEM_M_TRIM_THRESHOLD == M_TRIM_THRESHOLD, "M_TRIM_THRESHOLD");
_Static_assert(CSYSTEM_M_TOP_PAD == M_TOP_PAD, "M_TOP_PAD");
_Static_assert(CSYSTEM_M_MMAP_THRESHOLD == M_MMAP_THRESHOLD, "M_MMAP_THRESHOLD");
_Static_assert(CSYSTEM_M_MMAP_MAX == M_MMAP_MAX, "M_MMAP_MAX");
_Static_assert(CSYSTEM_M_CHECK_ACTION == M_CHECK_ACTION, "M_CHECK_ACTION");
_Static_assert(CSYSTEM_M_PERTURB == M_PERTURB, "M_PERTURB");
_Static_assert(CSYSTEM_M_ARENA_TEST == M_ARENA_TEST, "M_ARENA_TEST");
_Static_assert(CSYSTEM_M_ARENA_MAX == M_ARENA_MAX, "M_ARENA_MAX");

extern size_t csystem_malloc_usable_size(const void *pointer) {
  return malloc_usable_size((void *)pointer);
}

extern void *csystem_pvalloc(size_t size) {
  return pvalloc(size);
}

extern int csystem_malloc_trim(size_t pad) {
  return malloc_trim(pad);
}

extern int csystem_mallopt(int parameter, int value) {
  return mallopt(parameter, value);
}

extern int csystem_malloc_info(int options, void *stream) {
  return malloc_info(options, (FILE *)stream);
}

extern void csystem_malloc_stats(void) {
  malloc_stats();
}

extern void csystem_get_mallinfo2(struct csystem_mallinfo2 *info) {
  #if __GLIBC_PREREQ(2, 33)
  struct mallinfo2 m = mallinfo2();
  #define CSYSTEM_MALLINFO_FIELD(f) ((size_t)m.f)
  #else
  // mallinfo's int fields count modulo 2^32.
  struct mallinfo m = mallinfo();
  #define CSYSTEM_MALLINFO_FIELD(f) ((size_t)(unsigned int)m.f)
  #endif
  info->arena = CSYSTEM_MALLINFO_FIELD(arena);
  info->ordblks = CSYSTEM_MALLINFO_FIELD(ordblks);
  info->smblks = CSYSTEM_MALLINFO_FIELD(smblks);
  info->hblks = CSYSTEM_MALLINFO_FIELD(hblks);
  info->hblkhd = CSYSTEM_MALLINFO_FIELD(hblkhd);
  info->usmblks = CSYSTEM_MALLINFO_FIELD(usmblks);
  info->fsmblks = CSYSTEM_MALLINFO_FIELD(fsmblks);
  info->uordblks = CSYSTEM_MALLINFO_FIELD(uordblks);
  info->fordblks = CSYSTEM_MALLINFO_FIELD(fordblks);
  info->keepcost = CSYSTEM_MALLINFO_FIELD(keepcost);
  #undef CSYSTEM_MALLINFO_FIELD
}

// MARK: - The call stack

#include <execinfo.h>

extern int csystem_backtrace(void **buffer, int size) {
  return backtrace(buffer, size);
}

extern char **csystem_backtrace_symbols(void *const *buffer, int size) {
  return backtrace_symbols(buffer, size);
}
#endif // defined(__linux__) && defined(__GLIBC__)

#if defined(__FreeBSD__)
#include <malloc_np.h>

extern size_t csystem_malloc_usable_size(const void *pointer) {
  return malloc_usable_size(pointer);
}

#include <langinfo.h>
#include <stdlib.h>
#include <strings.h>
#include <xlocale.h>

extern double csystem_strtod_l(const char *string, char **end, void *locale) {
  return strtod_l(string, end, (locale_t)locale);
}

extern float csystem_strtof_l(const char *string, char **end, void *locale) {
  return strtof_l(string, end, (locale_t)locale);
}

extern int csystem_strncasecmp_l(const char *a, const char *b, size_t count, void *locale) {
  return strncasecmp_l(a, b, count, (locale_t)locale);
}

extern char *csystem_nl_langinfo_l(int item, void *locale) {
  return nl_langinfo_l((nl_item)item, (locale_t)locale);
}
#endif // defined(__FreeBSD__)

#if defined(__wasi__)
#include <malloc.h>

extern size_t csystem_malloc_usable_size(const void *pointer) {
  return malloc_usable_size((void *)pointer);
}
#endif // defined(__wasi__)

#ifdef __ANDROID__
#include <string.h>

extern void csystem_explicit_bzero(void *start, size_t count) {
  memset(start, 0, count);
  // The compiler must assume that the empty assembly reads the memory, so
  // it can't remove the memset as a store that nothing reads.
  __asm__ __volatile__("" : : "r"(start) : "memory");
}
#endif // __ANDROID__

// MARK: - Spawning with other credentials

#if defined(__APPLE__)
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

// A pipe whose ends are close-on-exec: atomically where pipe2 exists, and
// otherwise in a second step; the macOS 26 SDK has no other way to make a
// pipe or a socket pair close-on-exec at once (no SOCK_CLOEXEC). A program
// that another thread starts between the two steps (with fork and exec, or
// posix_spawn) inherits both ends, and then the parent's read in
// csystem_spawn_with_credentials, which ends when every write end has
// closed, waits until that program exits or closes its copy, even after the
// child's program has started.
static int csystem_pipe_cloexec(int fds[2]) {
  #if defined(HAVE_PIPE2_DUP3)
  if (__builtin_available(macOS 27, iOS 27, tvOS 27, watchOS 27, visionOS 27, *))
    return pipe2(fds, O_CLOEXEC);
  #endif
  if (pipe(fds) != 0) return -1;
  if (fcntl(fds[0], F_SETFD, FD_CLOEXEC) == -1 || fcntl(fds[1], F_SETFD, FD_CLOEXEC) == -1) {
    int error = errno;
    close(fds[0]);
    close(fds[1]);
    errno = error;
    return -1;
  }
  return 0;
}

// In the child, which may call only async-signal-safe functions: reports
// an error number to the parent, and exits.
static void csystem_report_child_error(int fd, int error) {
  while (write(fd, &error, sizeof(error)) == -1 && errno == EINTR) {}
  _exit(127);
}

extern int csystem_spawn_with_credentials(
    int *pid, const char *path, int search_path,
    const void *file_actions, const void *attributes,
    char *const arguments[], char *const environment[],
    const unsigned int *user, const unsigned int *group,
    int group_count, const unsigned int *groups,
    int descriptor_count, const int *descriptors) {
  int fds[2];
  if (csystem_pipe_cloexec(fds) != 0) return errno;

  // The child runs none of the parent's signal handlers: every signal is
  // blocked across the fork, and the child resets its handlers before it
  // unblocks them for the program.
  sigset_t all, old;
  sigfillset(&all);
  pthread_sigmask(SIG_SETMASK, &all, &old);
  pid_t child = fork();
  if (child == 0) {
    close(fds[0]);
    for (int sig = 1; sig < NSIG; sig++) {
      struct sigaction action;
      if (sigaction(sig, NULL, &action) == 0
          && action.sa_handler != SIG_DFL && action.sa_handler != SIG_IGN) {
        action.sa_handler = SIG_DFL;
        action.sa_flags = 0;
        sigemptyset(&action.sa_mask);
        (void)sigaction(sig, &action, NULL);
      }
    }
    // The groups before the user: once the user isn't root, they can't change.
    if (group_count >= 0 && setgroups(group_count, (const gid_t *)groups) != 0)
      csystem_report_child_error(fds[1], errno);
    if (group != NULL && setgid((gid_t)*group) != 0)
      csystem_report_child_error(fds[1], errno);
    if (user != NULL && setuid((uid_t)*user) != 0)
      csystem_report_child_error(fds[1], errno);
    // With POSIX_SPAWN_SETEXEC, Darwin closes close-on-exec descriptors
    // before it applies the file actions, which would then fail with EBADF.
    for (int i = 0; i < descriptor_count; i++) {
      int flags = fcntl(descriptors[i], F_GETFD);
      if (flags == -1 || ((flags & FD_CLOEXEC) != 0
          && fcntl(descriptors[i], F_SETFD, flags & ~FD_CLOEXEC) == -1))
        csystem_report_child_error(fds[1], errno);
    }
    // The attributes are the child's copy, so the parent's keep their flags.
    posix_spawnattr_t *spawn_attributes = (posix_spawnattr_t *)attributes;
    short flags = 0;
    int error = posix_spawnattr_getflags(spawn_attributes, &flags);
    if (error == 0)
      error = posix_spawnattr_setflags(spawn_attributes, flags | POSIX_SPAWN_SETEXEC);
    if (error == 0) {
      pthread_sigmask(SIG_SETMASK, &old, NULL);
      const posix_spawn_file_actions_t *actions = file_actions;
      pid_t unused;
      error = search_path
        ? posix_spawnp(&unused, path, actions, spawn_attributes, arguments, environment)
        : posix_spawn(&unused, path, actions, spawn_attributes, arguments, environment);
      // With POSIX_SPAWN_SETEXEC, posix_spawn returns only when it fails.
      if (error == 0) error = ENOEXEC;
    }
    csystem_report_child_error(fds[1], error);
  }
  int fork_error = errno;
  pthread_sigmask(SIG_SETMASK, &old, NULL);
  close(fds[1]);
  if (child == -1) {
    close(fds[0]);
    return fork_error;
  }
  // The write end closes when the program runs, or when the child exits,
  // unless another program inherited it (see csystem_pipe_cloexec).
  int error = 0;
  ssize_t count;
  do {
    count = read(fds[0], &error, sizeof(error));
  } while (count == -1 && errno == EINTR);
  int read_error = errno;
  close(fds[0]);
  if (count == 0) {
    *pid = child;
    return 0;
  }
  if (count != (ssize_t)sizeof(error)) error = count == -1 ? read_error : EIO;
  // The child has exited: reap it.
  while (waitpid(child, NULL, 0) == -1 && errno == EINTR) {}
  return error;
}
#endif // defined(__APPLE__)

#if defined(__linux__) && !defined(__ANDROID__)
#include <pthread.h>
#include <spawn.h>
#include <sys/syscall.h>
#include <unistd.h>

// Linux keeps credentials per thread, and the raw system calls change only
// the calling thread's (glibc's and Musl's setuid and the like change every
// thread's). A child gets the credentials of the thread that spawns it, so
// this spawns from a thread of its own, whose credentials it sets first:
// the process's other threads keep theirs, and the thread ends after the
// spawn. posix_spawn applies the file actions before exec closes the
// close-on-exec descriptors, so the descriptors that Darwin's version
// clears close-on-exec on need nothing here. On the 32-bit ABIs whose
// setgroups and friends take 16-bit IDs, the *32 calls take 32-bit ones.
#if defined(SYS_setresuid32)
#define CSYSTEM_SYS_SETGROUPS SYS_setgroups32
#define CSYSTEM_SYS_SETRESGID SYS_setresgid32
#define CSYSTEM_SYS_SETRESUID SYS_setresuid32
#else
#define CSYSTEM_SYS_SETGROUPS SYS_setgroups
#define CSYSTEM_SYS_SETRESGID SYS_setresgid
#define CSYSTEM_SYS_SETRESUID SYS_setresuid
#endif

struct csystem_credentials_spawn {
  int *pid;
  const char *path;
  int search_path;
  const void *file_actions;
  const void *attributes;
  char *const *arguments;
  char *const *environment;
  const unsigned int *user;
  const unsigned int *group;
  int group_count;
  const unsigned int *groups;
  int result;
};

static void *csystem_spawn_with_thread_credentials(void *argument) {
  struct csystem_credentials_spawn *spawn = argument;
  // The groups, the group, then the user: once the thread isn't root, it
  // can't change the others.
  if (spawn->group_count >= 0 &&
      syscall(CSYSTEM_SYS_SETGROUPS, (size_t)spawn->group_count, spawn->groups) != 0) {
    spawn->result = errno;
    return NULL;
  }
  if (spawn->group != NULL &&
      syscall(CSYSTEM_SYS_SETRESGID, *spawn->group, *spawn->group, *spawn->group) != 0) {
    spawn->result = errno;
    return NULL;
  }
  if (spawn->user != NULL &&
      syscall(CSYSTEM_SYS_SETRESUID, *spawn->user, *spawn->user, *spawn->user) != 0) {
    spawn->result = errno;
    return NULL;
  }
  pid_t pid = 0;
  const posix_spawn_file_actions_t *actions = spawn->file_actions;
  const posix_spawnattr_t *attributes = spawn->attributes;
  spawn->result = spawn->search_path
      ? posix_spawnp(&pid, spawn->path, actions, attributes, spawn->arguments, spawn->environment)
      : posix_spawn(&pid, spawn->path, actions, attributes, spawn->arguments, spawn->environment);
  if (spawn->result == 0) *spawn->pid = pid;
  return NULL;
}

int csystem_spawn_with_credentials(
    int *pid, const char *path, int search_path,
    const void *file_actions, const void *attributes,
    char *const arguments[], char *const environment[],
    const unsigned int *user, const unsigned int *group,
    int group_count, const unsigned int *groups,
    int descriptor_count, const int *descriptors) {
  (void)descriptor_count;
  (void)descriptors;
  struct csystem_credentials_spawn spawn = {
      pid, path, search_path, file_actions, attributes, arguments, environment,
      user, group, group_count, groups, 0,
  };
  pthread_t thread;
  int error = pthread_create(&thread, NULL, csystem_spawn_with_thread_credentials, &spawn);
  if (error != 0) return error;
  error = pthread_join(thread, NULL);
  return error != 0 ? error : spawn.result;
}
#endif // defined(__linux__) && !defined(__ANDROID__)
