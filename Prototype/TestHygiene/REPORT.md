# Test hygiene: report

Lane `test-hygiene`, branch `test-hygiene`, from system-next `7b0875f`. Goal: no test
passes or fails depending on machine load, timing, parallelism, disk state, or what
else runs. The rules applied are in `Tests/TESTING.md`.

Figures here come from `Prototype/TestHygiene/stress.sh`, which builds, starts CPU
loaders (`yes > /dev/null`), runs `swift test` and `swift test --parallel` repeatedly,
and lists each run's failures. Its logs go to `.build/hygiene-logs/`, which isn't
committed.

## 1. Inventory

Every test that depends on time or on state it shares, found by reading the test
targets (180 files) for sleeps, deadlines, clocks, scheduling, sampled values,
process-wide state, fixed names, and interruption races. File and line are at
`7b0875f`. "Seen" means it failed in the loaded runs of section 2.

swift-testing runs its tests in parallel threads of one process; XCTest runs one
test at a time in another process, and with `--parallel` each XCTest test runs in a
process of its own, beside the others. So process-wide state is a hazard only for
swift-testing tests, while system-wide state (files, names, the process table, the
disk) is shared by everything, including other checkouts' test runs.

### 1a. Scheduling

| Where | Test | Failure mode |
|---|---|---|
| `PThreadTests.swift:271` | `setCurrentQualityOfService` | **Seen, 8 of 10 runs.** The thread lowers itself to background QoS, then opens `ready`. A background thread gets no processor for many seconds on a busy machine, so `ready.wait()` (10 s) fails. The QoS the test then reads is still default (21): `pthread_set_qos_class_self_np` writes the TSD slot that `pthread_get_qos_class_np` reads in user space, after the kernel call returns, so the starved thread hasn't even recorded its new class. |

### 1b. Values sampled at two moments

| Where | Test | Failure mode |
|---|---|---|
| `AttributeListTests.swift:204` | `testVolumeAttributes` | **Seen, 3 of 10.** getattrlist's available space against statfs's a moment later; anything that writes to the disk in between changes it. |
| `LibProcTests.swift:166` | `testLists` | proc_listpids against sysctl's process table, needing 90% overlap. Under enough process churn (builds) more than a tenth can come and go between the calls, since the thread can be descheduled between them. |
| `ProcessCredentialsTests.swift:63` | `aUsersGroups` | System's group list against `getgrouplist` a moment later. Changes only if the directory service's answer changes; low. |
| `ProcessResourceTests.swift:63` | `testProcessorTimes` | proc_pid_rusage's user time bracketed by two getrusage calls. Sound if both read the same counter, which the passes suggest; kept. |

### 1c. Upper bounds on elapsed time, and events assumed to happen within a time

