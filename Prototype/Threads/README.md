# A typed pthread layer

`Sources/System/Threads/` prototypes typed wrappers for pthreads: threads,
their names and scheduling, mutexes, condition variables, read-write locks,
thread-specific storage, and CPU affinity. It is marked "PROTOTYPE… Not
API". NIO's coverage report ranks these among System's largest gaps, so the
layer starts with what NIO uses (`NIOPosix/ThreadPosix.swift`,
`LinuxCPUSet.swift`, and `NIOConcurrencyHelpers`), then adds rwlocks and
scheduling.

This write-up answers the six design questions with the evidence behind
each answer. One of them is deliberately left open: what destroying an
unjoined thread does. `Prototype/ThreadDeinit/` compares the policies, and
the package implements one of them as a default, not as a decision.

Everything here was built and run with Swift 6.2 (swiftlang-6.2.0.19.9) on
macOS 26.3. The Linux paths have only been typechecked; see
[Unverified off Darwin](#unverified-off-darwin). The compiler and runtime
checks cited as T1 to T13 are in `Verify/`; each opens with the claim it
checks and the command that runs it. V11a is in `Prototype/Verify/`.

## The API

Each C type `pthread_X_t` becomes `PThread.X`:

| C | Swift | Notes |
|---|---|---|
| a joinable `pthread_t` | `PThread` | noncopyable owner: `init(attributes:_:)` (`pthread_create`), `join()`, `detach()`, `init(taking:)`, `relinquish()`, `id` |
| `pthread_t` | `PThread.ID` | copyable and `Hashable`: `current` (`pthread_self`), `==` (`pthread_equal`), `name()`, `scheduling()`, `setScheduling(_:)`; `setName(_:)` on Linux, Android, FreeBSD; `qosClass()` on Darwin; `affinity()`, `setAffinity(_:)` on Linux |
| `pthread_attr_t` | `PThread.Attributes` | a value: `stackSize`, `guardSize`, `scheduling`; `qosClass`, `qosRelativePriority` on Darwin |
| `pthread_mutex_t`, `pthread_mutexattr_t` | `PThread.Mutex`, `.Attributes`, `.Kind`, `.PriorityProtocol` | `lock`, `tryLock`, `unlock`, `withLock`; `lock(until:)` except on Darwin; `markConsistent()` on Linux and FreeBSD; `priorityCeiling()`, `setPriorityCeiling(_:)` except on Android |
| `pthread_cond_t`, `pthread_condattr_t` | `PThread.Condition`, `.Attributes`, `.Clock` | `wait(on:)`, `wait(on:until:)`, `signal()`, `broadcast()`; `wait(on:timeout:)` on Darwin; `Clock` except on Darwin |
| `pthread_rwlock_t`, `pthread_rwlockattr_t` | `PThread.ReadWriteLock`, `.Attributes` | `lockForReading`, `lockForWriting`, their `try` forms, `unlock`, `withLockForReading`, `withLockForWriting` |
| `pthread_key_t` | `PThread.Key<Value>` | `value()`, `setValue(_:)` |
| `cpu_set_t` | `PThread.CPUSet` | Linux and Android: `PThread.currentAffinity()`, `setCurrentAffinity(_:)` (`sched_getaffinity`, `sched_setaffinity`) |
| the policy and `struct sched_param` | `PThread.SchedulingPolicy`, `PThread.Scheduling` | `SchedulingPolicy.priorityRange()` (`sched_get_priority_min`, `max`) |
| `qos_class_t` | `PThread.QoSClass` | Darwin: `current`, `main`, `PThread.setCurrentQoSClass(_:relativePriority:)` |
| `sched_yield`, `pthread_main_np`, `pthread_setname_np` | `PThread.yield()`, `PThread.isMainThread`, `PThread.setCurrentName(_:)` | `isMainThread` on Darwin, FreeBSD, OpenBSD |

`CInterop` gains `PThread`, `PThreadKey`, `PThreadMutex`,
`PThreadCondition`, and `PThreadReadWriteLock`. The last three are
optionals on FreeBSD and OpenBSD, where the C types are pointers to objects
that libc allocates.

**Naming (a design call).** The C names make a namespace:
`pthread_mutex_t` is `PThread.Mutex`. Flat names were rejected because the
natural ones collide: `Mutex` with `Synchronization.Mutex` in any file that
imports both, and `Thread` with Foundation's. An enum namespace with the
owner as `PThread.Owned` was rejected too: the owner is the type code names
most, so it gets the short name, as in C++, where `std::thread` owns and
`std::thread::id` names. `PThread` rather than `Pthread` treats the P as an
initialism; either is defensible, and the name is open, like `OwnedFD`'s.

## 1. Relationship to the standard library's Synchronization

**Choice: System is the typed pthread layer, not a lock library.** For
protecting a value within one process, use `Synchronization.Mutex`;
`PThread.Mutex`'s documentation says so. Confidence: high.

The evidence that the two don't overlap:

- `Mutex` isn't a pthread mutex. `Mutex<Void>` is 4 bytes, an
  `os_unfair_lock` on Darwin, against 64 for `pthread_mutex_t` (T7), and
  its interface (`Synchronization.swiftinterface`) wraps a `_MutexHandle`
  that vends only `withLock`, `withLockIfAvailable`, and unsafe
  lock/unlock. So `pthread_cond_wait` can't take one, and it has no
  attributes. It must also be a `let` (`@_staticExclusiveOnly`, T7).
- `Mutex` needs macOS 15 and iOS 18. As a package, `PThread.Mutex` has no
  OS floor, which matters to adopters like NIO that deploy to older OSes.
  In the SDK, `System 199` is new API, so this advantage is the package's
  only.

What System adds, each exercised by a test in `Tests/SystemTests`:

- condition variables, which need a pthread mutex (`PThreadConditionTests`);
- read-write locks (`PThreadReadWriteLockTests`);
- mutex kinds: recursive, and error-checking, which NIO uses in debug
  builds and which reports relocking as `EDEADLK` and a stray unlock as
  `EPERM` (`errorChecking`, `errorCheckingUnlockFromAnotherThread`);
- process-shared mutexes, conditions, and rwlocks, placed in `MAP_SHARED`
  memory (`processSharedMutexInSharedMemory` and its counterparts; Darwin
  accepts `PTHREAD_PROCESS_SHARED` for all three);
- robust mutexes, on Linux and FreeBSD (`robustMutexWhoseOwnerEnded`,
  unverified);
- priority inheritance and ceilings (`priorityProtocols`), and a timed
  lock except on Darwin;
- interoperation with C in both directions: `unsafeAddress` hands a
  System-owned object to C (`unsafeAddressIsTheMutexThatCUses`), and
  `withUnsafeMutex(at:_:)` and its counterparts lend a non-owning view of
  a C-owned one (`borrowingAMutexThatCOwns`, T10).

Where System defers: it has no `PThread.Mutex<Value>` (that's `Mutex`), no
atomics (that's `Atomic`), and no `pthread_once` (Swift's globals and
`static let`s are lazily initialized once).

## 2. Address stability

A `pthread_mutex_t`, `pthread_cond_t`, or `pthread_rwlock_t` must not move
after initialization: POSIX makes using a copy undefined, and in Darwin's
libpthread (from its source, not tested here) the kernel keys waiters by
the object's address, and initialization records the object's alignment. A
noncopyable struct can move whenever it's consumed.

| storage | compiles with 6.2 | address stable | can be stored | cost |
|---|---|---|---|---|
| inline in a noncopyable struct | yes | **no**: five addresses between init, a local, a borrow, a class field, and the deinit, which can only destroy a copy because a deinit's `self` is immutable (T1) | yes | none |
| `@_rawLayout`, as `Mutex` does | only with `-enable-experimental-feature RawLayout`, and `BuiltinModule` for `Builtin.addressOfRawLayout` (T2, T3) | during a borrow only: it moves into a class field, and before its deinit (T2, T3) | yes | none |
| closure-scoped (`withMutex { m in … }`) | yes | yes (T4) | **no**: it can't reach a thread body, which escapes (T4); only a scoped thread that's joined before the scope ends can borrow it (T5) | none |
| heap storage owned by a noncopyable struct (**chosen**) | yes | yes, through every move, at -Onone and -O (T6) | yes | one allocation per object |
| a class with the object tail-allocated (NIO's `LockStorage`) | yes | yes | yes, by reference | one allocation; a copyable reference |

`Mutex` gets away with moving because `os_unfair_lock` and a futex word are
plain integers when unlocked. `pthread_mutex_t` isn't specified to be.

**Choice: heap storage owned by a noncopyable struct.** It's the only
option that keeps the object at one address, compiles without experimental
features, and can be stored where threads share it. Around it:

- `init(unsafeUninitializedAddress:attributes:)` places the object in
  memory the caller provides, such as shared memory, which process-shared
  and robust objects need. The owner destroys the object but doesn't
  deallocate the memory.
- `unsafeAddress` hands the address to C; it's valid while the owner lives.
- `withUnsafeMutex(at:_:)` lends a `borrowing PThread.Mutex` over a C-owned
  mutex, ended with `discard self` so its deinit never runs (T10). A
  borrowed view can't be stored or escape (T10).

Confidence: high against inline, `@_rawLayout`, and closure-scoped storage.
Medium against the class: a class is the other option that works, and
reference semantics suit a lock that threads share, but the package's
direction is noncopyable owners (`OwnedFD`, `Mach.Port`, `IORing`), and a
class can be built on the owner but not the reverse.

**What it costs NIO.** NIOLock keeps its value and its `pthread_mutex_t` in
one `ManagedBuffer` allocation. A `PThread.Mutex` field would be a second
allocation. NIO could keep its layout with the unsafe pieces, but only
partly: `withUnsafeMutex(at:)` covers locking and waiting, while
initializing in place with `init(unsafeUninitializedAddress:)` leaves NIO
holding an owner that its tail allocation has no room for. An
`init(unsafeTaking:)` and `relinquish()` pair, like `OwnedFD`'s
`init(taking:)` and `relinquish()`, would close the gap. It isn't
implemented.

## 3. Threads

**`PThread.ID`** is the name of a thread: copyable, `Hashable`, and
`@unchecked Sendable`, since `pthread_t` is a pointer on Darwin and Musl.
`==` is `pthread_equal`, which compares the bits on every platform System
supports, so hashing the bits agrees with it. An ID is valid while its
thread runs, and after that until the thread is joined; the system can
reuse it. Darwin reports `ESRCH` for a stale ID, where Linux has undefined
behavior.

**`PThread`** is the responsibility: a noncopyable owner that must be
joined or detached.

- The body is `sending @escaping () -> Void`, not `@Sendable` (T9). It
  can capture non-Sendable values that the caller doesn't use again, which
  `@Sendable` rejects. The cost is one pattern `@Sendable` accepts: two
  bodies can't capture the same local noncopyable value, even a Sendable
  one; share it through a class instead, which is how locks are shared
  anyway. Writing `PThreadMockTests` hit the rule as intended: a body
  captured a local whose region a `weak var` shared.
- `join()` and `detach()` consume the owner. `join()` checks for the
  calling thread with `pthread_equal` before calling `pthread_join`,
  because Musl doesn't detect a thread joining itself and waits forever. A
  self-join detaches the thread and throws `Errno.deadlock`, rather than
  leaking it; so does a join that glibc reports as a deadlock between two
  threads.
- `init(taking:)` and `relinquish()` follow `OwnedFD`. They're also how an
  Array holds threads: an Array can't hold noncopyable elements, so the
  tests and samples keep IDs from `relinquish()` and join each with
  `PThread(taking:)`.
- The body's value isn't returned by `join()`. A generic `PThread<Result>`
  would make `PThread.ID` generic too. A thread that computes a value
  stores it where the joiner can read it.

**Destroying an unjoined thread** is the open question, the same one as
`OwnedFD`'s close policy (decisions item 54) and process reaping. The
package's deinit joins, and detaches when it runs on the thread itself,
which can't wait for itself. `Prototype/ThreadDeinit/README.md` compares
that default with detaching, trapping, and doing nothing, in a harness of
14 scenarios and across the package's own tests and samples. In short:

- **join** keeps threads structured: a thread started in a scope finishes
  before the scope ends, also when an error ends it, which T8 confirms is
  the end of the scope. Its costs are hidden blocking: it deadlocks when
  the thread waits for its owner's scope, blocks whoever releases a class
  that holds the owner, serializes a loop that drops its threads, and
  blocks a cooperative thread in async code. It also hides a missing join.
- **detach** never blocks; a dropped thread keeps running, and its work is
  unfinished when the scope ends. Rust's `JoinHandle` detaches.
- **trap** makes the owner linear at run time, as C++'s `std::thread`
  does. It traps in every scenario that drops an owner, error unwinding
  included, and satisfying it takes a `do`/`catch` per throwing scope
  (V11a: `defer` can't consume).
- **leak** is C's behavior when a join is forgotten.

Which is right isn't decided, and this prototype doesn't decide it.

## 4. Thread names

Darwin can name only the calling thread, with `pthread_setname_np(name)`,
and returns -1 with errno set, `ENAMETOOLONG` past 63 bytes. Linux, Android,
and FreeBSD can name any thread in the process, with
`pthread_setname_np(thread, name)`, which returns `ERANGE` past 15 bytes on
Linux. Every one of them can read any thread's name.

**Choice: the API has each call only where the platform has it.**

- `PThread.setCurrentName(_:)` exists everywhere. On Linux it calls
  `pthread_setname_np(pthread_self(), name)`, the same C function.
- `PThread.ID.setName(_:)` exists only on Linux, Android, and FreeBSD, so
  naming another thread on Darwin is a compile-time error, not a run-time
  surprise.
- `PThread.ID.name()` exists everywhere that has `pthread_getname_np`.
- Names aren't truncated. NIO truncates to 15 bytes; with System, a long
  name throws `fileNameTooLong` on Darwin and `outOfRange` on Linux, and
  NIO would keep its truncation as policy. A name containing NUL throws
  `invalidArgument`, since C would silently cut it short.

Rejected: an `ID.setName(_:)` on Darwin that asserts the ID is the calling
thread's, which is how NIO emulates Linux's signature, and a setter that
silently does nothing where it can't work. Tests: `PThreadNameTests`,
including the 63-byte and 64-byte cases. Confidence: high.

## 5. Thread-specific storage

**Choice: `PThread.Key<Value>`, a noncopyable owner of a key, which boxes
each thread's value in a class that the key's C destructor releases.**

- Values are any Swift type. The destructor runs when a thread finishes,
  including values that other destructors set, which POSIX handles with
  `PTHREAD_DESTRUCTOR_ITERATIONS` (`valueDestroyedAtThreadExitCanSetAnotherKey`).
  NIO's `ThreadSpecificVariable` restricts values to classes; boxing costs
  one allocation per `setValue(_:)`.
- Destroying the owner deletes the key and destroys the calling thread's
  value. POSIX runs no destructors when a key is deleted, so other threads'
  values leak. A key that lasts as long as the process, such as a `static
  let`, which is never destroyed, never leaks them; the documentation and
  the `threads-local` sample use one.
- `Key` is `Sendable` only when `Value` is, for the reason NIO gives: an
  unconditionally Sendable key could smuggle non-Sendable values between
  isolation domains that share a thread.
- `value()` and `setValue(_:)` are `noasync`, as Darwin marks the C
  functions ("Use Task Local Values instead").

**The existing internal TLS** (`makeTLSKey`, `setTLS`, and `getTLS` in
`Internals/Exports.swift`, and SystemSockets' private copy) stays as it is.
The mocking driver keeps its state there, and it can't go through the
mockable `pthread_setspecific`: the `setTLS(nil)` that turns mocking off
runs while mocking is on, so a mocked call would never turn it off. The
helpers also take no destructor and trap on failure. They could share
`system_pthread_key_create` if its hook were bypassed, which isn't worth
it for 30 lines.

Mocking found a hazard here: a mocked `pthread_key_create` left the key at
0, and the owner's unmocked `pthread_getspecific(0)` read Darwin's TSD slot
0, the thread's own `pthread_t`, which the deinit then released as a Swift
object. The mock now reports a real key that never has a value (commit
`ced8a0d`).

Confidence: medium-high. Open: whether to vend the raw key, for C code
that shares one; a C function can't interpret the boxes.

## 6. Errors

**Choice: every wrapper throws `Errno`, typed.**

- pthread functions return an error number, so the wrappers use
  `nothingOrReturnedErrno`. The exception is Darwin's
  `pthread_setname_np`, which returns -1 and sets errno (checked:
  `ENAMETOOLONG` in errno); `sched_get_priority_min` and `max` and the
  `sched_*affinity` calls also set errno.
- POSIX says these functions never fail with `EINTR`, so none takes
  `retryOnInterrupt`. The mock tests run every case as `.noInterrupt`: a
  forced `EINTR` is thrown, never retried.
- Expected outcomes are results, as `FileLock`'s `lock` returns `false`
  for `EAGAIN`: `tryLock` returns `false` for `EBUSY`, and timed waits for
  `ETIMEDOUT`.
- `withLock` and its rwlock counterparts use untyped `throws`, as
  `closeAfter` and `withRawMode` do. The body's error wins over an unlock
  error.
- Blocking calls are `noasync`, matching Darwin's annotations on the C
  functions; `withLock` and friends stay available to async code, since
  their body can't suspend.
- A deinit can't throw, so it drops errors, as `OwnedFD`'s does: `EBUSY`
  from destroying a locked mutex, and `ESRCH` or `EINVAL` from joining a
  thread that something else joined.
- Mock hooks cover every call that can fail except the attribute setters,
  which only fill in a local structure. `_mockReturningErrno` covers calls
  that return an error number, `_mock` those that set errno. Where a
  mocked call leaves an output that unmocked code then reads, the mock
  fills in something valid: `pthread_create` reports the calling thread,
  and `pthread_key_create` a real key.

One shape is a hazard, and it's left as POSIX has it: a robust mutex's
`lock()` throws `previousOwnerDied` with the mutex locked. Code that just
propagates the error leaves the mutex held. A `Bool` or enum result for
robust locking would avoid that. Confidence: high, except for the robust
case.

## Deliberately not wrapped

- `pthread_exit`: it ends the thread without running Swift cleanups.
- `pthread_cancel` and cancellation state: cancellation unwinds or stops
  code that doesn't expect it; Darwin marks these `noasync`.
- `pthread_once`: Swift's lazy globals do this.
- `pthread_kill` and `pthread_sigmask`: these belong with signals.
- `pthread_atfork`, stack placement (`pthread_attr_setstack`), kernel
  thread IDs (`gettid`, `pthread_threadid_np`), and Darwin's mutex
  policies (`pthread_mutexattr_setpolicy_np`): not needed by NIO; each is a
  small addition.
- Linux's `SCHED_BATCH` and `SCHED_IDLE`, which glibc defines only with
  `_GNU_SOURCE`.

## Windows

Out of scope for this lane. The equivalents a Windows layer would wrap:

| POSIX | Windows |
|---|---|
| `pthread_create`, `pthread_join`, `pthread_detach` | `CreateThread` or `_beginthreadex`; `WaitForSingleObject` and `CloseHandle`; `CloseHandle` alone |
| `pthread_self`, `pthread_equal` | `GetCurrentThreadId` and thread IDs (`GetCurrentThread` returns a pseudo-handle) |
| `pthread_mutex_t` | `SRWLOCK` (exclusive), or `CRITICAL_SECTION`, which is recursive; a named mutex from `CreateMutex` for other processes, whose `WAIT_ABANDONED` is like a robust mutex's `EOWNERDEAD` |
| `pthread_cond_t` | `CONDITION_VARIABLE`: `SleepConditionVariableSRW`, with a relative timeout in milliseconds; `WakeConditionVariable`, `WakeAllConditionVariable` |
| `pthread_rwlock_t` | `SRWLOCK`, shared and exclusive |
| `pthread_key_t` | `FlsAlloc`, whose callback is a destructor, or `TlsAlloc` |
| names | `SetThreadDescription`, `GetThreadDescription`: any thread, UTF-16 |
| affinity | `SetThreadAffinityMask`, `SetThreadGroupAffinity`, `SetThreadSelectedCpuSets` |
| scheduling, QoS | `SetThreadPriority`, `SetPriorityClass`, `SetThreadInformation` (power throttling) |
| `sched_yield` | `SwitchToThread` |
| `pthread_once` | `InitOnceExecuteOnce` |

## NIO coverage

The entries of NIO's coverage mapping (then `Utilities/nio-coverage/mapping.ini`,
now `Utilities/adopter-coverage/mapping.ini`) that this API covers, for the
adopter-coverage lane to update:

| entry | status | covering API | what's left |
|---|---|---|---|
| `[pthread_create]` | covered | `PThread(attributes:_:)`, `PThread.Attributes` (`qosClass = .main` is `pthread_attr_set_qos_class_np` with `qos_class_main()`), `join()`, `PThread.ID`, `.current`, `==` | System adapts the start routine to Android's NDK 27 and 28 signatures and Musl's `pthread_t` |
| `[thread names]` | partial | `PThread.setCurrentName(_:)`, `PThread.ID.name()`, `setName(_:)` on Linux, Android, FreeBSD | OpenBSD's `pthread_set_name_np`; Windows; NIO's 15-byte truncation and its `/proc` reading on Android stay NIO's |
| `[thread-specific storage]` | partial | `PThread.Key<Value>` for `ThreadSpecificVariable` | Windows' FLS; NIO's C11 `_Thread_local` event-loop ID is a compiler feature, not System's |
| `[CPU affinity]` | covered (Linux, Android; unverified) | `PThread.CPUSet`, `PThread.currentAffinity()`, `setCurrentAffinity(_:)`, `PThread.ID.affinity()`, `setAffinity(_:)` | |
| `[mutexes]` | covered on POSIX | `PThread.Mutex`, `Attributes(kind: .errorChecking)` | `SRWLOCK`; NIOLock's single allocation (see question 2) |
| `[condition variables]` | covered on POSIX | `PThread.Condition`: `wait(on:)`, `wait(on:until:)`, `signal()`, `broadcast()` | `CONDITION_VARIABLE`; the deadline still needs a clock (`[gettimeofday]`, `[monotonic clock]` stay missing) |
| `[yield]` | covered on POSIX | `PThread.yield()` | `sched_yield` everywhere, rather than `pthread_yield_np` on Darwin; Windows' `Sleep(0)` |
| `[main thread]` | covered | `PThread.isMainThread` | |
| `[Windows threads]` | missing | | out of scope |
| `[autoreleasepool]` | missing | | Objective-C's, not System's |

## Unverified off Darwin

Nothing here has been compiled against Glibc, Musl, Bionic, or FreeBSD.
The Linux branches typecheck on Darwin in a scratch copy, with Darwin's C
types and stub declarations of the Linux functions; there, the mock tests
(Linux cases included) and `CPUSet`'s set operations pass. Unverified:

- the CSystem shims (`csystem_pthread_setname_np`, `_getname_np`,
  `csystem_sched_setaffinity`, `_getaffinity`, `csystem_pthread_setaffinity_np`,
  `_getaffinity_np`) and their `_GNU_SOURCE` assumptions; Android's API 26
  check for `pthread_getname_np`;
- the storage aliases: `pthread_t` as an integer (Glibc, Bionic) or a
  pointer (Musl, FreeBSD), and FreeBSD's and OpenBSD's pointer-typed objects;
- constants that glibc and Bionic declare in anonymous enums (imported as
  `Int`), and FreeBSD's and OpenBSD's named mutex-type enum (`.rawValue`);
- the start routine and key destructor closures against Android's NDK 27
  and 28 signatures;
- `lock(until:)`, robust mutexes, `Condition.Clock`, `PThread.ID.setName(_:)`,
  and all of `CPUSet`'s calls;
- whether `timespec`'s members are attributed to CSystem under
  MemberImportVisibility (`Tests/MemberImportVisibility/ThreadsProbe.swift`
  checks it on Glibc, Musl, and Android);
- the Linux tests: timed and robust locking, the monotonic clock, naming
  another thread, and affinity.

## Other findings

- An Array can't hold a noncopyable `PThread`. The workarounds are IDs
  from `relinquish()` with `PThread(taking:)` to join, a class per thread,
  or `InlineArray` (macOS 26).
- In top-level code, a noncopyable `let` is a global and can't be consumed,
  so `try thread.join()` fails there (T12); the same holds for `OwnedFD`.
- Swift 6.2 crashes in the move checker instead of diagnosing a closure's
  borrowed noncopyable parameter captured by an escaping closure (T4).
- In a closure, a `do`/`catch` catches `any Error` unless it's written
  `do throws(Errno)`, and a closure whose only `try` is inside
  `#expect(...)` isn't inferred as throwing.
- Darwin 26.3 behaviors that its headers don't describe:
  `pthread_cond_timedwait_relative_np` waits forever for a negative
  `tv_sec` (T11), so `wait(on:timeout:)` clamps a negative `Duration` to
  zero; `sched_get_priority_min` and `max` ignore the policy (15...47 for
  any value); and `pthread_attr_set_qos_class_np` accepts any relative
  priority.

## Files

- `Sources/System/Threads/`, `Internals/Syscalls+Threads.swift`,
  `Internals/Constants+Threads.swift`, and the shims at the end of
  `Sources/CSystem/include/CSystemLinux.h` and `shims.c`.
- `Tests/SystemTests/PThread*.swift` and
  `Tests/MemberImportVisibility/ThreadsProbe.swift`.
- `Sources/Samples/Threads*.swift`: `threads-pool`, `threads-local`,
  `threads-info`.
- `Prototype/Threads/Verify/`, T1–T13, and `Prototype/ThreadDeinit/`.
