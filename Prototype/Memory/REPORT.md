# malloc lane report

The `malloc` lane (worktree `malloc`, from `system-next` at 9f5b261) wraps
the C allocator family as System API (part A), and prototypes owned,
noncopyable memory buffers on top of it (part B, in `Prototype/Memory/`).
Everything new is `@available(System 199, *)`. Only Darwin was built and
tested; Linux was paused, so its code is gated and listed as unverified.

## Part A: the C allocator as System API

Commits:
- `3d2e6b8` Add Memory, wrapping malloc, calloc, realloc, posix_memalign
  and free, Darwin's zones, and glibc's extensions
- `e959047` Add the malloc sample, for Memory's allocation, zones and
  secure zeroing

Files: `Sources/System/Memory/` (`Memory.swift`, `MemoryAllocator.swift`,
`MemoryBytes.swift`, `MemoryZone.swift`), `Internals/Syscalls+Memory.swift`,
`Internals/Constants+Memory.swift` (glibc only), shims in `CSystemLinux.h`,
`CSystemFreeBSD.h` and `shims.c`, `Sources/Samples/Malloc.swift`, and
`Tests/SystemTests/Memory{,Zone,Mock}Tests.swift`.

### API

`Memory` is a namespace (`enum`), on every Unix platform (not Windows or
WASI). No adopter (swift-nio, swift-foundation, swift-subprocess,
swift-package-manager) declares `Memory`, and nothing in System did.

| API | C | Platforms |
|---|---|---|
| `allocate(byteCount:) throws(Errno) -> UnsafeMutableRawPointer` | `malloc` | all |
| `allocateZeroed(byteCount:)`, `allocateZeroed(count:stride:)` | `calloc` | all |
| `allocate(byteCount:alignment:)` | `posix_memalign` | all |
| `reallocate(_:byteCount:)` | `realloc` | all |
| `free(_:)` | `free` | all |
| `reallocateFreeingOnFailure(_:byteCount:)` | `reallocf` | Darwin, FreeBSD |
| `allocatePageAligned(byteCount:)` | `valloc` | Darwin, Linux, FreeBSD |
| `allocatePages(byteCount:)` | `pvalloc` | glibc |
| `allocateFunction`, `allocateZeroedFunction`, `reallocateFunction`, `freeFunction` | `malloc`, `calloc`, `realloc`, `free` as `@convention(c)` values | all |
| `usableSize(of:) -> Int` | `malloc_size` (Darwin), `malloc_usable_size` | not OpenBSD |
| `goodSize(for:) -> Int` | `malloc_good_size` | Darwin |
| `Memory.Zone` (`rawValue: UnsafeMutablePointer<malloc_zone_t>`) | `malloc_zone_t *` | Darwin |
| `Zone.default`, `Zone.create(name:)`, `Zone(containing:)`, `destroy()` | `malloc_default_zone`, `malloc_create_zone`, `malloc_zone_from_ptr`, `malloc_destroy_zone` | Darwin |
| `zone.allocate(byteCount:)`, `allocateZeroed(…)`, `allocate(byteCount:alignment:)`, `allocatePageAligned(byteCount:)`, `reallocate(_:byteCount:)`, `free(_:)` | `malloc_zone_malloc`, `_calloc`, `_memalign`, `_valloc`, `_realloc`, `_free` | Darwin |
| `zone.name`, `zone.setName(_:)` | `malloc_get_zone_name`, `malloc_set_zone_name` | Darwin |
| `zone.relievePressure(goal:)`, `Zone.relievePressureInAllZones(goal:)` | `malloc_zone_pressure_relief` | Darwin |
| `zone.statistics()`, `Zone.statisticsForAllZones()`, `Zone.Statistics` | `malloc_zone_statistics`, `malloc_statistics_t` | Darwin |
| `trim(padding:) -> Bool` | `malloc_trim` | glibc |
| `setAllocatorOption(_:to:)`, `AllocatorOption` (`.maxFastSize`, `.trimThreshold`, `.topPadding`, `.mappingThreshold`, `.maxMappings`, `.checkAction`, `.perturbByte`, `.arenaTest`, `.maxArenas`) | `mallopt`, `M_*` | glibc |
| `allocatorStatistics() -> AllocatorStatistics` | `mallinfo2` (`mallinfo` before 2.33) | glibc |
| `allocatorReport() throws(Errno) -> String` | `malloc_info`, through `open_memstream` | glibc |
| `printAllocatorStatistics()` | `malloc_stats` | glibc |
| `compare(_:_:) -> Int` (buffers, and spans at macOS 15) | `memcmp` | all |
| `firstIndex(of:in:) -> Int?` (buffers, spans) | `memchr` | all |
| `secureZero(_:)` (buffers, `inout MutableRawSpan`) | `memset_s` (Darwin), `explicit_bzero` | all |
| renamed stubs `aligned_alloc()`, `memalign()`, `mstats()` | | |

