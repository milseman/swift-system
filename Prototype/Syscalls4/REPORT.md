# syscalls-4: system calls the adopters still make through the C library

The `syscalls-4` lane adds System API for the system calls that swift-nio,
SwiftPM, swift-foundation, swift-subprocess and the toolchain's other packages
still call through Darwin or Glibc, from the adopters' `SYSTEM-GAP` lists
(`../adopters/*/MIGRATION.md`) and the coverage tool's ecosystem report
(`../coverage-results/runs/5e5e16671a29-2d5ca14b/ECOSYSTEM.md`). Breadth over
polish: a correct, tested, documented wrapper per call, in the package's
patterns. One section per cluster, appended as each lands, in the queue's order.

All new API is `@available(System 199, *)`, throws `Errno` (typed), and has a
"The corresponding C function is `x`." sentence. Socket API is in
SystemSockets.

## Testing on Linux

At system-next `609feb0`, `swift test` on Linux stops at the
`MemberImportVisibility` probe target (`ProcessesProbe.swift`,
`EventsProbe.swift`), which the linux-build lane's unmerged commits fix. So
`linux-test.sh` copies this checkout to `.build/linux-experiments/syscalls4`,
applies `git diff system-next...linux-build` there, and runs `swift test` in
`swift:6.2-noble` through Apple's `container`, as `Utilities/linux/build.sh`
does. When linux-build merges into system-next, `Utilities/linux/build.sh test`
does the same job.

```sh
Prototype/Syscalls4/linux-test.sh                       # swift test
Prototype/Syscalls4/linux-test.sh test --filter Pseudoterminal
SWIFT_IMAGE=swift:6.3-noble Prototype/Syscalls4/linux-test.sh
```

## Baseline

System-next `609feb0` on macOS 26.3, Swift 6.2 (swiftlang-6.2.0.19.9):
swift-testing 265 tests in 34 suites pass.

## 1. Process exit and pseudoterminals

### Commits and API

`5297e94`: exit.

| API | C |
|---|---|
| `ProcessID.exit(_ status: CInt) -> Never` | `exit` |
| `ProcessID.exitImmediately(_ status: CInt) -> Never` | `_exit` |
| `ProcessID.addExitHandler(_: @convention(c) () -> Void) throws(Errno)` | `atexit` |

`7119764`: pseudoterminals.

| API | C |
|---|---|
| `TerminalDescriptor.openPseudoterminal(attributes:windowSize:closeOnExec:) throws(Errno) -> (controller: FileDescriptor, terminal: TerminalDescriptor)` | `openpty`, done with `posix_openpt`, `grantpt`, `unlockpt`, `ptsname_r`, `open`, `tcsetattr`, `ioctl(TIOCSWINSZ)` |
| `FileDescriptor.pseudoterminalPath() throws(Errno) -> FilePath` | `ptsname_r` |

Files: `Sources/System/ProcessExit/ProcessExit.swift`,
`Sources/System/Pseudoterminals/Pseudoterminal.swift`,
`Internals/Syscalls+ProcessExit.swift`, `Internals/Syscalls+Pseudoterminals.swift`;
the `pty-run` sample, in a new "More system call samples" group in `main.swift`.

### Design calls

- **Exit goes on `ProcessID`, as statics**, beside the processes lane's
  `execute`, `spawn` and `createSession`, which also act on the calling
  process. Rejected: top-level `exit`, which would make every `exit(…)`
  ambiguous in a file that also imports the C library (and Foundation
  re-exports it); a namespace type (`Process` is Foundation's).
- **`_exit` is `exitImmediately(_:)`**, a method of its own rather than a
  flag on `exit`, since the two belong to different places: `_exit` is the
  async-signal-safe one, for signal handlers and forked children. Rejected:
  `exit(_:runningHandlers:)`, and the C name.
- **The status is a `CInt`**, as every adopter passes (`exit(main(…))`,
  `exit(code.rawValue)`). Rejected: `EXIT_SUCCESS`/`EXIT_FAILURE` constants
  or a status type: they're 0 and 1 on every platform System builds, and
  ArgumentParser's `ExitCode` already fills that role in the packages that
  want one.
- **`addExitHandler` takes a C function**, which a closure that captures
  nothing converts to: every adopter's handler (Subprocess's five, SwiftPM's
  `atexit(dump)`) captures nothing. Rejected: a registry of Swift closures
  behind one C trampoline. It would work (exit handlers run in ordinary
  context, unlike signal handlers) but adds a global, a lock, and
  allocation, for no adopter.
