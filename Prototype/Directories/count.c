// A dyld interposer that counts the file system calls a walk makes,
// including those that libc's fts makes, and prints the counts at exit.
// Usage: DYLD_INSERT_LIBRARIES=count.dylib walk MODE ROOT
#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <unistd.h>
#define DYLD_INTERPOSE(_replacement,_replacee) \
  __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
  __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };
static long n_bulk, n_fstatat, n_lstat, n_stat, n_fstat, n_open, n_openat, n_readdir;
static int my_getattrlistbulk(int fd, void *a, void *b, size_t c, uint64_t o) { n_bulk++; return getattrlistbulk(fd, a, b, c, o); }
static int my_fstatat(int fd, const char *p, struct stat *s, int f) { n_fstatat++; return fstatat(fd, p, s, f); }
static int my_lstat(const char *p, struct stat *s) { n_lstat++; return lstat(p, s); }
static int my_stat(const char *p, struct stat *s) { n_stat++; return stat(p, s); }
static int my_fstat(int fd, struct stat *s) { n_fstat++; return fstat(fd, s); }
static int my_open(const char *p, int f, ...) { va_list ap; va_start(ap, f); int m = va_arg(ap, int); va_end(ap); n_open++; return open(p, f, m); }
static int my_openat(int fd, const char *p, int f, ...) { va_list ap; va_start(ap, f); int m = va_arg(ap, int); va_end(ap); n_openat++; return openat(fd, p, f, m); }
static struct dirent *my_readdir(DIR *d) { n_readdir++; return readdir(d); }
DYLD_INTERPOSE(my_getattrlistbulk, getattrlistbulk)
DYLD_INTERPOSE(my_fstatat, fstatat)
DYLD_INTERPOSE(my_lstat, lstat)
DYLD_INTERPOSE(my_stat, stat)
DYLD_INTERPOSE(my_fstat, fstat)
DYLD_INTERPOSE(my_open, open)
DYLD_INTERPOSE(my_openat, openat)
DYLD_INTERPOSE(my_readdir, readdir)
__attribute__((destructor)) static void done(void) {
  fprintf(stderr, "  getattrlistbulk %ld, fstatat %ld, lstat %ld, stat %ld, fstat %ld, open %ld, openat %ld, readdir %ld\n",
          n_bulk, n_fstatat, n_lstat, n_stat, n_fstat, n_open, n_openat, n_readdir);
}