### Design calls, and the alternatives rejected

- **Zero is one byte, everywhere.** C lets `malloc(0)` return NULL or a
  block, so NULL couldn't mean failure; `realloc(p, 0)` frees and returns
  NULL on glibc, allocates a minimum block on Darwin (probe), and is
  undefined in C23. Rejected: passing zero through (the result's meaning
  would differ by platform), an `Optional` result for zero, and trapping
  (callers computing sizes would special-case empty).
- **A negative size is a precondition failure**, a caller's bug. Rejected:
  the `ENOMEM` C gives for the huge `size_t` it becomes, which would report
  the bug as running out of memory; `EINVAL`, as `MemoryMapping` does for a
  length of zero or less (there it mirrors `mmap`'s own error).
- **A NULL allocation is `noMemory`, without reading errno.** The only
  other error is a bad alignment, which System checks first; Darwin's zones
  needn't set errno at all (a failed `malloc_zone_memalign` left a stale
  `EOPNOTSUPP` in a probe). `posix_memalign` returns its error, which is
  thrown. Rejected: `Errno.current` as elsewhere, which can be stale; and
  clearing errno before each call (the `checkOptional` pattern), which costs
  a TLS store per allocation to learn nothing new.
- **`allocate(byteCount:alignment:)` is `posix_memalign`**, raising an
  alignment below a pointer's size to it (so every power of two works, as
  with `aligned_alloc`), and throwing `invalidArgument` for others before
  any call. **`aligned_alloc` and `memalign` are renamed stubs**, as `dup`
  and `dup2` are for `duplicate`: they allocate the same blocks, and
  `aligned_alloc` needs macOS 10.15 and Android API level 28, and on Darwin
  rejects a size that isn't a multiple of the alignment (man page and
  probe). Rejected: a second Swift name for the same operation.
- **`valloc` and `pvalloc` are wrappers of their own**
  (`allocatePageAligned`, `allocatePages`): they take no alignment, so
  they're conveniences, and `pvalloc` rounds the size to whole pages.
  Rejected: stubs, like `aligned_alloc`'s.
- **`mstats` is a renamed stub** for `Zone.statisticsForAllZones()`:
  libmalloc computes it from `malloc_zone_statistics(NULL)`, with
  `chunks_free` always 0 and `bytes_free` the difference of two others,
  which a probe confirmed field by field. Rejected: a second statistics
  type with a field that's always zero.
- **`reallocf` is `reallocateFreeingOnFailure`.** Rejected:
  `reallocateOrFree`, which reads as C's old free-on-zero; and a Bool
  parameter on `reallocate`, which would exist only on Darwin and FreeBSD.
  With `throws` the leak `reallocf` prevents in C (`p = realloc(p, n)`)
  doesn't arise, so it's for code that has nothing left to do with a block
  whose resize failed.
- **`free`, not `deallocate`.** It's C's allocator, whose blocks C code
  frees with `free`; `deallocate` reads as the standard library's, whose
  allocator needn't be the same. The namespace's documentation says not to
  mix the two.
