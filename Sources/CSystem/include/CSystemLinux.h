/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#ifdef __linux__

// Swift attributes a C type that two modules declare to the module whose
// copy it loads first, and SystemPackage loads CSystem's copy when it calls
// a CSystem function that takes the type, as timerfd_settime took
// itimerspec, and so timespec. MemberImportVisibility then hides the type's
// members from clients, which don't import CSystem (#320). So beyond these,
// this header includes none of the headers that glibc's Swift module
// includes, and the shims below take their types as `void *`, while shims.c
// includes the real headers. The thread shims need only <sys/types.h>'s
// pthread_t and pid_t; <pthread.h> and <sched.h> would declare timespec and
// sched_param here.
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/sysinfo.h>
#include <sys/types.h>
#include <errno.h>
#include <unistd.h>
#include "io_uring.h"

// Terminal ioctl shims. `ws` points to a struct winsize. It's untyped so that
// this header needn't include <sys/ioctl.h>: members of a C type defined
// through a CSystem header can be attributed to CSystem, which clients don't
// import, so MemberImportVisibility hides those members from them (#320).
int _system_ioctl_TIOCGWINSZ(int fd, void *ws);
int _system_ioctl_TIOCSWINSZ(int fd, const void *ws);

// FICLONE, which clones the contents of the file that `source` refers to
// into the file that `fd` refers to. It's in <linux/fs.h>, which this header
// doesn't include; see shims.c.
int _system_ioctl_FICLONE(int fd, int source);

// timerfd. Each value points to a struct itimerspec, untyped so that this
// header needn't include <sys/timerfd.h>, whose <time.h> declares timespec.
extern int csystem_timerfd_create(int clockid, int flags);
extern int csystem_timerfd_settime(int fd, int flags,
                                   const void *new_value, void *old_value);
extern int csystem_timerfd_gettime(int fd, void *curr_value);

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

// open's O_PATH and O_TMPFILE and the *at functions' AT_EMPTY_PATH, which
// glibc declares only with _GNU_SOURCE, as Musl does the last two, which
// can't be defined here; see shims.c. O_PATH's value and O_TMPFILE's
// O_DIRECTORY differ by architecture, so these are the headers' own values.
int _system_get_AT_EMPTY_PATH(void);
int _system_get_O_PATH(void);
int _system_get_O_TMPFILE(void);

// MAXSYMLINKS, from <sys/param.h>, which glibc's and Bionic's Swift modules
// don't include, and which this header can't, since it includes
// <signal.h>; and XATTR_NAME_MAX, from <linux/limits.h>, which Musl's
// <limits.h> doesn't include. See shims.c.
int _system_get_MAXSYMLINKS(void);
int _system_get_XATTR_NAME_MAX(void);

// The special times for futimens and utimensat, which glibc and Bionic define
// as expressions that Swift can't import. They have these values on every
// architecture; shims.c checks them against <sys/stat.h>.
#define CSYSTEM_UTIME_NOW 0x3fffffff
#define CSYSTEM_UTIME_OMIT 0x3ffffffe

// tcgetsid, which not every C library declares without feature macros
// such as _GNU_SOURCE, which can't be defined here; see shims.c.
extern int csystem_tcgetsid(int fd);

// The `ST_*` mount-flag constants in <sys/statvfs.h> require _GNU_SOURCE.
// Rather than define _GNU_SOURCE module-wide, which clashes with SwiftGlibc,
// expose them through these getters, defined in shims.c under _GNU_SOURCE.
#include <stdint.h>
uint64_t _system_get_ST_RDONLY(void);
uint64_t _system_get_ST_NOSUID(void);
uint64_t _system_get_ST_NODEV(void);
uint64_t _system_get_ST_NOEXEC(void);
uint64_t _system_get_ST_SYNCHRONOUS(void);
uint64_t _system_get_ST_MANDLOCK(void);
uint64_t _system_get_ST_NOATIME(void);
uint64_t _system_get_ST_NODIRATIME(void);
uint64_t _system_get_ST_RELATIME(void);
uint64_t _system_get_ST_NOSYMFOLLOW(void);
#if !defined(__ANDROID__)
uint64_t _system_get_ST_WRITE(void);
uint64_t _system_get_ST_APPEND(void);
uint64_t _system_get_ST_IMMUTABLE(void);
#endif

// statfs and fstatfs, for the one field that statvfs lacks: f_type, the
// file system's magic number. They return only that field. glibc's module
// doesn't declare statfs, and a struct statfs declared through this header
// would have its members attributed to CSystem, which clients don't import
// (see the ioctl shims above). See shims.c.
extern int csystem_statfs_type(const char *path, unsigned long *type);
extern int csystem_fstatfs_type(int fd, unsigned long *type);
#endif

#ifdef __linux__
// Pseudoterminal functions. glibc declares them only with _XOPEN_SOURCE or
// _GNU_SOURCE, which can't be defined here; see shims.c.
extern int csystem_posix_openpt(int flags);
extern int csystem_grantpt(int fd);
extern int csystem_unlockpt(int fd);
extern int csystem_ptsname_r(int fd, char *buffer, size_t length);
#endif // __linux__

