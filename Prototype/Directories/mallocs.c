// A dyld interposer that counts heap allocations, for bench.swift to read
// through dlsym. Usage: DYLD_INSERT_LIBRARIES=mallocs.dylib bench MODE PATH
#include <malloc/malloc.h>
#include <stdlib.h>
#define DYLD_INTERPOSE(_replacement,_replacee) \
  __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
  __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };
long directory_evidence_mallocs = 0;
// One allocator entry point can call another, such as malloc_type_malloc
// calling malloc_type_zone_malloc; count only the outermost call.
static int depth = 0;  // Not thread-local: TLS setup calls malloc. The benchmarks are single-threaded.
#define COUNTED(call) ({ if (depth++ == 0) directory_evidence_mallocs++; void *r = (call); depth--; r; })
static void *my_malloc(size_t n) { return COUNTED(malloc(n)); }
static void *my_calloc(size_t c, size_t n) { return COUNTED(calloc(c, n)); }
static void *my_realloc(void *p, size_t n) { return COUNTED(realloc(p, n)); }
static void *my_type_malloc(size_t n, malloc_type_id_t t) { return COUNTED(malloc_type_malloc(n, t)); }
static void *my_type_calloc(size_t c, size_t n, malloc_type_id_t t) { return COUNTED(malloc_type_calloc(c, n, t)); }
static void *my_type_realloc(void *p, size_t n, malloc_type_id_t t) { return COUNTED(malloc_type_realloc(p, n, t)); }
static void *my_zone_malloc(malloc_zone_t *z, size_t n) { return COUNTED(malloc_zone_malloc(z, n)); }
static void *my_type_zone_malloc(malloc_zone_t *z, size_t n, malloc_type_id_t t) { return COUNTED(malloc_type_zone_malloc(z, n, t)); }
DYLD_INTERPOSE(my_malloc, malloc)
DYLD_INTERPOSE(my_calloc, calloc)
DYLD_INTERPOSE(my_realloc, realloc)
DYLD_INTERPOSE(my_type_malloc, malloc_type_malloc)
DYLD_INTERPOSE(my_type_calloc, malloc_type_calloc)
DYLD_INTERPOSE(my_type_realloc, malloc_type_realloc)
DYLD_INTERPOSE(my_zone_malloc, malloc_zone_malloc)
DYLD_INTERPOSE(my_type_zone_malloc, malloc_type_zone_malloc)
