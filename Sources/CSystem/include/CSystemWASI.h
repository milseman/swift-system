/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 - 2025 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#pragma once

#if __wasi__

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h> // For NAME_MAX
#include <time.h>

// wasi-libc ships <sys/statvfs.h>, but the Swift WASILibc module does not
// surface it. Re-export them through CSystem here.
#include <sys/statvfs.h>

// wasi-libc defines the following constants in a way that Clang Importer can't
// understand, so we need to expose them manually.
static inline int32_t _getConst_O_ACCMODE(void) { return O_ACCMODE; }
static inline int32_t _getConst_O_APPEND(void) { return O_APPEND; }
static inline int32_t _getConst_O_CREAT(void) { return O_CREAT; }
static inline int32_t _getConst_O_DIRECTORY(void) { return O_DIRECTORY; }
static inline int32_t _getConst_O_EXCL(void) { return O_EXCL; }
static inline int32_t _getConst_O_NONBLOCK(void) { return O_NONBLOCK; }
static inline int32_t _getConst_O_TRUNC(void) { return O_TRUNC; }
static inline int32_t _getConst_O_WRONLY(void) { return O_WRONLY; }

static inline int32_t _getConst_EWOULDBLOCK(void) { return EWOULDBLOCK; }
static inline int32_t _getConst_EOPNOTSUPP(void) { return EOPNOTSUPP; }

static inline int32_t _getConst_POSIX_FADV_NORMAL(void) { return POSIX_FADV_NORMAL; }
static inline int32_t _getConst_POSIX_FADV_SEQUENTIAL(void) { return POSIX_FADV_SEQUENTIAL; }
static inline int32_t _getConst_POSIX_FADV_RANDOM(void) { return POSIX_FADV_RANDOM; }
static inline int32_t _getConst_POSIX_FADV_WILLNEED(void) { return POSIX_FADV_WILLNEED; }
static inline int32_t _getConst_POSIX_FADV_DONTNEED(void) { return POSIX_FADV_DONTNEED; }
static inline int32_t _getConst_POSIX_FADV_NOREUSE(void) { return POSIX_FADV_NOREUSE; }

static inline uint8_t _getConst_DT_DIR(void) { return DT_DIR; }
static inline uint8_t _getConst_DT_UNKNOWN(void) { return DT_UNKNOWN; }
static inline uint8_t _getConst_DT_FIFO(void) { return DT_FIFO; }
static inline uint8_t _getConst_DT_CHR(void) { return DT_CHR; }
static inline uint8_t _getConst_DT_BLK(void) { return DT_BLK; }
static inline uint8_t _getConst_DT_REG(void) { return DT_REG; }
static inline uint8_t _getConst_DT_LNK(void) { return DT_LNK; }
static inline uint8_t _getConst_DT_SOCK(void) { return DT_SOCK; }

// The clocks are the addresses of constants, which Swift can't import.
static inline clockid_t _getConst_CLOCK_REALTIME(void) { return CLOCK_REALTIME; }
static inline clockid_t _getConst_CLOCK_MONOTONIC(void) { return CLOCK_MONOTONIC; }

// Modified dirent struct that can be imported to Swift
struct _system_dirent {
  ino_t d_ino;
  unsigned char d_type;
  // char d_name[] cannot be imported to Swift
  char d_name[NAME_MAX + 1];
};

// malloc_usable_size, which wasi-libc declares in <malloc.h>, which its
// Swift module doesn't include; see shims.c.
extern size_t csystem_malloc_usable_size(const void *pointer);

// Convert WASI dirent with d_name[] to _system_dirent
static inline
struct _system_dirent *
_system_dirent_from_wasi_dirent(const struct dirent *wasi_dirent) {

  // Match readdir behavior and use thread-local storage for the converted dirent
  static __thread struct _system_dirent _converted_dirent;

  if (wasi_dirent == NULL) {
    return NULL;
  }

  memset(&_converted_dirent, 0, sizeof(struct _system_dirent));

  _converted_dirent.d_ino = wasi_dirent->d_ino;
  _converted_dirent.d_type = wasi_dirent->d_type;

  strncpy(_converted_dirent.d_name, wasi_dirent->d_name, NAME_MAX);
  _converted_dirent.d_name[NAME_MAX] = '\0';

  return &_converted_dirent;
}

#endif