| Where | Test | Failure mode |
|---|---|---|
| `KernelQueueTests.swift:160` | `testOneShotTimer` | **Seen, 1 of 10.** Expects `data == 1` for a one-shot 10 ms timer; Darwin reports how many intervals passed before the event was read, 3 when the poll ran 30 ms late. |
| `KernelQueueTests.swift:173` | `testRepeatingTimerInNanoseconds` | Sleeps 30 ms, then polls without waiting and expects the timer to have fired; a timer that the kernel defers past the sleep fails the unwrap. |
| `KernelQueueTests.swift:230` | `testFullSpanDoesNotWait` | Asserts a call took under 5 s. |
| `MachTimeTests.swift:93` | `testInstants` | Compares an interval read with Mach time to one read with `SuspendingClock`, starting the Mach one first and ending it first; a preemption between the two starts makes the Mach interval longer by the delay. |
| `ProcessTimerTests.swift:53,57,87` | `testSettingAndReadingEachTimer`, `testAlarmSetsTheRealTimer` | A 100 s timer must read more than 99 s: fails if the thread is descheduled for a second. |
| `ProcessTimerTests.swift:92` | `testAlarmSetsTheRealTimer` | 2.4 s must round up to 3: fails if 0.4 s pass between setting and reading. |
| `ProcessTimerTests.swift:80` | `testAnExpiredOneShotTimerIsDisarmed` | Sleeps 100 ms for a 10 ms timer. Sound on Darwin, whose getitimer compares with the clock; Linux reports 1 µs left until the hrtimer has fired, which a delayed timer interrupt (a VM's vCPU) postpones. |
| `ProcessWaitTests.swift:42` and `SpawnTests.swift:153-205`, `LinuxProcessTests.swift:49`, `ProcessPriorityTests.swift:55` | tests with `sleep 10` or `sleep 30` children | Assume the child is still running when the test signals, stops, or reprioritizes it, 10 or 30 s after spawning it. |
| `ProcessWaitTests.swift:175` | `testDestroyingARunningChildEndsAndReapsIt` | Asserts the deinit took under 10 s. |
| `SignalInterruptTests.swift:180-184` | `testReadRetriesOnlyWhenAsked`, `testWriteRetriesOnlyWhenAsked`, `testSpanWriteAllRetriesOnlyWhenAsked` | Sends 20 signals 5 ms apart, 10 ms after the thread starts. If the thread hasn't entered the blocking call by the last one, nothing interrupts it, and the `retryOnInterrupt: false` case gets 1 byte instead of EINTR. |
| `WriteAllInterruptTests.swift:144-148` | `testSpanWriteAllRetriesOnlyWhenAsked` | The same, with 40 signals. |
| `StatTests.swift:249` | `times` | The new directory's times must be within 4 s of a clock read made before creating it. |
| `EventPollTests.swift:198` (Linux) | `testOneShotTimer` | Reads a 10 ms timer's time left right after setting it and expects it positive; 10 ms of delay disarms it. |
| `IORingTests.swift:478` (Linux) | `testPollAddMultiShotRearmsAcrossEvents` | Retries 100 times, 1 ms apart, for the cancelled poll's completion. |
| `SocketIPMessagesTests.swift:164` | `receivesIPv4DatagramInformation` | The arrival timestamp must be within 60 s of `time(nil)`. |
| `SocketTCPInfoTests.swift:98` (Linux) | `aConnectionsLife` | Expects the client's acknowledged byte count right after the server read the data; the ACK can still be in flight. |

### 1d. Waits whose timeout is only a hang guard, but short

A short guard fails a test on a busy machine even though nothing is wrong.

| Where | Guard |
|---|---|
| `PThreadTestSupport.swift:83` | `Latch.wait()`, 10 s; every thread test that hands off with a latch |
| `SignalInterruptTests.swift:241` | the helper's waits for the thread, 10 s |
| `Pseudoterminal.swift:132`, `TerminalTests.swift:700,724` | `readBytes` and `isReadable`, 5 s |
| `KernelQueueTests.swift:156-320`, `EventPollTests.swift:215`, `PollTests.swift:74` | polls of 10 or 30 s |
| `IORingTests.swift:346-580` (Linux) | completions, 1 s |
| `SharedMemoryTests.swift:190`, `FileLockTests.swift:351` | 10 s |
| `SocketMultipleMessagesTests.swift:204` | 5 s |

### 1e. Process-wide state under swift-testing's parallelism

| Where | Test | Failure mode |
|---|---|---|
| `MemoryZoneTests.swift:135` | `pressureReliefAndStatistics` | **Seen: crashes the swift-testing process with SIGSEGV** (1 of 10 full runs; 2 of 20 runs of the memory suites alone). `malloc_zone_statistics(NULL)`, behind `statisticsForAllZones()`, walks every zone without the lock that `malloc_destroy_zone` honors, so another test destroying its zone meanwhile makes it read freed memory. A C probe (`zonestats.c` mode 2, section 3) crashes the same way. |
| `MachVirtualMemoryTests.swift:39` | `allocatingZeroedPages` | Deallocates a region twice. Another thread can be given those pages in between, and the second deallocation takes them away from it: another way to crash the process. |
| `MachVirtualMemoryTests.swift:103` | `copyingToOrFromUnallocatedMemory` | **Seen, 1 of 20 memory-suite runs.** Deallocates a page, then expects copies from and to it to fail. Another thread was given the page meanwhile, so the copy succeeded, into memory that thread owned. |
| `MemoryTests.swift:170`, `MemoryZoneTests.swift:36,94` | `reallocateFreeingOnFailureFreesTheBlock`, `aZoneAllocatesAndFreesItsOwnBlocks`, `destroyingAZoneFreesItsBlocks` | **Seen, 1 of 20 memory-suite runs.** Exact block counts from a private zone's statistics. They're wrong about 0.4% of the time even in a single-threaded C program (`zonestats3.c`): the zone reports 0 blocks with two allocated. |
| `ProcessPriorityTests.swift:54` | `settingAChildsPriority` | Spawns a child from the parallel process without close-on-exec by default, so it holds whatever descriptors other tests have open, such as a pipe's end another test is waiting to see closed. |

### 1f. Shared names and paths

- `IORingTests.swift:101` (Linux): every run shares `/tmp/IORingTests/test.txt`, which
  `testOpenReadAndWriteFixedFile` leaves behind (its cleanup's `rmdir` fails on the
  file). The next run reuses it, and fails if an earlier run was another user's,
  such as root's in a container; `--parallel` runs the three tests at once on it.
- POSIX shared memory and semaphores (`SharedMemoryTests.swift:33`) include the
  process ID. A crashed run leaves its names behind, which a later process with the
  same ID would trip over with an exclusive create.
- Kept: temporary files from `withTemporaryFilePath`, a unique directory under
  `$TMPDIR`; `CInteropAccessorsTests.swift:81` and `SocketSendFileTests.swift:39` use
  `/tmp` with the process ID or `mkstemp`.
- Sockets bind to port 0 or use socket pairs. No fixed port or socket path is bound.
- `TerminalJobControlTests.swift:65` hands the controlling terminal's foreground group back and forth, which briefly affects the terminal's other jobs; it skips without a terminal, as under Claude Code.

### 1g. Interruption and EAGAIN races

| Where | Test | Failure mode |
|---|---|---|
| `SocketOpenOptionsTests.swift:90` | `acceptSetsExactlyTheOptions` | Fixed in `68c6bec` by retrying EAGAIN for 2 s: still a time limit. |
| `SignalInterruptTests.swift`, `WriteAllInterruptTests.swift` | as in 1c | |

### 1h. Kept: checks that time can't break

These wait for time to pass, and load only makes them wait longer:

- Lower bounds: `PollTests.testTimeout`, `KernelQueueTests.testTimeout` and `testOneShotTimer`'s elapsed check, `EventPollTests.testTimeout`, `PThreadConditionTests.deadlinePasses` and `timeout`, `ClockTests.sleepLastsAtLeastItsDuration`, `FileLockTests.testLockTimeout`, `SocketIPOptionsTests.aReceiveTimesOut`, `IORingTests.testBlockingConsumeCompletionWithTimeoutOnIdleRing`, `StatTests.times`' 50 ms sleeps between file operations.
- Absence checks, which wait a moment to give a wrong result the chance to show, and can't fail when the code is right: `SpawnTests.testStartSuspended`, `FileLockTests.testWaitingLock`'s first wait, `TerminalTests`' `isReadable(fd, timeout: 100)`.
- Polls without a deadline for a state that must come: `ProcessWaitTests.testTryWait` and friends, `ProvisionalStdioTests.testLocking`.

A realtime clock step could still break `deadlinePasses` (realtime deadline, monotonic measurement) and `ClockTests.realtimeIsTheTimeSinceTheEpoch`; section 5.

## 2. Reproduction before the fixes

5 runs of `swift test` and 5 of `swift test --parallel`, at `7b0875f`, with 10 loaders
on a 10-core Mac whose load average was already 60 to 100 from other lanes' builds
(it reached 205). `Prototype/TestHygiene/stress.sh -n 5 -l 10`.

| Test | Failed in |
|---|---|
| `setCurrentQualityOfService` | 8 of 10 runs (all but the crashed one and one other) |
| `testVolumeAttributes` | 3 |
| swift-testing process crashed, SIGSEGV | 1 (serial run 2, before any test finished) |
| `KernelQueueTests.testOneShotTimer` | 1 (`data` 3, not 1) |

The memory suites alone (`--filter "Memory|MachVirtualMemory|MemoryMapping"`, 20 runs
with 10 loaders): 2 SIGSEGV crashes, 1 `copyingToOrFromUnallocatedMemory` (the copy
from a deallocated page succeeded), 1 `reallocateFreeingOnFailureFreesTheBlock`
(`blocksInUse` 0, not 1).

Not reproduced in these runs, though inventoried: `acceptSetsExactlyTheOptions`
(its 2 s retry held), and the 1c timing assumptions other than the timer.

`LibProcTest.testLists` took 64.6 s and `SystemControlTest.testProcesses` 19.4 s in
one loaded run, without failing. A standalone probe took 38 s and then 253 s for the
first `sysctl(KERN_PROC_ALL)` size query of its process, with no ENOMEM retries, and
1 ms for each later one: the time is in the kernel's first answer to a new process,
not in `SystemControl`'s retry loop.

## 3. Fixes

Commits `5b29c65`, `ac6bdd1`, `a83fffe`, `4da9cc1`, and the one that adds `abi-check.sh`.
Each fix makes the outcome depend on an event, an invariant, or isolation instead of
on timing. Where a check had to get weaker to be deterministic, the entry says so.

### 3a. Scheduling

- `setCurrentQualityOfService`: a `pthread_override_qos_class_start_np` override keeps
  the thread at the default class until it's joined. `pthread_get_qos_class_np`
  reports the class the thread asked for, not overrides, so the check is unchanged.
  Before: failed 8 of 10 loaded runs, after 10 s each. After: 8 of 8 runs of the test
  alone under 10 loaders passed, in 1 ms, and every full run since.

### 3b. Sampled values

- `testVolumeAttributes`: compares with statfs only what the volume doesn't change
  (size, I/O block size, type name), and checks the space values of one call against
  each other: available ≤ free ≤ size, whole blocks, used ≤ size, a full disk allowed.
  It requests `.volumeSize` and `.volumeFreeSpace` too. **Weaker**: available space is
  no longer checked for equality with statfs's; its position in the buffer is still
  checked by the values around it. Before: 3 of 10 loaded runs. After: none.
- `LibProcTest.testLists`: both lists must hold the processes that live through both
  calls (this one, its parent, launchd, and a child it keeps running), instead of 90%
  overlap. **Weaker**: other processes aren't compared.

### 3c. Timing

- Kernel queue: a one-shot timer's `data` is at least 1, not exactly 1 (Darwin counts
  the intervals that passed before the event was read); the repeating timer waits for
  the queue to become readable before sleeping 10 ms and counting; the full span's
  poll gets a timeout of twice the hang guard and must return within the guard.
