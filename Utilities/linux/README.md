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
Utilities/linux/build.sh shell                        # bash in the container
```

The package directory is mounted at `/code`, and each run starts a new container and removes it afterward. The arguments after `--` go to the swift command, after its `--scratch-path`. The first run of an image pulls it (about 3.7 GB), and the first build in a scratch path fetches the dependencies; a clean build and test takes under a minute.

| Option | Default | |
|---|---|---|
| `--image <image>` | `swift:<swift>-<distro>` | Any image with a Swift toolchain. |
| `--swift <version>` | `6.2` | The Swift version of the default image. |
| `--distro <name>` | `noble` | The distribution of the default image: `noble`, `jammy`, and so on. |
| `--arch <arch>` | `arm64` | `amd64` runs the image under Rosetta. |
| `--user <uid:gid>` | root | Runs as this user, with `HOME=/tmp`. `1000:1000` is `ubuntu` in the noble images, and can write the mount. |
| `--memory <size>` | `8G` | The container's memory. |
| `--cpus <count>` | the tool's | The container's CPUs. |
| `--scratch <path>` | `.build/linux-<tag>` | SwiftPM's scratch path, relative to the package. |
| `--log <path>` | `.build/linux-<tag>-<action>.log` | The log, which also gets a line with the date and command. A test run ends with XCTest's and swift-testing's totals. |

- `<tag>` is the image's tag, such as `6.2-noble`, with `-amd64` for amd64, so each image and architecture builds into a scratch path of its own. Another image keeps its name: `swiftlang/swift:nightly-main-noble` is `swiftlang-swift-nightly-main-noble`.
- Each worktree has its own `.build`, so lanes don't share a scratch path. Two runs of one image in one worktree do, and SwiftPM's lock makes the second wait.
- Files that the container writes appear on the host as yours, whether it runs as root or as `--user`.
- If `container` says its API server isn't running, start it with `container system start`.
- Exit status: the swift command's.

## What it has checked

As of 2026-09-27, at the tip of the `linux-build` branch, every target builds and every test passes on each of these:

| Image | Arch | Swift | glibc | XCTest | swift-testing |
|---|---|---|---|---|---|
| `swift:6.2-noble` | arm64 | 6.2.4 | 2.39 | 274, 2 skipped | 208, 1 skipped |
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
- **Which module owns a C type.** Under MemberImportVisibility, a C type that both glibc's Swift module and a CSystem header declare belongs to whichever module's copy Swift loads first, and then its members can be hidden from clients, which don't import CSystem (#320). A CSystem function that takes such a type, as `timerfd_settime` took `itimerspec` and `timespec`, makes CSystem's copy the one SystemPackage's module refers to. So `CSystemLinux.h` includes as few of glibc's module's headers as it can, and its shims take such types as `void *`, with the real header in `shims.c`. `Tests/MemberImportVisibility` reads the members as a client would; add a probe there for each C type a new API vends. `sigset_t` is still attributed to CSystem: SystemPackage names it in files that import CSystem, and it's fixed only by naming it through its module (`Glibc.sigset_t`).
- **Duplicate names.** Code under `#if os(Linux)` compiles only here, so two lanes' definitions of one internal name, such as `_CLOCK_REALTIME`, collide only here. Grep `Sources/` before adding one.
- **Mutable C globals.** glibc declares `stdin`, `stdout`, and `stderr` as mutable globals, which Swift 6 rejects; `@preconcurrency import Glibc` accepts them.
- **Behaviors that differ.** `sysconf(_SC_JOB_CONTROL)` is 1, not 200112. `pathconf` gives a directory the terminal limits (`_PC_MAX_CANON` is 255) rather than failing. A mutex's priority ceiling must be in `SCHED_FIFO`'s range, 1 through 99; `SCHED_OTHER`'s is 0 through 0.
