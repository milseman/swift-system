# coverage-9 report

Lane `coverage-9`, worktree `../coverage-9`, branch `coverage-9`, from `system-next` at `3f3aed7` (2026-10-07), which
didn't move during the lane. The work: the gaps of `Prototype/Status/STATUS.md`'s section 5 ("System gaps, by sites
unblocked") but the socket ones, which wait on Michael's decision about the Windows-only sockets module, highest
*Unblocks* first; after coverage-8 nearly all of them are on Windows, with some on WASI, the BSDs and Android.

## Resume here

- Done. Every item below is committed, with tests; the runs are in "Runs". `system-next` hasn't moved since `3f3aed7`,
  so there's been nothing to merge.
- **Nothing here builds real Windows.** The Win32 code is compiled on macOS against a model of the SDK
  (`Prototype/Win32/check-windows.sh`), and its tests have never run; each section says what a Windows run must check.
  The FreeBSD and OpenBSD code is unbuilt too.
- `Utilities/lint/lint.sh cmake api` reports 0 errors and 0 warnings at the last code commit, with no new allowlist
  entries.
- The gaps left are design questions, needs outside these files, or not fillable: section 13, each with the adopter's
  site and a default.
- Open for Michael: the design calls marked *Default*, and "Needs outside these files".
- `Prototype/Status/STATUS.md` is regenerated once, at the end, with `STATUS_SYSTEM_NEXT=coverage-9` (section "Status").

| # | Item | Gaps (10-07 rows) | Commits | Section |
|---|---|---|---|---|
| 1 | `Win32.Error.current`, 28 error codes, `Win32.Error(hResult:)`, `Win32.NTStatus` | 3, 38, 39, 66, 107-109, 121-123, 125-129, 131-139, 158, 159 | `e1876fb`, `42f214a` | 1 |
| 2 | `Errno` and `Errno.current` on Windows: `errno_t`, `_get_errno`, `_set_errno` | 19 | `e1876fb` | 2 |
| 3 | `FilePath.remove()` on WASI and Windows, `canonicalized()` on WASI | 7, 93 | `b8d7cd3`, `9822ffe` | 3 |
| 4 | `Memory` and `CString` on Windows, `Memory.firstRange(of:in:)` on WASI | 9, 17, 73 | `743f889` | 4 |
| 5 | `Signal` on Windows: the C runtime's signals, `name`, `raise()` | 10, 56, 58 | `b5d8c3f` | 5 |
| 6 | The extended attribute API on FreeBSD | 15 | `f840b2c` | 6 |
| 7 | `Win32.KnownFolder`, `freeLocalMemory(_:)`, `maxPathLength`; what the Win32 API passes | 18, 20, 21, 27-31, 42-44, 75, 78, 81, 104, 106, 130, 149, 150, 178 | `69de280` | 7 |
| 8 | WASI: `isTerminal`, the synchronized I/O flags, the sysexits codes, the compile-time limits; the BSDs' unique files; Windows streams, environment and `isatty` | 33 (Windows), 34, 37, 46, 57, 74, 76, 77, 83, 142, 144, 146, 147 (part), 148, 160, 175 | `e668021` | 8 |
| 9 | `Win32.handlesReferToSameObject(_:_:)`; the Windows clocks' C names | 61, 62, 67, 94, 181, 182 | `5e3a522` | 9 |
| 10 | `ProcessID.executablePath()` on FreeBSD; `SetFileTime`, `UNLEN` | 82, 105, 176 | `07e73a8` | 10 |
| 11 | `Win32.PriorityClass`; `Win32.readPassphrase(prompt:maxCount:)`; `fseek` | 80, 89, 155, 167, 168 | `5305bb0`, `c112feb` | 11 |
| 12 | The ledger's readings: Swift words, `.member` in markers | 46 (its reading), 87, 91, 92 | `e668021`, `42f214a` | 12 |
| 13 | Design questions, needs, and what can't be filled | the rest | none | 13 |

Names: no new public top-level name. `Memory`, `CString` and `Signal` are names System has elsewhere, now on Windows;
the other new types (`Win32.NTStatus`, `Win32.KnownFolder`, `Win32.KnownFolderOptions`, `Win32.PriorityClass`) are
in the `Win32` namespace, and grepping `Sources/` and `Tests/` found no other declaration of them.

How the gaps were chosen: the 10-07 list, against a regeneration at the lane's start (`STATUS_OUT`, `STATUS_WORK`,
`STATUS_LEDGER_JSON` under `.build/coverage-9/`), whose rows were the same; in rank order, each adopter's site read
first, and a second regeneration midway, against this branch, to see which rows the first ones had left the last
holders of a site (the priority classes, `ERROR_DRIVE_LOCKED`, the `sync` marker).

## 1. Win32 errors (`e1876fb`, `42f214a`)

