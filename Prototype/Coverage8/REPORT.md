# coverage-8 report

Lane `coverage-8`, worktree `../coverage-8`, branch `coverage-8`, from `system-next` at `7c545cc` (2026-10-07), which
didn't move during the lane. Two kinds of System work: the gaps of `Prototype/Status/STATUS.md`'s section 5 ("System
gaps, by sites unblocked") whose *Lacks* include Darwin or Linux, and the convention errors of
`Utilities/lint/lint.sh api`; and the bookkeeping that goes with them.

## Resume here

- Done. Every item below is committed, with tests; the runs are in "Runs". `system-next` hasn't moved since
  `7c545cc`, so there's been nothing to merge.
- `Utilities/lint/lint.sh cmake api` reports 0 errors and 0 warnings at the last code commit, with
  `allowlist.ini`'s entries (two added, section 2).
- Gaps left as design questions are in section 15, each with the adopter's site and a default to start from.
- Open for Michael: the design calls marked *Default* in each section, the proposed allowlist entry
  `throws:AddressResolutionError` (section 2), an exclusion for swift-syntax's editor extension off Darwin (finding
  F6), and "Needs outside these files".
- `Prototype/Status/STATUS.md` is regenerated once, at `841ac4a`, with `STATUS_SYSTEM_NEXT=coverage-8` (section
  "Status").

| # | Item | Gaps (10-07 rows) | Commits | Section |
|---|---|---|---|---|
| 1 | lint: `api/availability`, `api/doc-sentence` | | `7651172`, `0e11632`, `938cbd9`, `24c02fa` | 1 |
| 2 | lint: `api/typed-throws`, `api/aeic` | | `acf1ae7` | 2 |
| 3 | `CString.compareIgnoringCase` (strcasecmp, strncasecmp) | 15 | `29f87da` | 3 |
| 4 | PThread names on OpenBSD | 19 | `5752984` | 4 |
| 5 | `MachOFile.LoadCommandType.symbolTable`, `entryPoint`; loaded images | 35, 36 | `77639ff`, `7a0ecc4` | 5 |
| 6 | `LoadAverage` (getloadavg) | 38 | `c15a036` | 6 |
| 7 | `Memory.firstRange(of:in:)` (memmem) | 54 | `06cec42`, `835e3e8` | 7 |
| 8 | `FileStream.openTemporaryFile()`, `open(memory:mode:)`, `open(memoryCapacity:mode:)` | 55, 56 | `91e0c3c` | 8 |
| 9 | `SystemConfig.StringName.gnuLibraryVersion` | 98 | `083e221` | 9 |
| 10 | `SpawnFileAction.closeAll(from:)` at run time, `supportsCloseAll` | 57 | `406358b` | 10 |
| 11 | `CallStack` on glibc, `asyncReturnAddresses(maxCount:)` | 104, 105 | `5487cb1` | 11 |
| 12 | `Signal.name` (sys_signame, sigabbrev_np) | 107, 108 | `bc50c7b` | 12 |
| 13 | `ProcessID.executablePath()` on Linux and Android | 103, 109, 110 | `b5d1724` | 13 |
| 14 | `WindowSize`'s fields; the ledger's Swift words, `objectFormat()`, marker platforms | 37, 113, 114 | `841184c`, `7a0ecc4`, `2f5f878`, `841ac4a` | 14 |
| 15 | Design questions: funopen, getc_unlocked, strchr, task_set_exception_ports, file cloning, MPTCP | 50-53, 106, 111, 112, 120, 121 | none | 15 |
| 16 | `exceptions.ini` E6, `mapping.ini` | | `8acfdbd`, and each item's | 16 |

Names: the one new public top-level name is `LoadAverage` (section 6); everything else is a member of an existing type.
`LoadAverage` and `loadAverage` were grepped in `Sources/`, `Tests/` and the four sister clones (`../swift-foundation`,
`../swift-subprocess`, `../swift-nio`, `../swift-package-manager`): only System's `SystemControl.Name.loadAverage`
(Darwin's `vm.loadavg`) has the word.

How the gaps were chosen: the 10-06 list, against a regeneration at the lane's start (`STATUS_OUT`, `STATUS_WORK`,
`STATUS_LEDGER_JSON` under `.build/coverage-8/`), whose rows were the same plus row 35, which also lacks Darwin; in
rank order, highest first, each adopter's site read first. Rows that unblock nothing alone (103, 104, 106, 107, 109,
111, 113, 120) go with the row whose site they share.

## 1. lint: `api/availability` and `api/doc-sentence` (`7651172`, `0e11632`, `938cbd9`, `24c02fa`)

