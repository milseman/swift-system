// Walks a tree with fts(3), or with a walker built on openat, fdopendir and
// readdir as DirectoryWalk is, and prints what it found and how long it took.
//
// Usage: walk MODE ROOT, where MODE is one of
//   fts-nostat   FTS_PHYSICAL | FTS_NOCHDIR | FTS_NOSTAT
//   fts-stat     FTS_PHYSICAL | FTS_NOCHDIR, as NIO's recursive listing uses
//   fts-chdir    FTS_PHYSICAL | FTS_NOSTAT, which changes the working directory
//   native       openat and fdopendir for each directory, types from d_type
//   native-stat  the same, with fstatat for each entry
//
// The native walker counts the root as an entry and a directory, as fts's
// level 0 does. Errors are counted, and fts's are printed.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fts.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static long entries, dirs, errors, maxdepth;
static long long bytes;

static void walk_fts(const char *root, int options) {
  char *paths[] = {(char *)root, NULL};
  FTS *fts = fts_open(paths, options, NULL);
  if (!fts) { perror("fts_open"); exit(1); }
  FTSENT *e;
  errno = 0;
  while ((e = fts_read(fts))) {
    switch (e->fts_info) {
    case FTS_DP: continue;
    case FTS_D: dirs++; break;
    case FTS_DNR: case FTS_ERR: case FTS_NS:
      if (!errors) fprintf(stderr, "  fts reports an error at level %ld: %s\n", (long)e->fts_level, strerror(e->fts_errno));
      errors++;
      break;
    default: break;
    }
    if (e->fts_level > maxdepth) maxdepth = e->fts_level;
    if (!(options & FTS_NOSTAT) && e->fts_statp && e->fts_info != FTS_NS) bytes += e->fts_statp->st_size;
    entries++;
  }
  if (errno) perror("fts_read");
  fts_close(fts);
}

static void walk_native(int parent, const char *name, int depth, int withStat) {
  int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (fd < 0) { errors++; return; }
  DIR *d = fdopendir(fd);
  if (!d) { close(fd); errors++; return; }
  if (depth > maxdepth) maxdepth = depth;
  struct dirent *e;
  for (;;) {
    errno = 0;
    e = readdir(d);
    if (!e) { if (errno) errors++; break; }
    if (e->d_name[0] == '.' && (e->d_name[1] == 0 || (e->d_name[1] == '.' && e->d_name[2] == 0))) continue;
    entries++;
    unsigned char type = e->d_type;
    if (withStat || type == DT_UNKNOWN) {
      struct stat st;
      if (fstatat(fd, e->d_name, &st, AT_SYMLINK_NOFOLLOW) == 0) {
        bytes += st.st_size;
        if (S_ISDIR(st.st_mode)) type = DT_DIR;
      } else errors++;
    }
    if (type == DT_DIR) { dirs++; walk_native(fd, e->d_name, depth + 1, withStat); }
  }
  closedir(d);
}

int main(int argc, char **argv) {
  if (argc != 3) { fprintf(stderr, "usage: walk MODE ROOT\n"); return 2; }
  const char *mode = argv[1], *root = argv[2];
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  if (!strcmp(mode, "fts-nostat")) walk_fts(root, FTS_PHYSICAL | FTS_NOCHDIR | FTS_NOSTAT);
  else if (!strcmp(mode, "fts-stat")) walk_fts(root, FTS_PHYSICAL | FTS_NOCHDIR);
  else if (!strcmp(mode, "fts-chdir")) walk_fts(root, FTS_PHYSICAL | FTS_NOSTAT);
  else if (!strcmp(mode, "native")) { dirs++; entries++; walk_native(AT_FDCWD, root, 1, 0); }
  else if (!strcmp(mode, "native-stat")) { dirs++; entries++; walk_native(AT_FDCWD, root, 1, 1); }
  else { fprintf(stderr, "bad mode\n"); return 2; }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
  printf("%-12s entries %ld dirs %ld errors %ld maxdepth %ld bytes %lld  %.1f ms\n",
         mode, entries, dirs, errors, maxdepth, bytes, ms);
  return 0;
}