- `MachTimeTests.testInstants`: the `SuspendingClock` interval starts first and ends
  last, so it contains the Mach interval whatever the delays.
- `ProcessTimerTests`: 100,000 s timers must read within the hang guard of that; the
  expired one-shot timer waits for its SIGALRM handler to run; `setAlarm`'s rounding
  is checked against bounds computed from a clock read around the two calls, so a
  delay under 0.4 s (always, unloaded) still pins it to one value.
- `SignalInterruptTests` and `WriteAllInterruptTests`: one signal at a time, each
  after the handler ran; a call that isn't retried is signaled until it returns,
  which it can do only by being interrupted. **Weaker for the retried call**: after
  three handled signals the test unblocks it, without knowing whether any of them
  reached the call rather than the code before it; the result it checks is the same
  either way.
- Running children: `spawnWaitingChild()` (sh reading a pipe that only the test
  process holds) replaces `sleep 10` and `sleep 30`; the two deinit tests use a
  `sleep` of twice the hang guard and require the deinit to finish within the guard.
- `StatTests.times`, `SocketIPMessagesTests`: timestamps lie between clock readings
  made around the operation, instead of within 4 s or 60 s of one.
- `acceptSetsExactlyTheOptions`: polls the listener until it's readable, which it is
  once the connection is queued, instead of retrying EAGAIN for 2 s.
