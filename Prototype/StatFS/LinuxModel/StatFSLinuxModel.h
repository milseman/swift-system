/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The Linux declarations that StatFS's Swift code calls and Darwin lacks,
// as CSystemLinux.h declares them. The rest, statvfs and fstatvfs and the
// statvfs struct, Darwin's C library has with the same names.

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
uint64_t _system_get_ST_WRITE(void);
uint64_t _system_get_ST_APPEND(void);
uint64_t _system_get_ST_IMMUTABLE(void);

int csystem_statfs_type(const char *path, unsigned long *type);
int csystem_fstatfs_type(int fd, unsigned long *type);
