# Owned memory buffers (a prototype)

Noncopyable owners of the C allocator's memory, built on part A's `Memory`
API: a buffer whose deinit frees it, which grows through `realloc` and
vends spans, with typed and raw access, zeroed and aligned creation, and
zones on Darwin; an owned zone whose buffers can't outlive it; and, as the
worked example, a reusable pool of I/O vectors for `writev`, NIO's pattern.

**Status: speculative, and not API.** Nothing here is in `Sources/`; the
last section says what could move and what holds each part back. It's all
`@available(System 199, *)`, and was built and run only on macOS 26.3 with
Swift 6.2.

## Files

| file | what |
|---|---|
| `Sources/Buffer.swift` | `Memory.Buffer<Element: BitwiseCopyable>`: the owned buffer |
| `Sources/Allocator.swift` | `Memory._Allocator`, a buffer's choice of calls (default, aligned, zone), and the deinit policies |
| `Sources/Zone.swift` | `Memory.OwnedZone` and `Memory.ZoneBuffer` (Darwin) |
| `Sources/IOVectorPool.swift` | `IOVectorPool`, the worked example |
| `Checks/main.swift` | the prototype's checks, run as a program |
| `Policies/main.swift` | deinit-policy scenarios, after `Prototype/CloseErrors` |
| `Verify/M*.swift` | compiler checks: misuse that mustn't compile, and 6.2 limits |
| `Bench/main.swift` | growth through `realloc`, against allocating anew and copying |
| `run.sh` | builds and runs each of these under `$TMPDIR/malloc-prototype` |

`Sources/` builds as a module of its own, `MemoryPrototype`, a client of
the built SystemPackage, so the checks exercise it across a module
boundary, as a client would: `@frozen`, `@usableFromInline` and the
lifetime annotations included.

```sh
swift build                                      # for checks, policies, verify
swift build -c release --target SystemPackage    # for bench
Prototype/Memory/run.sh                          # checks, policies, verify
Prototype/Memory/run.sh bench
```

## The types

```swift
extension Memory {
  struct Buffer<Element: BitwiseCopyable>: ~Copyable      // Sendable when Element is
  struct OwnedZone: ~Copyable                              // Darwin
  struct ZoneBuffer<Element: BitwiseCopyable>: ~Copyable, ~Escapable  // Darwin
}
struct IOVectorPool: ~Copyable
```

| `Memory.Buffer` | C |
|---|---|
| `init(capacity:)` | `malloc` |
| `init(capacity:alignment:)` | `posix_memalign` |
| `init(repeating:count:)` | `calloc` when the value's bytes are zeros, else `malloc` and a fill |
| `init(capacity:in:)`, `init(repeating:count:in:)` (Darwin) | `malloc_zone_malloc`, `malloc_zone_calloc` |
| `init(unsafeTaking:count:capacity:)`, `relinquish()`, `free()`, deinit | `free`, or the zone's |
| `count`, `capacity`, `isEmpty`, `append(_:)`, `removeLast(_:)`, `removeAll()` | |
| `reserveCapacity(_:)`, `shrinkToFit()`, growth in `append` | `realloc`, or for an aligned buffer `posix_memalign`, a copy and `free` |
| `span`, `mutableSpan`, `bytes`; `mutableBytes` for bytes | |
| `withUnusedCapacity(_:)` (an `OutputSpan`), `withUnusedByteCapacity(_:)` (an `OutputRawSpan`) | |
| `withUnsafeBufferPointer(_:)`, `withUnsafeMutableBufferPointer(_:)` | |

`OwnedZone` creates a zone (`init(name:)`) and destroys it in its deinit or
`destroy()`; `zone` is its handle, for `Memory.Zone`'s calls. `ZoneBuffer`
is a `Buffer` in an `OwnedZone`, whose lifetime depends on the zone's
(`@_lifetime(borrow zone)`), with `count`, `capacity`, `append`,
`reserveCapacity`, `removeAll`, `span` and `mutableSpan`.

`IOVectorPool(limit:byteLimit:)` has `write(_:to:)` and `writeAll(_:to:)`
over a collection of `UnsafeRawBufferPointer`s.

## What run.sh shows

