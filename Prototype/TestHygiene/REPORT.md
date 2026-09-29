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

None collide today; kept as they are.

- Temporary files: `withTemporaryFilePath` makes a unique directory under `$TMPDIR`; `CInteropAccessorsTests.swift:81` and `SocketSendFileTests.swift:39` use `/tmp` with the process ID or `mkstemp`.
- POSIX shared memory and semaphores (`SharedMemoryTests.swift:33`) include the process ID. A crashed run leaves its names behind, which a later process with the same ID would trip over; low.
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
