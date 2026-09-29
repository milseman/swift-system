// Is malloc_zone_from_ptr (and free of a private zone's block) safe while
// another thread creates and destroys zones? Mode 1: lookups of a stack
// address; mode 2: pressure relief of all zones; mode 3: allocate and free
// in a zone of this thread's own.
#include <malloc/malloc.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>

static atomic_int stop;
static void *churn(void *arg) {
  while (!atomic_load(&stop)) {
    malloc_zone_t *z = malloc_create_zone(0, 0);
    malloc_set_zone_name(z, "churn");
    void *p = malloc_zone_malloc(z, 64);
    malloc_zone_free(z, p);
    malloc_destroy_zone(z);
  }
  return NULL;
}

int main(int argc, char **argv) {
  int mode = atoi(argv[1]);
  pthread_t t[4];
  for (int i = 0; i < 2; i++) pthread_create(&t[i], NULL, churn, NULL);
  int local = 0;
  long found = 0;
  malloc_zone_t *mine = malloc_create_zone(0, 0);
  for (int i = 0; i < 2000000; i++) {
    if (mode == 1) found += malloc_zone_from_ptr(&local) != NULL;
    if (mode == 2) malloc_zone_pressure_relief(NULL, 1);
    if (mode == 3) { void *p = malloc_zone_malloc(mine, 64); free(p); }
  }
  atomic_store(&stop, 1);
  for (int i = 0; i < 2; i++) pthread_join(t[i], NULL);
  printf("mode %d survived (%ld found)\n", mode, found);
}
