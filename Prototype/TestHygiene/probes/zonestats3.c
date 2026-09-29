// In the cases where a private zone's count doesn't go up by one for an
// allocation: what are the counts, and does the zone still own the block?
// After a free, does any zone claim the block?
#include <malloc/malloc.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

static unsigned inuse(malloc_zone_t *z) { malloc_statistics_t s; malloc_zone_statistics(z, &s); return s.blocks_in_use; }
static atomic_int stop;
static void *relieve(void *arg) { while (!atomic_load(&stop)) malloc_zone_pressure_relief(NULL, 1); return NULL; }

int main(int argc, char **argv) {
  size_t size = argc > 1 ? strtoul(argv[1], NULL, 0) : 64;
  int relievers = argc > 2 ? atoi(argv[2]) : 0;
  pthread_t t[8];
  for (int i = 0; i < relievers; i++) pthread_create(&t[i], NULL, relieve, NULL);
  int n = 20000, shown = 0, claimedAfterFree = 0, notOwned = 0;
  for (int i = 0; i < n; i++) {
    malloc_zone_t *z = malloc_create_zone(0, 0);
    malloc_set_zone_name(z, "reallocf test");
    unsigned base = inuse(z);
    void *b = malloc_zone_malloc(z, size);
    unsigned after = inuse(z);
    unsigned again = inuse(z);
    if (malloc_zone_from_ptr(b) != z) notOwned++;
    if (after != base + 1 && shown < 5) { printf("  base %u, after %u, again %u\n", base, after, again); shown++; }
    void *r = reallocf(b, SIZE_MAX);
    if (r) abort();
    if (malloc_zone_from_ptr(b) != NULL) claimedAfterFree++;
    malloc_destroy_zone(z);
  }
  atomic_store(&stop, 1);
  for (int i = 0; i < relievers; i++) pthread_join(t[i], NULL);
  printf("size %zu relievers %d: %d not owned by the zone, %d claimed after the failed reallocf\n", size, relievers, notOwned, claimedAfterFree);
}
