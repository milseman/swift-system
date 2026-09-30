# linux-2: a clean Linux run, O1, and the adopters on Linux

Lane `linux-2` (worktree `../linux-2`, branch `linux-2`, base system-next `4365f83`). Linux runs are
swift:6.2-noble on arm64 (Swift 6.2.4, glibc 2.39, kernel 6.18), through `Utilities/linux/build.sh --quiet`,
with logs in `../linux-logs/linux-2-<commit>-<what>.log`.

## Resume here

- State: steps 1 to 3 are done (sections 1 to 3); step 4, swift-nio's `migrate-unix` on Linux, is next
  (section 4).
- System's Linux run: `container system start >/dev/null 2>&1; Utilities/linux/build.sh --quiet --log
  ../linux-logs/linux-2-$(git rev-parse --short HEAD)-<what>.log test`, with `--user 1000:1000` for the
  unprivileged run and `-- --filter <Suite>` to narrow. Commit first: the log is named for HEAD.
- An adopter's run (section 3): `--root .. --dir adopters-unix/<pkg>`, with `--scratch` and `--log` outside
  the adopter's worktree, and `--mount .:swift-system` to build it against this worktree.
- Merge system-next whenever it moves; delete this lane's scratch paths when done.

## For unix-adopt

What fails on Linux in `../adopters-unix`, per package and file (section 4). Nothing yet.

## Baseline

At `4365f83`:

- Darwin (`swift build && swift test`): XCTest 571 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82
  suites passed.
- Linux, as root (`linux-2-4365f83-baseline.log`): XCTest 481 tests, 6 skipped, 5 failures; swift-testing 463
  tests in 78 suites, 7 issues.

## 1. The Linux run, clean: `1173838`

Each failure, what caused it, and the fix. Only one expectation was a root assumption as the brief had it; the
others are Linux's or glibc's behavior, where System's code is right, so the tests changed, and where a doc would
have misled a reader on Linux, it says what Linux does.

| Test | Cause | Fix |
|---|---|---|
| DirectoryWalk: `anUnreadableDirectoryOnce`, `anUnreadableDirectoryWhenEntered`, `anUnreadableDirectory` (bounded), `entriesWhoseStatusCantBeRead` | `try #require(getuid() != 0)` records an issue as root rather than skipping | `@Test(.enabled(if: geteuid() != 0, "root can read any directory"))`, as `DirectoryWalkTests.anUnreadableDirectoryIsReportedAndSkipped` has it |
| `ProcessCredentialsTests.aUsersGroups` | glibc's `getgrouplist` lists the group it's given and the groups whose member lists name the user. Darwin's list also has the user's primary group. With another group included, root's group 0 isn't in glibc's list, since `/etc/group` doesn't list root as a member of group 0 | off Darwin, the check adds the primary group back; `GroupID.supplementary(forUser:including:)`'s doc says how the lists differ |
| `ProcessPriorityTests.adjustingTheCallersPriority` | Not root: Linux's nice values are per thread (nice(2), setpriority(2) BUGS). `nice` changes the calling thread's, and `PRIO_PROCESS` with the process's ID reads its main thread's, while the exit test's body runs on another thread; so the read-back after `adjust(by: 3)` found the main thread's 0, and the first guard failed. The root branch was right | off Darwin, the test reads `.process(ProcessID(rawValue: 0))`, the calling thread; `ProcessPriority`'s doc says what a nice value belongs to on Linux, and `adjust(by:)`'s says the calling thread's |
| `ProcessTimerTests.testSettingAndReadingEachTimer` | Linux adds a scheduler tick (`TICK_NSEC`: 4 ms at 250 Hz) to `ITIMER_VIRTUAL`'s and `ITIMER_PROF`'s expiration (`set_cpu_itimer`), so a timer set to 100,000 s reads back 100,000.004 s | the upper bound allows 10 ms (100 Hz's tick) for those two on Linux and Android; `setSchedule(_:)`'s doc says it |
| `IORingTests.testPollAddMultiShotRearmsAcrossEvents` | A test bug from `a83fffe` (test-hygiene, unbuilt on Linux): the wait for the cancelled poll's last completion used `blockingConsumeCompletion()`, which throws a failed completion's result, so the poll's `-ECANCELED` came as a thrown error, which ended the wait with nothing recorded (only the cancel's own completion, context 0, result 1) | the wait polls the ring's descriptor, readable while a completion waits (up to the hang guard), and takes completions with `tryConsumeCompletion()`, which returns them as they are |
| `ProvisionalStdioTests.testBuffering` | glibc's `fwrite` sends a stream's first write straight to the descriptor when the buffer is smaller than 128 bytes (`_IO_new_file_xsputn` writes whole blocks, and a block under 128 bytes is written through). The test's line-buffered stream had a 64-byte buffer, so `part` arrived before the newline. Not `setvbuf` failing, as linux-api's section 3 had it: the call that didn't throw was the read that expected `EAGAIN` | a 256-byte buffer; `setBuffering(_:buffer:)`'s doc says it |
| `ProvisionalMathTests.knownValues` | glibc 2.39's `cbrt` isn't correctly rounded: `cbrt(-27.0)` isn't -3 (`cbrt(-8.0)` is -2) | within 1e-15; `Math`'s doc says its results are the C library's |

Design calls:

- Skipping as root is a trait (`.enabled(if:)`), not `#require`, so a root run reports a skip with the reason.
  `geteuid`, since permission checks use the effective user.