**Availability.** `Errno.notCapable` (new on Darwin), `Errno.current`, `Stat.Flags.realDevice` and
`Stat.Flags.descriptorOnly` carry `@available(System 199, *)` on the member, in their older extensions.
`Errno.current` had kept its extension's availability on purpose: System's own code reads errno through it, some of
it in internal functions with no availability (`valueOrErrno`, `_valueOrNil`, the temporary-file and unique-file
helpers), which the ABI-stable build checks at the deployment target. That code now reads `Errno._current`, an
internal accessor emitted into the client with System 0.0.1 availability, and the public property forwards to it.
*Rejected*: annotating every internal caller, which spreads System 199 into System 0.0.1 code paths. Tests that read
`Errno.current` outside System 199 scopes (`ErrnoAccessTests`, `StatTests`, `UtilTests`, and `ErrnoTest`'s
`ENOTCAPABLE` check) are annotated or read `_current` (`24c02fa`); the ABI-stable check found them (Runs).

**Doc sentences** (26 errors, `0e11632`). Changed the docs rather than teaching `derive.py` the forms: the lint's own
fixture (`Utilities/lint/scripts/test_lint.py`, `Foo.flags`) expects "The corresponding C parameter of `X` is `y`."
to be a finding, and a parameter isn't a C interface, so reading `y` would invent a C name.
- 13 Win32 types that said "The corresponding C parameter of `F` is `p`." now say where the values go in prose
  ("`CreateFileW` takes a share mode in its `dwShareMode` parameter.") and "The corresponding C type is `DWORD`.",
  as their `ACCESS_MASK` siblings in the same files name their type.
- `Win32.VolumeInformation`'s five properties keep only the prose (what `GetVolumeInformationByHandleW` writes to
  which parameter): a parameter they're filled from isn't an interface.
- "The corresponding C field of `S` is `f`." (three Win32 flag types) became "The corresponding C field is `S.f`.",
  which derive.py reads as the field with its structure.
- Wildcard families (`IO_REPARSE_TAG_*`, `JOB_OBJECT_MSG_*`, `VOL_CAP_FMT_*`, `VOL_CAP_INT_*`, `PROX_FDTYPE_*`)
  moved to prose, and the sentence names what holds the values: `DWORD`, `vol_capabilities_attr_t.capabilities` at
  `VOL_CAPABILITIES_FORMAT` or `_INTERFACES`, `proc_fdinfo.proc_fdtype`.
- `Memory.Zone`: "a pointer to `malloc_zone_t`" instead of `malloc_zone_t *`.

**`api/doc-sentence-missing`** (the 12 warnings, `938cbd9`): each declaration got the sentence for what its code
wraps (inet_pton and inet_ntop for the IPv4 and IPv6 addresses, `sockaddr_un` with `AF_UNIX`, `sun_path`, `sigdelset`
and `sigaddset`, `NAME_MAX`, `tv_sec` with `tv_nsec` or `tv_usec`, and `int` as error numbers). Each new sentence was
run through `derive.sentences` and `derive.parse` first, so that no Swift name, such as a parameter, reads as C.

## 2. lint: `api/typed-throws` and `api/aeic` (`acf1ae7`)

- SystemSockets' 24 operations and options (open, pair, close, shutdown, bind, listen, both accepts, connect, the
  sends and receives, `getLocalAddress`, `getPeerAddress`, `getOption`/`setOption` and their conveniences) throw
  `Errno`: each returns a `Result<_, Errno>`'s `get()`. `SocketDescriptor.writeAll(_:)` calls
  `FileDescriptor.writeAll(_:)`, which throws untyped as System's older API does but throws only `Errno`, and casts
  in a catch-all. *Rejected*: reimplementing it over `send`, which changes what it's documented to equal.
