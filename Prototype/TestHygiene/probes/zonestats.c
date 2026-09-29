// Does another thread's pressure relief, or anything else, change a private
// zone's block count while this thread allocates and reallocf's in it?
#include <malloc/malloc.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static atomic_int stop;
static int mode;

static void *relieve(void *arg) {
  while (!atomic_load(&stop)) {
    if (mode == 1) malloc_zone_pressure_relief(NULL, 1);
    if (mode == 2) { malloc_statistics_t s; malloc_zone_statistics(NULL, &s); }
    if (mode == 3) { malloc_zone_t *z = malloc_create_zone(0, 0); void *p = malloc_zone_malloc(z, 64); malloc_zone_free(z, p); malloc_destroy_zone(z); }
  }
  return NULL;
}

static unsigned inuse(malloc_zone_t *z) { malloc_statistics_t s; malloc_zone_statistics(z, &s); return s.blocks_in_use; }

int main(int argc, char **argv) {
  mode = argc > 1 ? atoi(argv[1]) : 0;
  int threads = argc > 2 ? atoi(argv[2]) : 1;
  size_t size = argc > 3 ? strtoul(argv[3], NULL, 0) : 64;
  pthread_t t[16];
  if (mode) for (int i = 0; i < threads; i++) pthread_create(&t[i], NULL, relieve, NULL);
  int bad1 = 0, bad2 = 0, n = 20000;
  for (int i = 0; i < n; i++) {
    malloc_zone_t *z = malloc_create_zone(0, 0);
    malloc_set_zone_name(z, "reallocf test");
    unsigned base = inuse(z);
    void *b = malloc_zone_malloc(z, size);
    b = reallocf(b, size * 2);
    if (inuse(z) != base + 1) bad1++;
    void *r = reallocf(b, SIZE_MAX);
    if (r) abort();
    if (inuse(z) != base) bad2++;
    malloc_destroy_zone(z);
  }
  atomic_store(&stop, 1);
  if (mode) for (int i = 0; i < threads; i++) pthread_join(t[i], NULL);
  printf("mode %d threads %d size %zu: %d/%d wrong after realloc, %d/%d wrong after the failed reallocf\n", mode, threads, size, bad1, n, bad2, n);
}