**Sites.** `GetLastError` after a Win32 call in 17 files of 11 repositories: swift-nio's `NIOConcurrencyHelpers/
lock.swift:195`, `:234-235` (with `ERROR_TIMEOUT`), `NIOPosix/Windows.swift:78-106` (with `SetLastError`); swift-build's
`SWBUtil/Win32.swift:30`, `PathWindows.swift:35`; Foundation's file manager and Data files; Subprocess's
`Configuration.swift`, `AsyncIO+Windows.swift:391`, `:509` (`ERROR_IO_INCOMPLETE`, `ERROR_NOT_FOUND`); SwiftPM's
`SwiftTestCommand.swift:2331` (`ERROR_NOT_FOUND` as an exit code); WasmKit's `PALErrnoMapping.swift:218-288`, a
table of 26 codes onto WASI's errno. The messages: NIO's `IO.swift:147-175` and swift-build's `Win32Error.swift:25`
(`FormatMessageW` with `FORMAT_MESSAGE_*`, `LANG_NEUTRAL`, `SUBLANG_DEFAULT`). `FACILITY_WIN32`: swift-build's
`PathWindows.swift:64-88`, Foundation's `WinSDK+Extensions.swift:291-310` and Subprocess's
`Subprocess+Windows.swift:1725-1744`, the same `WIN32_FROM_HRESULT` in each. `NTSTATUS`: Subprocess's public
`WindowsError.ntStatus` (`Error.swift:229`, `:249`) and Foundation's `RtlGetVersion` (`ProcessInfo.swift:300`).

**What.**
- `Win32.Error.current`, get and set: the thread's last error, `GetLastError` and `SetLastError`, as `Errno.current`
  is errno, with its warning about reading it right after the call and its PROTOTYPE note.
- 28 codes, in an extension of their own in numeric order: `invalidBlock`, `invalidAccess`, `invalidData`,
  `invalidDrive`, `currentDirectory`, `noMoreFiles`, `writeProtected`, `badNetworkPath`, `networkAccessDenied`,
  `badNetworkName`, `cannotCreate` (`ERROR_CANNOT_MAKE`), `failOnInterrupt24`, `driveLocked`, `bufferOverflow`,
  `invalidTargetHandle`, `seekOnDevice`, `labelTooLong`, `badArguments`, `maxThreadsReached`, `lockFailed`,
  `invalidStartingCodeSegment`, `fileNameOrExtensionTooLong` (`ERROR_FILENAME_EXCED_RANGE`), `diskResourcesExhausted`,
  `fileSystemLimitation`, `ioIncomplete`, `notFound`, `canceledByUser` (`ERROR_CANCELLED`), `timeoutExpired`
  (`ERROR_TIMEOUT`). `debugDescription`'s table names every named code, five it had missed included. `success`'s doc
  names `NO_ERROR`, `description`'s the `FORMAT_MESSAGE_*` flags it passes, and `HResult.win32Error`'s
  `FACILITY_WIN32`.
- `Win32.Error(hResult:)`: the adopters' `WIN32_FROM_HRESULT`, the Win32 code of a `FACILITY_WIN32` failure, the bit
  pattern of another failure, and `success` for any success, as System's Win32 API reports an `HRESULT`.
- `Win32.NTStatus`, the native API's `NTSTATUS`, beside `Win32.HResult`: `success` (`STATUS_SUCCESS`), `isSuccess`
  (`NT_SUCCESS`), `isError` (`NT_ERROR`), and a description from ntdll's message table (`FormatMessageW` with
  `FORMAT_MESSAGE_FROM_HMODULE`), sharing `_win32Message` with `Win32.Error`'s.

**Design calls.**
- *Default*: names that Errno doesn't use (`timeoutExpired`, `canceledByUser`, `fileNameOrExtensionTooLong`), so an
  untyped `catch .timedOut` on Windows, which means Errno's, stays unambiguous. `ERROR_TOO_MANY_OPEN_FILES` and
  `ERROR_OUTOFMEMORY`, which no site needs, aren't added: their names would collide too. *Rejected*: the C names'
  words (`timeout` is Errno's `ETIME`).
- *Default*: `current` alone. *Rejected for now*: `Win32.Error.check { ... }` helpers like `Errno.check`, for calls
  that fail with `FALSE` or `NULL`; the adopters throw error types of their own, and `Errno`'s are a prototype too.
- *Default*: `NTStatus` as a type, so Subprocess's public `WindowsError` can hold System's types for all four of its
  cases (`NTStatus`, `Error`, `HResult`, `Errno`). *Rejected*: `NTSTATUS` as `[Win32 scalar types]`' `Int32`, as
  `HRESULT` would be. Not done: `RtlNtStatusToDosError`, a status's Win32 code.
- *Default*: `description` keeps language 0 (the neutral language, then the thread's, the user's, the system's, US
  English), where NIO and swift-build ask for the user's (`MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)`); mapping.ini's
  `[Win32 error messages]` covers `LANG_NEUTRAL` and `SUBLANG_DEFAULT` by hand, since the description spares the
  caller them.

A Windows run must check: each code against the SDK's macro (`testCodesMatchTheSDK`), `current` against
`GetLastError` and `SetLastError` and after a failing `GetHandleInformation(nil, ...)`, `init(hResult:)`, and
`NTStatus`'s severities and ntdll's message for `0xC0000005`.

## 2. `Errno` on Windows (`e1876fb`)

**Sites.** NIO's `System.swift:306`, TSC's `TSCLibc/libc.swift:45`, `:80`, WasmKit's `PALFileDescriptor.swift:21`,
`CLICommands/Platform.swift:192`, `WasmParser/Platform/FileIO.swift:54` (`_get_errno`, `_set_errno`), and Subprocess's
`WindowsError.cRuntime(errno_t)` (`Error.swift:247`).

**What.** Docs only: `Errno.current` already reads and sets errno on Windows with the C runtime's `_get_errno` and
`_set_errno`, and its doc now says so; `Errno`'s names `errno_t`, the type that Windows and C11's bounds-checking
interfaces give an error number.

## 3. `remove` and `realpath` (`b8d7cd3`, `9822ffe`)

**Sites.** swift-testing's tests remove their files with `remove` on every platform (`AttachmentTests.swift:96`,
`:113`, `:144`, `:152`, `:180`, `:200`, `ColorTests.swift:41`, `FileHandleTests.swift:287`, `SwiftPMTests.swift:388`
to `:614`); `FileHandle.swift:901` uses `realpath` on WASI.

**What.**
- WASI: `FilePath.remove()` and `canonicalized()` build there, over wasi-libc's `remove` and `realpath`
  (`realpath` is declared under `_XOPEN_SOURCE` or `_BSD_SOURCE`, which its `features.h` defines by default).
- Windows: `FilePath.remove()` and the C-string overload, beside `canonicalized()` in
  `FilePathResolutionWindows.swift`. The C runtime's `_wremove` is `DeleteFileW`, which can't remove a directory, so a
  removal that fails with `EACCES` on a directory is retried with `_wrmdir`, which removes a directory link or a
  junction itself; glibc's `remove` tries `unlink` first the same way. Errors are the C runtime's errno; both calls
  have mock hooks.

**Design call.** *Default*: the C runtime, whose errno the signature promises. *Rejected*: `DeleteFileW` and
`RemoveDirectoryW` with `Errno(approximating:)`, which `Win32.deleteFile` and `removeDirectory` already offer with
the Win32 code.

Under WasmKit, `readlink` of a file that isn't a link fails with `ENOTSUP`, where wasi-libc's `realpath`, which reads
each component as a link, expects `EINVAL`, so `canonicalized()` fails there for every path (F3); its test returns
early on WASI. A Windows run must check `Win32FilePathRemoveTests`: files, empty directories and a directory link
removed, a full directory, a missing path, a read-only file and one open without sharing deletion refused.

## 4. `Memory` and `CString` on Windows, `memmem` on WASI (`743f889`)

**Sites.** The C runtime's string and memory calls in Windows arms: Foundation's `Data+Writing.swift:299`, `:568`,
`FileOperations.swift:51`, `:54`, `Platform.swift:262`, `:448`, `:453`, `ProcessInfo.swift:130-131`,
`String+Internals.swift:91`, `TimeZone_Cache.swift:138`, `Data.swift:51`; Subprocess's `Configuration.swift:940`,
`:946`, `Subprocess+Windows.swift:904-905`; swift-testing's `AttachableImageFormat+CLSID.swift:156`,
`Backtrace+Symbolication.swift:150-158`, `ABIEntryPointTests.swift:242-248`, `ABI.swift:364`; TSC's `Path.swift:605`,
`:618`, `TSCLibc/libc.swift:40-44`, `:75-79`; swift-certificates' `ServerIdentityPolicy.swift:387`, `:389`;
swift-crypto's `RSA_boring.swift:966`, `SecureBytes.swift:318`, `Zeroization.swift:31`, `:39`, `:48`, `:57`
(`memset_s`). swift-testing's `ABI.VersionNumber.swift:226` uses `memmem` on WASI.

**What.**
- `MemoryWindows.swift`: `Memory` on Windows, over the C runtime's heap: `allocate(byteCount:)`,
  `allocateZeroed(byteCount:)` and `(count:stride:)`, `reallocate(_:byteCount:)`, `free(_:)`, the four C function
  values, `compare(_:_:)` (`memcmp`, emitted into the client with `@inline(__always)`, as elsewhere),
  `firstIndex(of:in:)` (`memchr`) and `secureZero(_:)` (`RtlSecureZeroMemory`), for buffers and spans.
- `CStringWindows.swift`: `CString` on Windows: `length(of:)` (`strlen`), `length(of:maxLength:)` (`strnlen`),
  `length(of:)` of a wide string (`wcslen`), `duplicate(_:)` (`_strdup`), `compare(_:_:)` and
  `compare(_:_:maxLength:)` (`strcmp`, `strncmp`).
- WASI: `Memory.firstRange(of:in:)` through `csystem_memmem`, a CSystem shim that declares wasi-libc's `memmem`, which
  its `<string.h>` declares only with `_GNU_SOURCE`.

**Design calls.**
- *Default*: declarations of their own for Windows, in `Sources/System/Win32/`, as `FileStream`'s and `DynamicLibrary`'s
  are, so `check-windows.sh` compiles them. *Rejected*: widening `Memory.swift` and `Provisional+StringH.swift`, which
  nothing here would compile for Windows.
- *Default*: what the C runtime has. Not on Windows: the aligned allocation (`_aligned_malloc`'s blocks need
  `_aligned_free`, which `free(_:)` can't promise), the platform allocators, `firstRange` (no `memmem`), `strndup`,
  `strlcpy` and the case-insensitive comparisons (`_stricmp`, which no site asks for).
- *Default*: `RtlSecureZeroMemory`, which `winnt.h` defines inline with volatile stores, imported through WinSDK.
  *Rejected*: a CSystem shim over `SecureZeroMemory`, which would work if the import doesn't. A Windows run must
  check that the inline function imports and links.

## 5. `Signal` on Windows (`b5d8c3f`)

**Sites.** sourcekit-lsp's `Process+Run.swift:48`, `:59` (`SIGINT`, `SIGABRT`), swift-driver's `main.swift:47`
(`SIGINT`), SwiftPM's `Cancellator.swift:214`, `:225` (`SIGINT`, `SIGTERM`); swift-testing's `ExitTestTests.swift:51`,
`:82-83`, `:90` and on (`SIGABRT`, `SIGSEGV`, `raise`) and `ExitStatus.swift:126-150` (a signal's name). Their other
platforms' arms already use `Signal`.

**What.** `SignalWindows.swift` declares `Signal` for Windows: `interrupt`, `illegalInstruction`,
`floatingPointException`, `segmentationViolation`, `terminate` and `abort`, at the C runtime's numbers (`SIGABRT` is
22), with `controlBreak` (`SIGBREAK`), the C spellings as unavailable renames, `description` and `name` from System's
own table, since the C runtime has none, and `raise()`, with a thread-local invalid parameter handler that returns, so
that a number that names no signal throws `EINVAL` rather than ending the process. One process can't send another a
signal on Windows, so there's no `sendSignal`. mapping.ini's `[signal names]` is covered by `Signal.name` by hand,
for Windows, where it calls neither `sys_signame` nor `sigabbrev_np`.

A Windows run must check `Win32SignalTests`: the numbers against ucrt's macros, a number that isn't a signal, and
`SIGINT` raised with a handler the test installs and restores.

## 6. Extended attributes on FreeBSD (`f840b2c`)

**Sites.** Foundation's FreeBSD arms: `FileManager+Files.swift:498-526`, `:548-576`, `FileManager+Utilities.swift:
197-204`, `Data+Reading.swift:68`, `Data+Writing.swift:850`, which call `extattr_get_file`, `extattr_get_link`,
`extattr_list_file` and `extattr_set_file` in the user namespace, where the other arms call System.

**What.** FilePath's and FileDescriptor's extended attribute API on FreeBSD, over its extattr calls in
`EXTATTR_NAMESPACE_USER`, whose names have no prefix: the `_link` calls for a link itself, the `_fd` calls for a
descriptor. FreeBSD's differences, in the wrappers and readers: its set takes no options and returns the bytes it
wrote (`ExtendedAttributeOptions` has no members there, and raw options throw `EINVAL`); its get and list truncate to
the buffer rather than failing with `ERANGE` (the readers ask for a byte more and read again when it's filled); its
list is length-prefixed (`_attributeNames(lengthPrefixed:)`, built everywhere so the tests check it).

**Design call.** *Default*: the user namespace only, as Foundation uses it and an unprivileged process can write.
*Rejected for now*: Linux-style `user.` and `system.` prefixes mapped to namespaces; a namespace parameter on FreeBSD.
Unbuilt: nothing here builds for FreeBSD.

## 7. Known folders, the local heap, `MAX_PATH`, and what the Win32 API passes (`69de280`)

**Sites.** SwiftPM's `Basics/KnownFolders.swift:18-67`, swift-build's `SWBWindowsPlatform/KnownFolders.swift:17-60`,
Foundation's `FileManager+WindowsSearchPaths.swift:17-75` (`SHGetKnownFolderPath`, `CoTaskMemFree`); `LocalFree` in
nine files (the buffers of `FormatMessageW`, `PathAllocCanonicalize`, `PathAllocCombine`, `ConvertSidToStringSidW`);
`MAX_PATH` in nine; `LoadLibraryW` (indexstore-db's and sourcekit-lsp's `dlopen.swift:70`, `:115`, swift-driver's
`Loader.swift:140`, Foundation's `ProcessInfo.swift:296`); `GetModuleHandleW` (swift-driver's `Loader.swift:161`,
SwiftPM's `Plugin.swift:637`, swift-build's `CLIConnection.swift:312`, Subprocess's `Subprocess+Windows.swift:686`,
`:710`).

**What.**
- `Win32.KnownFolder` (`KNOWNFOLDERID`), with Windows' folders as static members (Program Files and its x86 and
  per-user forms, ProgramData, System32, Windows, the user's application data, profile, desktop, documents, downloads,
  music, pictures, videos, and the shared folders) and `path(options:)` over `SHGetKnownFolderPath`, which frees the
  result with `CoTaskMemFree`; `Win32.KnownFolderOptions` (`create`, `doNotVerify`, `defaultPath`, `noAlias`). The
  GUIDs are values, from mingw-w64's `knownfolders.h`, read through api.github.com; the tests compare them with the
  SDK's. It's the Windows counterpart of Darwin's `SearchPaths`.
- `Win32.freeLocalMemory(_:)` (`LocalFree`), for the functions System doesn't wrap; it doesn't throw, since `LocalFree`
  fails only for memory it didn't allocate. `Win32.maxPathLength` (`MAX_PATH`, 260 UTF-16 code units).
- Doc sentences, for what the API already does: `LoadLibraryW` (`LoadLibraryExW` without options),
  `GetModuleHandleW` and `GetModuleHandleA` (without the reference `GetModuleHandleExW` takes),
  `PATHCCH_ALLOW_LONG_PATHS` (`ExtendedLengthPrefix.whenNeeded`), `DUPLICATE_SAME_ACCESS`, `WAIT_OBJECT_0` and
  `WAIT_TIMEOUT`, `SECURITY_ATTRIBUTES`, the named pipe flags (`FILE_FLAG_FIRST_PIPE_INSTANCE`,
  `PIPE_REJECT_REMOTE_CLIENTS`, `PIPE_WAIT`, `PIPE_READMODE_BYTE`, `PIPE_NOWAIT`), `COPYFILE2_EXTENDED_PARAMETERS`,
  `FILE_DISPOSITION_INFO_EX`, `FILE_RENAME_INFO`, `FILE_END_OF_FILE_INFO`, `MAXIMUM_REPARSE_DATA_BUFFER_SIZE` and
  `INVALID_FILE_ATTRIBUTES`. Each was run through `derive.parse` first.

**Design call.** *Default*: the known folders the adopters and Foundation's search paths use, as a struct over the
GUID, so any other GUID works too. Known folders were the windows-api lane's "the Shell; not System's" (its report,
section 8); with Darwin's sysdir in System, they're its Windows counterpart.

A Windows run must check `Win32KnownFoldersTests`: the GUIDs and options against the SDK, the system and Windows
directories against their own functions, and a `LocalAlloc` block freed.

## 8. WASI, the BSDs, and Windows bookkeeping (`e668021`)

**What.**
- WASI: `FileDescriptor.isTerminal` (wasi-libc's `isatty`; swift-testing's `FileHandle.swift:800`); `OpenOptions` and
  `StatusFlags`' `sync`, `dataSync` and `readSync`, which WASI's fdflags have as bits of their own, read through
  CSystem's `_getConst_` accessors (WasmKit's `PALFileDescriptor.swift:123`, `:397`); `ProcessID.ExitCode`'s
  sysexits codes, since the 6.2.4 SDK's WASILibc module includes `<sysexits.h>` (swift-testing's
  `SwiftPMEntryPoint.swift:31`); `SystemConfig`'s `maxFileNameBytes`, `maxPathBytes`, `guaranteedArgumentBytes` and
  `maxSymbolicLinks` (`MAXSYMLINKS` through shims.c, as on Linux; swift-testing's `AttachmentTests.swift:163`,
  Foundation's `String+Path.swift:669`).
- FreeBSD and OpenBSD: `FilePath.makeUniqueFile(options:permissions:)` and its `relativeTo:` form, which make the name
  themselves, as on Linux; OpenBSD's linker warns about `mktemp` as glibc's does (Foundation's
  `Data+Writing.swift:294-311`).
- Windows doc sentences: `ConvertSidToStringSidW` (SecurityIdentifier's description writes its form),
  `FreeEnvironmentStringsW`, `JOBOBJECT_EXTENDED_LIMIT_INFORMATION`, `TOKEN_ELEVATION`, process creation's
  `STARTUPINFOEXW`, `PROCESS_INFORMATION` and attribute list calls, `FILE_NAME_NORMALIZED`, `PSID`.
- mapping.ini: `same.fopen = _wfopen` and `same.fileno = _fileno` in `[stdio]`; `same._dupenv_s =
  GetEnvironmentVariableW` and `same._putenv = _wputenv_s` in `[getenv]`; an `[isatty]` entry covered by
  `isTerminal`, by hand for Windows, where it's a console check (TSC's `TerminalController.swift:122`, SwiftPM's
  `ManifestLoader.swift:855`, NIO's `Utilities.swift:325`, SwiftPM's `Environment.swift:213-250`).

## 9. Handles and clocks (`5e3a522`)

- `Win32.handlesReferToSameObject(_:_:)`, `CompareObjectHandles` (Windows 10, version 1607), over raw handles, which
  an owner's `unsafeRawHandle` lends, since the comparison spans the owner types and the pseudo-handles (NIO's
  `ThreadWindows.swift:104`, `:151`, Foundation's `FileManager+Basics.swift:105`).
- Doc sentences: `LARGE_INTEGER` on `GetFileSizeEx` and the performance counter's (WasmKit's `PALSystemClocks.swift:
  15-33`, Foundation's `FileManager+Basics.swift:174-176`); `LPOVERLAPPED` on the completion port's dequeue
  (Subprocess's `AsyncIO+Windows.swift:86`, TSC's `misc.swift:154`).
- mapping.ini: `[timespec_get]`, covered by `ClockID.currentTimeSpec()` and, on Windows, which has no `ClockID`, by
  `Win32.FileTime`'s `durationSinceUnixEpoch` (swift-testing's `Clock.swift:33-41`); `[Windows wall clock]`
  (`_time64`, `__time64_t`), covered by the same (swift-log's `StreamLogHandler.swift:221-233`).

## 10. FreeBSD's executable path, `SetFileTime`, `UNLEN` (`07e73a8`)

- `ProcessID.executablePath()` on FreeBSD, through `csystem_kern_proc_pathname`, a shim for sysctl's
  `KERN_PROC_PATHNAME`, since FreeBSD's Swift module doesn't include `<sys/sysctl.h>`; it asks again if the path grew
  between the size and the read (swift-testing's `CommandLineAdditions.swift:61-76`). Unbuilt.
- mapping.ini's `[Windows file times]` covers `SetFileTime` by `Win32.FileHandle.setTimes(...)`, which is
  `SetFileInformationByHandle` with `FileBasicInfo` (Foundation's `FileManager+Files.swift:874-882`, WasmKit's
  `PALFileDescriptor.swift:327-338`); `Win32.userName()`'s doc names `UNLEN`, its starting buffer (Subprocess's
  `WindowsTests.swift:69-77`).

## 11. Priority classes, a passphrase, `fseek` (`5305bb0`, `c112feb`)

- `Win32.PriorityClass` and `Win32.ProcessHandle`'s `priorityClass()` and `setPriorityClass(_:)`
  (`GetPriorityClass`, `SetPriorityClass`), for sourcekit-lsp's `Process+Run.swift:179-210`, whose other C names
  sections 1 and 5 covered.
- `Win32.readPassphrase(prompt:maxCount:)`, the counterpart of `TerminalDescriptor.readPassphrase(prompt:maxByteCount:
  options:)`: it opens `CONIN$` and `CONOUT$`, as `readpassphrase` opens `/dev/tty`, reads a line with `ReadConsoleW`
  in line mode with processed input and no echo, keeps at most `maxCount` UTF-16 code units, restores the mode, and
  clears what it read into (SwiftPM's `PackageRegistryCommand+Auth.swift:32-70`, with `ReadConsoleA`).
  `same.ReadConsoleA = ReadConsoleW`. No test: a real call waits for a user.
- `FileStream.seek`'s docs name `fseek` beside `fseeko`, and on Windows beside `_fseeki64` (WasmKit's
  `CLICommands/Platform.swift:141`).

**Design call.** *Default*: a String result, as `TerminalDescriptor`'s convenience has, with the memory it read into
cleared. *Rejected*: a buffer form, which no site needs.

## 12. The ledger's readings (`e668021`, `42f214a`)

- `overwrite`, `raw` and `buf` join the ledger's `NOT_C`: Swift parameter names (Foundation's
  `ProcessInfoTests.swift:50`, Subprocess's `Input.swift:421`, swift-argument-parser's `Mutex.swift:123`) that read as
  C names on Windows.
- status.py's marker parser, which the ledger reads markers with, takes an item that starts with `.` as a Swift
  implicit member: WasmKit's "OpenOptions.dataSync and .sync on WASI" had read as C's `sync`, which WASI lacks, though
  System now has the options there (section 8).

Tests: `test_ledger.py`'s Swift words and marker parser tests.

## 13. Gaps left: design questions, needs, and what can't be filled

Each is recorded, not built; the adopter's site and a default to start from.

| Gap | Site | The question | A default |
|---|---|---|---|
| `RegisterWaitForSingleObject` | swift-build `Tests/SwiftBuildTests/ConsoleCommands/ServiceConsoleTests.swift:142-158`; Subprocess `Subprocess+Windows.swift:592-611` | A callback when a handle is signaled: the closure's lifetime, once or repeated, which thread | `Win32.ProcessHandle.onExit(_:)` returning an owner that unregisters (`UnregisterWaitEx` with `INVALID_HANDLE_VALUE`) and frees a boxed closure |
| `POSIXErrorCode` on Windows | Foundation `Error/ErrorCodes+POSIX.swift:83-89`, `:557-1075` | platforms-2's 8.4: each platform's errno set | as platforms-2 decides |
| `LC_ALL`, `setlocale` on Windows | Foundation `Platform.swift:362`, `JSONEncoderTests.swift:1515-1516` | `CLocale` over the C runtime's `_locale_t` (`_create_locale`, `_wsetlocale`) | `CLocale` on Windows with the categories the C runtime has |
| Windows file mapping (`UnmapViewOfFile`) | Foundation `Data/Data.swift:73-78`, `Data+Reading.swift:285-295` | windows-3's next item | `Win32.FileMapping` and a mapped view owner, as `MemoryMapping` is |
| Windows directory enumeration (`FindFirstFileExW`, `FindNextFileW`, `FindClose`, `WIN32_FIND_DATAW`) | Foundation `FileManager/FileOperations+Enumeration.swift:15-60` | windows-3's next item | `DirectoryStream` on Windows |
| `stat` on Windows (`st_dev`, `st_ino`, `st_mode`, `st_size`) | llbuild | Stat on Windows, or Win32's file information | Win32's `FileHandle.basicInformation()` and file IDs |
| Process creation as another user, window state (`CreateProcessWithLogonW`, `SW_*`, `STARTF_USESHOWWINDOW`) | Subprocess `Subprocess+Windows.swift:191`, `:1073-1178` | parameters of `ProcessHandle.create` | a `showWindow:` parameter and a `user:` form over `CreateProcessWithLogonW` |
| `RTLD_DEFAULT` (`dlsym`) | swift-testing `Support/GetSymbol.swift:34` | a lookup in every loaded image, which `DynamicLibrary`'s owned handle can't express | `DynamicLibrary.address(ofGlobal:)`, `RTLD_DEFAULT` on POSIX and `EnumProcessModules` on Windows |
| `Signal` on WASI (`SIGABRT`, `raise`) | swift-testing `ExitTestTests.swift:149`, `:181`, `:187`, `:813` | WASI has no signals; wasi-libc's emulation is the `wasi_emulated_signal` module, which needs `-D_WASI_EMULATED_SIGNAL` (Needs); the sites are exit tests, which WASI doesn't run (coverage-8's F5) | none until WASI tests count |
| `mmap`, `munmap`, `MAP_*`, `PROT_READ` on WASI | Foundation `Data/Data.swift:85`, `Data+Reading.swift:34` | the `wasi_emulated_mman` module needs `-D_WASI_EMULATED_MMAN` (Needs) | `MemoryMapping` on WASI once the manifest defines it |
| `usleep`, `useconds_t` on WASI and Android | swift-sdk-generator `IntegrationTests.swift:1177`; swift-stress-tester `SwiftCWrapperToolTests.swift:89-91` | `PThread` on WASI is Coverage5's N2; stress-tester supports macOS 11, before `Duration` | N2's answer |
| `backtrace` on Musl and the BSDs | swift-testing `Backtrace.swift:67` | Musl has no `execinfo`; the BSDs' is libexecinfo (coverage-8's need) | the manifest need |
| `fmemopen` on Android | swift-testing `FileHandleTests.swift:224` | Bionic has it from API level 23, above Swift's default 21 | a `dlsym` lookup at run time, as `closeAll` does |
| statvfs on the BSDs (`f_frsize`) | Foundation `FileManager+Files.swift:752-775` | System's `StatFS` on the BSDs is statfs; Foundation wants statvfs's number fsid and fragment size | a `StatVFS` beside `StatFS` |
| Can't be filled | WasmKit `PALErrnoMapping.swift:9`, `:122` (`EMULTIHOP`, `ENOLINK` on OpenBSD); NIO `FileTypeTests.swift:49` (`S_IFWHT` on OpenBSD); WasmKit `PALClock.swift:55` (`CLOCK_MONOTONIC_RAW` on the BSDs); Foundation `FileManagerTests.swift:208` (`getuid` on WASI); swift-testing `FileHandle.swift:722` (`pipe2` on WASI); extattr on OpenBSD, WASI and Windows | The platform has no such thing | the adopter gates the use |

coverage-8's design questions (`funopen`, `getc_unlocked`, `strchr`, `task_set_exception_ports`, file cloning, MPTCP)
and swift-syntax's editor extension (its F6) are unchanged.

## 14. Bookkeeping

mapping.ini, in each item's commit: `[Win32 errors]` (the new codes, a note) and `[Win32 error messages]` (covered by
`description`); `[Windows errno]`, `[remove]`, `[realpath]` (new), `[string functions]`, `[secure zeroing]` (new),
`[signal numbers]`, `[signal names]` (covered by `Signal.name`) and `[signal descriptions]` (new), `[FreeBSD extended
attributes]` (new, covered), `[Win32 scalar types]` (`UINT`, `ULONGLONG`, `ULONG_PTR`, `PCWSTR`, `LPCWSTR`),
`[Windows DLLs]` (`LoadLibraryW`), `[Windows local memory]`, `[Windows handles]`, `[Windows paths]`, `[Windows known
folders]`, `[Windows named pipes]`, `[PATH_MAX]`, `[stdio]`, `[getenv]`, `[isatty]` (new), `[timespec_get]` (new),
`[Windows wall clock]` (new), `[Windows threads]`, `[Windows I/O completion ports]`, `[executable path]`, `[Windows
file information]`, `[Windows file times]` (new), `[Windows consoles]`. Six notes said System lacked API it has (F5).

## Per-gap adopter changes

What an adopter would change to use each addition, at the commits STATUS.md read at the lane's start; no adopter was
changed.

| Gap | Adopter: file:line | Change |
|---|---|---|
| Win32 errors | every Windows `GetLastError()` site above | `Win32.Error.current`, right after the call; `SetLastError(0)` is `Win32.Error.current = .success` |
| Win32 errors | swift-nio `NIOConcurrencyHelpers/lock.swift:234-235` | `if Win32.Error.current == .timeoutExpired` (or System's `Win32.ConditionVariable` wait with a timeout) |
| Win32 errors | swift-nio `NIOCore/IO.swift:147-175`; swift-build `SWBUtil/Win32Error.swift:14-40` | `Win32.Error(code).description` |
| Win32 errors | swift-build `PathWindows.swift:64-88`; Foundation `WinSDK+Extensions.swift:291-310`; Subprocess `Subprocess+Windows.swift:1725-1744` | `Win32.Error(hResult: Win32.HResult(hr))` for `WIN32_FROM_HRESULT` |
| Win32 errors | Subprocess `Error.swift:223-261` | `case ntStatus(Win32.NTStatus)`, `win32(Win32.Error)`, `hresult(Win32.HResult)`, `cRuntime(Errno)` (a public API change, Subprocess's call) |
| Win32 errors | Subprocess `AsyncIO+Windows.swift:391`, `:509`; SwiftPM `SwiftTestCommand.swift:2331` | `.ioIncomplete`, `.notFound`, `Win32.Error.notFound.rawValue` |
| Win32 errors | WasmKit `PALErrnoMapping.swift:218-288`; Foundation `WinSDK+Extensions.swift:48-126` | switch over `Win32.Error(code)`'s named codes |
| Win32 errors | Foundation `ProcessInfo.swift:295-310` | `Win32.osVersion()`, which calls `RtlGetVersion` |
| Windows errno | NIO `System.swift:306`; TSC `TSCLibc/libc.swift:45`, `:80`; WasmKit `PALFileDescriptor.swift:21`, `CLICommands/Platform.swift:192`, `FileIO.swift:54` | `Errno.current` |
| remove, realpath | swift-testing `AttachmentTests.swift:96` and the other `remove` sites; `FileHandle.swift:901` | `try? FilePath(path).remove()`; `FilePath(path).canonicalized()` on WASI |
| string functions | Foundation, Subprocess, swift-testing, TSC sites in section 4 | `CString.length(of:)`, `CString.duplicate(_:)`, `CString.compare(_:_:maxLength:)`, `Memory.compare(_:_:)`, `Memory.allocateZeroed(count:stride:)`, `Memory.free(_:)` on Windows too |
| memset_s | swift-crypto `SecureBytes.swift:318`, `Zeroization.swift:31-57` | `Memory.secureZero(_:)` |
| memmem | swift-testing `ABI.VersionNumber.swift:224-233` | `Memory.firstRange(of:in:)` on WASI too |
| signal numbers | sourcekit-lsp `Process+Run.swift:45-62`; swift-driver `main.swift:44-48`; SwiftPM `Cancellator.swift:213-228` | the non-Windows arms' `Signal.interrupt.rawValue`, `.abort`, `.terminate` on Windows too |
| signal numbers | swift-testing `ExitTestTests.swift:51`, `:82-83` | `Signal.abort.rawValue`; `try Signal.segmentationViolation.raise()` |
| extattr | Foundation `FileManager+Files.swift:486-576`, `FileManager+Utilities.swift:184-212` | the Darwin and Linux arms, with `canImport(Darwin) || os(Linux) || os(Android) || os(FreeBSD)` |
| known folders | SwiftPM `Basics/KnownFolders.swift:18-67`; swift-build `SWBWindowsPlatform/KnownFolders.swift:17-60`; Foundation `FileManager+WindowsSearchPaths.swift:17-75` | `try Win32.KnownFolder.userProgramFiles.path()`, `.programFilesX86`, `.system`, ... |
| LocalFree | the nine files in section 7 | `Win32.freeLocalMemory(_:)`; or the System call that frees for itself: `description`, `Win32.fullPath(of:)`, `SecurityIdentifier.description` |
| MAX_PATH | indexstore-db `TibsToolchain.swift:246-247`, `LibIndexStoreProvider.swift:26-27`; sourcekit-lsp `FindTool.swift:28-29`; ... | `Win32.maxPathLength`, or System's call that sizes its own buffer (`Win32.windowsDirectory()`, `FilePath.currentExecutable()`) |
| LoadLibraryW, GetModuleHandleW | indexstore-db `dlopen.swift:70`; sourcekit-lsp `dlopen.swift:115`; swift-driver `Loader.swift:140`, `:161`; SwiftPM `Plugin.swift:637`; Subprocess `Subprocess+Windows.swift:686`, `:710` | `DynamicLibrary(path)`, `DynamicLibrary.mainProgram()`, `DynamicLibrary(alreadyLoaded: "ntdll.dll")` |
| Windows handles | NIO `ThreadWindows.swift:70-131`; Subprocess `Teardown.swift:267` | `Win32.ThreadHandle`'s API and `handlesReferToSameObject`; `try process.waitForExit(timeout: .zero)` |
| PATHCCH_ALLOW_LONG_PATHS | swift-build `PathWindows.swift:27-61`; Foundation `String+Internals.swift:40-79`; TSC `Path.swift:86`, `:603`, `:616` | `Win32.fullPath(of:)` |
| isTerminal | swift-testing `FileHandle.swift:800-803`; TSC `TerminalController.swift:122` | `FileDescriptor(rawValue: fd).isTerminal` on WASI and Windows |
| sync flags | WasmKit `PALFileDescriptor.swift:122-128`, `:396-402` | the other platforms' `SystemPackage.FileDescriptor.open(...)` on WASI |
| sysexits, limits | swift-testing `SwiftPMEntryPoint.swift:31`, `AttachmentTests.swift:163`; Foundation `String+Path.swift:669` | `ProcessID.ExitCode.serviceUnavailable`, `SystemConfig.maxFileNameBytes`, `maxSymbolicLinks` on WASI |
| mktemp | Foundation `Data+Writing.swift:294-311` | `makeUniqueFile(options:permissions:)` on FreeBSD and OpenBSD |
| getenv | NIO `Utilities.swift:320-335`; SwiftPM `Environment.swift:213-250` | `ProcessEnvironment.value(of:)`, `set(_:to:)`, `remove(_:)` |
| timespec_get, _time64 | swift-testing `Clock.swift:33-43`; swift-log `StreamLogHandler.swift:220-234` | `Win32.FileTime.now.durationSinceUnixEpoch`, then `BrokenDownTime(secondsSinceEpoch:in:)` |
| executable path | swift-testing `CommandLineAdditions.swift:61-76` | `ProcessID.current.executablePath()` on FreeBSD |
| SetFileTime | Foundation `FileManager+Files.swift:861-883`; WasmKit `PALFileDescriptor.swift:327-338` | `Win32.FileHandle.setTimes(lastWrite:)` |
| priority classes | sourcekit-lsp `Process+Run.swift:179-210` | `Win32.ProcessHandle.open(ProcessID(rawValue: pid), access: .setInformation).setPriorityClass(.belowNormal)` |
| ReadConsoleA | SwiftPM `PackageRegistryCommand+Auth.swift:32-70` | `Win32.readPassphrase(prompt:maxCount:)` |

## Tests added or changed, and what each can touch

Each was checked before it ran for what it can delete, move, overwrite, change permissions on, signal, or reach on the
network: none reaches the network, and each stays within its own temporary files, its own process and its own
memory. The Windows ones (`Win32*`) haven't run.

| Test (file) | Touches |
|---|---|
| `Win32ErrorTests` (changed: new codes, `NO_ERROR`, symbolic names, `current`) | the thread's last error, restored; `GetHandleInformation` of a null handle, which changes nothing |
| `Win32HResultTests` (changed: `init(hResult:)`), `Win32NTStatusTests` (added) | values only; ntdll's message table |
| `Win32FilePathRemoveTests` (added) | files, directories and a directory link in its own temporary directory; a mocked `_wremove` |
| `PathsAndFilesTests` (changed: builds on WASI) | its own temporary directory |
| `Win32MemoryTests`, `Win32CStringTests` (added) | memory it allocates, and literals |
| `MemoryTests` (changed: `memmem` on WASI) | memory only |
| `Win32SignalTests` (added) | the process's SIGINT handler, installed before `SIGINT` is raised and restored after; a mocked `raise` |
| `ExtendedAttributesTests` (changed: FreeBSD, `listsOfNames`) | its own temporary file's attributes; byte arrays |
| `Win32KnownFoldersTests` (added) | reads known folders' paths; a `LocalAlloc` block it frees |
| `IsTerminalTests` (added), `WASILimitsAndFlagsTests` (added), `ExitCodeTests` (changed: WASI without its exit tests) | a file in its own temporary directory; values |
| `UniqueFilesWithPermissionsTests`, `UniqueFilesWithPermissionsLinuxTests` (changed: the BSDs) | unchanged on the platforms that ran them |
| `Win32HandleComparisonTests` (added) | a file in its own temporary directory; the calling thread's handle, which it duplicates and closes |
| `Win32ProcessPriorityTests` (added) | the test process's own priority class, set to below normal and restored |
| `test_ledger.py` (changed: Swift words, `.sync`) | in-memory fixtures and a git repository in a `tempfile.mkdtemp` directory it removes |

## Runs

- macOS, before (`3f3aed7`): XCTest executed 582 tests, 5 skipped, 0 failures; swift-testing 536 tests in 89 suites
  passed. After (`c112feb`, the last code commit): XCTest 582 tests, 5 skipped, 0 failures; swift-testing 538 tests in
  90 suites passed.
- Linux (`Utilities/linux/build.sh`, Swift 6.2, noble), at `c112feb`: XCTest 496 tests, 6 skipped, 0 failures;
  swift-testing 502 tests in 87 suites passed; no `error:` lines. Log `../linux-logs/coverage-9-c112feb-test.log`.
- Musl (`cross.sh musl build -- --target SystemPackage`): 0 errors at `c112feb`.
- WASI (`cross.sh wasi build -- --target SystemPackage`): 0 errors at each WASI change and at `c112feb`. Under WasmKit,
  `--disable-xctest --filter "WASILimitsAndFlagsTests|ExitCodeTests|IsTerminalTests|MemoryFunctionTests|
  PathsAndFilesTests"`: 12 tests in 5 suites passed (one, `canonicalized()`'s, failed before `9822ffe`; F3).
