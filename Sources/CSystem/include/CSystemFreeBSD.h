/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if defined(__FreeBSD__)

#include <fcntl.h>

#ifdef O_CLOFORK
#define COMPATIBILITY_O_CLOFORK O_CLOFORK
#else
#define COMPATIBILITY_O_CLOFORK 0
#endif

// malloc_usable_size, which FreeBSD declares in <malloc_np.h>, which its
// Swift module doesn't include; see shims.c.
extern size_t csystem_malloc_usable_size(const void *pointer);

// The locale calls that System wraps provisionally whose declarations
// FreeBSD's <stdlib.h> and <strings.h> make only after <xlocale.h>, as
// Darwin's do; see shims.c. `locale` is a locale_t: NULL is the POSIX
// locale, and LC_GLOBAL_LOCALE the global one.
extern double csystem_strtod_l(const char *string, char **end, void *locale);
extern float csystem_strtof_l(const char *string, char **end, void *locale);
extern int csystem_strncasecmp_l(const char *a, const char *b, size_t count, void *locale);
extern char *csystem_nl_langinfo_l(int item, void *locale);

// sysctl's KERN_PROC_PATHNAME for a process, from <sys/sysctl.h>, which
// FreeBSD's Swift module doesn't include; see shims.c. `size` is the
// buffer's size in, and the path's, with its terminator, out.
extern int csystem_kern_proc_pathname(int pid, char *buffer, size_t *size);

#endif // defined(__FreeBSD__)
