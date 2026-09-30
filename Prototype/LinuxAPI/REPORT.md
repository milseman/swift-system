# linux-api: Linux API for the adopters' non-Darwin branches

The `linux-api` lane (worktree `../linux-api`, branch `linux-api`, base
system-next `6a9833f`) adds Linux API speculatively: nothing here is built or
run on Linux by this lane. Michael runs `Utilities/linux/build.sh` and puts
the logs in `../linux-logs/`; each batch below says what to check there.

"Linux" means glibc and musl. Android is included where Bionic has the same
interface at Swift's default API level (21), and said otherwise.

## Resume here

- State: inventory (section 1) and batches 1 to 11 (sections 2.1 to 2.11)
  committed. Batch 9 made system-next's code build on Linux: SystemPackage,
  the MemberImportVisibility probes and SystemTests all build, and the tests
  run; the failures left are other lanes' tests (section 3). Every earlier
  batch's Linux check (below) passed at `eabcd46`, but batch 8's pipe
  expectation, fixed in `08c79ad`.
- Next: `clone3` with `CLONE_PIDFD` (Subprocess), then the section 4
  needs, or a new pass over section 1.4 against the adopters' current
  branches. `SpawnCredentials` on Linux (Subprocess) is designed but left
  (section 2.10's note). `copy_file_range` turned out not to be needed on
  Linux (2.8).
- This lane owns `Sources/System/**`, `Sources/CSystem`, `Tests/SystemTests`
  and this report, not SystemSockets or its tests: socket API (vsock, UDP
  offload) goes to section 4, with a patch where one is written.
- Before each batch: read the newest log in `../linux-logs/`; compile errors
  in System come first.
- The lane runs the Linux build itself now, with the one command it's
  allowed (the build.sh line that writes
  `../linux-logs/linux-api-<commit>-noble-test.log` and prints the distinct
  errors, totals and failures), optionally with `-- --filter <Suite>`. It
  works from this sandbox.
- After each batch: run its Linux check, record the totals under the batch,
  and update this section.

## For the Linux run

Each check is run from this worktree (`../linux-api`) at the batch's commit or
later; a log goes to `../linux-logs/`. Items 1 to 8 ran at `eabcd46`, as
root on swift:6.2-noble arm64, in the full run
(`../linux-logs/linux-api-eabcd46-noble-test.log`): every one passed but
item 8's pipe check, fixed and rerun at `08c79ad`. Not run: the
`--user 1000:1000` variants, which the lane's command doesn't take, and
musl.

1. Batch 1 (O_TMPFILE, AT_EMPTY_PATH, the I/O vector limit):
   - `Utilities/linux/build.sh test -- --filter "UnnamedTemporaryFileTests|IOVectorLimitTests"`,
     as root, then again with `--user 1000:1000`. Expect the build to pass
     (the two CSystem getters in `shims.c`, `UIO_MAXIOV` from the C
     library's module) and 6 swift-testing tests to pass in both runs. As
     root, `anUnnamedFileGetsAName` links through `AT_EMPTY_PATH`; as 1000 it
     may take the `/proc/self/fd` fallback. If the scratch directory's file
     system has no `O_TMPFILE`, the two file tests pass without checking
     anything past the open: say so if the log shows it.
   - `Utilities/linux/build.sh test`: nothing else should change.
2. Batch 2 (`POSIXErrorCode`, `maxSymbolicLinks`,
   `maxExtendedAttributeNameBytes`):
   - `Utilities/linux/build.sh test -- --filter "POSIXErrorCode|CompileTimeLimits"`.
     Expect the build to pass (`Glibc.POSIXErrorCode`, and the
     `MAXSYMLINKS` and `XATTR_NAME_MAX` getters in `shims.c`), and 5
     swift-testing tests (the 2 `POSIXErrorCode` tests, now built on Linux,
     and 3 in `CompileTimeLimitsLinuxTests`) and the XCTest
     `CompileTimeLimitsTest`'s 4 cross-platform tests to pass.
     `extendedAttributeNames` returns early if the scratch file system has
     no `user.` attributes; say so if it does.
   - For the musl half, when a static-SDK build is available:
     `swift build --swift-sdk <musl SDK>`, which takes the `XATTR_NAME_MAX`
     fallback in `shims.c` and `Musl.POSIXErrorCode`.
3. Batch 3 (`CLocale` on glibc and musl):
   - `Utilities/linux/build.sh test -- --filter "ProvisionalLocale"`. Expect
     the build to pass (`csystem_strtod_l`, `csystem_strtof_l` and the
     `LC_ALL_MASK` getter in `shims.c`; `LC_*_MASK`, which are
     `(1 << __LC_*)` in glibc, importing into Swift), and 6 XCTest tests in
     `ProvisionalLocaleLinuxTest` to pass, or 4 and 2 skipped where
     `fr_FR.UTF-8` isn't installed, as in the plain swift images. If the
     masks don't import, the build fails in `Constants+Provisional.swift`:
     say so, and they become getters.
   - To run the French checks: `Utilities/linux/build.sh shell`, then
     `apt-get update && apt-get install -y locales && locale-gen fr_FR.UTF-8`
     and the same `swift test` command in the container.
4. Batch 4 (the time zone paths):
   - `Utilities/linux/build.sh test -- --filter TimeZoneFiles`. Expect the
     build to pass (the `TZDIR` and `TZDEFAULT` getters in `shims.c`) and
     `TimeZoneFilesLinuxTests`' test to pass. Where
     `/usr/share/zoneinfo` exists it also stats `Etc/UTC`; say whether the
     image has it.
5. Batch 5 (`mkostemps`, `dladdr`, `RTLD_DEEPBIND`):
   - `Utilities/linux/build.sh test -- --filter SmallLinuxGapsTest`. Expect
     the build to pass (`csystem_mkostemps` and `csystem_dladdr` in
     `shims.c`, `RTLD_DEEPBIND` from Glibc's module) and 4 XCTest tests to
     pass. `testSymbolInfo` names the symbol `getpid` or `__getpid`; say
     which, and the library path, if it fails.
6. Batch 6 (the default pthread initializers, `O_SYNC`, `O_DSYNC`):
   - `Utilities/linux/build.sh test -- --filter SmallLinuxGapsTest`: now 6
     XCTest tests, the new ones `testStaticInitializers` and
     `testSynchronizedIO`. The latter checks that Linux's `F_SETFL` ignores
     `O_SYNC`, as the man page says; if it fails there, the doc is wrong.
7. Batch 7 (unique files with permissions):
   - `Utilities/linux/build.sh test -- --filter UniqueFilesWithPermissions`:
     6 XCTest tests, the 4 real ones from `UniqueFilesWithPermissionsTest`
     (now built on Linux) and the 2 mock ones in
     `UniqueFilesWithPermissionsLinuxTest`. With `--user 1000:1000` too, to
     be sure the creation-mask test holds for an unprivileged user.
   - The link should print no `mktemp` warning: say if one appears.
8. Batch 8 (`FICLONE`):
   - `Utilities/linux/build.sh test -- --filter FileContentsCloneTest`: 2
     XCTest tests. On the container's file systems the clone throws
     `EOPNOTSUPP`, which the test accepts after checking `EINVAL` for a
     pipe and `EBADF` for a read-only destination. To see a clone work,
     run it on Btrfs or XFS with reflinks, if there's one to mount.
9. Batch 10 (`readPassphrase`): `--filter ReadPassphrase`, 5 XCTest tests;
   passed at `7f99387`.
10. Batch 11 (`FileWatcher`): `--filter FileWatcherTest`, 4 XCTest tests;
    passed at `1c3e1c5`.

## Baseline (Darwin)

system-next `6a9833f`, macOS 26.3, Swift 6.2 (swiftlang-6.2.0.19.9),
`swift build && swift test`: XCTest 565 tests, 4 skipped, 0 failures;
swift-testing 496 tests in 80 suites passed.

## 1. Inventory

### 1.0 Sources

- (a) comes from the api-delta report of `main` (`1b452c2`) against
  system-next `eee1da2` (`../swift-system/.build/api-graph/api-delta/`),
  whose entries carry the platforms each declaration builds on, and from the
  coverage tool's derivation of what System names per platform
  (`../coverage-results/systems/145df6b…/*/derived.json`). Only four commits
  touched `Sources/` between those and `6a9833f` (loadedImageCount,
  DirectoryWalk options, Errno.notCapable, FileStream.readLine), none of them
  Darwin-only API with a Linux twin.
- (b) comes from three views of each adopter: the System declarations its
  migrated Darwin branch calls (the API graph's `uses`, from the
  `migrate-darwin` index builds) intersected with the Darwin-only entries of
  (a); the coverage results for its merge-base commit
  (`../coverage-results/results/<pkg>/…/a3a634eb…/`), whose per-platform
  status shows entries covered on Darwin and not on Linux, and entries used
  only on Linux; and a lexical scan of the files on `migrate-darwin`
  (swift-foundation: `no-darwin`) that import Glibc, Musl, Bionic or
  Android, for the C names in the first two views.

### 1.1 (a) Darwin-only API where glibc and musl have the same C interface

| System API (file) | C interface | glibc | musl | Bionic | Values that differ | Adopters |
|---|---|---|---|---|---|---|
| `CInterop.POSIXErrorCode`, `init?(_: Errno)`, `.errno` (Provisional/Provisional+POSIXErrorCode.swift) | the overlay's `POSIXErrorCode` enum | `Glibc.POSIXErrorCode` | `Musl.POSIXErrorCode` | `Android.POSIXErrorCode` | the cases' raw values are each platform's errno | swift-foundation (ErrorCodes+POSIX.swift, 122 references), TSC (6), indexstore-db (1) |
| `SystemConfig.maxSymbolicLinks` (Limits/CompileTimeLimits.swift) | `MAXSYMLINKS`, `<sys/param.h>` | 20; not in Glibc's module | 20; in Musl's | 8 (from memory of Bionic's header); not in the NDK module | Darwin 32. Linux's kernel follows 40, more than the headers say | swift-foundation (String+Path.swift, 2) |
| `SystemConfig.maxExtendedAttributeNameBytes` (same file) | `XATTR_MAXNAMELEN` on Darwin; `XATTR_NAME_MAX` on Linux, `<linux/limits.h>` | 255, through `<limits.h>` | 255; musl's `<limits.h>` doesn't include it | 255, through `<limits.h>` | Darwin 127. A longer name fails with `ENAMETOOLONG` on Darwin, `ERANGE` on Linux | swift-nio (FileSystemError+Syscall.swift, 6, in Darwin-only error mapping) |
| vsock: `SocketDescriptor.Domain.vsock`, `VMSocketAddress`, `CInterop.SockAddrVM` and its accessors, `SocketAddress(vsock:)`, `.vsock`, `localContextID()` (SystemSockets: SocketAddress+VMSocket.swift, CInterop+SocketAccessors.swift, SocketSyscalls+VMSockets.swift) | `AF_VSOCK`, `struct sockaddr_vm`, `VMADDR_*`, `IOCTL_VM_SOCKETS_GET_LOCAL_CID` | `AF_VSOCK` 40 in the module; `sockaddr_vm` only in `<linux/vm_sockets.h>`, which no libc module includes | same | same | `sockaddr_vm`: Darwin has `svm_len`, a one-byte family; Linux a two-byte family, and `svm_flags` (5.11) in the padding; both 16 bytes. `VMADDR_CID_LOCAL` (Linux 5.6) is Darwin's `VMADDR_CID_RESERVED`, both 1. The ioctl is `_IOR('s', 209, uint32_t)` on the socket on Darwin, `_IO(7, 0xb9)` = 0x7b9 on `/dev/vsock` on Linux | swift-nio (VsockAddress.swift: 12 `sockaddr_vm`, the family and CID constants, the ioctl through CNIOLinux) |
| `CLocale` (33 declarations: `newlocale`, `freelocale`, `setlocale`, `LC_*`, `LC_*_MASK`, `LC_GLOBAL_LOCALE`, `strtod_l`, `strtof_l`, `strncasecmp_l`) (Provisional/Provisional+Locale.swift) | POSIX 2008 locales, plus the GNU `strtod_l`/`strtof_l` | `newlocale` family and `strncasecmp_l` by default; `strtod_l`/`strtof_l` only with `_GNU_SOURCE`; `LC_ALL_MASK` is an OR of 12 macros, which Swift doesn't import | `strtod_l`/`strtof_l` with `_GNU_SOURCE`; `LC_ALL_MASK` 0x7fffffff | `newlocale` 21, `strtod_l` 26 (from memory) | categories: Darwin `LC_ALL` 0, `COLLATE` 1, `CTYPE` 2, `MONETARY` 3, `NUMERIC` 4, `TIME` 5, `MESSAGES` 6; glibc and musl `CTYPE` 0, `NUMERIC` 1, `TIME` 2, `COLLATE` 3, `MONETARY` 4, `MESSAGES` 5, `ALL` 6. Masks: Darwin `LC_ALL_MASK` 0x3f; glibc 0x1fbf (its 12 categories). `locale_t` is an opaque pointer on Darwin and musl, `UnsafeMutablePointer<__locale_struct>` on glibc. Darwin's `LC_C_LOCALE` is NULL; glibc and musl have no constant, and glibc's `*_l` functions crash on NULL | swift-foundation (Platform.swift: `strtod_l`, `strtof_l`, `strncasecmp_l`, `newlocale`, `locale_t`, `LC_C_LOCALE`; JSONEncoderTests: `setlocale`) |
| `FilePath.makeUniqueFile(suffixLength:options:)` (TemporaryFiles/UniqueFilesWithSuffix.swift; Darwin, FreeBSD, OpenBSD) | `mkostemps` | only with `_GNU_SOURCE` | with `_BSD_SOURCE`, musl's default | 23 | flags are `O_*` values | TSC (TemporaryFile.swift, Darwin branch uses it; Linux calls `mkstemps`) |
| `FilePath.makeUniqueFile(options:permissions:)` (TemporaryFiles/UniqueFilesWithPermissions.swift) | `mktemp`, then `open` with `O_EXCL` | yes, but the linker warns that `mktemp` is dangerous | yes | yes | — | swift-foundation (Data+Writing.swift, 6 `mktemp`) |
| `DynamicLibrary.symbolInfo(containing:)`, `SymbolInfo` (DynamicLoading/DynamicLibrary.swift) | `dladdr`, `Dl_info` | only with `_GNU_SOURCE`, so the struct isn't visible either | with `_BSD_SOURCE` | always | — | swift-build (coverage: `dladdr`, `Dl_info` on Linux, 3) |
| `FileDescriptor.OpenOptions.sync`, `.dataSync`, and the `StatusFlags` pair (SynchronizedIO/SynchronizedIO.swift) | `O_SYNC`, `O_DSYNC` | yes | yes | yes | Darwin 0x80 and 0x400000; Linux 0x101000 (04010000) and 0x1000 (010000) on x86_64 and arm64 | none found |
| `CInterop.PThreadMutex.initializer`, `PThreadCondition.initializer`, `PThreadReadWriteLock.initializer` (Threads/PThreadStaticInitializers.swift) | `PTHREAD_MUTEX_INITIALIZER`, `PTHREAD_COND_INITIALIZER`, `PTHREAD_RWLOCK_INITIALIZER` | struct-initializer macros Swift can't import; all three are all-zero bytes | all zero | all zero | the recursive and error-checking mutex initializers are GNU (`_NP`) in glibc and Bionic, and missing in musl | swift-sdk-generator (4) |
| `CInterop.SpawnAttributes`, `SpawnFileActions` (RawSpawn/RawSpawn.swift; Darwin, FreeBSD, OpenBSD) | `posix_spawnattr_t`, `posix_spawn_file_actions_t` | structs | structs | structs | pointers on Darwin and the BSDs | swift-subprocess's Darwin branch; its Linux branch forks through its own shim |

### 1.2 (a) Darwin-only API with a Linux counterpart under another C interface

| System API | Darwin | Linux | Adopters |
|---|---|---|---|
| `FilePath.currentExecutable()` | `_NSGetExecutablePath` | `readlink("/proc/self/exe")` | swift-foundation (Platform.swift) |
| `FilePath.timeZoneDirectory`, `.defaultTimeZoneFile` | `TZDIR`, `TZDEFAULT` from `<tzfile.h>` | no header: glibc doesn't install `<tzfile.h>`; the conventional `/usr/share/zoneinfo` and `/etc/localtime` | swift-foundation (TimeZone_Cache.swift: `TZDIR` 2, `TZDEFAULT` 3, its own values) |
| `TerminalDescriptor.readPassphrase` | `readpassphrase` | none in glibc or musl (libbsd has it); `getpass`, obsolete | swift-package-manager (PackageRegistryCommand+Auth.swift, `getpass` 3) |
| `SpawnCredentials`, `ProcessID.spawn(…credentials:…)` | `fork`, credentials, then `posix_spawn` with `POSIX_SPAWN_SETEXEC` | `fork`, `setgroups`/`setgid`/`setuid`, file actions by hand, `execve` | swift-subprocess (Subprocess+Darwin.swift 4; its Linux branch has `_subprocess_fork_exec`, `fork` 16) |
| `PThread.isMainThread` | `pthread_main_np` | `gettid() == getpid()` | swift-nio (Darwin-only check) |
| `PThread.Condition.wait(on:timeout:)` | `pthread_cond_timedwait_relative_np` | already answered: `Attributes.clock` with `CLOCK_MONOTONIC`, then `wait(on:until:)`, as the doc says | swift-nio (lock.swift) |
| `FilePath.copy`, `FileDescriptor.copy` | `copyfile`, `fcopyfile` | `copy_file_range`, `sendfile`, `ioctl(FICLONE)` | swift-nio (FileSystem.swift), swift-foundation (FileOperations.swift: `copy_file_range` 2, `sendfile` 2, `FICLONE` 1) |
| `SocketDescriptor.TCPConnectionInfo` | `TCP_CONNECTION_INFO` | already answered: `CInterop.TCPInfo` and `.info` (`TCP_INFO`) in SocketTCPInfo.swift | swift-nio |
| `KernelQueue`, `KernelEvent` | kqueue | already answered: `EventPoll` (epoll_create1, ctl, wait, pwait) | swift-nio, swift-subprocess |
| `Entropy.generate` | `arc4random*` (Darwin, Android, BSDs) | glibc 2.36 and later only; musl none; `getentropy`/`getrandom` elsewhere | — |
| `CallStack` | `backtrace`, `backtrace_symbols` | glibc's `<execinfo.h>`; musl none | — |

### 1.3 Darwin-only with no Linux counterpart (left as they are)

Attribute lists, volume capabilities, `copyfile`/`clonefile`, `removefile`,
kqueue types, Darwin `fcntl` commands and structs, `F_GETPATH`,
`F_NOCACHE`, `F_SETNOSIGPIPE`/`SO_NOSIGPIPE`, `chflags` and file flags, mount
flags, `getfsstat`, `fsid_t`, file system subtypes, `st_birthtime`,
`st_flags`, `AT_FDONLY`, `AT_REALDEV`, `AT_SYMLINK_NOFOLLOW_ANY`,
`AT_RESOLVE_BENEATH` (Linux has `openat2`), Darwin quotas, libproc, sysctl,
`confstr(_CS_DARWIN_*)`, `mkpath_np`, `mkostempsat_np`, sysdir search paths,
Mach time, VM, CPU types and kernel errors, malloc zones, typed allocation,
`malloc_good_size`, `reallocf`, unfair locks, QoS classes, `pthread_getugid_np`,
I/O policy, Darwin clocks, Darwin-only errno values, `SIGEMT`/`SIGINFO`,
`POSIX_SPAWN_CLOEXEC_DEFAULT`/`START_SUSPENDED`/`SETEXEC`, `RTLD_FIRST`,
`O_EVTONLY`, `O_SYMLINK`, `O_EXLOCK`/`O_SHLOCK`, `O_EXEC`/`O_SEARCH` (musl
defines both as `O_PATH`, glibc neither), `SEEK_HOLE`/`SEEK_DATA` (Linux
has them; System's are Darwin and FreeBSD, a small widening for later),
`_PC_MIN_HOLE_SIZE`, `_PC_XATTR_SIZE_BITS`, Darwin baud rates, termios
flags and control characters, `TCSASOFT`, `AF_NDRV`, `AF_SYSTEM`,
`IP_RECVDSTADDR`, `SO_LINGER_SEC`, the Finder-info and resource-fork
attribute names.

### 1.4 (b) The adopters' non-Darwin branches, by adopter weight

Counts are references in the files that import a Linux C module
(migrate-darwin), or sites in the coverage results, as marked.

1. **swift-nio**
   - Darwin answer, no Linux one: vsock (above; 12 `sockaddr_vm`, the ioctl
     and constants through CNIOLinux). `maxExtendedAttributeNameBytes` and
     `isMainThread` are used only in Darwin-only code.
   - Linux-only, missing: `O_TMPFILE` (NIO extends System's
     `FileDescriptor.OpenOptions` with `temporaryFile` from
     `CNIOLinux_O_TMPFILE`), `AT_EMPTY_PATH` (its own resolution flag from
     `CNIOLinux_AT_EMPTY_PATH`), `UDP_SEGMENT`/`UDP_GRO` (hardcoded 103 and
     104, 7), `UIO_MAXIOV` (8; System has only `sysconf(_SC_IOV_MAX)`),
     liburing's poll API (io_uring; not this lane's).
   - Linux-only, covered already: epoll (`EventPoll`), `tcp_info`,
     `renameat2`, `sendfile`, `if_nametoindex`, `getifaddrs`, `getpwuid_r`,
     CPU sets, eventfd, timerfd, `statfs` `f_type` (`FileSystemType`).
2. **swift-foundation**
   - Darwin answer, no Linux one: `POSIXErrorCode` (122), `CLocale`
     (Platform.swift, 12), `MAXSYMLINKS` (2), `mktemp` (6),
     `_NSGetExecutablePath` (2), `TZDIR`/`TZDEFAULT` (5).
   - Linux-only, missing: `copy_file_range` (2), `FICLONE` (1), `tzset`,
     `O_PATH` (1). `CLOCK_MONOTONIC_RAW` is covered (`ClockID.monotonicRaw`).
3. **swift-subprocess**
   - Darwin answer, no Linux one: `SpawnCredentials` (the `fork` and exec
     path, 16 `fork`), the environment lock (`_subprocess_lock_environ`).
   - Linux-only: epoll (covered), pidfd and `waitid(P_PIDFD)` (covered:
     `ProcessDescriptor`), `close_range` (covered), `signalfd` (covered),
     `clone3` with `CLONE_PIDFD` (6, missing).
4. **swift-package-manager**: `getpass` (3), whose Darwin answer is
   `readPassphrase`.
5. **swift-build**: `dladdr`/`Dl_info` (coverage, 3).
6. **swift-tools-support-core**: `POSIXErrorCode` (6), `mkstemps` (its
   Darwin branch uses `makeUniqueFile(suffixLength:)`), inotify (FSWatch:
   `inotify_init1`, `inotify_add_watch`, `inotify_event`, 12 `IN_*`; missing),
   `RTLD_DEEPBIND` (2; glibc only), `select`/`fd_set` (5).
7. **swift-driver**: `RTLD_DEEPBIND` (1).
8. **swift-llbuild**: nothing beyond `syscall` (which System won't wrap).
9. The rest: indexstore-db (`POSIXErrorCode`), swift-sdk-generator
   (`PTHREAD_MUTEX_INITIALIZER` 4; `getdents64` for closing descriptors,
   which `close_range` covers), WasmKit (`MAP_ANONYMOUS`, `O_RSYNC`),
   swift-syntax (`proc_pid_rusage`, no Linux twin). sourcekit-lsp,
   swift-argument-parser, swift-async-algorithms, swift-certificates,
   swift-corelibs-xctest, swift-docc, swift-log, swift-tools-protocols: none.

### 1.5 Batch plan

In the ranking's order, each small enough to review alone:

1. NIO: `O_TMPFILE`, `AT_EMPTY_PATH`, a compile-time `UIO_MAXIOV`
   (done, section 2.1). vsock and `UDP_SEGMENT`/`UDP_GRO` are SystemSockets
   API, outside this lane's files: section 4.
2. Foundation (and TSC, indexstore-db): `POSIXErrorCode`;
   `maxSymbolicLinks` and `maxExtendedAttributeNameBytes` on Linux.
3. Foundation: `CLocale` on glibc and musl.
4. Foundation: the time zone paths on Linux. `currentExecutable()` stays
   Darwin's (section 2.4).
5. TSC: `makeUniqueFile(suffixLength:)` (`mkostemps`); swift-build:
   `symbolInfo(containing:)` (`dladdr`); TSC and swift-driver:
   `RTLD_DEEPBIND` on glibc (done, section 2.5).
6. swift-sdk-generator: the three default pthread initializers; `O_SYNC`
   and `O_DSYNC` (done, section 2.6).
7. Larger, later: `readPassphrase` on Linux (SwiftPM; done, section 2.10),
   `SpawnCredentials` on Linux (Subprocess; left, 2.10), inotify (TSC; done,
   2.11), `FICLONE` (Foundation; done, 2.8), `clone3` (Subprocess).

## 2. Batches

### 2.1 Batch 1: unnamed temporary files and the I/O vector limit (swift-nio)

What NIO's Linux branch defines for itself from CNIOLinux, or per C library:

- `FileDescriptor.OpenOptions.temporaryFile` (`O_TMPFILE`) and
  `FilePath.ResolutionFlags.emptyPath` (`AT_EMPTY_PATH`), on Linux and
  Android, in `TemporaryFiles/UnnamedTemporaryFiles.swift`. NIO's
  SystemFileHandle opens an unnamed file with `temporaryFile` (its own
  extension of System's `OpenOptions`, from `CNIOLinux_O_TMPFILE`) and names
  it with `linkat` and its own `emptyPath` flag; System's `makeHardLink(relativeTo:to:relativeTo:flags:)`
  takes the flag. glibc and Musl declare both constants only with
  `_GNU_SOURCE`, so `shims.c`, which defines it, returns them through
  `_system_get_O_TMPFILE` and `_system_get_AT_EMPTY_PATH`, as the `ST_*`
  getters do. Bionic defines both.
- `SystemConfig.maxIOVectors`, the headers' limit on a vectored call's
  buffers, on Darwin (`IOV_MAX`), Linux and Android (`UIO_MAXIOV`, which
  glibc exposes where `IOV_MAX` needs `_XOPEN_SOURCE`): 1024 everywhere.
  NIO's `Posix.UIO_MAXIOV` is 1024 on Darwin, and `Glibc.UIO_MAXIOV`,
  `Musl.UIO_MAXIOV` or `Android.UIO_MAXIOV` elsewhere.
  `SystemConfig.Name.maxIOVectors` is the `sysconf` limit; the static
  property follows `maxFileNameBytes`, the headers' limit beside the run
  time's.

Design calls:

- Getters rather than `CSYSTEM_` macros: `O_TMPFILE` includes `O_DIRECTORY`,
  which differs by architecture (x86_64 `020200000`, arm64 `020040000`), and
  glibc's `__O_TMPFILE` includes it where the kernel's doesn't, so a
  hardcoded value would need one per architecture. Rejected: a macro with a
  `_Static_assert` per architecture.
- `temporaryFile` gets the `O_TMPFILE` renamed stub, as the other
  `OpenOptions` do; `ResolutionFlags` has none, so `emptyPath` doesn't.
- `open` doesn't require permissions with `temporaryFile`, as it does
  (with a trap) for `create`, though the kernel reads a mode for both. The
  doc says to pass them. Open: whether `_open` should trap for
  `temporaryFile` too; that's a change to `FileOperations.swift`'s behavior
  on Linux, not a gate.
- `emptyPath` is only a `ResolutionFlags`; `Stat.Flags` (for `fstatat`)
  could take it too, which NIO doesn't need.
- Naming: NIO's own `temporaryFile` extension will shadow System's in NIO's
  module until NIO deletes it.
- `maxIOVectors` is gated to Darwin, Linux and Android; FreeBSD and OpenBSD
  have `IOV_MAX` too, unchecked here.

Tests:

- `Tests/SystemTests/UnnamedTemporaryFileTests.swift` (Linux and Android,
  swift-testing): the flags' values; an unnamed file has no links, links
  through `emptyPath` (or, without `CAP_DAC_READ_SEARCH`, through
  `/proc/self/fd` and `symlinkFollow`), and then has one, with the same
  inode and size; `exclusiveCreate` prevents the link; opening read-only
  throws `EINVAL`. A file system without `O_TMPFILE` ends the file tests
  after the open.
- `Tests/SystemTests/IOVectorLimitTests.swift` (Darwin, Linux, Android): the
  limit is 1024 and no more than `sysconf`'s; a `writev` of that many
  buffers to `/dev/null` writes them all, and one more throws `EINVAL`.
- The Linux code was typechecked on Darwin in a scratch copy, with its
  conditions made true and the getters' values stubbed, which caught two
  catch clauses comparing `any Error` with an `Errno` (a `do` inside a
  closure doesn't infer the typed error).
- Darwin, after (`swift build && swift test`): XCTest 565 tests, 4 skipped,
  0 failures; swift-testing 498 tests in 81 suites passed (the two new
  I/O vector tests; the unnamed-file tests don't build on Darwin).

### 2.2 Batch 2: `POSIXErrorCode` and two header limits (swift-foundation, TSC, indexstore-db)

- `CInterop.POSIXErrorCode`, and its `init?(_: Errno)` and `errno`, widen
  to Linux and Android, where the type is the Glibc, Musl or Android
  overlay's `POSIXErrorCode` (the overlays each compile the standard
  library's `POSIXError.swift`, with their C library's values). Foundation's
  Linux branch imports Glibc, Musl or Android in `ErrorCodes+POSIX.swift`
  for that type alone (122 references); its Darwin branch already names it
  through System. TSC (6) and indexstore-db (1) use it too.
- `SystemConfig.maxSymbolicLinks` (`MAXSYMLINKS`) and
  `maxExtendedAttributeNameBytes` (`XATTR_NAME_MAX` on Linux) widen to
  Linux and Android. Foundation's Linux branch reads `MAXSYMLINKS` for its
  own link resolution (String+Path.swift) where its Darwin branch reads
  `maxSymbolicLinks`. `MAXSYMLINKS` is in `<sys/param.h>`, which glibc's
  and Bionic's modules don't include and `CSystemLinux.h` can't (it
  includes `<signal.h>`); `XATTR_NAME_MAX` is in `<linux/limits.h>`, which
  Musl's `<limits.h>` doesn't include. So both come from getters in
  `shims.c`, with the kernel's 255 where Musl lacks the macro.

Design calls:

- `maxSymbolicLinks` returns the headers' `MAXSYMLINKS` on Linux, 20 in
  glibc and Musl, though the kernel follows 40, so the doc says so. That's
  the value Foundation's Linux code uses today, so migrating changes
  nothing. Rejected: returning 40, which no Linux header names as
  `MAXSYMLINKS` (Musl's `SYMLOOP_MAX` is 40; glibc has none, and its own
  `realpath` uses at least 40). Bionic's value is 8, from memory of its
  header, unchecked, so the doc doesn't say it.
- `maxExtendedAttributeNameBytes` keeps its name and gets Linux's
  different constant and error (`ERANGE`, not `ENAMETOOLONG`), in the doc.
- The Android typealias is `Android.POSIXErrorCode`, from the Android
  overlay, which compiles `POSIXError.swift` (checked in the swift
  checkout's `stdlib/public/Platform/CMakeLists.txt`). FreeBSD and OpenBSD
  get the type from the Glibc overlay too; they're left out, unchecked.

Tests:

- `ProvisionalPOSIXErrorCodeTests.swift` widens to Linux and Android (its
  imports only).
- `Tests/SystemTests/CompileTimeLimitsLinuxTests.swift` (Linux and Android,
  swift-testing): 20 and 255 on glibc and Musl; a chain of
  `maxSymbolicLinks` links and one of 40 open, and one of 41 throws
  `ELOOP`; a 255-byte `user.` attribute name is accepted and a 256-byte one
  throws `ERANGE` (unless the file system has no user attributes).
  Typechecked on Darwin in a scratch copy with its condition made true.
- Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
  tests in 81 suites passed (no new Darwin tests).

### 2.3 Batch 3: `CLocale` on glibc and musl (swift-foundation)

Foundation's `Platform.swift` parses and compares text in the POSIX locale:
on Darwin through `CLocale.posix`'s `parseDouble`, `parseFloat` and
`compareIgnoringCase`; on Linux with its own `newlocale(LC_ALL_MASK, "C", 0)`
(through its `_stringshims_LC_ALL_MASK`) and `strtod_l`, `strtof_l` and
`strncasecmp_l`, visible there because its package defines `_GNU_SOURCE`
for the Swift target. `CLocale` and `CInterop.Locale` widen to Linux, so it
can do the same there.

- The calls: `newlocale`, `freelocale`, `setlocale` and `strncasecmp_l` are
  in glibc's and Musl's modules; `strtod_l` and `strtof_l` need
  `_GNU_SOURCE`, so they're `csystem_strtod_l` and `csystem_strtof_l`, which
  take the locale as `void *`.
- The categories and masks are the C library's (glibc and Musl share
  `LC_CTYPE` 0 through `LC_MESSAGES` 5 and `LC_ALL` 6, unlike Darwin).
  `Categories.all` is `LC_ALL_MASK` on Linux, from a getter: glibc's is an
  OR of twelve masks (0x1fbf, with its six extra categories), Musl's
  0x7fffffff. On Darwin it stays the OR of the six, which is Darwin's
  `LC_ALL_MASK`.
- `posix` stays `CLocale(rawValue: nil)`, as on Darwin, where the null
  locale is `LC_C_LOCALE`. Linux has no such constant, and glibc's `*_l`
  calls crash on a null locale, so the wrappers pass a POSIX locale that
  `newlocale` makes once, in a `nonisolated(unsafe)` global that nothing
  frees. Rejected: a non-nil `posix` on Linux, which would make `free()`
  able to free the shared locale, and `rawValue`'s meaning differ by
  platform.
- `global` is `LC_GLOBAL_LOCALE`, `(locale_t)-1` everywhere, now spelled
  `CInterop.Locale(bitPattern: -1)`, since glibc's `locale_t` is a typed
  pointer, not an `OpaquePointer`. POSIX leaves `LC_GLOBAL_LOCALE` undefined
  for the `*_l` calls, and glibc's crash on it, so on Linux the wrappers
  call `strtod`, `strtof` and `strncasecmp` for it, which follow the calling
  thread's locale: the global one unless the thread called `uselocale`,
  which System doesn't wrap. The doc says so. Open: `duplocale(LC_GLOBAL_LOCALE)`
  per call, exact but an allocation each time.
- Android stays out: Bionic has `strtod_l` and `strtof_l` from API level 26
  (from memory), and Swift's default is 21. A shim that fails below 26, as
  `csystem_pthread_getname_np` does, would do; Foundation's Android branch
  is the same as its Linux one.

Tests:

- `Tests/SystemTests/ProvisionalLocaleLinuxTests.swift` (Linux, XCTest,
  since it sets the global locale): the mock test with Linux's
  `LC_ALL_MASK`; the categories' Linux values; parsing and comparing in the
  POSIX locale (the Darwin test's cases) and comparing in the global one;
  `C.UTF-8`, which glibc 2.35 and Musl build in; and on glibc, where
  `fr_FR.UTF-8` is installed (it isn't in the plain images: `XCTSkip`
  otherwise), a comma decimal separator in a named, a numeric-only and the
  global locale, while the POSIX locale's doesn't change. Musl's numbers
  don't follow the locale, and it accepts any locale name, so those checks
  are glibc's.
- Typechecked on Darwin in a scratch copy, with the Linux branches of
  `Syscalls+ProvisionalLocale.swift` and the test made true and the shims
  stubbed. That checks Musl's shape (`locale_t` an `OpaquePointer`), not
  glibc's typed pointer.
- Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
  tests in 81 suites passed (Darwin's `ProvisionalLocaleTest` unchanged:
  its mock locale and `global` are now spelled through `locale_t`).

### 2.4 Batch 4: the time zone paths (swift-foundation)

- `FilePath.timeZoneDirectory` (`TZDIR`) and `.defaultTimeZoneFile`
  (`TZDEFAULT`) widen to Linux, glibc and Musl. Foundation's
  `TimeZone_Cache.swift` reads them through System on Darwin, and on Linux
  through its own `_CStdlib.h`, which includes `<tzfile.h>` where there's
  one and otherwise defines `/usr/share/zoneinfo/` and `/etc/localtime`;
  its Linux branch then calls `readlink` on `TZDEFAULT` itself. glibc
  doesn't install `<tzfile.h>` and Musl has none, so `shims.c` does as
  Foundation does, through `_system_get_TZDIR` and `_system_get_TZDEFAULT`.
- The docs say what differs on Linux: the directory can be missing (a
  container without tzdata), and `/etc/localtime` can be a copy rather than
  a link, or missing, meaning UTC.
- Android stays out: Bionic keeps every zone in one `tzdata` file and has
  no `/etc/localtime`.
- `FilePath.currentExecutable()` stays Darwin's. On Linux the path is
  `/proc/self/exe`'s target, which `FilePath.readSymbolicLink` already reads
  on every platform (Foundation's Linux branch reads it through
  `FileManager`, not a C call). A Linux `currentExecutable()` would have to
  throw, since `/proc` can be missing, where Darwin's doesn't, and it would
  give the resolved path where Darwin's gives the one executed. Rejected
  for now; open: a throwing `ProcessID.executablePath()` on Linux, beside
  macOS's libproc one, which also resolves the path.

Tests:

- `Tests/SystemTests/TimeZoneFilesLinuxTests.swift` (Linux, swift-testing):
  the two paths, and `Etc/UTC` a regular file where the directory exists.
  Typechecked on Darwin in a scratch copy.
- Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
  tests in 81 suites passed (no new Darwin tests).

### 2.5 Batch 5: `mkostemps`, `dladdr`, `RTLD_DEEPBIND` (TSC, swift-build, swift-driver)

- `FilePath.makeUniqueFile(suffixLength:options:)` (`mkostemps`) widens to
  Linux and Android. TSC's `TemporaryFile.swift` calls it on Darwin and
  `mkstemps` on Linux. glibc and Musl declare `mkostemps` only with
  `_GNU_SOURCE`, and Bionic from API level 23, so it's
  `csystem_mkostemps`, beside `csystem_mkostemp` and on its pattern: below
  API 23 it calls `mkstemps` when there are no options and fails with
  `ENOSYS` when there are. The relative variant (`mkostempsat_np`) stays
  Darwin's.
- `DynamicLibrary.symbolInfo(containing:)` and `SymbolInfo` (`dladdr`,
  `Dl_info`) widen to Linux and Android, for swift-build's Linux `dladdr`.
  glibc declares both only with `_GNU_SOURCE`, so `csystem_dladdr` returns
  `Dl_info`'s four fields through pointers; the Swift type is unchanged.
  The doc says what Linux's loader finds: exported symbols only, and
  nothing in a statically linked program.
- `DynamicLibrary.OpenOptions.deepBind` (`RTLD_DEEPBIND`), on Linux with
  glibc only: Musl and Bionic don't have it. TSC and swift-driver load
  libSwiftScan with it on Linux where they pass `RTLD_FIRST` on Darwin.
  Named on the pattern of `noLoad` and `noDelete`; rejected: `deepBinding`.

Tests:

- `Tests/SystemTests/SmallLinuxGapsTests.swift` (Linux and Android,
  XCTest, as its Darwin counterparts are): the `mkostemps` mock test; a
  unique file with a suffix (name, mode 0600, close-on-exec, and the
  six-X rule); `dladdr` on `getpid`'s address, found through
  `mainProgram()` (skipped where the program has no dynamic symbols, as a
  static Musl one doesn't), with glibc's library path; and on glibc,
  `libm.so.6` loaded with `deepBind` finding `cos`.
- Typechecked on Darwin in a scratch copy, with the Linux branches made
  true and the shims stubbed.
- Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
  tests in 81 suites passed (no new Darwin tests).

### 2.6 Batch 6: the default pthread initializers, `O_SYNC` and `O_DSYNC`

- `CInterop.PThreadMutex.initializer`, `PThreadCondition.initializer` and
  `PThreadReadWriteLock.initializer` widen to Linux and Android, where
  `PTHREAD_MUTEX_INITIALIZER`, `PTHREAD_COND_INITIALIZER` and
  `PTHREAD_RWLOCK_INITIALIZER` are all zero bytes in glibc, Musl and
  Bionic, so each is the C type's zero value. swift-sdk-generator's
  non-Darwin branch uses `PTHREAD_MUTEX_INITIALIZER`. The error-checking
  and recursive initializers stay Darwin's: glibc and Bionic have them only
  as `_NP` macros that set a kind field, and Musl has none. Rejected:
  setting glibc's `__data.__kind`, an implementation detail Musl lays out
  differently.
- `FileDescriptor.OpenOptions.sync` and `.dataSync`, and the `StatusFlags`
  pair, widen to Linux and Android (`O_SYNC`, `O_DSYNC`, in every C
  library's module). No adopter needs them; they're here because the C
  interface is the same. Linux's `O_SYNC` includes `O_DSYNC`'s bit, and its
  `F_SETFL` ignores both, which the docs say.

Tests (`SmallLinuxGapsTests.swift`, XCTest): the initializers are zero
bytes and make a mutex, a condition variable and a read-write lock that
work without an init call (the Darwin test's checks, without the
error-checking and recursive mutexes); the flags' values on x86_64 and
arm64, `O_SYNC` reported with `O_DSYNC`, and `F_SETFL` leaving `O_SYNC`
off. Typechecked on Darwin in a scratch copy.

Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
tests in 81 suites passed (no new Darwin tests).

### 2.7 Batch 7: unique files with permissions (swift-foundation)

- `FilePath.makeUniqueFile(options:permissions:)` and
  `makeUniqueFile(relativeTo:options:permissions:)` widen to Linux and
  Android. Foundation's `Data+Writing.swift` calls them on Darwin; its
  Linux branch calls `mktemp` itself (silencing the deprecation) and then
  `open` or `openat` with `O_CREAT | O_EXCL` and the mode.
- On Linux and Android, System makes the name without `mktemp`, whose use
  glibc's linker warns about in every program that links it (why the file
  said Darwin only): `_makeTemplateName` replaces the trailing `X`s, as
  `mktemp` does, with letters and digits from the standard library's
  `SystemRandomNumberGenerator`. The rest (the six-`X` check, `O_EXCL`,
  100 attempts, the `EINTR` rule) is shared. Rejected: `getentropy`
  through a shim, which is what the generator already reads, with an API
  level check on Android; `mkstemp` and `fchmod`, which skips the creation
  mask, the reason this API exists.
- OpenBSD, whose linker warns too, stays out.

Tests:

- `UniqueFilesWithPermissionsTests.swift`'s gate widens to Linux and
  Android for its four real tests, and its mock tests, which expect
  `mktemp` calls, stay Darwin's.
- `Tests/SystemTests/UniqueFilesWithPermissionsLinuxTests.swift` (Linux and
  Android, with mocking): the traces have only `open` and `openat`, with
  made names (the prefix, then six letters or digits) and the flags and
  mode; retries after `EEXIST` up to the limit, and after `EINTR` only
  when asked; no call for a bad template.
- Both ran on Darwin in a scratch copy with `_makeTemplateName` taking the
  Linux branch: the 2 mock tests and the 4 real ones passed.
- Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
  tests in 81 suites passed (the Darwin mock and real tests unchanged).

### 2.8 Batch 8: `FICLONE` (swift-foundation)

- `FileDescriptor.cloneContents(of:)`, on Linux and Android: the `FICLONE`
  ioctl, which makes this file's contents another file's, sharing storage
  (Btrfs, XFS, bcachefs), and throws `EOPNOTSUPP` where the file system
  can't. Foundation's `FileOperations.swift` tries it first on Linux
  (through `_filemanager_shims_FICLONE`), then falls back to a `sendfile`
  loop, which System already has (`FileDescriptor.sendFile`, in
  `SendFile.swift`), so that loop needs nothing new: the inventory's
  `copy_file_range` is FreeBSD's use in Foundation, not Linux's.
- The request is `_IOW(0x94, 9, int)`, whose encoding differs by
  architecture, so it's a shim, `_system_ioctl_FICLONE`, beside the
  terminal ones. `shims.c` defines `FICLONE` itself rather than include
  `<linux/fs.h>`, which pulls in `<linux/mount.h>`, which some glibc
  versions' `<sys/mount.h>` conflicts with.
- Naming: Darwin's `clonefile` makes a new file (`clone(to:options:)`),
  where `FICLONE` fills an open one, so it gets a name of its own. Rejected:
  `clone(from:)`, which reads as the inverse of Darwin's call on the same
  type. Open: `FICLONERANGE` (a range) and `FIDEDUPERANGE`, which no adopter
  uses.
- No `retryOnInterrupt`: the call doesn't wait for anything.

Tests: `Tests/SystemTests/FileContentsCloneTests.swift` (Linux and Android,
XCTest): the mock test (`.noInterrupt`), and on a real file, `EINVAL` for a
pipe source and `EBADF` for a read-only destination (the kernel checks
those before the file system), then the clone, or `EOPNOTSUPP` where the
file system can't. The mock test ran on Darwin in a scratch copy with the
Linux condition made true.

Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
tests in 81 suites passed (no new Darwin tests).

### 2.9 Batch 9: system-next's Linux build

The first Linux log of this branch (`linux-api-0af1510-noble-test.log`)
failed to build SystemPackage, in system-next's code. Layers, each a
commit and a run:

1. `51c160b`, as asked: `import CSystem` beside Glibc, Musl and Android in
   `Timeouts.swift`, `ProcessTimer.swift` and
   `Syscalls+TimersAndPriority.swift`, where timespec's and timeval's
   members were CSystem's; `Syscalls+Memory.swift`'s duplicate
   `system_fclose` removed (Syscalls+Provisional.swift's, with the mocking
   hook, stays); `@preconcurrency import` of Glibc, Musl and Android in
   `Constants+Provisional.swift` for the mutable `stdin`, `stdout` and
   `stderr` (rejected: `nonisolated(unsafe)` copies). SystemPackage built;
   the MemberImportVisibility probes didn't: a client couldn't read
   `stat.st_atim.tv_sec` (`TimespecProbe.swift`, `EventsProbe.swift`), the
   regression 0741e13 had fixed.
2. `e8e4698`: a wrong theory, that the first module loaded owns the types,
   and so importing Glibc before CSystem in `BrokenDownTime.swift`, the
   first file in path order. Same failures; reverted in the next layer.
3. `3b77940`: the cause. `ClockTime.swift`, new since dfe83cb (the last
   Linux build), is the first file whose interface names timespec,
   through `CInterop.TimeSpec`, and `CInterop+Accessors.swift` (also new)
   declared that alias with an unqualified `timespec` in a file that
   imports CSystem, so the first copy Swift loaded was CSystem's. At
   dfe83cb the first was `IntervalTimer.swift`, which imports only Glibc.
   The fix is `CInterop.SignalSet`'s: on glibc, `TimeSpec = Glibc.timespec`
   and `TimeVal = Glibc.timeval`. The probes then built.
4. `eabcd46`: SystemTests' four Linux-only spellings: `UTIME_NOW` and
   `UTIME_OMIT` (expressions Swift can't import; the test compares their
   values), glibc's `__priority_which` for `getpriority`, Darwin's
   `closeOnExecByDefault` in a flags round trip (`createSession`
   elsewhere), and the Glibc overlay's `timespec(Duration)`, which this
   target doesn't find on Linux (below). Everything built and the tests
   ran.
5. `08c79ad`: batch 8's test, which expected `EINVAL` from a pipe source;
   Linux checks the mounts first, so it's `EXDEV`, and the doc says the rule
   is one mount.

Layer 1's imports aren't needed once layer 3 fixes the cause: 0741e13 had
removed such imports so that SystemPackage's own build would fail again
if CSystem ever owned these types. They stay, as asked; the probe target
catches a regression for clients either way. Open: removing them again.

Linux (swift:6.2-noble, arm64, as root), full runs:

- `eabcd46` (`../linux-logs/linux-api-eabcd46-noble-test.log`): XCTest 458
  run, 5 skipped, 6 failures; swift-testing 459 tests in 77 suites, 7
  issues. The failures are listed in section 3.
- `08c79ad`, `--filter FileContentsCloneTest`: 2 XCTest tests pass.
- `4f776e5` (`../linux-logs/linux-api-4f776e5-noble-test.log`): XCTest 458
  run, 5 skipped, 5 failures; swift-testing 459 tests in 77 suites, 7
  issues. Every failure is one of section 3's, in other lanes' tests; this
  lane's tests all pass.

Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
tests in 81 suites passed.

### 2.10 Batch 10: `readPassphrase` on Linux and Android (swift-package-manager)

- `TerminalDescriptor.readPassphrase(prompt:into:options:)` and
  `readPassphrase(prompt:maxByteCount:options:)`, and `PassphraseOptions`,
  widen to Linux and Android. SwiftPM's Darwin branch reads a registry
  password with them; its Linux branch calls `getpass`.
- glibc, Musl and Bionic have no `readpassphrase`, so there System takes
  its steps itself (`_readPassphrase(prompt:into:options:input:output:onTerminal:)`),
  following OpenBSD's: `/dev/tty`, or standard input and standard error
  (with `standardInput`, or without a terminal), and `ENOTTY` for
  `requireTerminal` without one; echo and `ECHONL` off on the terminal it
  opened, unless `echo`, set with `TCSAFLUSH`, which discards type-ahead;
  the prompt; a line to a newline or carriage return, keeping what fits,
  with `sevenBit` and the C locale's case changes; a newline when echo was
  off; the attributes restored. `EINTR` ends the read and is thrown after
  the terminal is restored. The options' raw values are the BSDs'
  and libbsd's.
- Design calls: no signal handling, unlike `readpassphrase`, which
  restores the terminal on `SIGINT` and re-raises it, and restarts after
  `SIGTSTP`: a signal that ends the process leaves echo off, as glibc's
  `getpass` does, and the doc says so. Rejected: wrapping `getpass`, which
  takes no options and isn't in Bionic; porting `readpassphrase`'s signal
  handling to C, which is process-wide state for a library to take. Open:
  that port, if adopters need it.
- `SpawnCredentials` on Linux, looked at for this batch and left: Darwin's
  forks, sets the credentials, and runs the program with `posix_spawn` and
  `POSIX_SPAWN_SETEXEC`, which glibc lacks, so a Linux version would apply
  the file actions and attributes itself in the child, and the `cFileActions:`
  form's glibc `posix_spawn_file_actions_t` can't be replayed. The
  `[SpawnFileAction]` forms could, in C in `shims.c`, as Subprocess's
  `_subprocess_fork_exec` does; that's a batch of its own, with a design.

Tests:

- `ReadPassphraseTests.swift` widens to Linux and Android (its standard
  input, long line and `requireTerminal` tests); its mock test, which
  expects `readpassphrase` calls, stays Darwin's.
- `Tests/SystemTests/ReadPassphraseLinuxTests.swift` (Linux and Android,
  XCTest): the steps on a pseudoterminal, from a thread, with the test
  typing only after the prompt arrives (echo is off by then): nothing
  typed is echoed, a CR LF follows, the attributes come back; with `echo`
  and `uppercase`, what's typed is echoed and upcased. The controller
  reads everything before the thread is joined: restoring the attributes
  with `TCSAFLUSH` waits until the terminal's output is read, on Darwin,
  which is where a first version of the test hung (in a scratch copy with
  the Linux path taken, where all 5 tests then passed).

Linux (`../linux-logs/linux-api-7f99387-noble-test.log`,
`--filter ReadPassphrase`): 5 XCTest tests pass.

Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
tests in 81 suites passed.

### 2.11 Batch 11: `FileWatcher`, an owned inotify instance (swift-tools-support-core)

- `FileWatcher` (`Events/FileWatcher.swift`, Linux and Android), on
  `EventPoll`'s pattern: a noncopyable owner of an inotify descriptor, from
  `inotify_init1` (`Options`: `nonBlocking`, `closeOnExec`) or
  `init(taking:)`, with `fileDescriptor`, `close()` and `relinquish()`;
  `add(_:events:)` (`inotify_add_watch`, `FilePath` and C string forms)
  returning a `Watch`; `remove(_:)` (`inotify_rm_watch`); and
  `read(into:retryOnInterrupt:)` and `read(retryOnInterrupt:)`, which parse
  the records into `Event`s: the watch, the `Mask`, the cookie, and the name
  as a `FilePath.Component`. `Mask` holds the events (`created`, `movedFrom`,
  ...; `closed`, `moved` and `allEvents` as unions, since glibc's
  `IN_ALL_EVENTS` is an OR Swift can't import), the flags events carry
  (`ignored`, `isDirectory`, `queueOverflowed`, `unmounted`), and a watch's
  options (`onlyDirectory`, `noFollow`, `excludeUnlinked`, `addToExisting`,
  `oneShot`), as C's mask and `EventPoll.Mask` do.
  `minimumReadByteCount` is a header and `NAME_MAX` plus one.
- TSC's `FSWatch.swift` calls `inotify_init1`, `inotify_add_watch` and reads
  `inotify_event`s on Linux, waiting with `select`; with this and
  `FileDescriptor.poll(for:timeout:)` it needs neither.
- Every Linux C library's module includes `<sys/inotify.h>`, so no shims.
  The records are parsed by offset, with `inotify_event`'s 16-byte header
  loaded unaligned; the name ends at its first zero byte.
- Design calls, open: the name (`FileWatcher`; rejected `InotifyDescriptor`,
  a C name, and `FileSystemWatcher`, which SwiftPM and sourcekit-lsp use for
  the LSP type); one `Mask` for events, flags and options, as C and
  `EventPoll` have it, rather than three types; `IN_MASK_CREATE` (Linux
  4.18) left out, since older headers lack it; the allocating `read()`
  uses a 4 KiB temporary buffer.

Tests: `Tests/SystemTests/FileWatcherTests.swift` (Linux and Android,
XCTest): the three calls' mocks, through the internal static forms so that
no watcher owns a made-up descriptor; the mask's unions; a directory's
events in order (create, a move's two halves with one cookie, a
subdirectory with `isDirectory`, a delete, `ignored` after `remove`, and
`EINVAL` for removing it again); a file's own events with no name,
`ENOTDIR` for `onlyDirectory`, and `EINVAL` for a buffer too small for the
next event. The kernel queues an event during the call that causes it, so
each nonblocking read right after has it.

Linux (`../linux-logs/linux-api-1c3e1c5-noble-test.log`,
`--filter FileWatcherTest`): 4 XCTest tests pass, on the first build.

Darwin, after: XCTest 565 tests, 4 skipped, 0 failures; swift-testing 498
tests in 81 suites passed.

## 3. Findings

- **Linux test failures at `eabcd46`, in other lanes' tests** (Tests/SystemTests;
  diagnoses from the log, not fixed here, since they're changes to those
  tests' logic rather than gates):
  - Running as root, which the container does and the lane's command can't
    change, breaks tests that assume an unprivileged user: four
    DirectoryWalk tests (`DirectoryWalkVisitsTests.swift:86` and `:149`,
    `DirectoryWalkBoundedTests.swift:87`,
    `DirectoryWalkRootAndStatusTests.swift:155`) expect `getuid() != 0`
    rather than skipping as root; `ProcessPriorityTests.swift:62` expects
    lowering the nice value to fail, which root may do.
  - `ProcessCredentialsTests.swift:69` (`aUsersGroups`): Linux's
    `getgroups` doesn't add the effective group, as Darwin's does, so root's
    group 0 isn't in the list read back.
  - `ProvisionalMathTests.swift:42`: glibc's `cbrt(-27.0)` isn't exactly
    -3 (glibc's cbrt isn't correctly rounded).
  - `ProcessTimerTests.swift:63`: a timer set to 100,000 s reads back
    100,000.004 s: Linux rounds the CPU-time timers up to the scheduler
    tick (4 ms at 250 Hz), so the read-back can exceed what was set.
  - `ProvisionalStdioTests.swift:190` and `:196` (`testBuffering`): a
    `setvbuf` that the test expects to throw doesn't, and a line comes out
    unbuffered: glibc's buffering rules differ from Darwin's.
  - `IORingTests.swift:503` (`testPollAddMultiShotRearmsAcrossEvents`): no
    terminal completion for a cancelled multishot poll on Linux 6.18.
- **The Glibc overlay's `timespec(Duration)` isn't found in SystemTests on
  Linux** (likely cause, unconfirmed): several of the target's files import
  CSystem, so this compile can take CSystem's copy of timespec, and the
  overlay's conversion extends its own. Clients that don't import CSystem
  aren't affected (the probes pass), but any SystemPackage file that names
  a doubly declared C type unqualified, in a file that imports CSystem, can
  flip that type's owner again. The durable fix is for CSystem's headers
  not to declare glibc's types at all; one way, untried: in
  `CSystemLinux.h`, `#pragma clang module import SwiftGlibc` under
  `#if defined(__swift__) && defined(__GLIBC__)`, so that its includes of
  `<sys/types.h>` and `<sys/epoll.h>` find those headers already included.

- The decisions doc (`claude/system-next-decisions.md`) isn't in this
  checkout or its neighbors; only `../Claude outputs/decisions-triage.md`,
  which sorts it, is. Its "Linux, later" section couldn't be read.

## 4. Needs outside this lane's files

- **vsock on Linux and Android** (SystemSockets, for swift-nio). Appendix A
  is the patch, written and then reverted here: it builds on Darwin, where
  the vsock and accessor tests pass (9 swift-testing tests), and is
  otherwise unchecked. Its shape:
  - `SocketDescriptor.Domain.vsock`, `VMSocketAddress`, `SocketAddress(vsock:)`
    and `.vsock` widen to Linux and Android. The context IDs are numbers
    there (`<linux/vm_sockets.h>` is in no C library's module), which
    `shims.c` checks against the header.
  - On Linux, `CInterop.SockAddrVM` is a Swift structure with the kernel's
    layout (as `CInterop.MMsgHdr` is): SystemSockets imports CSystem
    `@_implementationOnly`, so it can't vend the header's C type. No
    `svm_len`, so no `length` accessor there; `svm_flags` (Linux 5.11) is a
    field. `shims.c` checks size and offsets.
  - Linux's `IOCTL_VM_SOCKETS_GET_LOCAL_CID` works on `/dev/vsock`, not a
    socket, so the call is `FileDescriptor.localContextID()` there, beside
    Darwin's `SocketDescriptor.localContextID()`. The request comes from a
    CSystem getter, since `_IO`'s encoding differs by architecture.
    Rejected: NIO's shape, a socket method that ignores its socket on Linux;
    open: a static `ContextID` property that opens the device itself.
  - Tests: the Darwin ones widen; on Linux, creating a socket succeeds or
    throws `EAFNOSUPPORT`, or `EPERM` under a seccomp filter such as
    Docker's default; `/dev/vsock`, where it exists, returns any, the host,
    or a guest's ID; a pipe throws `ENOTTY`; the mock test checks the
    request (`0x7B9` on x86_64 and arm64).
  - A MemberImportVisibility probe for `CInterop.SockAddrVM` on Linux
    (Tests/MemberImportVisibility is also outside this lane).
- **`UDP_SEGMENT` and `UDP_GRO`** (SystemSockets, for swift-nio): options at
  `IPPROTO_UDP` (`SOL_UDP`, 17), 103 and 104 in `<netinet/udp.h>` /
  `<linux/udp.h>`, which Glibc's module doesn't include. NIO hardcodes them.

## Appendix A: vsock on Linux, the patch

Against `6a9833f`; apply with `git apply`.

<details>
<summary>SystemSockets, CSystem and SystemSocketsTests (313 lines added)</summary>

```diff
diff --git a/Sources/CSystem/include/CSystemLinux.h b/Sources/CSystem/include/CSystemLinux.h
index 783f5e4..9d7ddd9 100644
--- a/Sources/CSystem/include/CSystemLinux.h
+++ b/Sources/CSystem/include/CSystemLinux.h
@@ -212,6 +212,12 @@ extern int csystem_accept4(int fd, void *addr, void *addrlen, int flags);
 // timespec, untyped for the same reason as accept4's arguments.
 extern int csystem_sendmmsg(int fd, void *msgvec, unsigned int vlen, int flags);
 extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout);
+
+// IOCTL_VM_SOCKETS_GET_LOCAL_CID, from <linux/vm_sockets.h>, which no C
+// library's Swift module includes, and which this header doesn't include
+// either, so as not to declare struct sockaddr_vm here: SystemSockets'
+// CInterop.SockAddrVM mirrors it, and shims.c checks the two agree.
+unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void);
 #endif // __linux__
 
 #if defined(__linux__) && defined(__GLIBC__)
diff --git a/Sources/CSystem/shims.c b/Sources/CSystem/shims.c
index 317f2b1..9193432 100644
--- a/Sources/CSystem/shims.c
+++ b/Sources/CSystem/shims.c
@@ -574,6 +574,48 @@ extern int csystem_sendmmsg(int fd, void *msgvec, unsigned int vlen, int flags)
 extern int csystem_recvmmsg(int fd, void *msgvec, unsigned int vlen, int flags, void *timeout) {
   return recvmmsg(fd, (struct mmsghdr *)msgvec, vlen, flags, (struct timespec *)timeout);
 }
+
+// VM sockets. <linux/vm_sockets.h> needs struct sockaddr, from
+// <sys/socket.h>, first.
+#if __has_include(<linux/vm_sockets.h>)
+#include <linux/vm_sockets.h>
+
+// CInterop.SockAddrVM, in Swift, is these fields, laid out as C lays them
+// out; Linux 5.11 took svm_flags from the start of svm_zero. And the
+// context IDs that VMSocketAddress.ContextID spells as numbers.
+struct csystem_sockaddr_vm_layout {
+  sa_family_t svm_family;
+  unsigned short svm_reserved1;
+  unsigned int svm_port;
+  unsigned int svm_cid;
+  unsigned char svm_flags;
+  unsigned char svm_zero[3];
+};
+_Static_assert(sizeof(struct sockaddr_vm) == sizeof(struct csystem_sockaddr_vm_layout),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(offsetof(struct sockaddr_vm, svm_port) ==
+                   offsetof(struct csystem_sockaddr_vm_layout, svm_port),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(offsetof(struct sockaddr_vm, svm_cid) ==
+                   offsetof(struct csystem_sockaddr_vm_layout, svm_cid),
+               "CInterop.SockAddrVM must match struct sockaddr_vm");
+_Static_assert(VMADDR_CID_HYPERVISOR == 0, "VMADDR_CID_HYPERVISOR");
+_Static_assert(VMADDR_CID_HOST == 2, "VMADDR_CID_HOST");
+_Static_assert(VMADDR_CID_ANY == -1U, "VMADDR_CID_ANY");
+_Static_assert(VMADDR_PORT_ANY == -1U, "VMADDR_PORT_ANY");
+#ifdef VMADDR_CID_LOCAL
+_Static_assert(VMADDR_CID_LOCAL == 1, "VMADDR_CID_LOCAL");
+#endif
+#endif // __has_include(<linux/vm_sockets.h>)
+
+#ifndef IOCTL_VM_SOCKETS_GET_LOCAL_CID
+// The kernel's value, for a C library without the header.
+#define IOCTL_VM_SOCKETS_GET_LOCAL_CID _IO(7, 0xb9)
+#endif
+
+unsigned long _system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID(void) {
+  return IOCTL_VM_SOCKETS_GET_LOCAL_CID;
+}
 #endif // __linux__
 
 // MARK: - The allocator
diff --git a/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift b/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift
index f23a74f..a44c4e2 100644
--- a/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift
+++ b/Sources/SystemSockets/Internals/CInterop+SocketAccessors.swift
@@ -559,7 +559,7 @@ extension CInterop.In6Addr {
 
 // MARK: - sockaddr_vm
 
-#if SYSTEM_PACKAGE_DARWIN
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 @available(System 199, *)
 extension CInterop.SockAddrVM {
   /// Creates a VM socket address from its fields, by default all zero.
@@ -580,14 +580,18 @@ extension CInterop.SockAddrVM {
     self.contextID = contextID
   }
 
+  #if SYSTEM_PACKAGE_DARWIN
   /// The address's length in bytes.
   ///
   /// The corresponding C field is `svm_len`.
+  ///
+  /// - Note: Only available on Darwin.
   @_alwaysEmitIntoClient
   public var length: UInt8 {
     get { svm_len }
     set { svm_len = newValue }
   }
+  #endif
 
   /// The address's family.
   ///
@@ -616,7 +620,7 @@ extension CInterop.SockAddrVM {
     set { svm_cid = newValue }
   }
 }
-#endif // SYSTEM_PACKAGE_DARWIN
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 
 // MARK: - linger
 
diff --git a/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift b/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift
index f95bbad..735eb75 100644
--- a/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift
+++ b/Sources/SystemSockets/Internals/SocketSyscalls+VMSockets.swift
@@ -11,6 +11,18 @@
 
 #if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif os(Linux) || os(Android)
+@_implementationOnly import CSystem
+#if canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
+#endif
+
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 import SystemPackage
 
 internal func system_ioctl(
@@ -21,10 +33,19 @@ internal func system_ioctl(
 #endif
   return ioctl(fd, request, value)
 }
+#endif
 
+#if SYSTEM_PACKAGE_DARWIN
 // IOCTL_VM_SOCKETS_GET_LOCAL_CID, _IOR('s', 209, uint32_t), a macro that
 // Swift can't import: IOC_OUT, the argument's size, the group, the number.
 internal var _IOCTL_VM_SOCKETS_GET_LOCAL_CID: UInt {
   0x4000_0000 | UInt(MemoryLayout<UInt32>.size) << 16 | UInt(UInt8(ascii: "s")) << 8 | 209
 }
+#elseif os(Linux) || os(Android)
+// IOCTL_VM_SOCKETS_GET_LOCAL_CID, _IO(7, 0xb9), from <linux/vm_sockets.h>,
+// which no C library's Swift module includes. _IO's encoding differs by
+// architecture, so this is the header's own value, from shims.c.
+internal var _IOCTL_VM_SOCKETS_GET_LOCAL_CID: UInt {
+  UInt(_system_get_IOCTL_VM_SOCKETS_GET_LOCAL_CID())
+}
 #endif
diff --git a/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift b/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift
index fa52c1a..0968889 100644
--- a/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift
+++ b/Sources/SystemSockets/Sockets/SocketAddress+VMSocket.swift
@@ -11,15 +11,31 @@ import SystemPackage
 
 #if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif os(Linux) || os(Android)
+#if canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
+#endif
+
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 
 @available(System 199, *)
 extension SocketDescriptor.Domain {
   /// Communication between a virtual machine and its host,
   /// through VM sockets.
   ///
-  /// The transport is in a virtual machine, which it connects to its host:
+  /// On Darwin the transport is in a virtual machine,
+  /// which it connects to its host:
   /// on a Mac that isn't a virtual machine, creating such a socket fails
   /// with ``Errno/operationNotSupportedByDevice`` (`ENODEV`).
+  /// On Linux a guest's transport connects it to its host,
+  /// and a host's (`vhost_vsock`) to its guests;
+  /// without one, creating such a socket fails
+  /// with ``Errno/addressFamilyNotSupported`` (`EAFNOSUPPORT`).
   ///
   /// A socket address's ``SocketAddress/family`` is this domain
   /// for a VM socket address.
@@ -27,7 +43,7 @@ extension SocketDescriptor.Domain {
   /// The corresponding C constants are `PF_VSOCK` and `AF_VSOCK`,
   /// which have the same value.
   ///
-  /// - Note: Only available on Darwin.
+  /// - Note: Only available on Darwin, Linux, and Android.
   @_alwaysEmitIntoClient
   public static var vsock: Self { Self(rawValue: PF_VSOCK) }
 }
@@ -40,7 +56,7 @@ extension SocketDescriptor.Domain {
 ///
 /// The corresponding C type is `struct sockaddr_vm`.
 ///
-/// - Note: Only available on Darwin.
+/// - Note: Only available on Darwin, Linux, and Android.
 @frozen
 @available(System 199, *)
 public struct VMSocketAddress: Hashable, Sendable, CustomStringConvertible {
@@ -87,24 +103,47 @@ extension VMSocketAddress {
     @_alwaysEmitIntoClient
     public static var any: Self { Self(rawValue: UInt32(bitPattern: -1)) }
 
+    // Linux declares the context IDs in <linux/vm_sockets.h>, which no C
+    // library's Swift module includes; these are its values, which shims.c
+    // checks against it.
+
     /// The hypervisor.
     ///
     /// The corresponding C constant is `VMADDR_CID_HYPERVISOR`.
     @_alwaysEmitIntoClient
-    public static var hypervisor: Self { Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR)) }
+    public static var hypervisor: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR))
+      #else
+      Self(rawValue: 0)
+      #endif
+    }
 
     /// Context ID 1, which Darwin reserves, and Linux uses for local
-    /// communication (`VMADDR_CID_LOCAL`).
+    /// communication, from Linux 5.6.
     ///
-    /// The corresponding C constant is `VMADDR_CID_RESERVED`.
+    /// The corresponding C constant is `VMADDR_CID_RESERVED`,
+    /// or on Linux `VMADDR_CID_LOCAL`.
     @_alwaysEmitIntoClient
-    public static var local: Self { Self(rawValue: UInt32(VMADDR_CID_RESERVED)) }
+    public static var local: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_RESERVED))
+      #else
+      Self(rawValue: 1)
+      #endif
+    }
 
     /// The host of the virtual machine that the socket is in.
     ///
     /// The corresponding C constant is `VMADDR_CID_HOST`.
     @_alwaysEmitIntoClient
-    public static var host: Self { Self(rawValue: UInt32(VMADDR_CID_HOST)) }
+    public static var host: Self {
+      #if SYSTEM_PACKAGE_DARWIN
+      Self(rawValue: UInt32(VMADDR_CID_HOST))
+      #else
+      Self(rawValue: 2)
+      #endif
+    }
 
     public var description: String { self == .any ? "-1" : rawValue.description }
   }
@@ -133,18 +172,79 @@ extension VMSocketAddress {
   }
 }
 
+#if SYSTEM_PACKAGE_DARWIN
 @available(System 199, *)
 extension CInterop {
   /// The corresponding C type is `struct sockaddr_vm`.
   public typealias SockAddrVM = sockaddr_vm
 }
+#else
+@available(System 199, *)
+extension CInterop {
+  /// A VM socket address, as the system calls take it.
+  ///
+  /// This is a Swift structure with the C structure's layout,
+  /// since Linux declares `struct sockaddr_vm`
+  /// in `<linux/vm_sockets.h>`, which no C library's Swift module includes.
+  /// Its fields have the C names;
+  /// the accessors ``family``, ``port``, and ``contextID`` name them in Swift,
+  /// and ``VMSocketAddress`` is the Swift type for these addresses.
+  ///
+  /// The corresponding C type is `struct sockaddr_vm`.
+  @frozen
+  public struct SockAddrVM {
+    /// The address's family, ``SocketDescriptor/Domain/vsock``.
+    ///
+    /// The corresponding C field is `svm_family`.
+    public var svm_family: sa_family_t
+
+    /// Reserved, and zero.
+    ///
+    /// The corresponding C field is `svm_reserved1`.
+    public var svm_reserved1: UInt16
+
+    /// The port.
+    ///
+    /// The corresponding C field is `svm_port`.
+    public var svm_port: UInt32
+
+    /// The context ID.
+    ///
+    /// The corresponding C field is `svm_cid`.
+    public var svm_cid: UInt32
+
+    /// Flags for the address, from Linux 5.11; zero before it.
+    ///
+    /// The corresponding C field is `svm_flags`.
+    public var svm_flags: UInt8
+
+    /// Padding to the size of `struct sockaddr`, which must be zero.
+    ///
+    /// The corresponding C field is `svm_zero`.
+    public var svm_zero: (UInt8, UInt8, UInt8)
+
+    /// Creates an address whose fields are all zero.
+    @_alwaysEmitIntoClient
+    public init() {
+      svm_family = 0
+      svm_reserved1 = 0
+      svm_port = 0
+      svm_cid = 0
+      svm_flags = 0
+      svm_zero = (0, 0, 0)
+    }
+  }
+}
+#endif
 
 @available(System 199, *)
 extension SocketAddress {
   /// Creates a socket address from a VM socket address.
   public init(vsock address: VMSocketAddress) {
-    var vm = sockaddr_vm()
-    vm.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
+    var vm = CInterop.SockAddrVM()
+    #if SYSTEM_PACKAGE_DARWIN
+    vm.svm_len = UInt8(MemoryLayout<CInterop.SockAddrVM>.size)
+    #endif
     vm.svm_family = sa_family_t(AF_VSOCK)
     vm.svm_port = address.port.rawValue
     vm.svm_cid = address.contextID.rawValue
@@ -153,17 +253,21 @@ extension SocketAddress {
 
   /// The address as a VM socket address, if it's one.
   public var vsock: VMSocketAddress? {
-    guard family == .vsock, length >= MemoryLayout<sockaddr_vm>.size else { return nil }
-    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: sockaddr_vm.self) }
+    guard family == .vsock, length >= MemoryLayout<CInterop.SockAddrVM>.size else { return nil }
+    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: CInterop.SockAddrVM.self) }
     return VMSocketAddress(contextID: .init(rawValue: vm.svm_cid), port: .init(rawValue: vm.svm_port))
   }
 }
 
+#if SYSTEM_PACKAGE_DARWIN
 @available(System 199, *)
 extension SocketDescriptor {
   /// Returns the context ID of the machine that this VM socket is on:
   /// the virtual machine's, in a guest.
   ///
+  /// On Linux, the call takes a descriptor for `/dev/vsock` instead:
+  /// see `FileDescriptor.localContextID()`.
+  ///
   /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
   ///
   /// - Note: Only available on Darwin.
@@ -180,5 +284,41 @@ extension SocketDescriptor {
     }.map { VMSocketAddress.ContextID(rawValue: contextID) }
   }
 }
+#else
+@available(System 199, *)
+extension FileDescriptor {
+  /// Returns the context ID of this machine, through the VM sockets device:
+  /// the virtual machine's, in a guest, or the host's, on a host.
+  ///
+  /// Call it on a descriptor for `/dev/vsock`:
+  ///
+  ///     let device = try FileDescriptor.open(
+  ///       "/dev/vsock", .readOnly, options: .closeOnExec)
+  ///     defer { try? device.close() }
+  ///     let contextID = try device.localContextID()
+  ///
+  /// With no transport, the context ID is ``VMSocketAddress/ContextID/any``.
+  /// Another descriptor throws
+  /// ``Errno/inappropriateIOCTLForDevice`` (`ENOTTY`).
+  /// On Darwin, the call takes a VM socket instead:
+  /// see `SocketDescriptor.localContextID()`.
+  ///
+  /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
+  ///
+  /// - Note: Only available on Linux and Android.
+  @_alwaysEmitIntoClient
+  public func localContextID() throws(Errno) -> VMSocketAddress.ContextID {
+    try _localContextID().get()
+  }
+
+  @usableFromInline
+  internal func _localContextID() -> Result<VMSocketAddress.ContextID, Errno> {
+    var contextID = VMSocketAddress.ContextID.any.rawValue
+    return nothingOrErrno(retryOnInterrupt: false) {
+      system_ioctl(self.rawValue, _IOCTL_VM_SOCKETS_GET_LOCAL_CID, &contextID)
+    }.map { VMSocketAddress.ContextID(rawValue: contextID) }
+  }
+}
+#endif
 
-#endif // SYSTEM_PACKAGE_DARWIN
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
diff --git a/Sources/SystemSockets/Sockets/SocketDescriptor.swift b/Sources/SystemSockets/Sockets/SocketDescriptor.swift
index 895c950..b73b143 100644
--- a/Sources/SystemSockets/Sockets/SocketDescriptor.swift
+++ b/Sources/SystemSockets/Sockets/SocketDescriptor.swift
@@ -170,6 +170,8 @@ extension SocketDescriptor {
       #if SYSTEM_PACKAGE_DARWIN
       case .system: return "system"
       case .networkDevice: return "networkDevice"
+      #endif
+      #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
       case .vsock: return "vsock"
       #endif
       default: return "Domain(\(rawValue))"
diff --git a/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift b/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift
index 8143bad..ed96842 100644
--- a/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift
+++ b/Tests/SystemSocketsTests/CInteropSocketAccessorsTests.swift
@@ -130,11 +130,24 @@ private struct CInteropSocketAccessorsTests {
     #if SYSTEM_PACKAGE_DARWIN
     ipv4.length = 16
     #expect(ipv4.sin_len == 16)
+    #endif
+    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
     var vm = CInterop.SockAddrVM(family: .vsock, port: 1024, contextID: 2)
     #expect(vm.svm_family == sa_family_t(AF_VSOCK) && vm.svm_port == 1024 && vm.svm_cid == 2)
+    #if SYSTEM_PACKAGE_DARWIN
     vm.length = 12
     #expect(vm.svm_len == 12)
     #expect(sameBytes(CInterop.SockAddrVM(), sockaddr_vm()))
+    #else
+    // Linux's is System's structure, with the C layout: 16 bytes.
+    vm.contextID = 3
+    vm.port = 1025
+    #expect(vm.svm_cid == 3 && vm.svm_port == 1025 && vm.family == .vsock)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.size == 16)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.offset(of: \.svm_port) == 4)
+    #expect(MemoryLayout<CInterop.SockAddrVM>.offset(of: \.svm_cid) == 8)
+    #expect(sameBytes(CInterop.SockAddrVM(), CInterop.SockAddrVM(family: .unspecified)))
+    #endif
     #endif
   }
 
diff --git a/Tests/SystemSocketsTests/SocketVMSocketTests.swift b/Tests/SystemSocketsTests/SocketVMSocketTests.swift
index 6ebc9a6..cdecf26 100644
--- a/Tests/SystemSocketsTests/SocketVMSocketTests.swift
+++ b/Tests/SystemSocketsTests/SocketVMSocketTests.swift
@@ -7,10 +7,18 @@
  See https://swift.org/LICENSE.txt for license information
 */
 
-#if SYSTEM_PACKAGE_DARWIN
+#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
 
 import Testing
+#if SYSTEM_PACKAGE_DARWIN
 import Darwin
+#elseif canImport(Glibc)
+import Glibc
+#elseif canImport(Musl)
+import Musl
+#elseif canImport(Android)
+import Android
+#endif
 
 import SystemPackage
 #if ENABLE_MOCKING
@@ -41,19 +49,26 @@ private struct SocketVMSocketTests {
 
     let socketAddress = SocketAddress(vsock: address)
     #expect(socketAddress.family == .vsock)
-    #expect(socketAddress.length == MemoryLayout<sockaddr_vm>.size)
+    #expect(socketAddress.length == MemoryLayout<CInterop.SockAddrVM>.size)
     #expect(socketAddress.vsock == address)
     #expect(socketAddress.ipv4 == nil)
     #expect(SocketAddress(ipv4: .loopback(port: 1)).vsock == nil)
 
-    // The C structure's fields, as a client that imports Darwin reads them.
+    // The C structure's fields, as a client that imports the C library
+    // reads them.
     let vm = socketAddress.withUnsafePointer { pointer, _ in
       UnsafeRawPointer(pointer).loadUnaligned(as: CInterop.SockAddrVM.self)
     }
     #expect(vm.svm_cid == 2 && vm.svm_port == 1024)
+    #expect(vm.svm_family == sa_family_t(AF_VSOCK))
+    #if SYSTEM_PACKAGE_DARWIN
     #expect(Int(vm.svm_len) == MemoryLayout<sockaddr_vm>.size)
+    #else
+    #expect(MemoryLayout<CInterop.SockAddrVM>.size == 16)
+    #endif
   }
 
+  #if SYSTEM_PACKAGE_DARWIN
   /// A Mac that isn't a virtual machine has no VM socket transport.
   @available(System 199, *)
   @Test func aSocketNeedsATransport() throws {
@@ -66,20 +81,71 @@ private struct SocketVMSocketTests {
       #expect(error == .operationNotSupportedByDevice)
     }
   }
+  #else
+  /// A socket needs the kernel's VM sockets, which a container may not
+  /// load, or a seccomp filter (such as Docker's default) may refuse.
+  @available(System 199, *)
+  @Test func aSocketNeedsVMSockets() throws {
+    do {
+      let socket = try SocketDescriptor.open(.vsock, .stream, options: .closeOnExec)
+      try socket.close()
+    } catch {
+      #expect(error == .addressFamilyNotSupported || error == .notPermitted)
+    }
+  }
+
+  /// The VM sockets device reports this machine's context ID: a guest's,
+  /// the host's, or with no transport, any. Without the device, as in most
+  /// containers, there's nothing to ask.
+  @available(System 199, *)
+  @Test func theDeviceHasTheLocalContextID() throws {
+    let device: FileDescriptor
+    do {
+      device = try FileDescriptor.open("/dev/vsock", .readOnly, options: .closeOnExec)
+    } catch {
+      return
+    }
+    defer { try? device.close() }
+    let id = try device.localContextID()
+    #expect(id == .any || id == .host || id.rawValue >= 3)
+  }
+
+  /// Only the device answers the call.
+  @available(System 199, *)
+  @Test func anotherDescriptorIsNotTheDevice() throws {
+    let pipe = try FileDescriptor.pipe()
+    defer {
+      try? pipe.readEnd.close()
+      try? pipe.writeEnd.close()
+    }
+    #expect(throws: Errno.inappropriateIOCTLForDevice) {
+      try pipe.readEnd.localContextID()
+    }
+  }
+  #endif
 
   #if ENABLE_MOCKING
   @available(System 199, *)
   @Test func theLocalContextIDCall() throws {
     try MockingDriver.withMockingEnabled { mocking in
+      #if SYSTEM_PACKAGE_DARWIN
       let id = try SocketDescriptor(rawValue: 9).localContextID()
+      #else
+      let id = try FileDescriptor(rawValue: 9).localContextID()
+      #endif
       // A mocked ioctl writes nothing.
       #expect(id == .any)
       let entry = mocking.trace.dequeue()
       #expect(entry?.name == "ioctl")
+      #if SYSTEM_PACKAGE_DARWIN
       #expect(entry?.arguments == [CInt(9), UInt(0x4004_73D1)])
+      #elseif arch(x86_64) || arch(arm64)
+      // _IO(7, 0xb9), from the header, through shims.c.
+      #expect(entry?.arguments == [CInt(9), UInt(0x7B9)])
+      #endif
     }
   }
   #endif
 }
 
-#endif // SYSTEM_PACKAGE_DARWIN
+#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
```

</details>