- Windows (`Prototype/Win32/check-windows.sh`): the Win32 files and the Windows test files (37 at the start, 44 at the
  end) compile, after each Windows change. Nothing here builds or runs real Windows.
- ABI-stable (`Prototype/TestHygiene/abi-check.sh c112feb`): SystemPackage, patched, builds; SystemTests 0 errors and
  31 warnings (32 before: a test line changed here); SystemSocketsTests the same 8 errors as coverage-7's F3.
- lint: `lint.sh cmake api` at `3f3aed7`, midway and at `c112feb`: 0 errors, 0 warnings. Python: adopter-coverage's
  32 tests pass.
- `status.sh`: three times, at the start and midway (scratch, `.build/coverage-9/`) and at the end into
  `Prototype/Status/STATUS.md`, the last two with `STATUS_SYSTEM_NEXT=coverage-9`.

## Findings

- **F1. The adopters' `WIN32_FROM_HRESULT` traps.** swift-build's `PathWindows.swift:64-88`, Foundation's
  `WinSDK+Extensions.swift:291-310` and Subprocess's `Subprocess+Windows.swift:1725-1744` each shift left in
  `HRESULT_FACILITY`, so `FACILITY_WIN32` never matches, and convert with `DWORD(hr)`, which traps for any failure:
  a failed `PathAllocCanonicalize` ends the process. windows-3's section 25 found it in two; Subprocess has it too.
  `Win32.Error(hResult:)` replaces all three.
