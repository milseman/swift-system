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

#include <CSystemLinux.h>
#include <sys/ioctl.h>

// Terminal ioctl shims for Linux
int _system_ioctl_TIOCGWINSZ(int fd, void *ws) {
  return ioctl(fd, TIOCGWINSZ, ws);
}

int _system_ioctl_TIOCSWINSZ(int fd, const void *ws) {
  return ioctl(fd, TIOCSWINSZ, ws);
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

#if !defined(_WIN32) && !defined(__wasi__)
#if defined(__APPLE__)
#include <crt_externs.h>
#endif

extern char **csystem_environ(void) {
  #if defined(__APPLE__)
  return *_NSGetEnviron();
  #else
  extern char **environ;
  return environ;
  #endif
}
#endif // !defined(_WIN32) && !defined(__wasi__)

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

extern int csystem_is_secure_execution(void) {
  return getauxval(AT_SECURE) != 0;
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

// glibc has addclosefrom_np from 2.34, and FreeBSD from 13.1.
#if defined(__GLIBC__)
#if __GLIBC_PREREQ(2, 34)
#define CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP 1
#endif
#elif defined(__FreeBSD__)
#include <sys/param.h>
#if __FreeBSD_version >= 1301000
#define CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP 1
#endif
#endif

extern int csystem_posix_spawn_file_actions_addclosefrom(void *actions, int from) {
  #if defined(CSYSTEM_HAVE_SPAWN_CLOSEFROM_NP)
  return posix_spawn_file_actions_addclosefrom_np(actions, from);
  #else
  (void)actions;
  (void)from;
  return ENOSYS;
  #endif
}
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
#endif // __linux__

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
#endif // defined(__linux__) && defined(__GLIBC__)

#if defined(__FreeBSD__)
#include <malloc_np.h>

extern size_t csystem_malloc_usable_size(const void *pointer) {
  return malloc_usable_size(pointer);
}
#endif // defined(__FreeBSD__)

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
