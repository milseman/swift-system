// Swaps a directory for a symbolic link while a walk is paused on it, as a
// concurrent process could, and reports whether the walk then removes a file
// outside the tree, as `rm -r` would. MODE: fts-nochdir | fts-chdir | native
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fts.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void setup(void) {
  system("rm -rf scratch && mkdir -p scratch/tree/a/b scratch/outside && "
         "touch scratch/tree/a/b/inside scratch/outside/precious");
}
static void swap(void) {
  // The directory is renamed away and a link to `outside` put in its place.
  rename("scratch/tree/a/b", "scratch/tree/a/b.moved");
  symlink("../../outside", "scratch/tree/a/b");
  printf("  swapped scratch/tree/a/b for a link to scratch/outside\n");
}
static void report(void) {
  struct stat st;
  printf("  scratch/outside/precious: %s\n",
         stat("scratch/outside/precious", &st) == 0 ? "still there" : "REMOVED");
}

static void fts_rm(int options) {
  char *paths[] = {"scratch/tree", NULL};
  FTS *fts = fts_open(paths, options, NULL);
  FTSENT *e;
  while ((e = fts_read(fts))) {
    if (e->fts_info == FTS_D && !strcmp(e->fts_name, "b")) swap();
    switch (e->fts_info) {
    case FTS_D: break;
    case FTS_DP: if (rmdir(e->fts_accpath)) printf("  rmdir %s: %s\n", e->fts_path, strerror(errno)); break;
    case FTS_DNR: case FTS_ERR: case FTS_NS:
      printf("  %s: fts_info %d, %s\n", e->fts_path, e->fts_info, strerror(e->fts_errno)); break;
    default:
      printf("  unlink %s\n", e->fts_path);
      unlink(e->fts_accpath);
    }
  }
  fts_close(fts);
}

static void native_rm(int parent, const char *name, const char *path) {
  int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (fd < 0) { printf("  open %s: %s\n", path, strerror(errno)); return; }
  DIR *d = fdopendir(fd);
  struct dirent *e;
  while ((errno = 0, e = readdir(d))) {
    if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
    char child[1024];
    snprintf(child, sizeof child, "%s/%s", path, e->d_name);
    if (e->d_type == DT_DIR) {
      if (!strcmp(e->d_name, "b")) swap();
      native_rm(fd, e->d_name, child);
      if (unlinkat(fd, e->d_name, AT_REMOVEDIR)) printf("  rmdir %s: %s\n", child, strerror(errno));
    } else {
      printf("  unlink %s\n", child);
      unlinkat(fd, e->d_name, 0);
    }
  }
  closedir(d);
}

int main(int argc, char **argv) {
  setup();
  printf("%s:\n", argv[1]);
  if (!strcmp(argv[1], "fts-nochdir")) fts_rm(FTS_PHYSICAL | FTS_NOCHDIR);
  else if (!strcmp(argv[1], "fts-chdir")) fts_rm(FTS_PHYSICAL);
  else native_rm(AT_FDCWD, "scratch/tree", "scratch/tree");
  report();
  return 0;
}