- **F2. Foundation's FreeBSD attribute listing reads nothing.** `FileManager+Files.swift:549-575`: the second
  `extattr_list_file` call passes `nil, 0` again rather than the buffer, so the names it parses are uninitialized
  memory, and it parses them null-separated, where FreeBSD's list is length-prefixed.
- **F3. wasi-libc and WasmKit.** wasi-libc defines `remove`, `realpath`, `isatty` and `memmem` (declared only with
  `_GNU_SOURCE`), and WASILibc's module includes `<sysexits.h>` (`7416b21` doubted it) but not `<sys/param.h>`
  (`MAXSYMLINKS`). Under WasmKit, `readlink` of a file that isn't a link fails with `ENOTSUP`, so wasi-libc's
  `realpath`, which wants `EINVAL` there, fails for every path.
- **F4. The language of a Win32 message.** NIO's and swift-build's `FormatMessageW` calls ask for the user's language
  (`MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)`), which fails where the message isn't in it; System's description
  passes 0, which falls back to the neutral language, the thread's, the user's, the system's and US English.
- **F5. Stale mapping.ini notes.** `[Windows DLLs]` said System had no dynamic loading, `[Windows handles]` no handle
  type, `[Windows paths]` no path calls, `[getenv]` nothing that sets a variable, `[Windows I/O completion ports]` no
  event API, and `[Windows consoles]` no console API on Windows; all corrected.
