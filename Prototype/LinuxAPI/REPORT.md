# linux-api: Linux API for the adopters' non-Darwin branches

The `linux-api` lane (worktree `../linux-api`, branch `linux-api`, base
system-next `6a9833f`) adds Linux API speculatively: nothing here is built or
run on Linux by this lane. Michael runs `Utilities/linux/build.sh` and puts
the logs in `../linux-logs/`; each batch below says what to check there.

"Linux" means glibc and musl. Android is included where Bionic has the same
interface at Swift's default API level (21), and said otherwise.

## Resume here

- State: inventory done (section 1). No batch committed yet.
- Next: batch 1 (section 2), then down the plan in section 1.4.
- Before each batch: read the newest log in `../linux-logs/`; compile errors
  in System come first. The only log so far,
  `6a9833f-noble-test.log`, is empty: the container service wasn't running
  (`XPC connection error`), so nothing was built.
- After each batch: add its commands to "For the Linux run", and update this
  section.

## For the Linux run

(Filled in per batch.)

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

1. NIO: vsock on Linux and Android.
2. NIO: `O_TMPFILE`, `AT_EMPTY_PATH`, `UDP_SEGMENT`/`UDP_GRO`, a
   compile-time `UIO_MAXIOV`.
3. Foundation (and TSC, indexstore-db): `POSIXErrorCode`;
   `maxSymbolicLinks` and `maxExtendedAttributeNameBytes` on Linux.
4. Foundation: `CLocale` on glibc and musl.
5. Foundation: `currentExecutable()` and the time zone paths on Linux.
6. TSC: `makeUniqueFile(suffixLength:)` (`mkostemps`); swift-build:
   `symbolInfo(containing:)` (`dladdr`); TSC and swift-driver:
   `RTLD_DEEPBIND` on glibc.
7. swift-sdk-generator: the three default pthread initializers; `O_SYNC`
   and `O_DSYNC`.
8. Larger, later: `readPassphrase` on Linux (SwiftPM), `SpawnCredentials` on
   Linux (Subprocess), inotify (TSC), `copy_file_range` and `FICLONE`
   (Foundation, NIO), `clone3` (Subprocess).

## 2. Batches

(One section per batch, as each lands.)

## 3. Findings

- The decisions doc (`claude/system-next-decisions.md`) isn't in this
  checkout or its neighbors; only `../Claude outputs/decisions-triage.md`,
  which sorts it, is. Its "Linux, later" section couldn't be read.

## 4. Needs outside this lane's files

(None yet.)
