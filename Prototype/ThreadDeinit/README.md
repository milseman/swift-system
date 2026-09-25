# Destroying an unjoined `PThread`

A `PThread` that's destroyed without `join()` or `detach()` has to do
something in its deinit: join, detach, trap, or nothing. This directory
compares those policies.

**Status: open.** The package's `PThread` joins, or detaches when it's
destroyed on its own thread, which can't wait for itself. That's a default
to measure the others against, not a decision. It's the same question as
`OwnedFD`'s close policy (decisions item 54, deliberately unresolved;
`Prototype/CloseErrors`) and as reaping a process.

## Policies

| policy | deinit | precedent |
|---|---|---|
| join (the package's default) | waits for the thread to finish; detaches it if the deinit runs on the thread itself | C++20's `std::jthread`, which also asks the thread to stop first |
| detach | lets the thread finish on its own | Rust's `std::thread::JoinHandle` |
| trap | traps whenever the deinit runs, so the owner must be consumed by `join()` or `detach()` | C++'s `std::thread`, which calls `std::terminate`; `NIOThread`'s deinit asserts this in debug builds |
| leak | nothing: the thread's resources stay allocated until the process exits | a forgotten `pthread_t` in C; `NIOThread` in release builds |

## The harness

`run.sh` builds `OwnedThread.swift`, a model of `PThread` with real
threads, with `Scenarios.swift` and `main.swift`, once per policy
(`-D POLICY_...`), and runs each scenario in its own process. A scenario
that traps shows as TRAP, and one that `alarm(5)` ends as HANG. "leaked N"
counts threads that were neither joined nor detached, and "dropped" the
errors that a deinit couldn't report. The `must-join:` rows are the same
code rewritten to satisfy the trap policy.

```sh
./Prototype/ThreadDeinit/run.sh
```

Output with Swift 6.2 (swiftlang-6.2.0.19.9) on macOS 26.3:

| scenario | modeled on | join | detach | trap | leak |
|---|---|---|---|---|---|
| explicit-join | PThreadTests.joinWaitsForTheBody | ok | ok | ok | ok |
| explicit-detach | PThreadTests.detach | ok | ok | ok | ok |
| scope-exit | an owner that goes out of scope | ok | unfinished at scope exit | TRAP | unfinished at scope exit; leaked 1 |
| error-exit | PThreadTests.deinitJoinsWhenAnErrorEndsTheScope | threw Stop | threw Stop; unfinished at scope exit | TRAP | threw Stop; unfinished at scope exit; leaked 1 |
| own-thread | PThreadTests.deinitOnItsOwnThreadDetaches | ok | ok | TRAP | leaked 1 |
| waits-for-its-owner | a worker told to stop after its owner's scope | HANG | ok | TRAP | leaked 1 |
| class-field | an event loop's thread in a class, released on the main thread | releasing the class blocked 50 ms | ok | TRAP | leaked 1 |
| loop-forgotten | a loop that starts a thread per item and drops it | loop took 380 ms | loop took 5 ms; 100 of 100 unfinished after the loop | TRAP | loop took 1 ms; 100 of 100 unfinished after the loop; leaked 100 |
| async-scope-exit | an owner destroyed in an async function | blocked a cooperative thread 58 ms | ok | TRAP | leaked 1 |
| joined-through-hatch | C code that joins the thread by its ID | dropped ESRCH | dropped ESRCH | TRAP | ok |
| relinquish-and-take | PThreadTests.manyThreads | ok | ok | ok | ok |
| must-join: scope-exit | scope-exit | ok | ok | ok | ok |
| must-join: error-exit | error-exit | threw Stop | threw Stop | threw Stop | threw Stop |
| must-join: class-field | class-field | releasing the class blocked 53 ms | releasing the class blocked 55 ms | releasing the class blocked 55 ms | releasing the class blocked 52 ms |

The timings vary from run to run; the loop's is 100 threads that each
sleep 2 ms.

## The same policies on the package

`run-package.sh` patches each policy into `PThread._destroy` in a copy of
the package, then runs each of the 71 PThread tests in its own process, and
the three thread samples:

| policy | tests (71) | samples |
|---|---|---|
| join | 71 pass | all run |
| detach | 67 pass; 4 fail | all run |
| trap | 64 pass; 7 trap | all run |
| leak | 67 pass; 4 fail, the same as detach's | all run |

Under detach and leak, `deinitJoins` and
`deinitJoinsWhenAnErrorEndsTheScope` fail, as they should, and so does
`PThreadMockTests/testJoinAndDetach`, which checks that the deinit calls
`pthread_join`. So does `PThreadReadWriteLockTests/writerExcludes`, which
wasn't written to test the policy: its helper starts a thread that holds
the lock until the helper's scope ends, and the test then expects the lock
to be free. That's true only if the scope's end waited for the thread.
Under detach it's a race, and it lost.

Under trap, those four trap, and so do three more that let an owner go at
the end of a scope: `deinitOnItsOwnThreadDetaches`,
`PThreadNameTests/nameOfAnotherThread`, and
`PThreadReadWriteLockTests/readersShare`.

The samples join every thread explicitly, so the policy doesn't reach them.

## What the results show

No policy is free.

- **Join** makes a thread started in a scope finish before the scope ends,
  also when an error ends it (`error-exit`), which is the structure that
  `writerExcludes` quietly relied on. Its cost is blocking that nothing at
  the call site shows. A thread that waits for its owner's scope deadlocks
  (`waits-for-its-owner`). Releasing a class blocks the releasing thread
  for as long as the thread runs (`class-field`), and so does leaving an
  async scope, on a cooperative thread, which Swift concurrency assumes
  never blocks (`async-scope-exit`). A loop that drops its threads runs
  them one at a time (`loop-forgotten`). It needs a special case for its
  own thread, where a plain join would deadlock on Musl and fail with
  `EDEADLK` elsewhere. And it hides a forgotten join, as long as the
  thread finishes.
- **Detach** never blocks, and never deadlocks. Its cost is that the work
  outlives the scope: nothing waits for it, error paths included, and when
  the process exits the work is cut off. Code that assumes the work is
  done, like `writerExcludes`' helper, races.
- **Trap** turns a forgotten `join()` or `detach()` into a crash at the
  place it happened. It traps in every scenario that drops an owner, error
  unwinding included, which is the complaint against `std::thread`: an
  error thrown between creating a thread and joining it ends the process.
  Satisfying it costs a `do`/`catch` per throwing scope, since `defer`
  can't consume (V11a), and the `class-field` rewrite blocks exactly as
  join does, because the class's deinit has to join.
- **Leak** is the C behavior. A finished thread that's never joined keeps
  some of its resources until the process exits: on Darwin, 500 of them
  held 15 MiB more virtual memory than 500 joined ones
  (`Prototype/Threads/Verify/T13`).

Both join and detach act on a thread by an ID that something else may
already have joined (`joined-through-hatch`). Darwin reports `ESRCH`; on
Linux the ID can already name a new thread, and using it is undefined
behavior. It's the thread's version of `OwnedFD` closing a descriptor number
that was reused, and no policy detects it there.

How this relates to the other ownership questions:

- For `OwnedFD`, the quiet cleanup is cheap: close doesn't block. For a
  thread, the quiet cleanup that finishes the work, joining, is the
  expensive one, and the cheap one, detaching, doesn't finish the work.
  That difference is why `OwnedFD`'s answer doesn't carry over directly.
- A process owner has the same three choices: `waitpid` in the deinit
  (join, and it blocks), a reaper or `SIGCHLD` set to `SIG_IGN` (detach),
  or neither, which leaves a zombie (leak).
- `CloseErrors` rejected must-close as "the guard that blocks legitimate
  cuts". Trap is the same guard here, and it trapped in 8 of the 11
  ordinary scenarios and 7 of the package's 71 tests.
- Swift's structured concurrency points both ways: a task group waits for
  its children when its scope ends, like join, and an unstructured `Task`
  runs on, like detach.

What would help decide: how adopters drop threads in practice. NIO joins
each event loop's thread when its group shuts down
(`SelectableEventLoop.syncFinaliseClose`) and each pool thread when its
pool does (`NIOThreadPool`), and `NIOThread` asserts in debug builds that
nothing forgot to. So join, detach, or a debug-only trap would all suit
NIO's code.

## Files

- `OwnedThread.swift`: the model owner and its four deinits.
- `Scenarios.swift`: the scenarios and their helpers.
- `main.swift`: runs one scenario and reports what happened.
- `run.sh`: the harness table.
- `run-package.sh`: the package's tests and samples under each policy,
  in copies under `$TMPDIR`.