- **The shared `system_free` stays unmocked, and a mocked allocation
  allocates for real.** `system_free` (posix-more's, for `realpath`)
  can't gain a hook: the `realpath` mock test requires a trace of exactly
  one call, and `canonicalized()` frees through it. So a mocked success
  performs the real call, as `system_realpath`'s mock returns real memory,
  and callers can use and free it; a forced error returns NULL. Zone
  `free` and `destroy` are hooked, since only this lane calls them.
  Rejected: fake addresses, as `mmap`'s mock returns, which the unmocked
  `free` would crash on. The hook-less `system_free` could move to
  `Syscalls+Memory.swift`; it's posix-more's file, so it stayed.
- **NIO's hooks, and C function values.** `ByteBufferAllocator`'s four
  hooks (`NIOCore/ByteBuffer-core.swift`) are `@convention(c)`: `allocate`
  is `malloc`'s shape, `reallocate` also takes the old size, `deallocate`
  a non-optional pointer, and `copy` returns nothing. So no set of C
  values System vends can fit all four; a context-free closure adapts
  them, as NIO's own default does. System vends `malloc`, `calloc`,
  `realloc` and `free` themselves as `@convention(c)` computed properties
  (`allocateFunction` and so on), with C's rules and zero cost, for such
  hooks and for C libraries that take an allocator's functions (expat,
  libxml2). A static method can't form a C function value, and neither can
  a module-qualified name like `Darwin.free` (both compiler errors, found
  here), so `freeFunction` is a closure. `try? Memory.allocate(byteCount:)`
  in such a closure works too (probe and test). Rejected: non-throwing
  static methods returning optionals beside the throwing ones, which would
  double the API and still need a closure; and properties of NIO's exact
  shapes, which would put NIO's hook signatures in System.
- **Darwin zones are a copyable handle** (`Memory.Zone`, `RawRepresentable`
  over `malloc_zone_t *`), as `FileDescriptor` is for descriptors: the
  default zone must never be destroyed, so it can't be an owner, and
  created zones need the same type. `destroy()` is a precondition failure
  for the default zone. The owned zone is part B's. `create(name:)` passes
  neither of `malloc_create_zone`'s arguments: libmalloc ignores the size,
  and the flags are its own. A NULL zone is `noMemory`, since the call
  documents no errno.
- **Statistics are Swift values**, not C structs: `Zone.Statistics` and
  glibc's `AllocatorStatistics` copy the fields out with Swift names
  (`bytesReserved` for `size_allocated`, "reserved in memory"). For glibc
  this is also what keeps MemberImportVisibility out of it: `struct
  mallinfo2` is declared only in `<malloc.h>`, which glibc's Swift module
  doesn't include, so its members would belong to CSystem. glibc's unused
  `usmblks` is left out.
- **glibc's extensions are CSystem shims** that take `FILE *` as `void *`,
  since `<malloc.h>` includes `<stdio.h>`, whose types a CSystem header
  mustn't declare (the linux-build lane's rule). The `M_*` values are
  CSystem macros that `shims.c` checks with `_Static_assert`s. `mallopt`
  reports failure as 0 with no errno, so `setAllocatorOption` throws
  `invalidArgument` then. `allocatorReport()` returns `malloc_info`'s XML
  as a `String`, through `open_memstream`. Rejected: writing to a
  `FileDescriptor`, which needs `fdopen` and an owner for the `FILE`.
- **`usableSize(of:)` is one name for `malloc_size` and
  `malloc_usable_size`**, which mean the same; the documentation says that
  Darwin answers zero for memory no zone allocated, where asking elsewhere
  is undefined. Rejected: a name per platform, for a single concept.
- **`compare` orders buffers of different counts**: `memcmp` over the
  bytes both have, then the shorter first, returning -1, 0 or 1. Rejected:
  a pointer-and-count form (the count mismatch is the classic overread),
  and returning `memcmp`'s own magnitude, which means nothing.
  `firstIndex(of:in:)` returns an offset rather than a pointer.
  `secureZero` is `memset_s` on Darwin, whose module does declare it (a
  probe; the header guards it with `__STDC_WANT_LIB_EXT1__`), and
  `explicit_bzero` elsewhere. Each has a buffer form and a span form.
- Not added: typed allocation (`malloc_type_*`, whose type IDs the C
  compiler derives), `malloc_zone_batch_malloc`/`batch_free`, purgeable
  zones, `malloc_zone_malloc_with_options` (macOS 26), `memmem`,
  `memrchr`, `timingsafe_bcmp`, and `reallocarray`.

### Tests

