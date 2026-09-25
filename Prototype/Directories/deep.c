// Makes a chain of directories, DEPTH deep, each named NAME, one file at the
// bottom, relative to descriptors, so that no path is ever resolved whole.
// Usage: deep DEPTH NAME
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
int main(int argc, char **argv) {
  int depth = atoi(argv[1]);
  const char *name = argv[2];
  mkdir("deep", 0755);
  int fd = open("deep", O_RDONLY | O_DIRECTORY);
  for (int i = 0; i < depth; i++) {
    if (mkdirat(fd, name, 0755)) { perror("mkdirat"); return 1; }
    int child = openat(fd, name, O_RDONLY | O_DIRECTORY);
    if (child < 0) { perror("openat"); return 1; }
    close(fd);
    fd = child;
  }
  close(openat(fd, "bottom", O_CREAT | O_WRONLY, 0644));
  printf("made deep/ with %d levels of %s: the bottom file's path is %zu bytes\n",
         depth, name, 5 + depth * (strlen(name) + 1) + 7);
  return 0;
}
