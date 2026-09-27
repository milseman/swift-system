# Processes and signals

`Sources/System/Processes/` prototypes process and signal API: signals and
their sets, actions, and masks; sending signals; process groups and sessions;
waiting and exit statuses; `posix_spawn` and `exec`; an owned child process;
resource limits; credentials; and on Linux, process and signal descriptors. It
is marked "PROTOTYPE… Not API". It fills the largest gap left for
swift-subprocess and SwiftPM, and NIO's one use of signals.

This write-up records the design calls, each with the alternative it rejects,
and the one question left open: what destroying an owned child that hasn't
been reaped does (decisions item 28). `Deinit/` compares the policies, and the
package implements one of them as a default, not as a decision.

Everything here was built and run with Swift 6.2 (swiftlang-6.2.0.19.9) on
macOS 26.3. The Linux paths have only been typechecked, against a model of
their C declarations (`check-linux.sh`); see
[Unverified off Darwin](#unverified-off-darwin).

## The API

| C | Swift | Notes |
|---|---|---|
| signal numbers | `Signal` | `RawRepresentable` over `CInt`; `hangup`, `interrupt`, `terminate`, `kill`, `stop`, `continue`, `childStatusChange`, `brokenPipe`, `userDefined1`, … with unavailable stubs for the C names; `emulatorTrap` and `informationRequest` on Darwin and the BSDs, `powerFailure` on Linux; its description is the C name |
| `sigset_t` | `SignalSet` | a `SetAlgebra` and a `Sequence` of its members in increasing order; `SignalSet.all` (`sigfillset`) |
| `struct sigaction` | `Signal.Action`, `.Handler`, `.Flags` | `signal.action()`, `setAction(_:)`, returning the previous action; `Handler` is `.default`, `.ignore`, `.function`, or `.functionWithInfo` |
| `siginfo_t` | `Signal.Information` | `signal`, `code`, `processID`, `userID`, `status`, `address`, read through CSystem shims |
| `pthread_sigmask`, `sigpending`, `sigwait`, `sigsuspend` | `PThread.currentSignalMask()`, `setCurrentSignalMask(_:)`, `blockSignals(_:)`, `unblockSignals(_:)`, `pendingSignals()`, `waitForSignal(in:)`, `suspendUntilSignal(mask:)` | the calling thread's signals, next to `PThread`'s other calling-thread operations |
| `kill`, `killpg`, `kill(-1, …)`, `pthread_kill`, `raise` | `ProcessID.sendSignal(_:)`, `sendSignalToProcessGroup(_:)`, `ProcessID.sendSignalToAllProcesses(_:)`, `PThread.ID.sendSignal(_:)`, `signal.raise()` | a `nil` signal checks for the process |
| `getpgrp`, `getpgid`, `setpgid`, `getsid`, `setsid` | `ProcessID.currentProcessGroup`, `processGroup()`, `setProcessGroup(_:)`, `sessionID()`, `ProcessID.createSession()` | groups and sessions are `ProcessID`s, as in `TerminalDescriptor` |
| `waitpid` | `ProcessID.wait(retryOnInterrupt:)`, `tryWait()`, `ProcessID.waitForAnyChild(retryOnInterrupt:)`, `tryWaitForAnyChild()` | return `ExitStatus` |
| `waitid` | `ProcessID.wait(for:retryOnInterrupt:)`, `ProcessID.waitForAnyChild(inProcessGroup:for:retryOnInterrupt:)`, `ProcessID.WaitOptions` | return `ProcessStateChange` |
| the `W*` macros, `CLD_*` | `ExitStatus` (`.exited`, `.signaled`), `ProcessStateChange` (`.terminated`, `.stopped`, `.continued`) | decode a wait status or a `siginfo_t` |
| `posix_spawn`, `posix_spawnp` | `ProcessID.spawn(_:arguments:environment:fileActions:attributes:)`, `spawn(searchingPathFor:…)`, and a C-array overload | return the raw ID |
| `posix_spawn_file_actions_t` | `[SpawnFileAction]` | `.open`, `.duplicate(_:as:)`, `.close`, `.setWorkingDirectory` (a path or a descriptor), `.inherit` on Darwin, `.closeAll(from:)` on Linux and FreeBSD |
| `posix_spawnattr_t` | `SpawnAttributes`, `.Flags`, `.ProcessGroup` | `processGroup` (`.new`, `.existing`), `signalMask`, `defaultSignals`, `qualityOfService` on Darwin; `Flags`: `resetIDs`, `createSession`, and on Darwin `closeOnExecByDefault` and `startSuspended` |
| `execve`, `execvp`, `posix_spawn` with `POSIX_SPAWN_SETEXEC` | `ProcessID.execute(_:arguments:environment:)`, `execute(searchingPathFor:arguments:)`, and on Darwin `execute(_:arguments:environment:fileActions:attributes:)` | return `Never` |
| an unreaped child | `ChildProcess` | noncopyable owner: `spawn`, `init(taking:)`, `id`, `wait()`, `tryWait()`, `sendSignal(_:)`, `relinquish()`; `openDescriptor(options:)` on Linux |
| `getrlimit`, `setrlimit`, `struct rlimit` | `ResourceLimit`, `.Value`, `.Resource` | `ResourceLimit.current(for:)`, `setCurrent(_:for:)`; `Value.unlimited` |
| `setuid`, `seteuid`, `setreuid`, and the group versions, `setgroups`, `initgroups` | `UserID.set(_:)`, `setEffective(_:)`, `set(real:effective:)`, the same on `GroupID`, `GroupID.setSupplementary(_:)`, `setSupplementary(forUser:including:)` | next to the getters in `Identifiers.swift` |
| `pidfd_open`, `pidfd_send_signal`, `waitid(P_PIDFD)` | `ProcessDescriptor` | Linux and Android |
| `signalfd`, `struct signalfd_siginfo` | `SignalDescriptor`, `.Information` | Linux and Android |
| `close_range`, `closefrom` | `FileDescriptor.closeAll(from:through:)`, `setCloseOnExecForAll(from:through:)` | Linux, Android, FreeBSD, OpenBSD (closing only), and macOS, which lists the process's descriptors instead |

`CInterop` gains `SignalSet`, `SignalAction`, `SignalInfo`, `ResourceLimit`,
and `ResourceLimitValue`. Everything is `@available(System 199, *)`, on every
platform but Windows and WASI; the spawn API is also missing on watchOS and
tvOS, where `posix_spawn` is unavailable, and on Android (design call 9).

## Design calls

Each with the alternative it rejects.

1. **`Signal` is a struct of a signal number, like `Errno`.** Names follow
   the two earlier drafts (`milseman/process_ego` and `dev/rauhul/posix`)
   where they agree, and describe the signal where the C name abbreviates:
   `terminalStop`, `backgroundRead`, `ioPossible`, `cpuTimeLimitExceeded`,
   `userDefined1`. `stop` and `continue` match the wait API's `.stopped` and
   `.continued`. Rejected: swift-subprocess's `suspend`, `resume`, and
   `terminalClosed`, which name one use of SIGSTOP, SIGCONT, and SIGHUP; an
   enum, which can't hold the numbers a platform adds; and `Codable`, since
   numbers differ between platforms (SIGUSR1 is 30 on Darwin and 10 on
   Linux), which adding later doesn't break. swift-subprocess has its own
   `public struct Signal`, so a file that imports both gets an ambiguity;
   the migrate-subprocess lane would typealias or convert. Confidence: high.

2. **`SignalSet` is a set of `Signal`s**: `SetAlgebra`, `Hashable` by its
   members rather than its bytes, and a `Sequence` in increasing order. A set
   holds only the numbers from 1 through `NSIG - 1`, which it checks itself:
   Darwin's `sigaddset` accepts 0 and shifts by it (found by a test). A
   number the C library reserves, such as glibc's 32 and 33, is left out
   rather than trapping, so a loop that inserts every number up to `NSIG`
   gets exactly the signals that exist. Rejected: `Set<Signal>` at the API, which each call
   would convert. Confidence: high.

3. **The handler decides `SA_SIGINFO`.** `Signal.Handler` is `.default`,
   `.ignore`, `.function`, or `.functionWithInfo`, and encoding an action
   sets `SA_SIGINFO` exactly when the handler takes the information, which C
   leaves the caller to keep consistent with `sa_handler` or
   `sa_sigaction`. A handler is a `@convention(c)` function, since a signal
   interrupts arbitrary code and Swift can't make a closure safe there; its
   documentation lists what a handler may do. The handler's union is read and
   written through a CSystem shim, since every C library names it
   differently (SwiftPM's Cancellator spells out four). Rejected: a Swift
   closure registry behind one C handler, which would run Swift code in a
   handler. Confidence: high.

4. **The calling thread's signal state goes on `PThread`**, next to
   `setCurrentName(_:)` and `currentAffinity()`, which the Threads lane left
   to this one. The mask calls can't fail, so they don't throw, and they're
   `noasync`, since an async function can resume on another thread.
   Rejected: a `sigprocmask` wrapper, which POSIX leaves unspecified in a
   multithreaded process, as every Swift process is; and hosting them on
   `SignalSet`, which reads as changing the set. Confidence: medium-high.

5. **Sending never reaches kill's special IDs by accident.** `kill` gives 0,
   -1, and negative IDs other meanings, so `sendSignal` throws
   `invalidArgument` for a nonpositive ID, and those meanings get their own
   methods: `sendSignalToProcessGroup` (`killpg`, which also rejects IDs
   below 2, since glibc's `killpg(1)` is `kill(-1)`) and
   `sendSignalToAllProcesses`. SwiftPM's AsyncProcess sends `kill(-pid, …)`,
   which becomes `kill(0, …)`, SwiftPM's own group, if a signal arrives
   before `posix_spawn` fills in the ID (from reading `AsyncProcess.swift`,
   where `processID` is 0 until then). A `nil` signal sends none and
   checks for the process, as Rust nix's `kill(pid, None)` does. Rejected:
   passing the ID through, as C does. Confidence: high.

6. **Process groups and sessions are `ProcessID`s**, as
   `TerminalDescriptor.foregroundProcessGroup()` and `sessionID()` already
   return. `setProcessGroup(_:)` takes the process's own ID for a new group,
   rather than C's 0. Rejected: a `ProcessGroupID` type, which the existing
   API would contradict. Confidence: high.

7. **Two results for waits.** `ExitStatus` (`.exited(CInt)`,
   `.signaled(Signal, coreDumped:)`) is what a termination-only wait
   returns, so callers don't handle stops they didn't ask for;
   `ProcessStateChange` adds `.stopped` and `.continued`. Decoding goes
   through CSystem shims of the `W*` macros, since each platform encodes a
   continued process differently, where SwiftPM and TSC reimplement them in
   Swift (without stops or core dumps). Rejected: one enum of all four
   cases, and the name `TerminationStatus`, swift-subprocess's.
   Confidence: medium-high.

8. **Waits:** `wait()` and `tryWait()` (`waitpid`) for the common cases,
   `wait(for:)` (`waitid`) for stops, continues, and `keepWaitable`
   (`WNOWAIT`), which is how swift-subprocess checks for an end without
   reaping. Blocking waits are `noasync`, as `PThread.join()` is; async code
   waits for the exit event (kqueue's `EVFILT_PROC` or a pidfd) and calls
   `tryWait()`. `tryWait` follows `PThread.Mutex.tryLock`'s name. Rejected:
   only one of the two calls, since SwiftPM uses `waitpid` and
   swift-subprocess `waitid`.
   Confidence: medium-high.

9. **Spawning has a raw and an owned form**, as `FileDescriptor.open` and
   `OwnedFD.open` do: `ProcessID.spawn` returns the ID, and
   `ChildProcess.spawn` an owner.
   - `arguments` include the first, the program's name, as C's argv and
     every adopter's arrays do. Rejected: Foundation's convention, which
     can't express a first argument that isn't the path (login shells,
     multi-call binaries).
   - `environment` is `NAME=value` strings, or `nil` for the calling
     process's, which a CSystem shim reads (`_NSGetEnviron()` on Darwin,
     where a library can't refer to `environ`).
   - File actions are an array of an opaque `SpawnFileAction` built with
     static factories, so a spawn takes an array literal. Rejected: a
     public enum, whose platform-specific cases every switch would need
     `#if` for.
   - `SpawnAttributes` properties set their flags: `processGroup` sets
     `POSIX_SPAWN_SETPGROUP`, `signalMask` `SETSIGMASK`, and so on; every
     adopter sets both by hand, and swift-subprocess drops the `setpgroup`
     result. A new group is `.new`, not C's pgroup 0.
   - **By default, a child starts with nothing blocked and every signal's
     default action** (`signalMask: []`, `defaultSignals: .all`), what both
     adopters configure for every spawn. C passes on the spawning thread's
     mask, and Swift concurrency's threads block SIGTERM (`Verify/P1`), so a
     child spawned from async code with C's defaults can't be asked to end;
     the deinit harness found this. It also passes on ignored signals, and
     NIO ignores SIGPIPE for the whole process. `nil` passes them on.
     Rejected: C's defaults, documented, which leave the hazard on the
     default path.
   - The chdir actions go through a CSystem shim that picks
     `posix_spawn_file_actions_addchdir` on macOS 26, the `_np` form
     elsewhere, and `ENOSYS` where neither exists (iOS, glibc before 2.29,
     Bionic before 34, OpenBSD), as TSC's shim does.
   - Not on Android: `posix_spawn` needs API level 28, Swift's Android
     SDK defaults to 21, and TSC needed a shim for the NDK's changing
     nullability. Rejected: shimming every spawn call through CSystem, for
     now.
   Confidence: medium-high; the defaults are the call most worth reviewing.

10. **`execute` returns `Never`**, so it returns only by throwing. On
    Darwin, a variant with file actions and attributes is `posix_spawn` with
    `POSIX_SPAWN_SETEXEC`, which does SwiftPM's safeExec in one call with
    `closeOnExecByDefault`. Confidence: high.

11. **`ChildProcess` reaps exactly once.** Until then, the child's ID can't
    be reused, so its `sendSignal` can't reach another process, which
    SwiftPM's AsyncProcess can after it reaps. `tryWait()` is `mutating` and
    remembers the status, so an event loop reaps without giving up the
    owner; a consuming `tryWait` can't return the owner when the child is
    still running. `wait()` consumes it, and retries `EINTR`, so a wait can't
    lose an unreaped owner; `id.wait(retryOnInterrupt: false)` waits
    interruptibly. `relinquish()` and `init(taking:)` follow `OwnedFD`. The
    deinit is the open question below. Confidence: high, except the deinit.

12. **`ResourceLimit`** is soft and hard `Value`s, with `.unlimited` for
    `RLIM_INFINITY`, whose macro doesn't import and whose value differs
    between platforms. `current(for:)` and `setCurrent(_:for:)` follow
    `FilePath.currentWorkingDirectory()`. Rejected: optionals for no limit,
    since `nil` means "unchanged" elsewhere in the package. Confidence: high.

13. **Credentials** go next to their getters: `UserID.set(_:)` is `setuid`,
    `setEffective(_:)` `seteuid`, `set(real:effective:)` `setreuid`, with
    `nil` for C's -1, and the same on `GroupID`, plus `setSupplementary`.
    They act on the calling process: `posix_spawn` can't change a child's,
    so swift-subprocess keeps its fork-exec shim for that. Rejected: C's
    names, and a credentials type. Confidence: medium; `UserID.set(_:)` is
    terse.

14. **Linux owners follow `Prototype/Subtypes`**: `ProcessDescriptor` and
    `SignalDescriptor` hold an `OwnedFD`, with no deinit of their own, and
    the same five ownership members as the Events lane's owners. Owning a
    pidfd is an obligation to close it, not to reap. The platform-enum
    lane's simulated stand-in has the same shape, but takes a `CInt` signal
    and returns a raw status. Confidence: medium; unverified.

15. **Closing descriptor ranges**: `close_range` where it exists, `closefrom`
    on OpenBSD, and on macOS a listing of the process's descriptors
    (`proc_pidinfo(PROC_PIDLISTFDS)`), as glibc's `closefrom` falls back to
    listing `/proc/self/fd`. Darwin has no system call for it; SwiftPM's
    safeExec loops over every number up to `getdtablesize()`, which can be a
    million. For spawning, `closeOnExecByDefault` on Darwin and the
    `closeAll(from:)` file action on Linux do it in the child, atomically.
    Confidence: medium.

## Destroying an unreaped `ChildProcess`

**Status: open.** The package's `ChildProcess` ends a running child with
SIGKILL and reaps it, and only reaps one that already ended. That's a default
to measure the others against, not a decision. It's the same question as
`OwnedFD`'s close policy (decisions item 54, `Prototype/CloseErrors`) and
`PThread`'s deinit (item 80, `Prototype/ThreadDeinit`).

Before it signals, the default checks with `waitid(WNOHANG | WNOWAIT)` that
the child is still its unreaped child: if something else reaped it, such as a
`SIGCHLD` handler that waits for any child, its ID may name another process,
which a SIGKILL must not reach.

### Policies

| policy | deinit | precedent |
|---|---|---|
| kill (the package's default) | SIGKILL if it's running, then reap | swift-subprocess's teardown when a body throws or its task is cancelled: `teardownSequence` defaults to `[]`, and every sequence ends with SIGKILL (`Teardown.swift:202`); Boost.Process's `child`, whose destructor ends a child it didn't detach |
| wait | reap, waiting for the child to end | `PThread`'s join-on-deinit |
| terminate | SIGTERM, a grace period (one second here), SIGKILL, then reap | swift-subprocess with a `.gracefulShutDown` step; SwiftPM's Cancellator (SIGINT, then SIGKILL) |
| reap | reap only if it already ended (`WNOHANG`) | |
| leak | nothing: the child runs on, and stays a zombie when it ends | Rust's `std::process::Child`; a forgotten `pid_t` in C |
| trap | trap whenever the deinit runs | C++'s `std::thread`, for threads |

### The harness

`Deinit/run.sh` builds `OwnedChild.swift`, a model of `ChildProcess` with real
children, with `Scenarios.swift` and `main.swift`, once per policy
(`-D POLICY_...`), and runs each scenario in its own process. A scenario that
traps shows as TRAP, and one that `alarm(5)` ends as HANG. "running" and
"zombie" are the child's state after its owner's scope; "dropped" counts the
errors a deinit couldn't report. The `must-wait:` rows are the same code
rewritten to satisfy the trap policy.

```sh
./Prototype/Processes/Deinit/run.sh
```

Output with Swift 6.2 on macOS 26.3:

| scenario | modeled on | kill | wait | terminate | reap | leak | trap |
|---|---|---|---|---|---|---|---|
| explicit-wait | ChildProcessTests.testSpawnAndWait | ok | ok | ok | ok | ok | ok |
| scope-exit | ChildProcessTests.testDestroyingARunningChild... | ok | HANG | ok | running after scope exit | running after scope exit | TRAP |
| ended-then-dropped | ChildProcessTests.testDestroyingAnEndedChild... | ok | ok | ok | ok | zombie after scope exit | TRAP |
| error-exit | ChildProcessTests.testDestroyingAChild...WhenAnErrorEnds... | threw Stop | HANG | threw Stop | threw Stop; running after scope exit | threw Stop; running after scope exit | TRAP |
| stdin-from-owner | process-run's pipes: cat reads a pipe the parent owns | ok | HANG | ok | running after scope exit | running after scope exit | TRAP |
| work-in-progress | a child that finishes its work after its owner's scope | work unfinished | ok | work unfinished | ok | ok | TRAP |
| ignores-SIGTERM | a child that traps SIGTERM, which teardown must escalate | ok | HANG | scope exit blocked 1015 ms | running after scope exit | running after scope exit | TRAP |
| loop-forgotten | a loop that starts a child per item and drops it | loop took 15 ms | loop took 1276 ms | loop took 147 ms | loop took 20 ms; 20 of 20 zombies after the loop | loop took 21 ms; 20 of 20 zombies after the loop | TRAP |
| class-field | a process manager's child in a class, released | ok | scope exit blocked 303 ms | ok | running after scope exit | running after scope exit | TRAP |
| async-scope-exit | an owner destroyed in an async function | ok | blocked a cooperative thread 305 ms | ok | running after scope exit | running after scope exit | TRAP |
| reaped-through-hatch | a SIGCHLD handler that reaps any child | dropped ECHILD | dropped ECHILD | dropped ECHILD | dropped ECHILD | ok | TRAP |
| SIGCHLD-ignored | a process that ignores SIGCHLD, so children never become zombies | dropped ECHILD | scope exit blocked 307 ms; dropped ECHILD | dropped ECHILD | running after scope exit | running after scope exit | TRAP |
| relinquish-and-reap | process-pipeline, which keeps IDs | ok | ok | ok | ok | ok | ok |
| must-wait: scope-exit | scope-exit | ok | ok | ok | ok | ok | ok |
| must-wait: error-exit | error-exit | threw Stop | threw Stop | threw Stop | threw Stop | threw Stop | threw Stop |
| must-wait: class-field | class-field | scope exit blocked 329 ms | scope exit blocked 316 ms | scope exit blocked 322 ms | scope exit blocked 312 ms | scope exit blocked 314 ms | scope exit blocked 303 ms |

Timings vary from run to run. The scope-exit children sleep 30 seconds, the
class and async ones 0.3.

### The same policies on the package

`Deinit/run-package.sh` patches each policy into `ChildProcess._destroy` in a
copy of the package, then runs each of the 36 tests in `ChildProcessTests`,
`SpawnTests`, and `ProcessWaitTests` in its own process, and three runs of the
samples that start children:

| policy | tests (36) | samples |
|---|---|---|
| kill | 36 pass | all run |
| wait | 33 pass; 1 fails; 2 hang | all run |
| terminate | 35 pass; 1 fails | all run |
| reap | 33 pass; 3 fail | all run |
| leak | 32 pass; 4 fail | all run |
| trap | 32 pass; 4 trap | all run |

`testDestroyingSignalsOnlyAnUnreapedChild`, a mock test that the deinit
signals only a child it hasn't lost, checks for the SIGKILL, so every other
policy fails it, as `PThreadMockTests` checks for the join. Under wait,
`testDestroyingARunningChildEndsAndReapsIt` and
`testDestroyingAChildEndsItWhenAnErrorEndsTheScope` hang: the deinit waits
for their 60-second children. Terminate passes them, since `sleep` ends on
SIGTERM. Reap and leak fail them, with the child still running, and leak
fails `testDestroyingAnEndedChildReapsIt` too, with a zombie. Trap traps in
all four. The samples wait for or relinquish every child, so the policy
doesn't reach them.

The first run of this script found two problems in the tests, fixed since. A
test that failed or trapped left its `sleep 60` child holding the test
runner's output open, so the script reported it as a hang; the wait tests'
children now write to `/dev/null`. And
`testAMissingProgramThrowsAndLeavesNoChild` flaked under every policy:
Darwin briefly shows a child after a failed spawn (see
[Other findings](#other-findings)); it now waits with a blocking wait.

### What the results show

No policy is free, and the costs differ from the thread case.

- **Kill** makes a child end with the scope that started it, errors
  included, and never blocks for long: a SIGKILL can't be caught, so the
  reap follows at once, and a loop that drops its children stays fast. Its
  cost is work the child hadn't finished (`work-in-progress`): a child meant
  to outlive its owner must be relinquished. It also skips the child's own
  cleanup, since SIGKILL can't be handled.
- **Wait** is `PThread`'s join, and blocks the same way, but a child is far
  likelier than a thread to run for a long time or forever. It hangs on a
  child that runs longer than its scope (`scope-exit`, `error-exit`), and
  deadlocks on one that reads a pipe whose other end the parent closes only
  after the owner (`stdin-from-owner`), which is how `process-run`,
  swift-subprocess, and AsyncProcess feed a child. It serializes a loop that
  drops its children, and blocks a class's releaser and a cooperative thread
  for the child's lifetime.
- **Terminate** lets the child clean up, and so costs a grace period for a
  child that ignores SIGTERM (`ignores-SIGTERM`), during which the deinit
  blocks. It's the right teardown for a caller that can wait, such as an
  async `run` whose scope ends; in a deinit, the grace period is blocking
  that nothing at the call site shows.
- **Reap** fixes only children that already ended, and leaves every other
  one a zombie when it ends: all 20 of the loop's.
- **Leak** is C's behavior. Each forgotten child holds a process-table entry
  until the parent exits, and a long-running server that forgets them runs
  out.
- **Trap** turns a forgotten `wait()` into a crash where it happened, error
  unwinding included: it trapped in 11 of the 13 ordinary scenarios.
  Satisfying it costs a `do`/`catch` per throwing scope, since `defer` can't
  consume (V11a).

Every policy that waits or signals acts on an ID that something else may
already have reaped (`reaped-through-hatch`, `SIGCHLD-ignored`). A reaped ID
can name a new process, which a wait can't reach but a signal can: that's why
the kill and terminate policies peek first. The peek narrows the race to a
reap that happens between it and the signal, on another thread; a pidfd on
Linux would close it.

How this relates to the other ownership questions:

- For `OwnedFD`, the quiet cleanup, closing, is cheap and finishes nothing.
  For a thread, the cleanup that finishes the work, joining, is the costly
  one. A process has a third option that neither has, ending the child,
  which is cheap and never blocks, but discards its work.
- The default here differs from `PThread`'s (join), because a thread can't
  be ended safely and a process can. If the package wants one rule for
  every owner, it's "the owner's end is the end of what it owns": close,
  join, or kill.

What would help decide: how adopters drop children. swift-subprocess never
drops one: its `run` waits for the child, and on cancellation or an error
tears it down with its `TeardownStep`s before reaping, by default SIGKILL
alone, which is the kill policy. SwiftPM's AsyncProcess is a class with no deinit, so a
dropped process runs on and is never reaped (leak), and its Cancellator
terminates what's registered when SwiftPM is interrupted.

## Adopter coverage

The `Utilities/adopter-coverage/mapping.ini` entries this API covers, for the
coverage lane to update:

| entry | status | covering API | what's left |
|---|---|---|---|
| `[posix_spawn]` | covered, except Android | `ProcessID.spawn`, `ChildProcess.spawn`, `SpawnFileAction`, `SpawnAttributes` (QoS through `PThread.QoSClass`) | Android; swift-subprocess's `_subprocess_spawn` shim, whose prefork path sets credentials |
| `[fork and exec]` | partial | `ProcessID.execute` (`execve`) | `fork`, deliberately; `_subprocess_fork_exec` stays C |
| `[wait]` | covered | `wait`, `tryWait`, `wait(for:)`, `waitForAnyChild`, `WaitOptions`, `ExitStatus`, `ProcessStateChange`, `Signal.Information`, `CInterop.SignalInfo` | |
| `[process descriptors]` | partial | `ProcessDescriptor` (pidfd, `waitid(P_PIDFD)`) | FreeBSD's `pdfork`, `pdkill`, `EVFILT_PROCDESC` |
| `[process groups and sessions]` | covered | `ProcessID.createSession()`, `setProcessGroup(_:)`, `SpawnAttributes.processGroup`, `.createSession` | |
| `[process credentials]` | covered for the calling process | `UserID.set(_:)`, `GroupID.set(_:)`, `GroupID.setSupplementary(_:)` | a child's credentials, which `posix_spawn` can't set |
| `[resource limits]` | covered | `ResourceLimit.current(for:)`, `setCurrent(_:for:)`, `CInterop.ResourceLimit` | |
| `[SIGPIPE]` | covered | `Signal.brokenPipe.setAction(.ignore)` | |
| `[signal numbers]` | covered | `Signal`'s constants; `SignalSet.all` for the `NSIG` loops | `NSIG` itself |
| `[kill]` | covered | `sendSignal(_:)`, `sendSignalToProcessGroup(_:)`, `nil` for signal 0 | |
| `[signal masks]` | covered | `SignalSet`, `PThread`'s mask operations, `SpawnAttributes.signalMask` and `defaultSignals` | `sigprocmask`, deliberately |
| `[signal dispositions]` | covered | `Signal.Action`, `setAction(_:)` | `signal(3)` itself; `_subprocess_install_sigchld_handler` becomes `Signal.childStatusChange.setAction(_:)` |
| `[closing inherited descriptors]` | covered on Linux, FreeBSD, OpenBSD, macOS | `FileDescriptor.closeAll(from:through:)`, `setCloseOnExecForAll(from:through:)`, the spawn actions | iOS and the other Darwin platforms |
| `[exit]` | missing | | `_exit` and `exit` weren't in scope |

What each adopter's code could replace, by file:

- **swift-subprocess**
  - `Platforms/Subprocess+Darwin.swift`: the whole `posix_spawn` setup
    (`adddup2`, `addclose`, `addchdir_np`, `setsigmask`, `setsigdefault`,
    `setpgroup`, `POSIX_SPAWN_CLOEXEC_DEFAULT`, `set_qos_class_np`) becomes a
    `ProcessID.spawn` with `SpawnFileAction`s and `SpawnAttributes`; its
    prefork path for `createSession` could use `.createSession`, but not for
    user and group IDs.
  - `Platforms/Subprocess+Unix.swift`: `Signal`, `send(signal:toProcessGroup:)`
    (`kill`, `kill(-pid)`), `_waitid`, `_blockingReap`, `_reap`,
    `_peekIfExited`, the `TerminationStatus` decoding, and the `si_status` and
    `si_pid` accessors for OpenBSD, Glibc, Musl, and Bionic.
  - `Platforms/Subprocess+Linux.swift`: `_pidfd_open`, `_pidfd_send_signal`,
    and the `P_PIDFD` probe (`ProcessDescriptor`); the SIGCHLD handler's
    installation (`Signal.Action` with `.restart` and `.noChildStop`); the
    empty `epoll_pwait` mask (`SignalSet()`).
  - `Teardown.swift`: `kill(pid, 0)` (`sendSignal(nil)`).
  - `_SubprocessCShims/process_shims.c`: the dead `W*` shims
    (`ExitStatus(waitStatus:)`) and `_subprocess_nofile_soft_limit`
    (`ResourceLimit`). The fork-exec shim stays: Swift can't run between
    `fork` and `exec`.
- **SwiftPM**
  - `Sources/Basics/Concurrency/AsyncProcess.swift`: `posix_spawnp`, its
    attributes and file actions, the `SPM_posix_spawn_file_actions_addchdir_np`
    shim (TSC's), `waitpid` and the reimplemented `W*` macros, and
    `kill(-pid)`. Throwing waits would fix the waitpid error that becomes
    `.terminated(code: 0)`, and `sendSignal` the `kill(-0)` window.
  - `Sources/Basics/Cancellator.swift`: `signal(SIGINT, SIG_IGN)`, the
    per-libc `sigaction` union code that restores `SIG_DFL`, and
    `kill(getpid(), SIGINT)`.
  - `Sources/Commands/Utilities/TestingSupport.swift` (`safeExec`): the
    signal reset loop (`SignalSet.all`, which skips glibc's reserved numbers
    that SwiftPM's loop warns on), `sigprocmask`, the `closefrom` and
    `FD_CLOEXEC` loops (`setCloseOnExecForAll(from:)`), and `execv`
    (`ProcessID.execute`); on Darwin, all of it is one `execute` with
    `closeOnExecByDefault`.
  - `Sources/SwiftPMBuildServer/DisableSigpipe.swift`: `signal(SIGPIPE, SIG_IGN)`.
  - TSC's `misc.swift` `exec(path:args:)`.
- **NIO**
  - `Sources/NIOPosix/SocketProtocols.swift`: the Linux, Android, and OpenBSD
    `signal(SIGPIPE, SIG_IGN)`, with its per-libc branches, and a result that
    it now can't ignore. That's NIO's only use of this API; Darwin's
    `F_SETNOSIGPIPE` was already covered.

The package's own samples also call C for things this API covers:
`JobControl.swift` (`getpgrp`, `getsid`), `PIDFile.swift` (`kill(pid, 0)`),
`SignalIO.swift` (`signal`, `sigprocmask`, `sigwait`), and the platform-enum
lane's `PlatformProcess.swift` and `Samples/Processes.swift` (`kill`,
`waitpid`, `posix_spawn`); they belong to other lanes.

## Deliberately not wrapped

- `fork`, `vfork`, `clone3`: only async-signal-safe code may run between a
  fork and an exec in a multithreaded process, which Swift can't promise.
  `posix_spawn` is the Swift path; code that needs more stays in C, as
  swift-subprocess's fork-exec shim does.
- `signal(3)`: `setAction(_:)` covers it, with defined semantics.
- `sigprocmask`: see design call 4.
- `sigaltstack`, `sigqueue`, `sigtimedwait`, `sigwaitinfo`, real-time signals
  (`SIGRTMIN` is a function call on glibc), `prlimit`, `setresuid` and
  `getresuid`, `wait4`'s resource usage, the `posix_spawnattr` scheduling
  calls, and Darwin's private spawn attributes (user, group, login,
  responsibility): each a small addition, none needed by the adopters.
- `_exit` and `exit`: outside this lane's scope; the `[exit]` entry stays
  missing.

## Unverified off Darwin

Nothing here has been compiled against Glibc, Musl, Bionic, or FreeBSD.
`check-linux.sh` builds the module for macOS with the Linux conditions on,
against `LinuxModel/ProcessesLinuxModel.h`, and compiles the Linux tests
through SIL; it passes. It can't check an `#elseif os(Linux)` after a Darwin
branch, anything Android-only, or differences from a real C library.
Unverified:

- the CSystem shims: the `W*` macros, the `siginfo_t` and `sigaction`
  accessors, `csystem_environ` (glibc declares `environ` only with
  `_GNU_SOURCE`, which `shims.c` defines), the chdir and closefrom spawn
  actions and their `__GLIBC_PREREQ` and `__ANDROID_API__` checks, the raw
  `pidfd_open`, `pidfd_send_signal`, and `close_range` system calls, and the
  `signalfd_siginfo` mirror and its `_Static_assert`;
- the constants spelled out for Linux (`RLIMIT_*`, `POSIX_SPAWN_SETSID`,
  `P_PIDFD`), `SA_RESETHAND`'s unsigned literal, glibc's anonymous-enum
  `CLD_*`, and Bionic's `idtype_t`, an `int`;
- the posix_spawn storage types on glibc and Musl (structures) and FreeBSD
  and OpenBSD (pointers), and FreeBSD's different `POSIX_SPAWN_*` values;
- whether `struct sigaction`'s and `siginfo_t`'s members are attributed to
  CSystem on Glibc (`Tests/MemberImportVisibility/ProcessesProbe.swift`),
  since `io_uring.h` includes `<signal.h>`;
- `ProcessDescriptor`, `SignalDescriptor`, `close_range`, and their tests
  (`LinuxProcessTests.swift`), and the samples' Linux branches;
- Android, where only the signal, wait, group, limit, and credential calls
  are built, all of them in Bionic at API level 21.

## Other findings

Darwin behaviors that its headers don't describe (macOS 26.3):

- `sigaddset` accepts signal 0, and returns success.
- A signal from `raise`, which is `pthread_kill`, arrives with `si_code` 0,
  not `SI_USER`, though `si_pid` is the sender.
- `setrlimit(RLIMIT_NOFILE)` accepts any soft limit, `RLIM_INFINITY`
  included, where the man page and older releases require at most
  `OPEN_MAX`.
- `waitpid` supports `WCONTINUED`, and reports a continued child as one
  stopped by SIGCONT.
- A `posix_spawn` that fails, with `ENOENT` for a missing program, leaves a
  child for a moment, which the system then removes: in 182 of 200 tries, a
  `WNOHANG` wait for any child right after the failure reported a running
  child, and a blocking one then failed with `ECHILD` every time. So
  `tryWaitForAnyChild()` can return `nil` just after a failed spawn;
  `SpawnTests` flaked on it until it used a blocking wait.
- An ignored signal is discarded when it's generated, even while it's
  blocked, so `sigwait` never takes it. A non-interactive shell starts a
  background job with SIGINT and SIGQUIT ignored, which is how the
  `process-signals` sample first missed a SIGINT.

Swift:

- Swift concurrency's threads block SIGTERM, among others, and a child
  inherits the spawning thread's mask (`Verify/P1`).
- Swift 6.2's move checker reports "copy of noncopyable typed value. This is
  a compiler bug" for a noncopyable `let` that a `do`/`catch` initializes
  (`check-linux.sh` found it in a test).
- An XCTest assertion's autoclosure can't consume a noncopyable value, so a
  test binds `child.wait()`'s result before asserting on it.
- An Array can't hold `ChildProcess` owners, so `process-pipeline` keeps IDs,
  as the Threads lane's samples keep thread IDs.
- ArgumentParser's `.captureForPassthrough` keeps a leading `--`.

## Files

- `Sources/System/Processes/`, `Internals/Syscalls+Processes.swift`,
  `Internals/Constants+Processes.swift`, and the shims at the end of
  `Sources/CSystem/include/CSystemShared.h`, `CSystemLinux.h`, and
  `shims.c`.
- `Tests/SystemTests/`: `SignalTests.swift` (swift-testing),
  `SignalActionTests.swift`, `SignalMockTests.swift`,
  `ProcessWaitMockTests.swift`, `ProcessWaitTests.swift`, `SpawnTests.swift`,
  `ProcessTestSupport.swift`, `ProcessResourceLimitTests.swift`,
  `CloseDescriptorsTests.swift`, and `LinuxProcessTests.swift`; and
  `Tests/MemberImportVisibility/ProcessesProbe.swift`.
- `Sources/Samples/Process*.swift`: `process-run`, `process-pipeline`,
  `process-signals`, `process-limits`, `process-exec`.
- `check-linux.sh` and `LinuxModel/`, `Deinit/` (the policy harness), and
  `Verify/P1_concurrency_threads_block_signals.swift`.
