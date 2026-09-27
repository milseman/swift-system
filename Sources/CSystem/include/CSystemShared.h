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
// The process's environ array. Darwin's is _NSGetEnviron's, since a library
// can't link to environ there, and not every other C library declares
// environ without feature macros.
extern char **csystem_environ(void);
#endif