#ifdef __linux__
// Thread names and CPU affinity. glibc declares these only with _GNU_SOURCE,
// and Musl and Bionic declare the affinity functions only with it; see
// shims.c. Each mask is a cpu_set_t of `size` bytes, untyped because Musl
// declares cpu_set_t itself only with _GNU_SOURCE.
extern int csystem_pthread_setname_np(pthread_t thread, const char *name);
extern int csystem_pthread_getname_np(pthread_t thread, char *name, size_t length);
extern int csystem_sched_setaffinity(pid_t pid, size_t size, const void *mask);
extern int csystem_sched_getaffinity(pid_t pid, size_t size, void *mask);
#ifndef __ANDROID__
// Bionic has no pthread affinity functions.
extern int csystem_pthread_setaffinity_np(pthread_t thread, size_t size, const void *mask);
extern int csystem_pthread_getaffinity_np(pthread_t thread, size_t size, void *mask);
#endif // !__ANDROID__
#endif // __linux__

#ifdef __ANDROID__
// preadv and pwritev, which Bionic declares only from API level 24; below
// it, these fail with ENOSYS. `iov` points to `iovcnt` struct iovecs, untyped
// so that this header needn't include <sys/uio.h> (see the ioctl shims).
extern ssize_t csystem_preadv(int fd, const void *iov, int iovcnt, off_t offset);
extern ssize_t csystem_pwritev(int fd, const void *iov, int iovcnt, off_t offset);

// getifaddrs and freeifaddrs, which Bionic declares only from API level 24;
// below it, getifaddrs fails with ENOSYS. `list` points to a struct ifaddrs *,
// untyped so that this header needn't include <ifaddrs.h>.
extern int csystem_getifaddrs(void **list);
extern void csystem_freeifaddrs(void *list);

// getentropy, which Bionic declares only from API level 28; below it, this
// fails with ENOSYS.
extern int csystem_getentropy(void *buffer, size_t length);
#endif // __ANDROID__

#ifdef __linux__
// The extended attribute calls, which glibc's Swift module doesn't include.
// The header declares no types, so nothing's members move to CSystem.
#include <sys/xattr.h>

// mkostemp, which glibc declares only with _GNU_SOURCE, and Bionic only from
// API level 23; below it, this calls mkstemp when there are no flags, and
// fails with ENOSYS when there are.
extern int csystem_mkostemp(char *path_template, int flags);

// mkostemps, the same with a suffix after the X's, which glibc and Musl
// declare only with _GNU_SOURCE, and Bionic only from API level 23; below
// it, this calls mkstemps when there are no flags.
extern int csystem_mkostemps(char *path_template, int suffix_length, int flags);

// dladdr, which glibc declares, with Dl_info, only with _GNU_SOURCE. It
// returns Dl_info's fields, dli_fname, dli_fbase, dli_sname and dli_saddr,
// through the pointers, and dladdr's result.
extern int csystem_dladdr(const void *address, const char **path, void **base,
                          const char **symbol, void **symbol_address);

// Whether the process runs with privileges it didn't start with, as a
// set-user-ID program does: getauxval(AT_SECURE). No C library's Swift module
// includes <sys/auxv.h>.
extern int csystem_is_secure_execution(void);

// Process descriptors, signal descriptors, and closing ranges of
// descriptors, through raw system calls, since not every C library has
// wrappers for them: glibc added pidfd_open in 2.36, and close_range in
// 2.34, and Musl has neither. These return -1 and set errno to ENOSYS where
// the kernel lacks them. `info` points to a siginfo_t, and `mask` to a
// sigset_t.
extern int csystem_pidfd_open(int pid, unsigned int flags);
extern int csystem_pidfd_send_signal(int pidfd, int sig, void *info, unsigned int flags);
extern int csystem_close_range(unsigned int first, unsigned int last, unsigned int flags);
extern int csystem_signalfd(int fd, const void *mask, int flags);

// The record that reading a signal descriptor returns, which is struct
// signalfd_siginfo; shims.c checks the two agree. It's declared here rather
// than through <sys/signalfd.h>, which glibc's and Bionic's Swift modules
// don't include, for the reason above.
struct csystem_signalfd_siginfo {
  unsigned int ssi_signo;
  int ssi_errno;
  int ssi_code;
  unsigned int ssi_pid;
  unsigned int ssi_uid;
  int ssi_fd;
  unsigned int ssi_tid;
  unsigned int ssi_band;
  unsigned int ssi_overrun;
  unsigned int ssi_trapno;
  int ssi_status;
  int ssi_int;
  unsigned long long ssi_ptr;
  unsigned long long ssi_utime;
  unsigned long long ssi_stime;
  unsigned long long ssi_addr;
  unsigned short ssi_addr_lsb;
  unsigned short __pad2;
  int ssi_syscall;
  unsigned long long ssi_call_addr;
  unsigned int ssi_arch;
  unsigned char __pad[28];
};
#endif // __linux__

