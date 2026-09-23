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
#define _GNU_SOURCE
#include <CSystemLinux.h>
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