- **F6. A hand status decides every platform.** check.py covers a hand `covered` entry only where its cited
  declarations compile, so an entry that the derivation covered on POSIX loses POSIX if only the Windows declaration
  is cited; `[timespec_get]`, `[isatty]` and `[signal names]` cite both.
- **F7. derive.py reads a backticked Swift parameter as a C name** in a "corresponding C" sentence (``normalized``
  read as an alternative of `GetFinalPathNameByHandleW`), and drops a name after `which`, `whose ... is` and the
  like; the sentences here keep Swift words out of backticks and put C names after `with` or `or`.
- **F8. The ledger read Swift identifiers as C names** on Windows (`overwrite`, `raw`, `buf`) and `.sync` in a marker
  as C's `sync`; section 12.

## Needs outside these files

- **Package.swift and CMake**: for WASI, `-Xcc -D_WASI_EMULATED_MMAN` and `-D_WASI_EMULATED_SIGNAL` with the
  `wasi_emulated_mman` and `wasi_emulated_signal` modules, for `MemoryMapping` and `Signal` there; libexecinfo on the
  BSDs (coverage-8's).
- **A Windows run**: every "A Windows run must check" above, and that `RtlSecureZeroMemory` imports (section 4).
- **The adopter round**: the per-gap adopter changes above, and F1 and F2.

## Status

`Utilities/adopter-coverage/status.sh`, once into the tracked file, at the end, with `STATUS_SYSTEM_NEXT=coverage-9`
(`system-next` hasn't moved, so this is what it will be after the merge): `Prototype/Status/STATUS.md` has the
figures. What changed in its section 5 with this lane: the non-socket rows with sites are section 13's design
questions and needs, and what can't be filled; the socket rows are as they were.

## Next

- Section 13's design questions, starting with Windows file mapping and directory enumeration (windows-3's next items)
  and `RegisterWaitForSingleObject`.
- The manifest needs for WASI's emulated `mman` and signals.
- A Windows run of the Win32 tests.