#ifdef __linux__
// accept4, which glibc and Musl declare only with _GNU_SOURCE; see shims.c.
// `addr` points to a struct sockaddr and `addrlen` to a socklen_t, untyped so
// that this header needn't include <sys/socket.h> (see the ioctl shims).
extern int csystem_accept4(int fd, void *addr, void *addrlen, int flags);

// sendmmsg and recvmmsg, which glibc and Musl declare only with _GNU_SOURCE,
// as they do struct mmsghdr. `msgvec` points to `vlen` struct mmsghdrs,
// which SystemSockets' CInterop.MMsgHdr mirrors, and `timeout` to a struct
// timespec, untyped for the same reason as accept4's arguments.
extern int csystem_sendmmsg(int fd, void *msgvec, unsigned int vlen, int flags);
extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout);

// IOCTL_VM_SOCKETS_GET_LOCAL_CID, from <linux/vm_sockets.h>, which no C
// library's Swift module includes, and which this header doesn't include
// either, so as not to declare struct sockaddr_vm here: SystemSockets'
// CInterop.SockAddrVM mirrors it, and shims.c checks the two agree.
unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void);
#endif // __linux__

#if defined(__linux__) && !defined(__ANDROID__)
// Starts a child that runs a program with other credentials, which
// posix_spawn can't set, as Darwin's version in CSystemDarwin.h does, with
// its arguments: from a thread whose own credentials it sets first (the
// supplementary groups unless group_count is -1, the group and the user
// unless NULL), with posix_spawn or posix_spawnp. The descriptors are
// unused. Returns 0 and sets *pid, or returns the error number of the step
// that failed. See shims.c and SpawnCredentials.swift.
int csystem_spawn_with_credentials(
    int *pid, const char *path, int search_path,
    const void *file_actions, const void *attributes,
    char *const arguments[], char *const environment[],
    const unsigned int *user, const unsigned int *group,
    int group_count, const unsigned int *groups,
    int descriptor_count, const int *descriptors);

// strtod_l and strtof_l, which glibc and Musl declare only with
// _GNU_SOURCE; see shims.c. `locale` is a locale_t, untyped so that this
// header needn't include <locale.h> (see the top of this file).
extern double csystem_strtod_l(const char *string, char **end, void *locale);
extern float csystem_strtof_l(const char *string, char **end, void *locale);

// <tzfile.h>'s TZDIR and TZDEFAULT, which glibc doesn't install and Musl
// doesn't have: the system's, where it has the header, and otherwise the
// conventional paths; see shims.c.
const char *_system_get_TZDEFAULT(void);
const char *_system_get_TZDIR(void);
#endif // defined(__linux__) && !defined(__ANDROID__)

#ifdef __linux__
// LC_ALL_MASK, which glibc and Bionic define as an OR of their twelve
// categories' masks, which Swift can't import; see shims.c.
int _system_get_LC_ALL_MASK(void);
#endif // __linux__

#if defined(__linux__) && defined(__GLIBC__)
// glibc's allocator extensions, which it declares in <malloc.h>, which its
// Swift module doesn't include. <malloc.h> includes <stdio.h>, and so FILE,
// which this header mustn't declare (see the top of this file), so these
// are shims, and shims.c includes it. `stream` points to a FILE.
extern size_t csystem_malloc_usable_size(const void *pointer);
extern void *csystem_pvalloc(size_t size);
extern int csystem_malloc_trim(size_t pad);
extern int csystem_mallopt(int parameter, int value);
extern int csystem_malloc_info(int options, void *stream);
extern void csystem_malloc_stats(void);

// The fields of glibc's struct mallinfo2, in its order, which
// csystem_get_mallinfo2 fills. Before glibc 2.33, which added mallinfo2,
// they're mallinfo's, whose int fields count modulo 4 GB.
struct csystem_mallinfo2 {
  size_t arena;
  size_t ordblks;
  size_t smblks;
  size_t hblks;
  size_t hblkhd;
  size_t usmblks;
  size_t fsmblks;
  size_t uordblks;
  size_t fordblks;
  size_t keepcost;
};
extern void csystem_get_mallinfo2(struct csystem_mallinfo2 *info);

// mallopt's parameters, which have these values in every glibc; shims.c
// checks them against <malloc.h>.
#define CSYSTEM_M_MXFAST 1
#define CSYSTEM_M_TRIM_THRESHOLD (-1)
#define CSYSTEM_M_TOP_PAD (-2)
#define CSYSTEM_M_MMAP_THRESHOLD (-3)
#define CSYSTEM_M_MMAP_MAX (-4)
#define CSYSTEM_M_CHECK_ACTION (-5)
#define CSYSTEM_M_PERTURB (-6)
#define CSYSTEM_M_ARENA_TEST (-7)
#define CSYSTEM_M_ARENA_MAX (-8)
#endif // defined(__linux__) && defined(__GLIBC__)

#ifdef __ANDROID__
// Zeroes memory with stores the compiler can't remove, as explicit_bzero
// does elsewhere; Bionic has no explicit_bzero.
extern void csystem_explicit_bzero(void *start, size_t count);
#endif // __ANDROID__