- `MemoryTests` and `MemoryZoneTests` (swift-testing, real calls): 28
  tests. Zone statistics come from zones of their own, so the parallel
  tests can't change them, and counts are relative to a baseline, since a
  zone's name is a block in it. `reallocateFreeingOnFailure`'s freeing is
  checked through its zone's block count.
- `MemoryMockTests` (XCTest): 5 tests of the calls' arguments (zero as
  one, raised alignments), their errors, and the zone calls.
- Totals after part A: XCTest 439 tests, 4 skipped, 0 failures;
  swift-testing 321 tests in 43 suites, all passed (from 293 in 40).
- The explicit-availability check (`-require-explicit-availability=warn`)
  finds nothing in the new files, and the ABI-stable build fails only in
  its known files.

### Unverified

Nothing off Darwin was built. By platform:
- glibc: every shim (`csystem_malloc_usable_size`, `_pvalloc`,
  `_malloc_trim`, `_mallopt`, `_malloc_info`, `_malloc_stats`,
  `_get_mallinfo2`, the `mallinfo` fallback before 2.33, and the
  `_Static_assert`s), `open_memstream`'s import, `valloc` and
  `explicit_bzero` through Glibc's module, and `Constants+Memory.swift`.
- Musl: `malloc_usable_size` through Musl's module (its `void *`
  parameter), `valloc`, `explicit_bzero`.
- Android: `malloc_usable_size` from Bionic's `<malloc.h>`, and the
  `csystem_explicit_bzero` shim (memset and a compiler barrier; Bionic has
  no `explicit_bzero`, from memory of its headers).
- FreeBSD: the `<malloc_np.h>` shim, `reallocf`, `valloc`,
  `explicit_bzero`. OpenBSD: `explicit_bzero`, and the absence of
  `usableSize`.
- The Linux sample branch (glibc statistics and trim) and the Linux tests
  (`pagesAreWholePages`).

## Part B: owned buffers (a prototype)

Commit: `ae1a5d3` Prototype owned malloc buffers: Memory.Buffer, an owned
zone, and a reusable I/O vector pool.

Files: `Prototype/Memory/` (`README.md`, the design record; `Sources/`, a
module of its own, `MemoryPrototype`; `Checks/`, `Policies/`, `Verify/`,
`Bench/`; and `run.sh`, which builds and runs them under
`$TMPDIR/malloc-prototype`). Nothing moved into `Sources/`.

### What it is

| Type | What |
|---|---|
| `Memory.Buffer<Element: BitwiseCopyable>: ~Copyable` | owns C's memory and frees it in its deinit: `count` initialized elements in `capacity`; `init(capacity:)`, `init(capacity:alignment:)`, `init(repeating:count:)` (`calloc` for zeros), zone forms; `append`, `reserveCapacity`, `shrinkToFit` (`realloc`); `span`, `mutableSpan`, `bytes`, `mutableBytes` (bytes only); `withUnusedCapacity` (`OutputSpan`), `withUnusedByteCapacity` (`OutputRawSpan`); `init(unsafeTaking:count:capacity:)`, `relinquish()`, `free()` |
| `Memory.OwnedZone: ~Copyable` (Darwin) | a zone destroyed in its deinit or `destroy()` |
| `Memory.ZoneBuffer<Element>: ~Copyable, ~Escapable` (Darwin) | a buffer in an owned zone, whose lifetime borrows the zone's |
| `IOVectorPool: ~Copyable` | NIO's pattern: vectors allocated once, `write(_:to:)` and `writeAll(_:to:)` over `UnsafeRawBufferPointer`s, capped at `IOV_MAX` vectors and 32 bits of bytes, resuming inside a buffer |

### Design calls, and the alternatives rejected

The README has each in full; in short:
- An initialized prefix within the capacity, since `malloc`'s memory starts
  uninitialized and spans may cover only initialized memory. Rejected: a
  wholly initialized block (`MemoryMapping` exactly), which must fill every
  byte first; and spans over uninitialized memory.
