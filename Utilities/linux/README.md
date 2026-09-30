# linux

`build.sh` builds or tests the package on Linux, in a container from Apple's [`container`](https://github.com/apple/container) tool, and writes a log. Nothing else here builds for Linux: `swift sdk list` is empty on this Mac, so Linux-only code (`IORing/`, the epoll, eventfd, and timerfd types, `CSystemLinux.h`, the MemberImportVisibility probes) compiles only this way.

## Running it

```sh
Utilities/linux/build.sh                              # swift build, Swift 6.2 on Ubuntu noble
Utilities/linux/build.sh build-tests                  # swift build --build-tests
Utilities/linux/build.sh test                         # swift test
Utilities/linux/build.sh --distro jammy test          # swift:6.2-jammy
Utilities/linux/build.sh --swift 6.3 test             # swift:6.3-noble
Utilities/linux/build.sh test -- --filter EventPollTests
Utilities/linux/build.sh build -- --target SystemTests
Utilities/linux/build.sh run -- system-samples platform process
Utilities/linux/build.sh --user 1000:1000 test        # unprivileged
Utilities/linux/build.sh --quiet test                 # the output only in the log, and a summary
Utilities/linux/build.sh shell                        # bash in the container
Utilities/linux/build.sh --root .. --dir adopters-unix/swift-nio build-tests   # another package (below)
```