- **A failed `atexit` throws `.noMemory`.** atexit returns nonzero and POSIX
  doesn't say it sets `errno`; the only way it can fail is running out of
  room. Rejected: reading `errno` (Darwin documents `ENOMEM`, Linux doesn't
  promise it), and a `Bool` result.
- **No mock hooks for `exit` and `_exit`**, which never return; exit tests
  check them for real.
- **Pseudoterminals use POSIX's functions, not `openpty`**: `openpty` needs
  libutil on glibc before 2.34 and on FreeBSD and OpenBSD (swift-build links
  `util` for OpenBSD), and its name argument is a buffer with no length. The
  POSIX functions reuse the `csystem_` shims that the tests'
  `withPseudoterminal` already uses on Linux.
- **Close-on-exec by default** (`closeOnExec: true`). C's `openpty` doesn't
  set it, and swift-build sets it with `fcntl` right after, which races any
  other thread's spawn. A spawn file action hands a child the terminal all
  the same. Rejected: C's default.
- **No `forkpty`** (fork is deliberately unwrapped: `Prototype/Processes`)
  **and no `login_tty`**, whose job is to make the pty the child's
  controlling terminal after a fork. With `posix_spawn`, that's a child in a
  new session (`SpawnAttributes.Flags.createSession`) that opens
  `pseudoterminalPath()` with a spawn file action; the docs say so, and
  `PseudoterminalSpawnTests` and `pty-run` check it on Darwin and Linux.
- **The ends are a `FileDescriptor` controller and a `TerminalDescriptor`
  terminal**, returned as raw descriptors, as `FileDescriptor.pipe()` returns
  them. Both ends are terminals on Darwin and Linux, so
  `TerminalDescriptor(unchecked: controller)` reaches the shared window size.
  Rejected: a new top-level pair type, which TSC's test support would sit
  beside with a `PseudoTerminal` class of its own, and which a tuple of the
  two descriptors doesn't need; an owned pair, which waits on `OwnedFD`
  leaving the prototype stage.
- **`attributes` and `windowSize` apply with `TCSANOW` and `TIOCSWINSZ`**, as
  `openpty`'s `termp` and `winp` do. `TCSANOW` rather than glibc's
  `TCSAFLUSH`, since flushing a new terminal has nothing to flush and can
  block on Darwin.
- **`ptsname_r`, never `ptsname`**, whose static buffer races; so the pty API
  carries `ptsname_r`'s floor, macOS 10.13.4 (iOS 11.3, watchOS 4.3, tvOS
  11.3), on the same extensions as `System 199`. `pty-run` needed an
  `#available` check for it. `system_ptsname_r` returns an error number on
  every platform (Darwin's returns -1 and sets `errno`), and the path grows its
  buffer on `ERANGE`.

### Findings

- **Darwin's `waitid` reports an exit status's full value**: 0x105 for
  `exit(0x105)`, and 24 bits of `exit(-1)` (16777215), where `waitpid`'s
  `WEXITSTATUS` gives the low 8 bits, as Linux's `waitid` does. The
  processes lane's `ProcessID.wait(for:)` (`waitid`) and `wait()`
  (`waitpid`) therefore report different `ExitStatus.exited` values on
  Darwin for a status above 255; that's theirs to decide (mask to 8 bits, or
  document).
- **On Darwin, a process that writes to a pseudoterminal and exits blocks in
  its last close until the controller reads the output**: a probe that
  waited for its child before reading hung for 15 minutes. The docs, the
  spawn test and the sample read first.