- Filling (output spans, throwing the closure's error) separate from
  growing (`reserveCapacity`, throwing `Errno`). Rejected: one call that
  grows and fills, with an error that's either.
- One generic type for typed and raw (`Buffer<UInt8>`), of
  `BitwiseCopyable` elements, which `realloc` can move. Rejected: two
  types; non-trivial elements; `mutableBytes` for any element type.
- Zeroed creation as `init(repeating:count:)`, `calloc` when the value's
  bytes are zeros. Rejected: `init(zeroedCount:)`, since zero bits isn't a
  valid value of every `BitwiseCopyable` type.
- Alignment kept across growth by allocating anew, since `realloc` doesn't
  keep it.
- Doubling growth, rounded to `goodSize` on Darwin. Rejected: using
  `usableSize`'s slack, which sanitizers report.
- Pointers only in closures, since the buffer moves. Rejected:
  `MemoryMapping`'s `unsafeBuffer` property.
- Zones two ways: through part A's handle (which can outlive the zone, M5)
  and through `OwnedZone` and `ZoneBuffer`, whose dependency makes the
  compiler stop it (M2, M3). `ZoneBuffer` wraps `Buffer` with an empty
  deinit, so that the inner buffer can't be moved out. Rejected: exposing
  the inner buffer, and a closure-scoped zone.
- Decision 54 stays open. The default frees in the deinit, which has no
  error to drop; must-free and checked (the must-close and `EBADF`
  analogs) are built with `-D` and compared in a table.
- The pool allocates once and gathers without allocating (a first version
  copied the caller's collection per write, which a review of it caught).
  It fills iovecs through C's `iov_base` and `iov_len`, with a C import;
  the syscalls-4 lane's `CInterop.IOVec(base:length:)`, `.base` and
  `.length` (its `338401f`) aren't in system-next.

### Findings

- **`realloc` growth is 2.4 times faster than allocate-and-copy to 1 MiB,
  and 2 to 2.5 times slower from 16 MiB,** on macOS 26.3, doubling a
  buffer whose bytes are all written. Darwin's own `realloc`, measured
  without `Memory.Buffer`, gives the same ratios. Numbers shared a process
  badly, since the allocator reuses freed large blocks, so each runs alone.
- **Deinit policies**: must-free traps on every ordinary scope end and
  error path, for nothing, since freeing can't fail; checked catches a
  large adopted block that something else freed, before libmalloc does,
  but not a small one. **macOS 26 didn't detect a small block's double
  free** at all; a large one's, it did ("pointer being freed was not
  allocated", written to stderr only with `MallocDebugReport=stderr` when
  it isn't a terminal).
- **Swift 6.2**: a `let` owner can't be consumed after a non-Escapable
  value borrowed it, even once the value is gone (M4a, as with
  `MemoryMapping`'s spans); with a `var` owner, a dependent value used in
  an autoclosure, such as `&&`'s right side, is reported as escaping (M4c);
  a function that borrows the owner avoids both (M4d). A consuming call
  can't be in a `defer` (`OutputSpan.finalize`). `@_alignment` stops at 16.
  In an extension of `Memory.Buffer`, `Memory._Allocator` isn't found
  unqualified.
- Part A's API held up: the prototype used `allocate`, `allocateZeroed`,
  `reallocate`, `free`, `usableSize`, `goodSize`, the zone calls and the C
  function values as they are, and needed nothing new from part A.

### Tests

- `run.sh`: 15 checks pass; all 10 Verify snippets behave as their headers
  expect (7 fail to compile, 3 compile); the policy table and the
  benchmark are in the README.
- Package totals after part B, which changed nothing in `Sources/`: XCTest
  439 tests, 4 skipped, 0 failures; swift-testing 321 tests in 43 suites,
  all passed.

### Unverified

- Linux: the prototype should build there without the zone types, but
  nothing built it, and the `realloc` crossover is Darwin's; glibc can
  `mremap` large blocks.
- An imported C element type more aligned than `malloc`, which the
  aligned path would serve.
- The checked policy exists only on Darwin, where `malloc_size` answers
  for any pointer.

### What could move into Sources

Nothing moved. `Memory.Buffer`'s core is the candidate: sound as far as
the checks and the move checker go, but its deinit policy is decision
54's, its growth strategy wants Linux's `realloc` measured, and its name
and overlap with `Array`'s API want review. `OwnedZone`/`ZoneBuffer` wait
on the 6.2 limits (M4); `IOVectorPool` is a client's policy over part A's
`write(vectors:)`.

The lane stops here, as asked.