- The per-thread nice value is documented, not worked around: `ProcessPriority` wraps `getpriority`, `setpriority`
  and `nice` as they are, and System isn't a cross-platform abstraction. Rejected: a `Target` case for the caller
  (who 0), new API that the doc's `ProcessID(rawValue: 0)` already spells; making `.process(.current)` pass 0 on
  Linux, which would change what a process's ID means there.
- The IORing wait: rejected, catching the thrown `ECANCELED` as the poll's completion, which loses its flags, and
  the check that the poll isn't still armed is what the test is for; and registering an eventfd with the ring,
  which works too but adds a descriptor and a read the ring's own readability already gives.

Left, noted: the same test's `first.result == -EINVAL` skip (kernels before 5.13 reject multishot polls) can't
happen, since `blockingConsumeCompletion()` would throw `EINVAL` instead; on such a kernel the test fails rather
than skips. It's unreachable on 6.18, so it's unchanged here.

Linux at `1173838`:

- As root (`linux-2-1173838-root.log`): XCTest 481 tests, 6 skipped, 0 failures; swift-testing 463 tests in 78
  suites passed (5 skipped as root: the four above and `anUnreadableDirectoryIsReportedAndSkipped`). The XCTest
  skips: `testChangesToAnotherUsersFileAreNotPermitted`, `testChangingTheRootNeedsPrivileges` and
  `testCredentialsThatNeedRoot` (root), `testControllingTerminal` (no controlling terminal), and
  `ProvisionalLocaleLinuxTest`'s two named-locale tests (no `fr_FR.UTF-8` in the image).
- As 1000:1000 (`linux-2-1173838-user.log`): XCTest 481 tests, 4 skipped, 0 failures; swift-testing 463 tests in
  78 suites passed. The skips: `testAnotherUsersChild` (needs root), `testControllingTerminal`, and the two locale
  tests.

Darwin at `1173838`: XCTest 571 tests, 5 skipped, 0 failures; swift-testing 502 tests in 82 suites passed.

## 2. O1: coverage-3's new API on Linux

Coverage-3's O1 (Prototype/Status/REPORT.md, sections 42 and 43), for Linux: `CInterop.Offset`,
`SystemConfig.maxAtomicPipeWriteBytes` and PThread cancellation build on glibc, and their tests pass, in both of
section 1's runs, with no change here:

- `OffsetAndPipeLimitTest` (3 XCTest tests): `CInterop.Offset` is `off_t` and `Int` on Linux;
  `maxAtomicPipeWriteBytes` is glibc's `PIPE_BUF`, 4096; a pipe's `fpathconf` limit is the same.
- `PThread cancellation` (4 swift-testing tests) and `PThreadCancellationMockTests` (2 XCTest tests): on glibc too,
  a cancelled thread ends at its next cancellation point, a pipe read that blocks included, and the disabled scope
  holds it off and restores the state it found; the thread-specific value's destructor, which the tests wait for,
  runs as the thread ends.

Not here: O1's Windows and WASI halves (the windows-2 and other-platforms lanes), and Musl (no static SDK run).

## 3. build.sh: another package, with the packages beside it: `cf4ef08`

`Utilities/linux/build.sh` mounted only this package at `/code`, so an adopter's `.package(path:
"../../swift-system")` didn't resolve in the container (unix-adopt's section 4 asked for this).

- `--root <dir>` mounts `<dir>` at `/code` instead of this package, and `--dir <path>` names the package under it,
  where the swift command runs (`-w /code/<path>`); it must be inside the root and have a `Package.swift`.
- `--mount <dir>:<path>` (repeatable) mounts another directory over one under the root. With `.:swift-system`, an
  adopter builds against this worktree rather than the checkout its manifest names, so a System fix can be tried
  on it before it's merged.
- `--scratch` and `--log` stay relative to the package, now `<root>/<dir>`; a log can also be absolute.
- The `==` lines and the log's first line name the package's container path and the root when they aren't this
  package. `--quiet`'s summary makes paths relative to the package: its own lose `/code/<dir>/`, the root's others
  get `../` up to the root (`../../swift-system/Sources/...`); XCTest's failures are the `error:` lines under the
  package's `Tests/`.
- README.md: the options' table, and a section with both examples.

Design calls: the paths stay relative to the package, as the scratch path already was, rather than to the
current directory or this checkout, so the default mode's rule doesn't change. Rejected: mounting the root
read-only, with a writable scratch mount elsewhere, which would make SwiftPM fail when it has to update
`Package.resolved`; a pass-through for any `container` argument, which the one needed mount doesn't justify.

Checks:

- Without the new options, nothing changed: with a stand-in `container` that records its arguments and replays a
  recorded log, the old and new scripts pass the same arguments, print the same lines, and write the same log but
  for its date. With it, root mode's arguments, header and summary (a package error, a root error, an XCTest
  failure under the package's Tests), and each argument check.
- On Linux: `--root .. --dir linux-2 ... test -- --filter ProcessTimerTests` (`linux-2-cf4ef08-rootmode.log`)
  and `--root .. --dir swift-system --mount .:swift-system` (`linux-2-cf4ef08-overlay.log`), 5 XCTest tests each,
  passing. The second passes only with this lane's timer fix, which the swift-system checkout (system-next
  `4365f83`) doesn't have, so the overlay is what the container built; that checkout's status stayed clean, and
  SwiftPM rewrote no `Package.resolved`.

## 4. unix-adopt's rewrites on Linux

Not started.

## Findings

- System's code was right on Linux in each of the failures: they were tests written for Darwin's behavior, or
  rewritten without a Linux build (section 1). Three docs now say what Linux does differently: per-thread nice
  values, the processor-time timers' tick, and glibc's writes through a small stdio buffer.

## Needs outside this lane's files

None yet.