- **On Darwin, a session leader that opens the terminal gets it as its
  controlling terminal even with `O_NOCTTY`**; Linux honors `O_NOCTTY`.
  The docs don't rely on either.
- **swift-testing 6.2's exit tests capture 32 bytes of their own** (the same
  bytes each run, likely the exit test's ID) on both standard output and
  error from a child that ends with `_exit`, and none from one that calls
  `exit`. The `_exit` test looks for what shouldn't be there instead of
  expecting no output.
- Swift 6.2 infers a closure's `throws` from the `try`s it can see, and a
  `try` inside `#expect(…)` is in a macro argument, so a test closure whose
  only `try`s are in `#expect` needs an explicit `throws`.

### What it replaces in the adopters

- **exit** (the ecosystem's top gap: 14 packages, 74 sites):
  - NIO `Tests/NIOPosixTests/EventLoopCrashTests.swift` (`exit(1)` … `exit(4)`),
    clearing `// SYSTEM-GAP: exit(3) (the crash tests end child processes with it)`.
  - SwiftPM `Sources/Runtimes/PackagePlugin/Plugin.swift` (six `exit(0)` and
    `exit(1)`), `Sources/swiftpm-testing-helper/Entrypoint.swift`
    (`exit(main(…))`).
  - Also in the report's list: llbuild, swift-argument-parser, swift-build,
    swift-corelibs-foundation, swift-corelibs-xctest, swift-docc, swift-driver,
    swift-sdk-generator, swift-syntax, swift-tools-support-core, wasmkit.
- **_exit**: SwiftPM `Sources/Commands/Utilities/TestingSupport.swift`
  (`_exit(EXIT_FAILURE)` in `safeExec`).
- **atexit**: Subprocess `Thread.swift`, `IO/AsyncIO+KQueue.swift`,
  `Platforms/Subprocess+BSD.swift` (each `import func Darwin.atexit  //
  SYSTEM-GAP: atexit`), and `IO/AsyncIO+Linux.swift`,
  `Platforms/Subprocess+Linux.swift` on Linux; SwiftPM
  `Sources/Runtimes/PackageDescription/PackageDescription.swift` (`atexit(dump)`,
  twice).
- **openpty**: Subprocess `Tests/SubprocessTests/UnixTests.swift`, clearing
  `// SYSTEM-GAP: openpty, for a pseudoterminal to hand to the child` (its
  `tcgetattr`/`cfmakeraw`/`tcsetattr` were already System's); also TSC
  `Sources/TSCTestSupport/PseudoTerminal.swift`, swift-testing
  `Tests/TestingTests/Support/FileHandleTests.swift`, and swift-build
  `Tests/SwiftBuildTests/ConsoleCommands/CLIConnection.swift` (whose
  `fcntl(FD_CLOEXEC)` calls the default makes unnecessary).
- The processes lane's README lists `[exit]` as missing in
  `Utilities/adopter-coverage/mapping.ini`; it's covered now, for the coverage
  lane to update.

### Platforms

- Built and tested: macOS 26.3 (arm64); Linux, swift:6.2-noble (arm64), with
  linux-build's probe fixes applied, every new test passing, the spawned
  child's controlling terminal included.
- Unverified: exit on WASI (wasi-libc has `exit`, `_exit`, `atexit`);
  pseudoterminals on Android (the existing shims' platforms), Musl, and iOS,
  tvOS, watchOS and visionOS (declared in their SDKs; the spawn test and
  sample skip watchOS and tvOS, where `posix_spawn` isn't wrapped).
  Not added for FreeBSD and OpenBSD.

### Tests

- New: `ProcessExitTests` (5 swift-testing exit tests), `ProcessExitMockTests`
  (2), `PseudoterminalTests` (6 swift-testing), `PseudoterminalSpawnTests` (1),
  `PseudoterminalMockTests` (5).
- macOS: XCTest 430 run, 4 skipped, 0 failures; swift-testing 276 tests in 36
  suites pass.
- Linux (swift:6.2-noble): XCTest 369 run, 2 skipped, 0 failures;
  swift-testing 277 tests in 37 suites pass.