- `SocketAddress.resolve(hostname:service:hints:)` and `reverseLookup(flags:)` throw `AddressResolutionError`:
  getaddrinfo and getnameinfo report an `EAI_` code, not errno. `allowlist.ini` gets
  `throws:AddressResolutionError`, *proposed*, as the other error types of their own are. (With `EAI_SYSTEM` the
  errno behind it isn't kept, as before.)
- `Win32.FileHandle.open(...)` already throws `Win32.Error`; api-delta's scanner keeps a declaration's first 400
  characters (`scan_sources.py`, `sig[:400]`), which end inside `throws(Win32`, so the lint read it as untyped.
  `allowlist.ini` exempts it by path, with that reason (F1).
- `SocketAddress.ResolutionFlags`' 7 constants and `ReverseResolutionFlags`' 5, and both types' `rawValue` and
  `init(rawValue:)`, are `@_alwaysEmitIntoClient`, as SystemSockets' other option sets are.

Callers are source compatible: a typed throw is a subtype of an untyped one. SystemSockets has no ABI to keep.

## 3. `CString.compareIgnoringCase` (gap 15, `29f87da`)

**Site.** swift-foundation `migrate-unix`, `Sources/FoundationEssentials/Platform.swift:375-376`:
`strncasecmp_clocale`'s `NO_LOCALIZATION` arm calls `strncasecmp`, which holds the file's imports on Linux, Musl,
Android, the BSDs and WASI (`:45`, `:49`, `:53`, `:76`, `:79`).

**What.** `CString.compareIgnoringCase(_:_:)` (strcasecmp) and `compareIgnoringCase(_:_:maxLength:)` (strncasecmp),
beside `compare(_:_:)` and `compare(_:_:maxLength:)`: C strings as pointers, an `Int` whose sign orders them, a
precondition on a negative `maxLength`. Case is the current locale's, as C's is; the docs point to
`CLocale.compareIgnoringCase(_:_:maxByteCount:)` for a locale the caller names. Provisional, with the other string
functions; not on Windows, as `CString` isn't.

**Design call.** *Default*: the current-locale functions, as C names them. *Rejected*: telling Foundation to use
`CLocale.posix.compareIgnoringCase` in that arm too, which would leave strncasecmp unwrapped for the next adopter.

## 4. PThread names on OpenBSD (gap 19, `5752984`)

**Sites.** swift-nio `migrate-unix`: `Sources/NIOPosix/ThreadPosix.swift:95` (the OpenBSD thread ops, `:111-112`,
`CNIOOpenBSD_pthread_get_name_np` and `_set_name_np`) and `Thread.swift:114`, `:130` (FreeBSD and OpenBSD's
`currentThreadName` and `currentThreadID`); swift-testing `migrate-all` `Sources/Testing/ExitTests/WaitFor.swift:175`
(`pthread_set_name_np` on FreeBSD and OpenBSD, `:183`).

**What.** `PThread.setCurrentName(_:)`, `PThread.ID.name()` and `PThread.ID.setName(_:)` build on OpenBSD, which, like
Linux, Android and FreeBSD, can name any thread. OpenBSD's functions return nothing and truncate a long name to 23
bytes (`_MAXCOMLEN - 1`), which the docs say. `<pthread_np.h>` may not be in its Swift module, so CSystem has shims,
the thread as `void *` so that `CSystemShared.h` needn't include `<pthread.h>`. The doc sentences name both spellings,
so the tools count `pthread_set_name_np` and `pthread_get_name_np` wherever the API builds (FreeBSD has both).

Checked against openbsd/src's `include/pthread_np.h`, `lib/librthread/rthread_np.c` and `getthrname(2)`, read
through api.github.com. Unbuilt: nothing here builds for OpenBSD.

## 5. Mach-O load commands, and the loaded images (gaps 35, 36; `77639ff`, `7a0ecc4`)

**Sites.** swift-build `migrate-all` `Tests/SWBUtilTests/MachOTests.swift:21-23` imports `MachO.LC_MAIN` and
`LC_SYMTAB`, scoped, for `:118-119`, `:180`, `:235`, `:296` and `:352`. swift-testing
`Sources/_TestDiscovery/SectionBounds.swift:44` and swift-syntax's `EditorExtension/SwiftRefactorExtension/
CommandDiscovery.swift:13-15` held gap 36 off Darwin.

**What.** `MachOFile.LoadCommandType.symbolTable` (LC_SYMTAB) and `entryPoint` (LC_MAIN, named for what its command
holds, as LC_UUID is `uuid`), without their commands' structures, which swift-build doesn't read. Gap 36 was the
ledger's: `SectionBounds.swift`'s marker sits under `objectFormat(MachO)`, which `platforms.py` answered "maybe"
everywhere; it's now true only where the object format is the one named (Mach-O on Apple's OSes, COFF on Windows,
Wasm on WASI, ELF elsewhere; section 14). On Darwin, System covers those names (coverage-7's `sectionData`); the site
is `_TestDiscovery`'s, which depends on no package. swift-syntax's editor extension is built only by an Xcode project,
for macOS, and the ledger compiles it everywhere: F6.

## 6. `LoadAverage` (gap 38, `c15a036`)

**Site.** swift-experimental-string-processing `Sources/RegexBenchmark/Utils/Environment.swift:12-16` (Darwin and
Glibc imports), for `getloadavg` (`currentLoadAverage()`, `:48-56`).

**What.** `LoadAverage`, the three averages getloadavg fills (one, five, fifteen minutes), and
`LoadAverage.current() throws(Errno)`, which throws the errno of the call that failed, or `Errno.ioError` if the C
library set none. Darwin, Linux (glibc and Musl), FreeBSD, OpenBSD. Not Android (Bionic has it from API level 29),
WASI or Windows. No mock hook: a mocked call fills no samples.

**Design call.** *Default*: a new top-level value type, since the averages go together and no namespace fits.
*Rejected*: a tuple-returning static on `SystemConfig` (limits and options) or `SystemIdentity` (uname's names);
`SystemControl.Name.loadAverage` reads the same averages in fixed point, on Darwin only.

## 7. `Memory.firstRange(of:in:)` (gap 54, `06cec42`, `835e3e8`)

**Site.** swift-testing `Sources/Testing/ABI/ABI.VersionNumber.swift:225`, `find(_:in:)` (`:222-232`), memmem because
`firstRange(of:)` is slow unspecialized in debug builds.

**What.** `Memory.firstRange(of:in:)` over raw buffers and, from macOS 15, raw spans, beside `firstIndex(of:in:)`
(memchr): the range of offsets where the bytes first appear, or nil. Empty bytes are found at offset 0, as the
standard library's `firstRange(of:)` finds an empty collection. Not on Windows (no memmem) nor WASI, whose libc
declares it only with `_GNU_SOURCE` or `_BSD_SOURCE`, which Swift's import doesn't define (F4).

## 8. Streams over a temporary file and over memory (gaps 55, 56; `91e0c3c`)

**Sites.** swift-testing `Tests/TestingTests/Support/FileHandleTests.swift:225` (`fmemopen(nil, 1, "wb+")`) and `:258`
(`tmpfile()`).

**What.** `FileStream.openTemporaryFile()` (tmpfile; not on WASI, whose libc leaves it out);
`FileStream.open(memory:mode:)` (fmemopen over a caller's buffer, which must outlive the stream) and
`open(memoryCapacity:mode:)` (fmemopen with a null buffer: memory the stream allocates and frees). Darwin has fmemopen
from macOS 10.13, so its extension carries that floor with System 199; Bionic from API level 23, so not Android.

**Design call.** *Default*: labels for what's opened, as `open(_:mode:)` has for paths and descriptors.
*Rejected*: an `UnsafeMutableRawBufferPointer` overload of `open(_:mode:)`, whose argument wouldn't say it's memory.

## 9. glibc's version (gap 98, `083e221`)

**Site.** swift-testing `Sources/Testing/Support/Versions.swift:240-251` (`gnu_get_libc_version`, then `vsscanf`).

**What.** `SystemConfig.StringName.gnuLibraryVersion`, `_CS_GNU_LIBC_VERSION`: `SystemConfig.string(_:)` returns the
run-time version as `"glibc 2.39"`. Linux with glibc only. `mapping.ini`'s `[C library version]` marks
`gnu_get_libc_version` covered by it.

**Design call.** *Default*: confstr's name, since `SystemConfig.string` exists. *Rejected*: a wrapper of
`gnu_get_libc_version`, whose `<gnu/libc-version.h>` Glibc's Swift module doesn't include (F3), so it'd need a shim
for what confstr returns.

## 10. `closeAll(from:)` at run time, and `supportsCloseAll` (gap 57, `406358b`)

**Site.** swift-testing `Sources/Testing/ExitTests/SpawnProcess.swift:91` (marker) and `:195`: it looks up
`posix_spawn_file_actions_addclosefrom_np` at run time and spawns without it if it's missing, where System's shim used
it only if the build-time glibc had it.

**What.** On glibc the shim finds the function with `dlsym(RTLD_DEFAULT)` as the action is added, so the action works
wherever the running glibc is 2.34 or later, and a System built against a newer glibc no longer needs `GLIBC_2.34` to
load (F8). Where it's missing, `spawn` still throws `Errno.noFunction`. `SpawnFileAction.supportsCloseAll` says
whether it works in this process. FreeBSD keeps its build-time test (13.1).

**Design call.** *Default*: fail loudly and let the caller ask first: closing the rest is what keeps a child from
inheriting a descriptor. *Rejected*: `closeAll(from:)` returning nil where it's missing (changes the action's type for
every caller); spawning without it (hides a missing guarantee).

## 11. The call stack (gaps 104, 105; `5487cb1`)

**Site.** swift-testing `Sources/Testing/SourceAttribution/Backtrace.swift:67` (marker), `:70` (`backtrace_async` on
Darwin) and the Linux, Android and BSD arms (`backtrace`).

**What.** `CallStack`'s `returnAddresses(maxCount:)` and `symbols(for:)` build on Linux with glibc, through CSystem
shims (Glibc's module doesn't include `<execinfo.h>`, F3). `CallStack.asyncReturnAddresses(maxCount:)`: Darwin's
`backtrace_async`, from macOS 12, which follows a task through the async functions that awaited it. Not on Musl (no
execinfo), Android (API level 33) or the BSDs (libexecinfo, which System's manifest doesn't link: Needs).

**Design call.** *Default*: a function of its own, since the two report different frames in a task. *Rejected*: a
parameter of `returnAddresses`. The task ID out parameter isn't returned.

## 12. `Signal.name` (gaps 107, 108; `bc50c7b`)

**Site.** swift-testing `Sources/Testing/ExitTests/ExitStatus.swift:126-150`: `"SIG"` + the C library's abbreviation
(sys_signame on Darwin, the BSDs and Android; glibc's `sigabbrev_np`, looked up at run time), or nil.

**What.** `Signal.name`: the C library's name for a signal, such as `SIGINT`, or nil for a number it has none for
(real-time signals, numbers that are no signal). sys_signame's entries are lowercase without `SIG`. glibc's
`sigabbrev_np` (2.32, declared only with `_GNU_SOURCE`) is found at run time, as `closeAll` now is. Where the C library
has no table (Musl, glibc before 2.32), it's the name `description` gives.

**Design call.** *Default*: an optional `name` beside `description` (System's own table) and `message` (strsignal).
*Rejected*: growing `description`'s table, which names only what System lists.

## 13. The executable's path (gaps 103, 109, 110; `b5d1724`)

**Site.** swift-testing `Sources/Testing/Support/Additions/CommandLineAdditions.swift:55` at `e2f8d449`: `/proc/self/exe`
at `:66` on Linux and Android, sysctl on FreeBSD. Since swift-testing's `7bb63d62` (2026-10-07), Linux and Android read
the link with `FilePath.readSymbolicLink()`, and the marker (`:62`) is FreeBSD's and OpenBSD's.

**What.** `ProcessID.executablePath()`, which throws and exists on macOS (proc_pidpath), builds on Linux and Android
too, reading the process's `/proc/<pid>/exe` link. `FilePath.currentExecutable()` stays Darwin's: it can't fail there,
and swift-foundation calls it without `try`. Errors are /proc's (EACCES for a process the caller can't trace, ENOENT
for none). Not FreeBSD (sysctl with `KERN_PROC_PATHNAME`, which needs a sysctl wrapper there) or OpenBSD (no API).

**Design call.** *Default*: the per-process API, which already throws. *Rejected*: `currentExecutable()` throwing
everywhere (breaks Foundation's Darwin call), or not throwing on Linux (nothing to return without /proc).

## 14. Docs and the ledger's readings (gaps 37, 113, 114; `841184c`, `7a0ecc4`, `2f5f878`, `841ac4a`)

- **ws_col** (gap 114): swift-nio's `dev/stackdiff/Sources/stackdiff/Stackdiff+Merge.swift:362-363` reads `ws_col`
  with ioctl on Linux, where `:359` uses `windowSize().columns` on Darwin. `WindowSize.rows` and `columns` now name
  `ws_row` and `ws_col`. A `mapping.ini` entry that listed the fields took them off the ledger's field path, which
  answers a field only if no entry lists it (`841ac4a`, F9); the entry lists `winsize` only.
- **timeout and label** (gaps 37, 113): Swift parameters read as C (Darwin's ncurses `timeout()`, struct fields):
  swift-subprocess's `readLine(timeout:)` (`Tests/SubprocessTests/UnixTests.swift:1353`), stackdiff's `label:`. Both
  join the ledger's NOT_C, and `timeout` counts when it's called, as CALL_ONLY's others do.
- **objectFormat()**: `platforms.py` answers it by the platform's object format (section 5).
- **A marker's C names count where the marker says they're missing** (`2f5f878`): each name is answered on the
  platforms named right after it (`on`, `in` or `for`, then platform words, past a parenthetical), of those its site
  compiles on; with none, on all of them, as before. It's how lint's markers check reads platforms, per name rather
  than per marker. *Rejected*: narrowing a whole marker to every platform it names, which gives `backtrace_async`
  Linux's; and the old reading, which asked System for `pthread_set_name_np` on Windows. This changes how every
  marker with a platform qualifier counts, in every repository.

Tests: `test_ledger.py`'s `test_swift_words_and_object_formats` and `test_marker_names_where_they_are_missing`.

## 15. Gaps left as design questions

Each is recorded, not built; the adopter's site and a default to start from.

| Gap | Site | The question | A default |
|---|---|---|---|
| 50 funopen | swift-testing `Tests/TestingTests/Support/FileHandleTests.swift:313-350` (a FILE whose close callback fires; funopen on Darwin and the BSDs, fopencookie through dlsym on Linux) | A stream over Swift callbacks: which operations, who owns the context, what a callback's error becomes (errno) | `FileStream.open(reading:writing:seeking:closing:)` with closures, a boxed context freed at close, errno from a thrown `Errno` |
| 51 getc_unlocked | swift-testing `Sources/Testing/Support/FileHandle.swift:518-523` (reads bytes under the stream's lock) | Unlocked I/O is safe only while the lock is held | a `withLock` overload passing a noncopyable `LockedFileStream` view whose `readByte()` is getc_unlocked |
| 52 strchr | swift-testing `Sources/Testing/Support/Environment.swift:90-99` | The marker is for Embedded Swift, which SystemPackage doesn't build for; `CString.firstIndex(of:in:)` helps no site | none until SystemPackage builds for Embedded |
| 53 task_set_exception_ports | swift-testing `Sources/Testing/ExitTests/ExitTest.swift:219-225` (no corpse notifications for an exit test) | What System says about Mach exception ports | a narrow `Mach.Task.disableCorpseNotifications()` rather than exception ports in general |
| 106, 111, 112 file cloning | swift-testing `Sources/Overlays/_Testing_Foundation/Attachments/_AttachableURLWrapper.swift:125-165` (fclonefileat, FICLONE, FreeBSD's copy_file_range) | One clone operation across platforms, which System has as two (`clone(to:)`, `cloneContents(of:)`) and none on FreeBSD | `FileDescriptor.copyFileRange(...)` on Linux and FreeBSD, then a `FilePath.clone(to:)` that picks per platform |
| 120, 121 MPTCP | swift-nio `Sources/NIOCore/SocketOptionProvider.swift:28-31`, `:387-393`, `:572-579`; `BSDSocketAPI.swift:616` | NIO's public API returns CNIOLinux's `mptcp_info`; glibc's module has no `<linux/mptcp.h>`, so System would declare the struct, with MemberImportVisibility's accessor pattern | `CInterop.MPTCPInfo` with Swift-named accessors and `SocketDescriptor`'s `mptcpInfo()`; NIO's API change is NIO's call |

## 16. Bookkeeping (`8acfdbd`, and each item's commit)

- `exceptions.ini` E6 (swift-corelibs-foundation, swift-corelibs-xctest): stays `undecided`, not an exception; reason
  "Set aside by Michael 2026-10-07: likely superseded by swift-foundation; to revisit", `decided` dated, and an `ends`.
- `mapping.ini`: `[string functions]` takes strcasecmp, strncasecmp, memchr and memmem; `[thread names]`, `[stdio]`
  (tmpfile, fmemopen), `[Mach-O file format]`, `[posix_spawn]` (addclosefrom_np, and its stale "System has no API to
  start a process") get notes; new entries `[load averages]`, `[C library version]` (`status = covered`),
  `[call stack]`, `[signal names]`, `[executable path]`, `[terminal window size]`.

## Per-gap adopter changes

What an adopter would change to use each addition, at the commits STATUS.md read at the lane's start (swift-testing
`e2f8d449`, which has moved since); no adopter was changed.

| Gap | Adopter: file:line | Change |
|---|---|---|
| 15 | swift-foundation `Sources/FoundationEssentials/Platform.swift:375-376` | `return Int32(CString.compareIgnoringCase(<s1 as CChar>, <s2 as CChar>, maxLength: n))` |
| 19 | swift-nio `Sources/NIOPosix/ThreadPosix.swift:111-112`, `Thread.swift:114-116`, `:130-132` | OpenBSD's thread ops through `PThread.ID.name()`, `setName(_:)` and `PThread.ID.current` |
| 19 | swift-testing `Sources/Testing/ExitTests/WaitFor.swift:175-185` | `try? PThread.setCurrentName("SWT subprocess monitor")` on every platform |
| 35 | swift-build `Tests/SWBUtilTests/MachOTests.swift:21-23`, `:118-119`, `:180`, `:235`, `:296`, `:352` | drop the scoped imports; compare with `MachOFile.LoadCommandType.entryPoint` and `.symbolTable` |
| 38 | swift-experimental-string-processing `Sources/RegexBenchmark/Utils/Environment.swift:48-56` (and `:21-23`, `:59-64`) | `(try? LoadAverage.current())?.oneMinute`; `SystemConfig.value(.processorsOnline)` for sysconf, `PThread.setCurrentQoSClass` for the QoS; then `:12-16`'s imports go |
| 114 | swift-nio `dev/stackdiff/Sources/stackdiff/Stackdiff+Merge.swift:356-363`, `:18-24` | use `:359`'s `windowSize().columns` everywhere; import SystemPackage, not Glibc or Musl |
| 54 | swift-testing `Sources/Testing/ABI/ABI.VersionNumber.swift:222-232` | `find` is `Memory.firstRange(of: needle, in: haystack)`, with `private import SystemPackage` (not WASI) |
| 55, 56 | swift-testing `Tests/TestingTests/Support/FileHandleTests.swift:225`, `:258` | `try FileStream.open(memoryCapacity: 1, mode: "wb+").rawValue`; `try FileStream.openTemporaryFile().rawValue` |
| 98 | swift-testing `Sources/Testing/Support/Versions.swift:240-251` | `try? SystemConfig.string(.gnuLibraryVersion)`, parsed after `"glibc "` |
| 57 | swift-testing `Sources/Testing/ExitTests/SpawnProcess.swift:195` | `if SpawnFileAction.supportsCloseAll { try SpawnFileAction.closeAll(from: FileDescriptor(rawValue: highestFD + 1)).add(to: &fileActions.pointee) }` |
| 104, 105 | swift-testing `Sources/Testing/SourceAttribution/Backtrace.swift:69-80` | Darwin: `CallStack.asyncReturnAddresses(maxCount:)`; Linux: `CallStack.returnAddresses(maxCount:)` |
| 107, 108 | swift-testing `Sources/Testing/ExitTests/ExitStatus.swift:126-150` | `result = Signal(rawValue: signal).name` but on Windows |
| 109, 110 | swift-testing `Sources/Testing/Support/Additions/CommandLineAdditions.swift:57-86` | Darwin `FilePath.currentExecutable().string`; Linux and Android `try ProcessID.current.executablePath().string` (`7bb63d62` reads the link with `FilePath.readSymbolicLink()`, the same thing) |
| 36 | swift-testing `Sources/_TestDiscovery/SectionBounds.swift:44` | System covers it on Darwin; `_TestDiscovery` depending on SystemPackage is swift-testing's call |

## Tests added or changed, and what each can touch

Each was checked before it ran for what it can delete, move, overwrite, change permissions on, signal, or reach on
the network: none reaches the network, and each stays within its own temporary files and its own children.

| Test (file) | Touches |
|---|---|
| `comparisonsIgnoringCase` (`ProvisionalStringTests.swift`, added) | calls on literals and an array's bytes |
| `PThreadNameTests` (changed: OpenBSD gates; `longNameIsTruncated`, OpenBSD only, unbuilt) | names threads it creates |
| `PThreadMockTests` (changed: an OpenBSD gate) | mocked calls only |
| `theTestImagesHeaderAndLoadCommands`, `sizesAndConstants` (`ProvisionalMachOTests.swift`, changed) | reads the test bundle's file, read-only, and its mapped headers |
| `LoadAverageTests.swift` (added) | reads the system's load averages |
| `firstRangeFindsTheFirstMatch` (`MemoryTests.swift`, added), `spans()` (changed) | memory only |
| `testSyscalls` (`ProvisionalStdioTests.swift`, changed: tmpfile and fmemopen mock cases) | mocked calls only |
| `testATemporaryFile` (added) | tmpfile's own new file in the system's temporary directory, unlinked as it's made, freed at close |
| `testAStreamOnMemory` (added) | memory only |
| `testTheCLibrarysVersion` (`SystemPathsTests.swift`, added; Linux) | reads confstr |
| `testClosingTheRestOfAChildsDescriptors` (`LinuxProcessTests.swift`, added; Linux) | its own pipe; spawns two `sh -c 'test -e /proc/self/fd/N'` children and waits for them |
| `testExecutablePaths` (`LinuxProcessTests.swift`, added; Linux) | reads /proc links; spawns a waiting `sh` child, which `ChildProcess` signals and reaps at the end |
| `CallStackTests.swift` (added) | the test's own stack |
| `SignalNameTests.swift` (added) | name lookups; sends no signal |
| `testNotCapable` (`ErrnoTest.swift`, moved from `testConstants`), `ErrnoAccessTests`, `StatTests`, `UtilTests` (changed) | availability attributes and `Errno._current`; no behavior changed |
| `test_swift_words_and_object_formats`, `test_marker_names_where_they_are_missing` (`test_ledger.py`, added) | a git repository in a `tempfile.mkdtemp` directory it removes (no global git configuration), and in-memory fixtures |

## Runs

- macOS, before (`7c545cc`): XCTest executed 579 tests, 5 skipped, 0 failures; swift-testing 528 tests in 86 suites
  passed. After (`24c02fa`, the last code commit): XCTest 582 tests, 5 skipped, 0 failures; swift-testing 536 tests in
  89 suites passed.
- Linux (`Utilities/linux/build.sh`, Swift 6.2, noble), at `24c02fa`: XCTest 496 tests, 6 skipped, 0 failures;
  swift-testing 500 tests in 86 suites passed; no `error:` lines. Log `../linux-logs/coverage-8-24c02fa-test.log`.
  Midway, at `406358b`: XCTest 495, 6 skipped, 0 failures; swift-testing 497 in 84 suites (log
  `../linux-logs/coverage-8-406358b-test.log`); filtered runs for the call stack, signal names and executable paths
  passed.
- Musl (`cross.sh musl build -- --target SystemSockets`, which builds SystemPackage): 0 errors at `24c02fa`.
- WASI (`cross.sh wasi build -- --target SystemPackage`): 0 errors at `24c02fa` (one, memmem, before `835e3e8`).
  Under WasmKit, `--disable-xctest --filter "ProvisionalStringTests|MemoryFunctionTests|SignalNameTests"`: 12 tests in
  3 suites passed.
- Windows (`Prototype/Win32/check-windows.sh`): the Win32 files and the 36 Windows test files compile, at `0e11632`
  and at `24c02fa`.
- ABI-stable (`Prototype/TestHygiene/abi-check.sh`): SystemPackage has the same 21 known OS-floor errors
  (`FilePathOperations.swift`, `FileTimes.swift`) and, patched, builds clean. SystemTests: 18 errors at `938cbd9`
  (`Errno.current` and `notCapable` in unannotated tests), 0 and the same 32 warnings at `24c02fa`.
  SystemSocketsTests: the same 8 errors as coverage-7's F3, in unchanged SystemSockets lines.
- Explicit availability (`-require-explicit-availability=warn`, `--target SystemPackage`): no warning in this lane's
  files.
- Warnings: a clean build of every target at `24c02fa` has no warning on a line this lane changed.
- lint: `lint.sh api` at `7c545cc`: 69 errors, 12 warnings; `lint.sh cmake api` at `938cbd9` and at `841ac4a`: 0
  errors, 0 warnings. Python: adopter-coverage's 32 tests, lint's 15 and api-graph's 23 pass.
- `status.sh`: twice, at the start (scratch, `.build/coverage-8/`) and at `841ac4a` into `Prototype/Status/STATUS.md`,
  both with `STATUS_SYSTEM_NEXT=coverage-8`.

## Findings

- **F1. api-delta's scanner truncates signatures** at 400 characters (`Utilities/api-delta/scripts/scan_sources.py`,
  `sig[:400]`), so lint's `own_effects` reads `throws(Win32` and calls a long declaration untyped (section 2).
- **F2. derive.py reads "The corresponding C type is `T`, as `F`'s `p`."** (the Win32 `ACCESS_MASK` types) with `F` as
  an alternative type and `p` as a C function. Harmless for coverage (both are Windows names, `F` wrapped elsewhere),
  but they're invented readings.
- **F3. Glibc's Swift module** (`SwiftGlibc.h` in swift:6.2-noble) includes neither `<gnu/libc-version.h>` nor
  `<execinfo.h>`; `__GLIBC__` and `__GLIBC_MINOR__` import.
- **F4. wasi-libc's Swift import** has `strcasecmp`, `strncasecmp` and `fmemopen`, but not `memmem` (needs
  `_GNU_SOURCE` or `_BSD_SOURCE`) or `tmpfile`.
- **F5. The ledger doesn't evaluate packages' own flags**: `scan_repository` uses status.py's `PACKAGE_MODEL`, so
  swift-testing's `SWT_*` defines are "maybe" on every platform, and its markers count everywhere unless they name
  their platforms (section 14). A model per repository from its manifest, as status.py's section 4 builds, would fix
  that.
- **F6. swift-syntax's `EditorExtension/`** is built by an Xcode project for macOS only, and the ledger compiles it on
  every platform (coverage-7's F6): it still holds `[loaded images]` and `[Mach-O file format]` off Darwin. An
  `excluded` entry for its non-Darwin platforms ("another build") would end it: Michael's call.
- **F7. Many swift-testing markers name several platforms' interfaces in prose.** The per-name reading (section 14)
  helps where a name is followed by its platforms; a marker whose qualifier follows the System API instead
  (`...: FilePath.currentExecutable() on Linux, Android, FreeBSD and OpenBSD`) still counts every name everywhere.
- **F8. A System built against glibc 2.34 or later needed `GLIBC_2.34` at load** for addclosefrom_np, and one built
  against older glibc never used it (section 10); dlsym ends both.
- **F9. The ledger answers a C field through the field path only if no mapping.ini entry lists it**
  (`categorize`'s `n not in coverage.entry_of`), and the derivation's names have no fields, so listing a field in an
  entry without a hand status makes it a gap (section 14).
- **F10. STATUS.md's section 3 says `gnu_get_libc_version` is "missing"** while the ledger (section 5) counts it
  covered through `[C library version]`'s `status = covered`: section 3 reads the derivation alone.

## Needs outside these files

- **Package.swift and CMake**: libexecinfo on FreeBSD and OpenBSD (`linkedLibrary("execinfo", .when(platforms:
  [.freebsd, .openbsd]))`), for `CallStack` there; an Android shim for API level 33 is this lane's kind of work.
- **api-delta**: keep whole signatures, or the effect clause, in `scan_sources.py` (F1).
- **The adopter round**: the per-gap adopter changes above.

## Status

`Utilities/adopter-coverage/status.sh`, once into the tracked file, at `841ac4a`, with `STATUS_SYSTEM_NEXT=coverage-8`
(`system-next` hasn't moved, so this is what it will be after the merge): `Prototype/Status/STATUS.md` has the figures.
What changed in its section 5 with this lane: the rows lacking Darwin or Linux are the design questions of section 15,
swift-syntax's editor extension (F6) and two that unblock nothing alone (`copy_file_range`, `IPTOS_ECN_*`); the others
of the 10-07 list are filled or narrowed to the platforms System can't serve (backtrace on Android and the BSDs, memmem
and the signal names on WASI and Windows, fmemopen on Android, KERN_PROC_PATHNAME on FreeBSD). The marker reading
(section 14) moves sites in other repositories too, wherever a marker names its platforms.

## Next

- Section 15's design questions, starting with getc_unlocked's locked view and copy_file_range.
- `CallStack` on Android (API 33 shim) and the BSDs (with the manifest need); `ProcessID.executablePath()` on FreeBSD
  (a sysctl wrapper for `KERN_PROC_PATHNAME`); memmem on WASI (a shim compiled with `_GNU_SOURCE`).
- The ledger: per-repository models from manifests (F5); fields in mapping entries (F9); section 3 and mapping.ini's
  hand status (F10).