The package directory is mounted at `/code` (or `--root`'s directory, below), and each run starts a new container and removes it afterward. The arguments after `--` go to the swift command, after its `--scratch-path`. The first run of an image pulls it (about 3.7 GB), and the first build in a scratch path fetches the dependencies; a clean build and test takes under a minute.

| Option | Default | |
|---|---|---|
| `--image <image>` | `swift:<swift>-<distro>` | Any image with a Swift toolchain. |
| `--swift <version>` | `6.2` | The Swift version of the default image. |
| `--distro <name>` | `noble` | The distribution of the default image: `noble`, `jammy`, and so on. |
| `--arch <arch>` | `arm64` | `amd64` runs the image under Rosetta. |
| `--user <uid:gid>` | root | Runs as this user, with `HOME=/tmp`. `1000:1000` is `ubuntu` in the noble images, and can write the mount. |
| `--memory <size>` | `8G` | The container's memory. |
| `--cpus <count>` | the tool's | The container's CPUs. |
| `--root <dir>` | this package | The directory to mount at `/code` (below). |
| `--dir <path>` | the root | The package to build, relative to the root; the swift command runs there. |
| `--mount <dir>:<path>` | none | Also mounts `<dir>` at `<path>`, relative to the root, over what's there. Repeatable. |
| `--scratch <path>` | `.build/linux-<tag>` | SwiftPM's scratch path, relative to the package. |
| `--log <path>` | `.build/linux-<tag>-<action>.log` | The log, relative to the package unless it's absolute, which also gets a line with the date and command. A test run ends with XCTest's and swift-testing's totals. |
| `--quiet` | off | Writes the output only to the log, and prints a summary instead (below). |

- `<tag>` is the image's tag, such as `6.2-noble`, with `-amd64` for amd64, so each image and architecture builds into a scratch path of its own. Another image keeps its name: `swiftlang/swift:nightly-main-noble` is `swiftlang-swift-nightly-main-noble`.
- Each worktree has its own `.build`, so lanes don't share a scratch path. Two runs of one image in one worktree do, and SwiftPM's lock makes the second wait.
- Files that the container writes appear on the host as yours, whether it runs as root or as `--user`.
- If `container` says its API server isn't running, start it with `container system start`.
- Exit status: the swift command's.

With `--quiet`, the run prints only its two `==` lines (the image and command, and the log's path), then a summary
of the log, and the exit status line; the log is the same as without it. The summary:

- the number of distinct error lines, and the first 40 of them. An error line is a line with `error:`, but not the
  `` | `- error: `` annotation under a diagnostic's source excerpt;
- for `test`, XCTest's and swift-testing's totals, as without `--quiet`, and the failing tests' lines:
  swift-testing's lines with ✘ (each issue, failed test and failed suite, but not its total) and XCTest's
  failures, its `error:` lines for files under `Tests/`, which have a line number but no column.

Each list keeps the log's order, drops repeats, and makes paths relative to the package (below), so a path is relative
to the package. A long XCTest message shows only its first line.

## Another package, with the packages beside it

A package whose manifest names others by path, as the adopters' `.package(path: "../../swift-system")` does, can't
build from its own directory alone: the container sees only what's mounted. `--root` mounts a directory above them
all at `/code` instead of this package, and `--dir` names the package under it, where the swift command runs.
Without them, the root and the package are this package, as before.

```sh
# swift-nio's unix-adopt worktree, against the swift-system checkout its manifest names (../../swift-system)
Utilities/linux/build.sh --root ~/development/base_dir/system-next --dir adopters-unix/swift-nio build-tests

# The same, against this worktree, with the scratch path and the log outside the package
Utilities/linux/build.sh --quiet --root .. --dir adopters-unix/swift-nio --mount .:swift-system \
  --scratch ../../linux-2/.build/linux-nio --log ../../linux-logs/nio-build-tests.log build-tests
```

- `--scratch` and `--log` are relative to the package, which is now `<root>/<dir>`, so by default the scratch path and
  the log are in the package's `.build`. Point them elsewhere under the root to leave the package's directory alone;
  SwiftPM also writes `Package.resolved` there if resolving changes it.
- `--mount <dir>:<path>` mounts another host directory over a directory under the root, as a second `-v` does. With
  `.:swift-system`, the package builds against this worktree rather than the checkout its manifest names, which is
  how a System change can be tried on an adopter before it's merged.
- The `==` lines, and the log's first line, name the package's path in the container and the root.
- The summary's paths are relative to the package: the package's own lose `/code/<dir>/`, and the root's others start
  with `../` up to it, as the manifest names them (`../../swift-system/Sources/...`). XCTest's failures are its
  `error:` lines under the package's `Tests/`.

## What it has checked

Every target builds and every test passes on each of these, as of 2026-09-27. The first row is system-next with the processes and posix-more lanes merged; the others are from before those merges (commit `25d3ea2`), and haven't been run since.

| Image | Arch | Swift | glibc | XCTest | swift-testing |
|---|---|---|---|---|---|
| `swift:6.2-noble` | arm64 | 6.2.4 | 2.39 | 356, 2 skipped | 247, 1 skipped |
| `swift:6.2-jammy` | arm64 | 6.2.4 | 2.35 | 274, 2 skipped | 208, 1 skipped |
| `swift:6.3-noble` | arm64 | 6.3.3 | 2.39 | 274, 2 skipped | 208, 1 skipped |
| `swift:6.2-noble` | amd64 | 6.2.4 | 2.39 | 274, 17 skipped | 208, 1 skipped |

- The container's kernel is Linux 6.18, with io_uring enabled, so on arm64 the IORing tests run rather than skip. Under Rosetta, `io_uring_setup` fails with `ENOSYS`, so on amd64 the 15 IORing tests skip. amd64 is where `epoll_event` is packed, and a clean build and test there takes over two minutes.
- As root, three tests skip: `FileOperationsErrorTest.testChangesToAnotherUsersFileAreNotPermitted` and swift-testing's `anUnreadableDirectoryIsReportedAndSkipped`, since root can do both, and `TerminalJobControlTest.testControllingTerminal`, since the container gives a process no controlling terminal. With `--user 1000:1000`, only the last skips.
- Swift 6.3.3 crashes on two patterns that 6.2 compiles, which four samples used: `Prototype/LinuxBuild/Verify/LB1_pattern_catch_with_var.swift` and `LB2_catch_where_or.swift`.
- Musl (the static Linux SDK), Android, FreeBSD, OpenBSD, and Windows are unverified.

## Writing code that builds on Linux

What broke the first Linux build, for code written on a Mac:

- **glibc's enums.** `SOCK_STREAM` and the other socket types are members of `enum __socket_type`, which Swift imports as a struct: use `CInt(SOCK_STREAM.rawValue)` under `#if os(Linux) && canImport(Glibc)`. `IPPROTO_*`, `MSG_*`, and `SHUT_*` are in anonymous enums, which import as `Int`: `CInt(IPPROTO_TCP)` works everywhere. `IPPROTO_IPV4` is `IPPROTO_IPIP` on Linux.
- **Macros Swift can't import.** glibc defines `UTIME_NOW` as `((1l << 30) - 1l)`, which the importer drops; `CSystemLinux.h` defines `CSYSTEM_UTIME_NOW`, checked against the real one in `shims.c`. Constants that glibc declares only with `_GNU_SOURCE` get `CSYSTEM_` definitions there too.
- **Which module owns a C type.** Under MemberImportVisibility, a C type that both glibc's Swift module and a CSystem header declare belongs to whichever module's copy Swift loads first, and then its members can be hidden from clients, which don't import CSystem (#320). A CSystem function that takes such a type, as `timerfd_settime` took `itimerspec` and `timespec`, makes CSystem's copy the one SystemPackage's module refers to. So `CSystemLinux.h` and `io_uring.h` include as few of glibc's module's headers as they can (not `<signal.h>`, `<pthread.h>`, `<sched.h>`, `<sys/socket.h>`, `<sys/stat.h>`, or `<sys/timerfd.h>`), and their shims take such types as `void *`, with the real header in `shims.c`. `Tests/MemberImportVisibility` reads the members as a client would; add a probe there for each C type a new API vends, in a file of its own if nothing else there should load the type first. `sigset_t` comes through `<sys/types.h>` and `<sys/epoll.h>`, which CSystem needs, so it's named through its module instead: `CInterop.SignalSet` is `Glibc.sigset_t`, and public API should take that rather than `sigset_t`.
- **Duplicate names.** Code under `#if os(Linux)` compiles only here, so two lanes' definitions of one internal name, such as `_CLOCK_REALTIME`, collide only here. So does an internal name that the C library also declares, such as glibc's `_NSIG`, for tests that `@testable import` SystemPackage. Grep `Sources/` before adding one.
- **Anonymous enums in other headers.** `PRIO_PROCESS` is a member of glibc's `enum __priority_which`, but `getpriority` takes an `int`, and `SI_USER` and `SI_TKILL` import as `Int`.
- **dash.** Ubuntu's `/bin/sh` is dash, which takes only single-digit descriptors in `>&n`; write to `/dev/fd/n` instead.
- **Mutable C globals.** glibc declares `stdin`, `stdout`, and `stderr` as mutable globals, which Swift 6 rejects; `@preconcurrency import Glibc` accepts them.
- **Behaviors that differ.** `sysconf(_SC_JOB_CONTROL)` is 1, not 200112. `pathconf` gives a directory the terminal limits (`_PC_MAX_CANON` is 255) rather than failing. A mutex's priority ceiling must be in `SCHED_FIFO`'s range, 1 through 99; `SCHED_OTHER`'s is 0 through 0.