- Linux only, not yet run: the timerfd test reads back a timer set far off, then sets
  a short one; the io_uring test waits for the cancelled poll's completion instead of
  retrying 100 times; the TCP test waits for `bytesAcknowledged` to reach 1000.

### 3c'. Shared names

- `IORingTests`' file lives in a directory from `makeUniqueDirectory()` under the
  temporary directory, and the cleanup removes both (Linux, not yet run).
- `SharedMemoryTests` removes any object of its name before creating one; only a
  dead process with the same ID can have made it.

### 3d. Hang guards

`hangGuardSeconds` (300, in `HangGuard.swift` in both test targets) bounds every wait
for something that should happen at once: `Latch.wait()` (was 10 s), pseudoterminal
reads (5 s), polls and kqueue waits (5 to 30 s), io_uring completions (1 s), and the
XCTest expectation, semaphore and lock waits (10 s).

### 3e. Isolation

- The malloc zone tests are one `.serialized` suite, check which zone holds a block
  (`Memory.Zone(containing:)`) instead of counting blocks, and read every zone's
  statistics only in an exit test. `reallocateFreeingOnFailureFreesTheBlock` moved
  into that suite.
- `MachVirtualMemoryTests`: deallocating twice (`deallocatingTwice`) and copying to
  and from a deallocated page are exit tests.
- `settingAChildsPriority` is an XCTest test (`ProcessPriorityChildTests`), so that
  its child can't hold swift-testing's other tests' descriptors.
- Before: the memory suites alone, 20 runs under 10 loaders: 2 SIGSEGV crashes and 2
  failures. After: 20 of 20 passed.

### 3f. Loaded runs after the fixes