Checks (`Checks/main.swift`), 15, all passing: growth and order, whole
blocks from `goodSize`, zeroed and filled creation (including a C
structure's zero `init()`), spans covering the elements only, appends
through an output span (and what's kept when the closure throws), a read
from a pipe straight into a byte buffer's capacity, alignment kept across
growth, `noMemory` for an unrepresentable capacity, ownership to C and back
(`relinquish` then C's `free`; `strdup`'s result adopted), a zone buffer
growing and freeing in its zone, an owned zone with buffers in it, and the
pool: one `writev`, many writes resuming inside buffers, and 3,077 one-byte
buffers, three times `IOV_MAX` and five more.

Compiler checks (`Verify/`, with `-emit-sil`, where the move checker runs):

| snippet | claim | result |
|---|---|---|
| M1 | a span can't be used after the buffer grows (and can move) | fails: overlapping accesses |
| M2 | a `ZoneBuffer` can't be returned past its zone's scope | fails: lifetime-dependent value escapes its scope |
| M3 | an `OwnedZone` can't be destroyed while a `ZoneBuffer` in it lives | fails: can't consume `arena`, borrowed by a non-Escapable type |
| M4a | 6.2 limit: a `let` zone can't be destroyed after a buffer borrowed it, even once the buffer is gone | fails |
| M4b | workaround: a `var` zone (with a spurious "never mutated" warning) | compiles |
| M4c | 6.2 limit: with a `var` zone, a buffer's span in an autoclosure (`&&`) "escapes its scope" | fails |
| M4d | workaround: make the buffers in a function that borrows the zone | compiles |
| M5 | the hazard of the handle: a `Buffer(capacity:in: zone)` outlives its zone | compiles |
| M6 | a buffer can't be used after `free()` | fails: used after consume |
| M7 | a buffer can't be copied | fails: used after consume |

The deinit policies and the growth benchmark have sections of their own
below.

## Design calls

- **The owner is `MemoryMapping`'s shape, with an initialized prefix.**
  Adopting (`init(unsafeTaking:count:capacity:)`), `relinquish()`, a deinit
  that frees, and spans through a borrow and a mutation are
  `MemoryMapping`'s. Unlike a mapping, `malloc`'s memory starts
  uninitialized, and a span may cover only initialized memory, so the
  buffer tracks `count` initialized elements at the start of its
  `capacity`, as `Array` and the standard library's `OutputSpan` do.
  Rejected: a fixed block that's always wholly initialized (`MemoryMapping`
  exactly), which must zero or fill every byte before anything reads it, or
  offer an unsafe way around that, and which loses `malloc`'s point; and
  spans over uninitialized memory, which are unsound.
- **Filling is separate from growing.** `reserveCapacity` allocates and
  throws `Errno`; `withUnusedCapacity` and `withUnusedByteCapacity` hand a
  closure an output span over the unused capacity, throw only the closure's
  error, and keep what it initialized even when it throws. The byte form is
  an `OutputRawSpan`, which System's `read(into:)` fills, so a read goes
  straight into the buffer (checked). Rejected: one
  `append(count:initializingWith:)` that grows and fills, whose error would
  have to be either `Errno` or the closure's.
- **One generic type, typed and raw.** `Buffer<Element: BitwiseCopyable>`
  has typed spans, and `bytes` for any element; the raw buffer is
  `Buffer<UInt8>`, which adds `mutableBytes` and `withUnusedByteCapacity`.
  Rejected: two types after the standard library's `Span` and `RawSpan`,
  which would duplicate the owner for no difference in its memory; and
  `mutableBytes` for every element type, since arbitrary bytes can be an
  invalid `Bool`, enum or non-optional pointer.
- **Elements are `BitwiseCopyable`**, because `realloc` moves elements by
  copying their bytes, and the deinit frees without deinitializing any.
  Rejected: `~Copyable` and other non-trivial elements, which would need
  deinitializing one by one, and moving by Swift rather than by `realloc`,
  since `realloc` would move address-sensitive types such as `Atomic` and
  `Mutex`, which no constraint excludes today.
- **Zeroed creation is `init(repeating:count:)`**, which uses `calloc` when
  the value's bytes, padding included, are all zero (`0`, `nil`, a C
  structure's `init()`), and `malloc` and a fill otherwise, so it's the
  same value either way. Rejected: `init(zeroedCount:)`, since all-zero
  bits isn't a valid value of every `BitwiseCopyable` type (a non-optional
  pointer isn't); and an unsafe form of it.
- **Aligned creation keeps its alignment as the buffer grows**, by
  allocating anew, copying and freeing, since `realloc` doesn't keep it
  (Darwin's man page says so). An element type whose alignment is more than
  `malloc`'s gets it too, but only an imported C type can be: Swift caps a
  type's alignment at 16 (`@_alignment(128)` is an error), which is
  `malloc`'s own on 64-bit platforms. An alignment that isn't a power of
  two throws `invalidArgument` before choosing an allocator (a check found
  that 3 was being taken as "malloc's own").
- **Growth doubles, rounded up to `goodSize` on Darwin**, so that the buffer
  asks for its whole block. Rejected: asking for less and using
  `usableSize`'s slack, which sanitizers report as an overflow.
  `shrinkToFit()` gives memory back.
- **Pointers only in closures.** A buffer can move when it grows, so it has
  `withUnsafeBufferPointer` and `withUnsafeMutableBufferPointer`, and no
  `unsafeBuffer` property, which `MemoryMapping` can have because its
  address never changes.
- **`free()` exists, though ending the lifetime does the same**, for code
  that wants to say so, and for the must-free policy below.
- **An overflowing capacity is `noMemory`**, as for `calloc`, rather than
  the trap `Array` gives, since creation already throws.
- **Zones two ways.** `Buffer(capacity:in: zone)` takes part A's
  `Memory.Zone` handle, which nothing stops being destroyed first (M5
  compiles). `OwnedZone` and `ZoneBuffer` make the compiler stop it (M2,
  M3): `ZoneBuffer` is `~Escapable`, and its lifetime borrows the zone.
  `ZoneBuffer` wraps a `Buffer` and forwards to it; it has a deinit that
  does nothing (the inner buffer's frees to the zone), because a deinit is
  what stops code from moving the inner buffer out of it and past the
  zone's lifetime. Rejected: exposing the inner buffer as a property, which
  `swap` could move out; and a closure-scoped zone
  (`withTemporaryZone { zone in … }`), whose `Escapable` buffers could
  escape the closure. An arena whose buffers don't free at all, leaving it
  to the zone's destruction, would be the same type with an empty deinit
  in the inner buffer; not built.
- **The deinit frees, by default, and the policy question stays open**
  (decision 54): see the next section.

## Compared with the standard library's allocation

| | `Memory.Buffer` | `UnsafeMutableRawBufferPointer.allocate` | `Array` |
|---|---|---|---|
| Ownership | noncopyable; the deinit frees | none: copies of the pointer, and a manual `deallocate()` | copy-on-write, reference-counted |
| Allocator | C's (`malloc`), so C can free it and it can adopt C's memory | `swift_slowAlloc`: `malloc` or aligned allocation today, but not promised to be C's | the standard library's |
| Failure | throws `noMemory` | traps (`swift_abortAllocationFailure`) | traps |
| Zero bytes | one byte | one byte (`swift_slowAlloc`), the same rule as part A's | no allocation |
| Growth | `realloc`, in place when it can | allocate, copy, deallocate, by hand | allocate, copy |
| Zeroed memory | `calloc` (free for fresh pages) | initialize by hand | `init(repeating:count:)` fills |
| Alignment | any power of two, kept as it grows | any, fixed | the element's |
| Zones | yes, on Darwin | no | no |
| Spans | over the initialized prefix, with lifetimes | none; `withUnsafeBytes` | `span` (macOS 26) |
| Overhead | none: a pointer, two counts, an allocator choice | none | a heap object's header |

The standard library's own clearing of secrets, `swift_clearSensitive`,
uses `memset` and relies on not being inlined; part A's `secureZero` is
`memset_s`.

### Growth, measured

`run.sh bench`: growing a buffer from 4 KiB by doubling, writing every new
byte with `memset`, the best of 5 in a process of its own, in µs, on macOS
26.3 (its allocator is xzone malloc):

| final size | `Memory.Buffer` (`realloc`) | allocate, copy, deallocate | `Array` |
|---|---|---|---|
| 64 KiB | 2 | 2 | 4 |
| 1 MiB | 20 | 46 | 50 |
| 16 MiB | 1,633 | 813 | 925 |
| 256 MiB | 27,297 | 10,507 | 11,458 |

`realloc` is about 2.4 times faster up to a megabyte, where it can grow
blocks in place, and 2 to 2.5 times slower from 16 MiB on. A direct probe of
Darwin's `realloc` against `malloc`, `memcpy` and `free`, without
`Memory.Buffer`, gives the same ratios, and rounding to `malloc_good_size`
doesn't change them, so it's the platform's large-block `realloc`. A
hybrid (`realloc` below a threshold, allocate-and-copy above it) would win
both ways here, but the threshold is a property of one allocator version,
and glibc's `realloc` (which can `mremap` large blocks) is unmeasured, so
the prototype doesn't do it. The numbers also moved with run order when
the variants shared a process, since the allocator keeps freed large blocks
for reuse, which is why each runs alone.

## Deinit policies (decision 54)

A buffer's deinit can't fail: `free` reports nothing, so the question
`Prototype/CloseErrors` asks for descriptors, what to do with a close
error, has nothing to drop here. The policies still differ in what they
demand and catch. The prototype's default is **free**: the deinit frees.
`run.sh policies` builds the module once per policy and runs each scenario
in a process of its own:

| scenario | modeled on | free (default) | must-free | checked |
|---|---|---|---|---|
| explicit-free | a buffer ended with free() | ok | ok | ok |
| end-of-scope | a buffer that goes out of scope, as most do | ok | TRAP: dropped without free() or relinquish() | ok |
| error-path | a buffer dropped by an error that ends its scope | threw | TRAP: dropped without free() or relinquish() | threw |
| relinquished | ownership handed to C, which frees | ok | ok | ok |
| adopted | a strdup result adopted with init(unsafeTaking:) | ok | TRAP: dropped without free() or relinquish() | ok |
| pool | an IOVectorPool dropped with its owner | ok | TRAP: dropped without free() or relinquish() | ok |
| freed-twice-small | a strdup result adopted, and freed by C too | undetected | TRAP: dropped without free() or relinquish() | undetected |
| freed-twice-large | the same, for a 200 KB block | TRAP: libmalloc: pointer being freed was not allocated | TRAP: dropped without free() or relinquish() | TRAP: a buffer's memory was freed by something else |

- **must-free** (the must-close policy) traps whenever a deinit runs, so
  every buffer must end in `free()` or `relinquish()`. For memory that's
  all cost: it traps on every error path and every ordinary scope end, and
  catches nothing the default gets wrong, since freeing can't fail.
- **checked** (the `EBADF` policy) traps in the deinit when Darwin's
  `malloc_size` says the block isn't a live allocation, which catches
  memory adopted with `init(unsafeTaking:)` that something else freed,
  with System's message, before libmalloc's abort. It can't catch a block
  that's been reused, as `EBADF` can't catch a reused descriptor number.
- **The double free of a small block went undetected** under both free and
  checked: the second free crashed nothing, and `malloc_size` answered as
  if the block were live. That's consistent with the allocator's
  configuration (printed with `MallocReportConfig=1`), which defers small
  frees ("Defer Tiny: 1"), but the cause wasn't established; a probe that
  printed between the two frees did trap. So neither the allocator nor a
  `malloc_size` check is a reliable detector, which argues for keeping
  `init(unsafeTaking:)` rare and named as unsafe, as it is.
- libmalloc writes its error messages only to a terminal unless
  `MallocDebugReport=stderr` is set, which `run.sh` does.
- Scrubbing secrets before freeing is a different axis, the contents
  rather than the lifetime, so it isn't a policy here: a wrapper whose
  deinit calls `Memory.secureZero` would be the shape. Not built.

## The worked example: a pool of I/O vectors

NIO's `PendingWritesManager` gathers a channel's pending buffers into a
pooled `UnsafeMutableBufferPointer<IOVector>`, sized with `UIO_MAXIOV`
(posix-more's README, cluster 1), so that a flush allocates nothing. From
memory of NIO's source, which this lane didn't reread: its event loop
allocates the pool once, beside storage references that keep the buffers
alive, and it caps a write at `Int32.max` bytes. `IOVectorPool` is that
pool on `Memory.Buffer<CInterop.IOVec>`:

- **One allocation, at creation**, of `limit` vectors, by default
  `SystemConfig.value(.maxIOVectors)` (1,024 here); `removeAll()` keeps the
  capacity, and gathering walks the caller's collection by its indices, so
  a write allocates nothing (a first version copied the collection into an
  `Array`, and `writeAll` mapped its lengths; both allocated per write).
- **A write covers at most `limit` vectors and `byteLimit` bytes**: Darwin's
  `writev` fails with `EINVAL` when the lengths' total overflows 32 bits
  (its man page), which is the reason for NIO's cap. `byteLimit` can be set
  lower, which is how a check makes writes stop inside buffers.
- **`writeAll` resumes inside whichever buffer a write stopped in**, as
  part A's span `writeAll` does, and skips empty buffers, which get no
  vector.
- **The buffers' lifetimes are the caller's**, for the call: vectors are raw
  pointers, and the pool keeps nothing between writes but stale vectors it
  doesn't read. A span can't be an array's element, so there's no safe
  form of a gather list (the span audit's finding); NIO keeps its storage
  references for this.
- **The vectors are filled through C's `iov_base` and `iov_len`**, which a
  client reaches only by importing the C library (MemberImportVisibility),
  so `IOVectorPool.swift` imports it. The syscalls-4 lane's accessors,
  `CInterop.IOVec(base:length:)`, `.base` and `.length` (its `338401f`),
  would replace those fields and the import; they aren't in system-next.

## Swift 6.2 findings

- A `let` noncopyable owner can't be consumed after a non-Escapable value
  borrowed it, even once that value is gone: `MemoryMapping`'s limit with
  spans (a memory note), and the same with a `ZoneBuffer` borrowing an
  `OwnedZone` (M4a). A `var` owner works, with a spurious warning (M4b),
  except that then a dependent value used in an autoclosure, such as the
  right side of `&&`, is reported as escaping (M4c). A function that
  borrows the owner avoids both (M4d), as the checks do.
- A span-consuming call can't go in a `defer`: `OutputSpan.finalize(for:)`
  consumes, and a `defer` counts as a closure capture ("missing
  reinitialization of closure capture after consume"), so the buffer
  finalizes in a `do`/`catch` on both paths.
- In an extension of `Memory.Buffer`, the prototype's `Memory._Allocator`
  isn't found unqualified, though it's a member of the outer type
  (declared in another module); it's spelled `Memory._Allocator`.
- `limit ?? (try ...)` inside a `throws(Errno)` initializer fails: the
  autoclosure throws `any Error`.
- `@_alignment` above 16 is an error, so no Swift type is more aligned
  than `malloc` is.

## What could move to Sources

Nothing moved. By part:

- `Memory.Buffer`'s core (creation, the initialized prefix, spans, output
  span appends, adoption and relinquishing, conditional `Sendable`) is
  sound as far as these checks and the move checker go, and could move
  first. What holds it back: its deinit policy is decision 54's, still
  open; its growth strategy wants the `realloc` crossover measured on Linux;
  and its name and its overlap with `Array`'s API want review.
- `OwnedZone` and `ZoneBuffer` work, but 6.2's limits (M4) make explicit
  destruction awkward enough that the first client would trip on them.
- `IOVectorPool` belongs to a client, such as NIO, more than to System:
  it's a policy (limits, resumption) over part A's `write(vectors:)`.
- The deinit policy switch is harness, not API.

## Unverified

- Everything off Darwin: the prototype builds on Linux in principle
  (`Memory.Buffer`, `IOVectorPool`; the zone types are Darwin-only), but
  nothing here built it, and the `realloc` measurements are Darwin's.
- `Memory.Buffer` with an imported C element type more aligned than
  `malloc`, which the aligned path would serve; no such type was at hand.
- The checked policy's `malloc_size` test is Darwin-only; glibc's
  `malloc_usable_size` of a freed block is undefined.