| Round | Loaders | Load average | Runs passed |
|---|---|---|---|
| `stress.sh -n 5 -l 10`, at `a83fffe` | 10 | 85 to 125 | 10 of 10 |
| `stress.sh -n 5 -l 20`, with `FileLockTests`' last two guards | 20 | 80 to 146 | 10 of 10 |

Each serial run: XCTest 557 tests with the 4 skips below, 0 failures; swift-testing
473 tests in 74 suites, passed. Each `--parallel` run: 557 of 557 XCTest tests ran,
and swift-testing passed. swift-testing's run takes 3 to 4 s instead of 6.5 s, now
that the QoS test doesn't wait for a starved thread.

The 4 skips are by design and don't depend on load: `dup3` and `pipe2` need Darwin 27
(3 tests), and `testControllingTerminal` needs a controlling terminal, which commands
run by Claude Code don't have.

The lane close block no longer needs `--skip testVolumeAttributes`.

`Prototype/TestHygiene/abi-check.sh` type-checks the test targets under
`SYSTEM_ABI_STABLE` in a patched scratch copy (the recipe that SystemPackage's known
failures make necessary). At `7b0875f` and at `4da9cc1`, SystemTests has the same 22
errors and 31 warnings, and SystemSocketsTests stops at the same 8 errors in
SystemSockets' sources: the fixes add no availability problems.

## 4. Rules

`Tests/TESTING.md`: what a test may and may not depend on, for the lanes that add
tests. In short: wait for events, with `hangGuardSeconds` only against hangs; bound
elapsed time from below; bracket clocks; compare invariants, not samples; keep
process-wide state, freed resources and child processes out of swift-testing tests;
name shared things uniquely; restore everything.

## 5. Remaining risks

- **Linux is unverified.** The Linux-only edits in 3c, the glibc branch of the alarm
  rounding (glibc and the Linux kernel round to the nearest second, not up, which
  `setAlarm`'s documentation doesn't say), and `LinuxProcessTests`' waiting child
  compile only on Linux. The `container` service isn't running
  (`container system start` fails inside Claude Code's sandbox), so nothing Linux has
  been built here.
- A step of the realtime clock (as when NTP corrects it) can still fail the checks
  that compare it across calls: `PThreadConditionTests.deadlinePasses`,
  `ClockTests.realtimeIsTheTimeSinceTheEpoch`, the brackets in `StatTests.times` and
  `SocketIPMessagesTests`. Load can't.
- Absence checks prove less on a busy machine, but can't fail: `testStartSuspended`,
  `testWaitingLock`'s first wait, the terminal's partial line.
- `StatTests.times` expects the temporary directory's access time unchanged; a
  process that reads the directory meanwhile would change it. Not seen.
- `MemoryMappingTests.protectionAdviceAndResidency` expects just-written pages
  resident; heavy memory pressure could evict one first. Not seen.
- `SharedMemoryTests` names include the process ID; a crashed run's leftovers would
  trip a later process with the same ID.
- `ProcessCredentialsTests.aUsersGroups` compares two answers from the directory
  service.
- `LibProcTest.testLists` and `SystemControlTest.testProcesses` can take a minute
  under load: the first `KERN_PROC_ALL` size query of a process took 38 s and 253 s
  in a probe. Nothing times out, so they pass slowly.

### Findings outside `Tests/`, not changed

- `Memory.Zone.statisticsForAllZones()` and `mstats()` (`MemoryZone.swift:397,419`)
  crash if another thread destroys a zone meanwhile: libmalloc reads every zone
  without the lock that `malloc_destroy_zone` takes. Their documentation could say
  so.
- `ProcessTimer.setAlarm`'s documentation (`ProcessTimer.swift:256`) says the seconds
  left are rounded up; on glibc they're rounded to the nearest second. Unverified
  until the Linux build runs.

## 6. Where to resume

Done: steps 1 to 5 of the lane's brief on Darwin (inventory, loaded reproduction,
fixes, `Tests/TESTING.md`, loaded runs passing). Open:

1. **Linux.** With the container service started from a Terminal
   (`container system start`), run `Utilities/linux/build.sh test` and then the
   Linux suite under load. Check the edits in 3c marked Linux, `LinuxProcessTests`,
   and `ProcessTimerTests.roundedAlarmSeconds`' glibc branch; if glibc does round to
   the nearest second, report the `setAlarm` documentation to its owner.
2. **New tests from other lanes.** When local system-next moves, merge it, and read
   the new test files against `Tests/TESTING.md` (a grep for `sleep`, `timeout:`,
   `seconds:`, `spawn`, `statistics`, `deallocate` and process-wide setters finds
   most hazards), then rerun `stress.sh`.
