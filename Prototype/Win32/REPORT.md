# The windows-api, windows-2 and windows-3 lanes

System's Win32 namespace, from the drafts in `../win32-drafts/` (SYS-0010 to SYS-0016), in their order: the
`Win32` namespace and `Win32.Error`, file handles, file types, file I/O, byte-range locking, volume information,
and final path names. Then a ranking of what the adopters' Windows code imports from WinSDK, ucrt, CRT and
visualc, against System's API. Base: system-next at `6a9833f`. Nothing here compiles Windows code, so the code is
written from the Win32 documentation, compiled on macOS against a model of the SDK (see *How it was checked*), and
kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

Darwin, before any change (`6a9833f`): XCTest 565 tests (4 skipped), swift-testing 496 tests in 80 suites, all
passing. After each commit: the same, since every new file compiles to nothing on Darwin.

The windows-2 lane (sections 11 on, base system-next at `4365f83`) applies patches P1 and P2 of section 10, then
adds API for the adopters' top Windows gaps of section 8, in its order, checked the same way. The windows-3 lane
(sections 23 on, base system-next at `bb950db`) continues that list, then the gaps the earlier sections left.

**Resume here:** windows-api's parts are done (sections 1 to 10), and so are windows-2's (11 to 22: P1 and P2,
then section 8's gaps from processes to file information). windows-3, in progress: long paths (section 23,
`315f25b`), threads (24, `054e9e2`), `HRESULT` (25, `b89b78c`), path operations (26, `8326373`), overlapped I/O (27,
`d479525`), system information (28, `c04d6b1`), and Winsock, as a design (29, `052ae8a`), which finishes section
8's list; then `BrokenDownTime` on Windows (30, the last commit).
- **Next, left within done gaps**: a Windows `ProcessID.exit(_:)` and `exitImmediately(_:)` (12); `CRITICAL_SECTION` (15); attaching, freeing and
  generating console events, and `SetStdHandle` (16); `AddDllDirectory` (18); a quoting helper for command lines
  (13); and packages-5's Windows gaps (`../adopters/PACKAGES-5-REPORT.md`, "Gaps, across platforms"):
  `ProcessID.ExitCode`'s `success` and `failure`, and `FileStream.setBuffering`.
- **For other lanes**: P3 (section 22) landed on system-next with coverage-4 (`8caa741`, merged here at
  `bb225ab`). The CMake list still lacks this lane's files, so the Win32 block in the windows-3 patches section must
  land with this branch's next merge, or CI's CMake job fails. P4 there brings `FileDescriptor`'s Windows
  canonicalization to section 23's rule. The PlatformEnum samples' Windows arms differ from `Win32.ProcessHandle`
  (section 21).
- **Tests**: no Windows test has run; each section lists what a Windows run must check. At each commit, Darwin
  `swift build` and `swift test` pass, with the same tests skipped as before the lane (for counts, see
  `Prototype/Status/STATUS.md`), and `check-windows.sh` compiles the Win32 files and the Windows test files. No
  Linux build was run in these lanes.

## How it was checked

- **The harness**, `Prototype/Win32/check-windows.sh`, compiles `Sources/System/Win32` and
  `Tests/SystemTests/Win32*.swift` on macOS to object code, so the move checker and IRGen run, with the files'
  `os(Windows)` conditions turned on. It builds them against `WindowsModel/`:
  - `WinSDK.h` and `ucrt.h`: the SDK and UCRT declarations the code uses, with the types Swift gives them on 64-bit
    Windows (32-bit `DWORD`, `LONG` and `ULONG`, 16-bit `WCHAR`, `int` enums, no nullability annotations);
  - `WinSDK.swift`: the overlay's `INVALID_HANDLE_VALUE`, and `WindowsBool` as `ObjCBool`, which the importer maps
    and bridges to `Bool` in function signatures the way it does Windows' `BOOL`;
  - `SystemPackageStubs.swift`: the SystemPackage declarations the code uses, as they are on Windows. The script
    checks each stand-in marked `// mirrors:` against the real declaration's signature first.

  It catches Swift errors: types, optionality, ownership, typed throws, `@_alwaysEmitIntoClient` visibility,
  MemberImportVisibility. It can't catch where the model differs from the SDK (a macro that doesn't import, a
  pointer the SDK annotates), runtime behavior, a name that collides with a Windows-only internal in a file it
  doesn't compile, or, in a file that imports `WinSDK`, a use of macOS's C library, which the `ObjectiveC` module
  behind `WindowsBool`'s stand-in brings in (a file that imports only `ucrt` doesn't see it; section 31); the new internal names were checked against all of `Sources/` and `Tests/` by grep. A
  deliberate use after `close()` and a type error in a test file both fail it. It takes a few seconds.
- **The constants** are spelled as values. Each one was checked against Rust's standard library bindings
  (`library/std/src/sys/pal/windows/c/windows_sys.rs`, generated from Microsoft's Windows metadata) where they
  have it, which is all but `MAXIMUM_ALLOWED`, `VOLUME_NAME_NT`, `FileModeInformation` and the `FILE_*` volume
  flags; those come from `winnt.h` as documented. Every test file's `testConstantsMatchTheSDK` compares each value
  with the SDK's macro on Windows.
- **Darwin**: `swift build` and `swift test` at each commit; see the top.

## Conventions across the drafts

- **Layers**, as the rest of System: `system_Foo` is the only caller of `Foo`; a `@usableFromInline internal`
  function returns `Result<T, Win32.Error>`; the public API is `@_alwaysEmitIntoClient`, as the drafts say, and
  throws `Win32.Error` (typed). `description` and `debugDescription` are compiled into the library, like Errno's.
- **The last error** is read on the statement after the failing call, before anything else can run, as SYS-0010
  requires. Where a Win32 function can succeed and leave a stale code that System reads (`GetFileType`, `ReadFile`
  for the Ctrl+C case), `SetLastError(ERROR_SUCCESS)` comes first.
- **Constants as values**, with the doc sentence naming the C constant. This departs from Errno, whose values come
  from the C macros through `Constants.swift`. Win32's values are fixed ABI, and literals don't depend on the SDK
  that builds System: several of SYS-0015's flags (`FILE_SUPPORTS_BYPASS_IO` and others) are only in Windows 11
  SDKs, and no macro-import quirk can break the build. The tests hold them to the SDK. Internal constants
  (`Win32Constants.swift`) are underscored C names, as in `Constants.swift`; MAX_PATH is `_win32MaxPath`, since
  the UCRT declares its own `_MAX_PATH`.
- **Availability**: `@available(System 199, *)` on the namespace, every extension, and the test classes. Nothing
  here compiles on Apple platforms, so the ABI-stable build never sees it.
- **Mocking**: the C runtime calls (`_get_osfhandle`, `_open_osfhandle`, `_setmode`), which fail with -1 and
  errno, have mock hooks, as their POSIX-named neighbors do through `Syscalls.swift`. The Win32 calls have
  `system_` wrappers without hooks, like the Win32 calls inside `WindowsSyscallAdapters.swift`: they fail with
  `FALSE` or `INVALID_HANDLE_VALUE` and `GetLastError`, which the mocking layer doesn't model. A mock that forces
  a Win32 code would need `Mocking.swift` to call `SetLastError`; not done.
- **Tests** are XCTest (one process, one test at a time: handles, share modes, locks), in
  `Tests/SystemTests/Win32*Tests.swift` under `#if os(Windows)`, with helpers in `Win32TestSupport.swift`. Where
  the API under test can't check itself, they check with raw Win32 calls. A pattern catch sits alone in a helper
  with no variables or interpolation (Swift 6.2 crashes in IRGen after one in a function that handles owners, and
  6.3.3 in a function with any variable), and results are bound before they're asserted. The harness compiles
  them with Swift 6.2 only.
- **Files beyond the lane's list**: `Prototype/Win32/check-windows.sh` with `WindowsModel/`, and
  `survey-windows-imports.py` (section 8). They're the means of checking this report; nothing else uses them.

## 1. SYS-0010: the Win32 namespace and Win32.Error: `bcfc566`

What: `Sources/System/Win32/Win32.swift` and `Win32Error.swift`.
- `@frozen public enum Win32 {}`, the namespace.
- `Win32.Error`: a `@frozen` struct over `DWORD` (`RawRepresentable`, `Swift.Error`, `Sendable`, `Hashable`,
  `Codable`), with `init(rawValue:)` and `init(_:)`, the draft's 33 named codes, and System's
  `incompleteTransfer` (`0xA0535901`) with `isSynthesized`.
- `description`: `FormatMessageW` with `FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ALLOCATE_BUFFER |
  FORMAT_MESSAGE_IGNORE_INSERTS`, language 0, the buffer freed with `LocalFree`, trailing whitespace (the `\r\n`)
  stripped, and `Unknown error 1234 (0x4D2)` when there's no message. System's code has its own message.
- `debugDescription`: `ERROR_SHARING_VIOLATION (32, 0x20)`; `1234 (0x4D2)` for a code with no name here;
  `incompleteTransfer (2689882369, 0xA0535901)` for System's.
- `~=(Win32.Error, Swift.Error)`, and `Errno(approximating:)`, which is `_mapWindowsErrorToErrno`, unchanged.

Follows the draft in every declaration it shows. The draft leaves open, and this implements:
- The named codes are exactly the draft's list, though it says "including". Candidates, if a later API needs
  them: 4 (`ERROR_TOO_MANY_OPEN_FILES`), 8 (`ERROR_NOT_ENOUGH_MEMORY`), 17 (`ERROR_NOT_SAME_DEVICE`), 18
  (`ERROR_NO_MORE_FILES`, enumeration's end), 19 (`ERROR_WRITE_PROTECT`), 145 (`ERROR_DIR_NOT_EMPTY`), 206
  (`ERROR_FILENAME_EXCED_RANGE`), 1113 (`ERROR_NO_UNICODE_TRANSLATION`), 1314 (`ERROR_PRIVILEGE_NOT_HELD`), 1338
  (`ERROR_INVALID_SECURITY_DESCR`).
- `isSynthesized` is true for `0xA0535900` through `0xA05359FF`: the draft gives the base, not the range. The low
  byte numbers System's codes.
- The unnamed and synthesized renderings above; the draft gives only the named form. They're the Samples
  stand-in's.
- `Errno(approximating:)` is `@_alwaysEmitIntoClient` over a new `@usableFromInline` entry point,
  `Errno._approximating(_:)`, since `_mapWindowsErrorToErrno` is internal.

Departs from the draft:
- `Win32.Error.~=` is `@_disfavoredOverload`, which the draft doesn't say, as the decisions doc and
  `Prototype/PlatformEnum` (V16f) require. `Errno.~=` needs it too, and it's in `Errno.swift`, which this lane
  doesn't edit: patch P1 (section 10). V16f, run here with Swift 6.2: with only Win32's disfavored, a typed
  `catch .fileExists` over a `Win32.Error` resolves to `Errno.fileExists` and never matches; with both, every
  form matches. Until P1 lands, typed catches of the five names both types have (`fileExists`, `fileTooLarge`,
  `notSupported`, `brokenPipe`, `noData`) must spell `Win32.Error.x`; every other pattern works. Not disfavoring
  Win32's would be worse: it makes the same patterns ambiguous for existing `Errno` code on Windows.
- Codes are literals (see *Conventions*).

Darwin tests: unchanged (see the top). Windows tests: `Win32ErrorTests`.

A Windows run must check:
- `testCodesMatchTheSDK` and `testInternalConstantsMatchTheSDK`: every value against the SDK.
- `testDescription`: `FormatMessageW`'s message for `ERROR_ACCESS_DENIED` is non-empty with no trailing
  whitespace or `\r`, and a customer code (`0x20000001`) has no system message, so it falls back.
- `testTypedCatchOfAWin32OnlyName`: `catch .sharingViolation` over `throws(Win32.Error)` matches, which it does
  through the standard library's `~=` for `Equatable` once Win32's operator is disfavored.
- `testErrnoApproximation`: the `_dosmaperr` folding the draft describes (codes 19 to 36 to EACCES; `ERROR_NO_DATA`,
  `ERROR_FILE_TOO_LARGE` and unknown codes to EINVAL).

Next: SYS-0011.

## 2. SYS-0011: Win32.FileHandle and Win32.DirectoryHandle: `965ca6a`

What: `Win32FileHandle.swift` (the two owners), `Win32Open.swift` (opening, its option types, and path
canonicalization), `Win32SecurityDescriptor.swift`, `Win32HandleOperations.swift` (duplication, reopening,
inheritance), `Win32FileDescriptorBridge.swift`, and the *Handles* sections of `Win32Syscalls.swift` and
`Win32Constants.swift`.
- `FileHandle` and `DirectoryHandle`: `~Copyable`, `@frozen @safe`, owning one `HANDLE`, with
  `@unsafe init?(unsafelyAdopting:)` (nil for `NULL` and `INVALID_HANDLE_VALUE`), `@unsafe unsafeRawHandle`,
  `@unsafe consuming relinquish()`, `consuming close() throws(Win32.Error)` (`CloseHandle`), and a deinit that
  closes and drops the error.
- `FileHandle.open` and `openOrCreate` (with `OpenOrCreateResult`), and `DirectoryHandle.open`, all over
  `CreateFileW`, with the draft's parameters and defaults: share read, write and delete; `.openExisting`; not
  inheritable. `DirectoryHandle.open` adds `FILE_FLAG_BACKUP_SEMANTICS`, then checks `FileStandardInfo`'s
  `Directory` and throws `notADirectory` after closing the handle.
- `AccessMask` (generic, standard and specific rights, with both spellings of the four directory rights, and
  `maximumAllowed`), `ShareMode`, `CreationDisposition`, `FileFlags` (with `overlapped` unavailable), and
  `FileAttributes`.
- `SecurityDescriptor`: owner of a `LocalAlloc`ed descriptor, `init(sddl:)` over
  `ConvertStringSecurityDescriptorToSecurityDescriptorW` with `SDDL_REVISION_1`, adoption, and `relinquish()`.
- `duplicate(access:inheritable:)` (`DuplicateHandle`, `DUPLICATE_SAME_ACCESS` for `nil`), `reopen` (`ReOpenFile`;
  a directory's adds `FILE_FLAG_BACKUP_SEMANTICS`), `isInheritable()` and `setInheritable(_:)`
  (`GetHandleInformation`, `SetHandleInformation`), on both types.
- `FileDescriptor.withWin32HandleIfAvailable(_:)`, `FileDescriptor.init(adopting:translation:append:)` and
  `FileDescriptor.TranslationMode`.

Follows the draft:
- Every open rejects `FILE_FLAG_OVERLAPPED` with `invalidParameter` before calling `CreateFileW`, checked on the
  combined flags and attributes, so the bit can't arrive through `FileAttributes(rawValue:)` either; `reopen`
  rejects it too. `init?(unsafelyAdopting:)` doesn't check, as drafted.
- `openOrCreate` reads `ERROR_ALREADY_EXISTS` from the last error of a successful `CreateFileW`.
- Paths: `GetFullPathNameW`, then `PathAllocCanonicalize` with `PATHCCH_ALLOW_LONG_PATHS`, as `FileDescriptor`
  does; a path that begins with `\\?\` or `\\.\` is passed through untouched. A failed `HRESULT` becomes its
  `FACILITY_WIN32` code, or, in another facility, its bit pattern, which Windows reads as an `HRESULT` wherever it
  expects a system error code.
- `withWin32HandleIfAvailable`: `_get_osfhandle` between two calls to `_set_thread_local_invalid_parameter_handler`
  (a handler that returns, then the previous one); `nil` for -1 and -2 (`_NO_CONSOLE_FILENO`); `nil` for an
  overlapped handle, found with `NtQueryInformationFile(FileModeInformation)` (neither `FILE_SYNCHRONOUS_IO_ALERT`
  nor `FILE_SYNCHRONOUS_IO_NONALERT`). The lent `FileHandle` is relinquished on every path.
- `init(adopting:)` consumes the handle and closes it on any failure; `FILE_TYPE_UNKNOWN` throws `invalidArgument`
  before `_open_osfhandle`; `.wideText` opens binary and then calls `_setmode`.

Departs from the draft, or chooses where it's open:
- **Owned only.** The decisions doc makes unowned copyable types the main ones and owners a layer on top, with
  Windows `HANDLE` as the named open exception. This follows the drafts: no copyable `RawFileHandle`, since a
  closed handle's value can be reused for an overlapped handle, on which the synchronous I/O isn't memory-safe
  (SYS-0011, *A copyable RawFileHandle beneath FileHandle*). The lent handle of `withWin32HandleIfAvailable` is the
  nearest thing to a borrowed one. A raw type plus an owner stays possible later: the owners store a bare
  `HANDLE`.
- **`@unchecked Sendable`.** The draft says `Sendable`; `HANDLE` and `PSECURITY_DESCRIPTOR` are unsafe pointers,
  which aren't, and each type owns its pointer uniquely. Clients see a `Sendable` type.
- **NtQueryInformationFile is looked up at run time**, with `GetModuleHandleW(L"ntdll.dll")` and
  `GetProcAddress`, as swift-subprocess and swift-foundation call ntdll: the WinSDK module map links no ntdll, and
  linking it would mean editing `Package.swift` and CMake. The `@convention(c)` cast is right on x64 and ARM64,
  which have one calling convention; 32-bit x86 would need `__stdcall`. A query that fails (a handle that isn't a
  file object) also returns `nil`.
- **Path canonicalization is new**, not `withCanonicalPathRepresentation`: that one throws untyped `Errno` and
  canonicalizes `\\?\` paths. It also skips `PathAllocCanonicalize` for a resolved path that begins with `\\.\`,
  as `FileDescriptor`'s does and the draft doesn't mention: a DOS device name such as `NUL` resolves to
  `\\.\NUL`, which `PathAllocCanonicalize` would mangle. It retries `GetFullPathNameW` when the current directory
  changes between the sizing call and the real one, where the old code throws (or traps; see section 9).
- **Translation modes beyond `.wideText`**: any raw value other than `_O_TEXT` and `_O_BINARY` opens binary and is
  applied with `_setmode`, so `TranslationMode(rawValue: _O_U16TEXT)` works too.
- Small additions: an internal initializer for `OpenOrCreateResult`; if SDDL parsing succeeds without a
  descriptor, it throws the last error.

Darwin tests: unchanged. Windows tests: `Win32FileHandleTests`, one mock test among them.

A Windows run must check:
- Opening: `testOpenOrCreateReportsWhetherTheFileExisted` (existed false, then true, and `overwriteExisting`
  truncates), `testOpenFailures` (fileNotFound, pathNotFound, fileExists, and accessDenied for a directory without
  backup semantics), `testExclusiveShareMode` (sharingViolation), `testDefaultShareModeAllowsDeletion`,
  `testMetadataOnlyOpen`, `testOverlappedIsRejected` (and that no file was created), `testDevicePaths` (`NUL` and
  `\\.\NUL`), and `testLongAndVerbatimPaths` (a path longer than MAX_PATH, and a `\\?\` one).
- `testDirectoryHandle`: a file gives notADirectory, and the handle it opened is closed (an exclusive open
  succeeds after).
- `testDuplicateAndReopen`, `testInheritance`, `testRelinquish`, `testAdoptionRejectsSentinels`.
- `testSecurityDescriptor` and `testTemplateFile` (the template's hidden attribute reaches the new file, as the
  draft says; if Windows doesn't copy it, the test is wrong, not the API).
- The bridges: `testAdoptingIntoADescriptor`, `testTextTranslation` (`\n` written as `\r\n`),
  `testWideTextTranslation` (`_setmode` applied: the newline expands in UTF-16), `testAppendingDescriptor`,
  `testAdoptingAnUnclassifiedHandleFails` (an event handle gives EINVAL), `testLendingADescriptorsHandle`,
  `testLendingFromInvalidDescriptors` (descriptors -1 and 12345 return nil and don't terminate the process), and
  the mock test `testAdoptingPassesTheCRuntimeFlags` (`_open_osfhandle` gets `_O_BINARY | _O_APPEND`, then
  `_setmode` gets `_O_WTEXT`).
- Not covered by a test: `nil` for a socket descriptor (needs Winsock) and for a standard descriptor with no
  console (-2); `HANDLE_FLAG_PROTECT_FROM_CLOSE`; `reopen` of a directory beyond opening one.

Next: SYS-0012.

## 3. SYS-0012: Win32.FileType: `2f455fd`

What: `Win32FileType.swift`: `Win32.FileType` (`disk`, `character`, `pipe`, `unknown`, both initializers) and
`FileHandle.fileType()`, which calls `SetLastError(ERROR_SUCCESS)`, then `GetFileType`, and throws only if
`FILE_TYPE_UNKNOWN` comes with a code.

Follows the draft exactly. `FILE_TYPE_REMOTE` isn't vended; `DirectoryHandle` has no `fileType()`.

Darwin tests: unchanged. Windows tests: `Win32FileTypeTests`.

A Windows run must check: a disk file, with and without access rights (`testDiskFile`); `NUL`
(`testCharacterDevice`); both ends of a `CreatePipe` pipe (`testPipe`); `CONOUT$` (skipped without a console); and
`\\.\MountPointManager` giving `.unknown` with no error, as the draft observed (skipped if it can't be opened
without elevation).

Next: SYS-0013.

## 4. SYS-0013: file I/O: `1c2a12b`

What: `Win32FileIO.swift` and the *File I/O* sections of the syscall and constant files.
- `read(fromAbsoluteOffset:into:)` for `MutableRawSpan`, `MutableSpan<UInt8>`, `OutputRawSpan` and
  `OutputSpan<UInt8>`: one `ReadFile`, with an `OVERLAPPED` offset for a non-`nil` offset.
- `readFully(fromAbsoluteOffset:into:)` for the same four: a loop that ends at a full span, at a zero-byte read,
  or at the first short read of a disk file. An output span's count grows with each read, even if a later one
  throws.
- `write(_:toAbsoluteOffset:)` and `write(draining:toAbsoluteOffset:)`: a loop, ending with `incompleteTransfer`
  when a `WriteFile` succeeds without writing. `append(_:)` and `append(draining:)`: one `WriteFile` at an
  `OVERLAPPED` offset of all ones, `incompleteTransfer` if it's short. The draining forms drop what was written
  from the span, whether they return or throw.
- `SeekOrigin`, `currentOffset()`, `seek(to:)`, `seek(offset:from:)` (`SetFilePointerEx`); `flush()`
  (`FlushFileBuffers`); `size()` (`GetFileSizeEx`); `resizeToCurrentOffset()` (`SetEndOfFile`); `resize(to:)`
  (`SetFileInformationByHandle` with `FileEndOfFileInfo`).

Follows the draft:
- Reads never throw `ERROR_HANDLE_EOF`, `ERROR_BROKEN_PIPE` or `ERROR_PIPE_NOT_CONNECTED`; they return 0.
  `ERROR_MORE_DATA` is a short read for `read` and a partial transfer that continues for `readFully`. A read that
  succeeds with zero bytes and `ERROR_OPERATION_ABORTED` (Ctrl+C in a console) throws `operationAborted`; the
  last error is cleared before each `ReadFile`, so a stale code can't cause it.
- Negative offsets are rejected before the call, since -1 and -2 are `OVERLAPPED` sentinels. `read` rejects a
  span above `DWORD.max` bytes; `readFully` and `write` split one; `append` rejects one.
- An empty span still calls `ReadFile` or `WriteFile` once.

Chooses where the draft is open, or departs:
- **The split size**: the draft says a sector multiple, not which. It's `0xFFFF0000`, the largest multiple of 64
  KiB a `DWORD` holds, for every handle, so offsets and addresses stay aligned for sectors up to 64 KiB.
- **`seek(to:)` and `resize(to:)` check for a negative value themselves** (`negativeSeek`, `invalidParameter`).
  The draft says the Win32 layer rejects them "mostly"; checking first makes the documented error hold on a pipe
  or console too.
- **An offset whose transfer would pass `Int64.max`** is rejected with `invalidParameter`; the draft doesn't say.
  Wrapping would reach the sentinels, and trapping would take the process down.
- **`GetFileType` is called only at a `readFully`'s first short read**, where the draft calls it with the loop; a
  read that fills the span never needs it.
- `read`'s doc comment says which codes it absorbs.

Darwin tests: unchanged. Windows tests: `Win32FileIOTests`.

A Windows run must check:
- `testWriteThenReadEachSpanKind`: every read overload.
- `testPositionalTransfersMoveTheFilePointer`: a read at offset 2 of 4 bytes leaves the pointer at 6, and a write
  at 0 of 2 leaves it at 2, unlike `pread` and `pwrite`.
- `testEndOfFile` (0 at the pointer's end, 0 past the end, and a short `readFully`), `testNegativeValuesAreRejected`,
  `testOversizedSpansAreRejected` (without touching the span's memory), `testAppend`, `testDrainingWrite`,
  `testSizeAndResize` (zeros when extending, the pointer unmoved), `testDuplicatesShareTheFilePointer` (and a
  reopened handle doesn't), `testLentHandleSharesTheDescriptorsFilePointer`.
- Pipes: `testPipeReads` (a short read, then `readFully` and `read` ending at 0 after the writer closes),
  `testWritingToAPipeWithNoReader` (`noData`, where POSIX says EPIPE), and
  `testNonblockingPipeWriteIsIncomplete`: a `PIPE_NOWAIT` server's 1 MiB write writes nothing and throws
  `incompleteTransfer`, and `append(draining:)` leaves the span whole. This relies on the draft's observation that
  such a write takes nothing when the span doesn't fit.
- `testNonBufferedFullRead`: `noBuffering` with sector-aligned memory, offset and length.
- Not covered: the Ctrl+C path, message-mode pipes (`ERROR_MORE_DATA`), a serial port's write time-out, and spans
  over 4 GiB.

Next: SYS-0014.

## 5. SYS-0014: byte-range locking: `cfc5d2c`

What: `Win32Locking.swift`: `Win32.LockMode` (`shared`, `exclusive`), and on `FileHandle`,
`withLock(byteRange:mode:_:)` (`noasync`) and `withLockIfAvailable(byteRange:mode:_:)`, each with a typed overload
and a `@_disfavoredOverload` untyped one, over `LockFileEx` and `UnlockFileEx`.

Follows the draft: `byteRange` defaults to `0...`, locking offset 0 for `Int64.max` bytes; an empty range runs
`body` without calling `LockFileEx`; a negative bound throws `invalidParameter`; the range resolves with
`relative(to:)` over an internal collection of `0..<Int64.max` whose `index(after:)` saturates, so `0...Int64.max`
doesn't trap; the unlock names the locked range exactly; `body`'s error wins over the unlock's, and an unlock
error after a successful `body` is thrown; `withLockIfAvailable` returns `nil` only for `ERROR_LOCK_VIOLATION`
under `LOCKFILE_FAIL_IMMEDIATELY`.

Departs from the draft: its mechanism and its promise disagree for two range types. The standard library's
`PartialRangeUpTo.relative(to:)` and `PartialRangeThrough.relative(to:)` make `0..<upperBound` (or
`0..<upperBound + 1`), which traps for a negative bound before System can reject it, and `...(-1)` becomes the
empty `0..<0`. So those two types are checked for a negative upper bound first. Another type conforming to
`RangeExpression` with a negative bound can still trap inside its own `relative(to:)`.

Darwin tests: unchanged. Windows tests: `Win32LockingTests`, which use two opens of one file, so two file objects,
as another process would have.

A Windows run must check: `testExclusiveLocksAreMandatory` (the other handle's read of the range fails with
`lockViolation`, outside it succeeds, and the locking handle can read); `testLockIfAvailable` (overlapping `nil`,
disjoint locked); `testSharedLocks` (shared with shared, not with exclusive, and a write through the locking
handle fails, as the draft says); `testWholeFileByDefault` (the default range covers bytes past the end);
`testEmptyRangeDoesNotLock` (on a pipe, where `LockFileEx` fails with `invalidFunction`, which a non-empty range
shows); `testNegativeBoundsAreRejected` (all five forms); `testRangesClosedAtTheLastOffset`;
`testBodyErrorsWinAndTheRangeIsUnlocked`.

Next: SYS-0015.

## 6. SYS-0015: volume information: `b689377`

What: `Win32VolumeInformation.swift`: `Win32.VolumeInformation` (`name`, `fileSystemName`, `serialNumber`,
`maximumComponentLength`, `flags`), `Win32.FileSystemFlags` (30 flags, in bit order), and `volumeInformation()`
on both handle types, over `GetVolumeInformationByHandleW` with two stack buffers of `MAX_PATH + 1` characters.

Follows the draft exactly. `VolumeInformation` has an internal memberwise initializer, and no public one, as
drafted. The flag values are `winnt.h`'s; the newest (`0x200` to `0x2000`, `0x40000000`) weren't in any source
available here to check against, so the Windows test is the check.

Darwin tests: unchanged. Windows tests: `Win32VolumeInformationTests`.

A Windows run must check: the 30 flags against the SDK; a temporary file's volume (a file system name, a component
length) equal to its directory's, which is opened with no access rights; a pipe reporting `NPFS`; and `NUL`
throwing `invalidFunction`. The last two are the draft's observations.

Next: SYS-0016.

## 7. SYS-0016: the final path name: `ca68ef8`

What: `Win32FinalPath.swift`: `Win32.VolumeNameFormat` (`dos`, `guid`, `nt`, `volumeRelative`) and
`finalPath(volumeName:normalized:)` on both handle types, over `GetFinalPathNameByHandleW`, starting with a stack
buffer of `MAX_PATH + 1` characters and retrying at the size it reports.

Follows the draft exactly: `normalized` is a `Bool` (`FILE_NAME_NORMALIZED` or `FILE_NAME_OPENED`), and the path
comes back as Windows reports it, with its `\\?\` prefix.

Darwin tests: unchanged. Windows tests: `Win32FinalPathTests`.

A Windows run must check: each format's shape (`\\?\`, `\Device\`, `\\?\Volume{`, and a volume-relative path);
`normalized` against the opened name's case; a file renamed while open; a directory; a path longer than MAX_PATH,
which needs the retry; and a pipe (`badPathName`) and `NUL` (`invalidParameter`), the draft's observations.

Next: the adopter ranking.

## 8. What the adopters' Windows code imports: this commit

What the adopters' Windows code takes from WinSDK, ucrt, CRT and visualc, and how much of it System covers,
from `Prototype/Win32/survey-windows-imports.py`. It's lexical, since nothing here compiles for Windows.

**What was surveyed.** The 20 checkouts in `../adopters`, committed content at each one's branch (`no-darwin` for
swift-foundation, `migrate-darwin` for the rest): WasmKit `4917e06`, indexstore-db `cc966b8`, sourcekit-lsp
`cb2881c5`, swift-argument-parser `0fbda27`, swift-async-algorithms `bd5f6f4`, swift-build `56ad2d9`,
swift-certificates `0df6bd1`, swift-corelibs-xctest `80a3f95`, swift-docc `ad021e3`, swift-driver `ddb51ccd`,
swift-foundation `ef3c5667`, swift-llbuild `f7a0650`, swift-log `4d6d77f`, swift-nio `e1623fbf`,
swift-package-manager `dbe05ec1e`, swift-sdk-generator `5956672`, swift-subprocess `d6b5866`, swift-syntax
`961f0b723`, swift-tools-protocols `18e8a9f9`, swift-tools-support-core `1ad4129`.
- A file counts if it imports one of the modules, in any form (`import struct WinSDK.socklen_t` too), on a line
  Windows compiles: 203 files in 18 packages, 156 in sources and 47 in tests; 160 import WinSDK, 48 ucrt and 42
  CRT, and none visualc. swift-corelibs-xctest and swift-sdk-generator have none.
- Which lines Windows compiles comes from the adopter-coverage tool's `#if` evaluator
  (`Utilities/adopter-coverage/scripts/platforms.py`). A line active only in some Windows builds counts. Flags
  that are decided on Windows are modeled: Apple-internal ones (`FOUNDATION_FRAMEWORK`, `LLBUILD_FRAMEWORK`,
  `DATA_LEGACY_ABI`) and swift-foundation's opt-outs (`NO_FILESYSTEM` and the like) are off, and `SWIFT_PACKAGE`
  is on.
- The names are the ones on those lines that look like C names: ALL_CAPS names, names that begin with an
  underscore, lowercase names from the C library interfaces that the coverage mapping lists (as calls, bare
  globals, or `_t` types), and other names that none of these declares: System's libraries, the adopters, and
  the macOS SDK's interfaces for the standard library, Foundation, Dispatch, XCTest and swift-testing. Names the
  SDK or UCRT declares count even where a package redeclares one. 815 names, every one classified by hand in
  the script's `CONCEPTS`.
- Limits: a file that reaches WinSDK through a re-export (swift-tools-support-core's TSCLibc, swift-build's
  SWBLibc, NIOPosix's ucrt) doesn't count, as the task asks for importing files; the re-exporting files do. An
  implicit member (`.foo`) isn't a name here. A lowercase C name outside the mapping's vocabulary is missed.
  Several names serve more than one concept and are counted in one (see *What this lane covers*). Code inside
  string literals, such as SwiftPM's generated test observer, isn't code.

**Which files System covers.** A file is covered when every name it uses is System's (currency types aside):
before this lane, with the API that already existed on Windows; now, with this lane's too.

| package | files (sources, tests) | nothing seen | only types | covered before | covered now | need a gap | need only other libraries |
|---|---|---|---|---|---|---|---|
| WasmKit | 9 (8, 1) | 0 | 0 | 0 | 2 | 4 | 3 |
| indexstore-db | 4 (4, 0) | 0 | 0 | 1 | 1 | 3 | 0 |
| sourcekit-lsp | 16 (14, 2) | 3 | 0 | 1 | 2 | 4 | 7 |
| swift-argument-parser | 2 (2, 0) | 0 | 0 | 0 | 0 | 2 | 0 |
| swift-async-algorithms | 1 (1, 0) | 0 | 0 | 0 | 0 | 1 | 0 |
| swift-build | 11 (9, 2) | 1 | 0 | 0 | 1 | 7 | 2 |
| swift-certificates | 3 (3, 0) | 0 | 0 | 0 | 0 | 3 | 0 |
| swift-docc | 6 (4, 2) | 0 | 0 | 0 | 0 | 5 | 1 |
| swift-driver | 12 (7, 5) | 8 | 0 | 0 | 0 | 4 | 0 |
| swift-foundation | 34 (27, 7) | 6 | 1 | 0 | 2 | 22 | 3 |
| swift-llbuild | 7 (7, 0) | 3 | 0 | 0 | 1 | 1 | 2 |
| swift-log | 6 (3, 3) | 2 | 0 | 0 | 0 | 4 | 0 |
| swift-nio | 50 (34, 16) | 6 | 0 | 2 | 7 | 36 | 1 |
| swift-package-manager | 12 (11, 1) | 3 | 0 | 0 | 0 | 7 | 2 |
| swift-subprocess | 16 (10, 6) | 2 | 1 | 0 | 2 | 11 | 0 |
| swift-syntax | 3 (3, 0) | 1 | 0 | 0 | 0 | 2 | 0 |
| swift-tools-protocols | 5 (3, 2) | 1 | 0 | 1 | 1 | 3 | 0 |
| swift-tools-support-core | 6 (6, 0) | 0 | 0 | 0 | 0 | 6 | 0 |
| all | 203 (156, 47) | 36 | 2 | 5 | 19 | 125 | 21 |

So 14 more files could drop their Windows imports with this lane's API, and 36 use nothing the survey sees:
imports kept for re-exports, for lowercase C functions it doesn't know, or for nothing. 125 files need at least
one gap, and 21 need only replacements that aren't System's (mostly the C library's strings, memory and stdio).

**What this lane covers.** The `new` rows of the ranking below. Some names are shared with gaps:
- `CloseHandle` is in 25 files: 8 close only file handles (from `CreateFileW`, `_get_osfhandle` or pipes), 5
  file handles and others, 10 only other kinds (processes, threads, jobs, events, tokens), and 2 can't be told.
  Owners for the other kinds are gaps.
- `ReadFile` and `WriteFile` are in 5 files. swift-foundation's read files it opened with `CreateFileW`, which
  `Win32.FileHandle` covers. NIO's pass an `OVERLAPPED` offset for positional reads and writes on a descriptor's
  handle, which `read(fromAbsoluteOffset:into:)` and `write(_:toAbsoluteOffset:)` cover through
  `withWin32HandleIfAvailable`. swift-subprocess's are overlapped reads of pipes, a gap.
- `SetFileInformationByHandle` is covered for `FileEndOfFileInfo` (WasmKit); swift-foundation's
  `FileRenameInfoEx` and NIO's `FileDispositionInfoEx` are in the file-information gap.
- `GetCurrentProcess` is in 10 files, 3 of them for `DuplicateHandle`; the rest query or end processes, so it's
  counted with processes.
- Error codes: 26 of `Win32.Error`'s 33 named codes are used. 43 more appear, most of them in WasmKit's copy of
  the C runtime's `_dosmaperr` table, which `Errno(approximating:)` replaces. The ones two or more packages use
  are the candidates for more names (section 1): `ERROR_FILENAME_EXCED_RANGE` (206, 3 packages), and
  `ERROR_BAD_ARGUMENTS` (160), `ERROR_INVALID_ACCESS` (12), `ERROR_INVALID_DATA` (13), `ERROR_INVALID_DRIVE`
  (15), `ERROR_BUFFER_OVERFLOW` (111), `ERROR_DIR_NOT_EMPTY` (145), `ERROR_NOT_ENOUGH_MEMORY` (8),
  `ERROR_NOT_FOUND` (1168), `ERROR_NOT_SAME_DEVICE` (17) and `ERROR_TOO_MANY_OPEN_FILES` (4), 2 packages each.

**The ranking.** Gaps first, by packages, then files; then what System covers, what isn't System's, the
currency types, and what the survey ignores. The names are each concept's most used; the script's `names`
output has them all, with their files.

| class | concept | packages | files (sources) | names, by uses | System, or owner |
|---|---|---|---|---|---|
| gap | Creating, waiting for and ending processes | 12: sourcekit-lsp, swift-argument-parser, swift-build, swift-docc, swift-driver, swift-foundation, swift-nio, swift-package-manager, swift-subprocess, swift-syntax, swift-tools-protocols, swift-tools-support-core | 27 (21) | `GetCurrentProcess`, `TerminateProcess`, `WaitForSingleObject`, `OpenProcess`, `PROCESS_INFORMATION`, `CREATE_SUSPENDED` and 59 more | Processes and RawSpawn are POSIX-only |
| gap | Clocks, sleeping and time zones | 10: WasmKit, indexstore-db, sourcekit-lsp, swift-build, swift-driver, swift-foundation, swift-llbuild, swift-log, swift-nio, swift-tools-protocols | 25 (14) | `Sleep`, `GetSystemTimePreciseAsFileTime`, `GetTickCount64`, `__time64_t`, `strftime`, `usleep` and 12 more | ClockTime, Sleep and BrokenDownTime are POSIX-only |
| gap | SRW locks and condition variables | 8: WasmKit, swift-argument-parser, swift-async-algorithms, swift-certificates, swift-docc, swift-log, swift-nio, swift-subprocess | 11 (10) | `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `SRWLOCK`, `InitializeSRWLock`, `CONDITION_VARIABLE`, `SleepConditionVariableSRW` and 12 more | Synchronization.Mutex covers the lock |
| gap | Consoles and standard handles | 8: sourcekit-lsp, swift-argument-parser, swift-docc, swift-nio, swift-package-manager, swift-subprocess, swift-syntax, swift-tools-support-core | 10 (9) | `GetStdHandle`, `STD_OUTPUT_HANDLE`, `CONSOLE_SCREEN_BUFFER_INFO`, `SetConsoleCtrlHandler`, `GetConsoleScreenBufferInfo`, `SetConsoleMode` and 10 more | Terminal is POSIX-only; SYS-0011 and SYS-0012's future directions |
| gap | The current, temporary, Windows and executable directories | 7: indexstore-db, sourcekit-lsp, swift-build, swift-foundation, swift-nio, swift-package-manager, swift-subprocess | 11 (9) | `GetSystemDirectoryW`, `GetWindowsDirectoryW`, `GetModuleFileNameW`, `GetCurrentDirectoryW`, `GetTempPathW`, `GetTempPath2W` and 2 more | SystemPaths and Executable are POSIX-only |
| gap | Dynamic loading | 7: indexstore-db, sourcekit-lsp, swift-build, swift-driver, swift-foundation, swift-package-manager, swift-subprocess | 8 (7) | `GetProcAddress`, `HMODULE`, `LoadLibraryW`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleA` | DynamicLibrary is POSIX-only |
| gap | Environment variables | 6: swift-build, swift-docc, swift-foundation, swift-nio, swift-package-manager, swift-subprocess | 10 (6) | `GetEnvironmentVariableW`, `SetEnvironmentVariableW`, `_putenv`, `FreeEnvironmentStringsW`, `GetEnvironmentStringsW`, `LPWCH` and 3 more | ProcessEnvironment is POSIX-only |
| gap | Querying and setting file information | 5: WasmKit, swift-driver, swift-foundation, swift-nio, swift-subprocess | 18 (18) | `FILE_ATTRIBUTE_DIRECTORY`, `FILE_ATTRIBUTE_REPARSE_POINT`, `FILE_ATTRIBUTE_READONLY`, `BY_HANDLE_FILE_INFORMATION`, `FILETIME`, `GetFileAttributesExW` and 16 more | SYS-0010's roadmap: GetFileInformationByHandleEx and SetFileInformationByHandle's other classes |
| gap | Long paths and canonicalization | 5: swift-build, swift-foundation, swift-package-manager, swift-subprocess, swift-tools-support-core | 10 (10) | `PATHCCH_ALLOW_LONG_PATHS`, `GetFullPathNameW`, `PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH`, `PathAllocCanonicalize`, `PathCchStripPrefix` | System canonicalizes internally; nothing public |
| gap | Threads and thread-local storage | 5: swift-foundation, swift-log, swift-nio, swift-subprocess, swift-tools-support-core | 9 (7) | `GetCurrentThread`, `GetCurrentThreadId`, `FlsAlloc`, `FlsGetValue`, `FlsSetValue`, `TF_USE_KERNEL_APC` and 5 more | Threads (PThread) is POSIX-only |
| gap | HRESULT | 4: swift-build, swift-foundation, swift-package-manager, swift-subprocess | 12 (12) | `HRESULT`, `S_OK`, `HRESULT_CODE`, `HRESULT_FACILITY`, `WIN32_FROM_HRESULT`, `FACILITY_WIN32` and 1 more | SYS-0010's future directions: Win32.HResult |
| gap | Creating, removing, renaming, copying and linking files | 4: WasmKit, swift-foundation, swift-nio, swift-tools-support-core | 11 (8) | `CreateDirectoryW`, `DeleteFileW`, `FILE_RENAME_INFO`, `MOVEFILE_COPY_ALLOWED`, `_mktemp_s`, `COPY_FILE_FAIL_IF_EXISTS` and 23 more | FilePathOperations is POSIX-only |
| gap | Overlapped I/O and completion ports | 4: swift-build, swift-nio, swift-subprocess, swift-tools-support-core | 7 (7) | `OVERLAPPED`, `GetOverlappedResult`, `_OVERLAPPED`, `CreateIoCompletionPort`, `FILE_FLAG_OVERLAPPED`, `CancelIoEx` and 3 more | SYS-0011 and SYS-0013's future directions |
| gap | System and processor information | 4: swift-driver, swift-foundation, swift-nio, swift-subprocess | 5 (5) | `VER_NT_WORKSTATION`, `SYSTEM_INFO`, `SYSTEM_LOGICAL_PROCESSOR_INFORMATION`, `GetSystemInfo`, `RTL_OSVERSIONINFOEXW`, `GetLogicalProcessorInformation` and 9 more | SystemConfig and uname are POSIX-only |
| gap | Users, tokens and security identifiers | 3: swift-foundation, swift-package-manager, swift-subprocess | 6 (5) | `TOKEN_QUERY`, `GetUserNameW`, `GetUserNameExW`, `GetUserProfileDirectoryW`, `LookupAccountNameW`, `NameDisplay` and 16 more | UserDatabase and ProcessCredentials are POSIX-only; SYS-0011's future directions |
| gap | Winsock sockets | 2: swift-certificates, swift-nio | 23 (19) | `socklen_t`, `WSAGetLastError`, `SOCKET_ERROR`, `AF_INET`, `AF_INET6`, `ADDRESS_FAMILY` and 139 more | SystemSockets is Unix-only |
| gap | Anonymous and named pipes | 2: swift-log, swift-subprocess | 4 (2) | `CreateNamedPipeW`, `CreatePipe`, `FILE_FLAG_FIRST_PIPE_INSTANCE`, `PIPE_ACCESS_INBOUND`, `PIPE_ACCESS_OUTBOUND`, `PIPE_NOWAIT` and 6 more | SYS-0011's future directions; FileDescriptor.pipe() makes C runtime pipes |
| gap | Job objects | 2: swift-subprocess, swift-tools-support-core | 3 (2) | `JOBOBJECT_EXTENDED_LIMIT_INFORMATION`, `AssignProcessToJobObject`, `JOBOBJECT_ASSOCIATE_COMPLETION_PORT`, `CreateJobObjectW`, `IsProcessInJob`, `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` and 7 more | the Windows counterpart of process groups |
| gap | Reparse points | 2: swift-foundation, swift-nio | 3 (3) | `CNIOWindows_REPARSE_DATA_BUFFER`, `DeviceIoControl`, `FSCTL_GET_REPARSE_POINT`, `IO_REPARSE_TAG_SYMLINK`, `REPARSE_DATA_BUFFER`, `IO_REPARSE_TAG_AF_UNIX` and 4 more | SYS-0016's future directions: DeviceIoControl with FSCTL_GET_REPARSE_POINT |
| gap | Events | 2: swift-subprocess, swift-tools-support-core | 2 (2) | `CreateEventW`, `SetEvent` | an owner for event handles |
| gap | Network interfaces | 2: swift-foundation, swift-nio | 2 (2) | `GetAdaptersAddresses`, `NETWORK_PREFIX` | NetworkInterfaces is POSIX-only |
| gap | Memory-mapped files | 1: swift-foundation | 3 (3) | `FILE_MAP_READ`, `PAGE_READONLY`, `UnmapViewOfFile`, `CreateFileMappingW`, `MapViewOfFile` | MemoryMapping is POSIX-only |
| gap | Directory enumeration | 1: swift-foundation | 2 (2) | `FIND_FIRST_EX_LARGE_FETCH`, `FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY`, `FindNextFileW`, `FindClose`, `FindExInfoBasic`, `FindExSearchNameMatch` and 2 more | SYS-0011's future directions (DirectoryHandle) |
| gap | Directory change notification | 1: swift-tools-support-core | 1 (1) | `FILE_NOTIFY_INFORMATION`, `FILE_NOTIFY_CHANGE_CREATION`, `FILE_NOTIFY_CHANGE_DIR_NAME`, `FILE_NOTIFY_CHANGE_FILE_NAME`, `FILE_NOTIFY_CHANGE_LAST_WRITE`, `FILE_NOTIFY_CHANGE_SIZE` and 1 more | SYS-0011's future directions (DirectoryHandle) |
| gap | Free space and volume paths | 1: swift-foundation | 1 (1) | `GetDiskFreeSpaceExW`, `GetVolumePathNameW` | SYS-0015's future directions |
| new | Error codes, messages and last error | 11: WasmKit, indexstore-db, sourcekit-lsp, swift-argument-parser, swift-build, swift-driver, swift-foundation, swift-nio, swift-package-manager, swift-subprocess, swift-tools-support-core | 49 (43) | `GetLastError`, `ERROR_FILE_NOT_FOUND`, `ERROR_ACCESS_DENIED`, `ERROR_SUCCESS`, `ERROR_INVALID_DATA`, `ERROR_PATH_NOT_FOUND` and 73 more | Win32.Error, its description, Errno(approximating:) |
| new | Opening and closing files | 9: sourcekit-lsp, swift-build, swift-foundation, swift-llbuild, swift-nio, swift-package-manager, swift-subprocess, swift-tools-protocols, swift-tools-support-core | 35 (29) | `CloseHandle`, `INVALID_HANDLE_VALUE`, `CreateFileW`, `FILE_SHARE_READ`, `FILE_SHARE_WRITE`, `OPEN_EXISTING` and 13 more | Win32.FileHandle.open, openOrCreate, close(); DirectoryHandle.open |
| new | Descriptor and handle bridges | 7: WasmKit, swift-foundation, swift-log, swift-nio, swift-package-manager, swift-subprocess, swift-tools-support-core | 21 (14) | `_get_osfhandle`, `_O_BINARY`, `_open_osfhandle`, `_O_APPEND`, `_O_NOINHERIT` | FileDescriptor.withWin32HandleIfAvailable(_:), init(adopting:translation:append:) |
| new | Reading, writing, size and flush | 4: WasmKit, swift-foundation, swift-nio, swift-subprocess | 7 (7) | `ReadFile`, `SetFileInformationByHandle`, `WriteFile`, `GetFileSizeEx`, `FILE_END_OF_FILE_INFO`, `FileEndOfFileInfo` and 1 more | Win32.FileHandle read, readFully, write, append, size(), flush(), resize(to:) |
| new | File type | 2: swift-foundation, swift-nio | 7 (7) | `FILE_TYPE_DISK`, `GetFileType`, `FILE_TYPE_PIPE`, `FILE_TYPE_CHAR`, `FILE_TYPE_UNKNOWN` | Win32.FileHandle.fileType() |
| new | Duplicating handles and inheritance | 2: swift-nio, swift-subprocess | 4 (3) | `HANDLE_FLAG_INHERIT`, `SetHandleInformation`, `DUPLICATE_SAME_ACCESS`, `DuplicateHandle` | duplicate(access:inheritable:), setInheritable(_:) |
| new | Final path of a handle | 2: swift-foundation, swift-tools-support-core | 3 (3) | `GetFinalPathNameByHandleW`, `VOLUME_NAME_DOS`, `FILE_NAME_NORMALIZED` | finalPath(volumeName:normalized:) |
| new | Byte-range locks | 1: swift-build | 1 (1) | `LOCKFILE_EXCLUSIVE_LOCK`, `LockFileEx`, `UnlockFileEx` | withLock(byteRange:mode:_:), withLockIfAvailable |
| new | Volume information | 1: swift-foundation | 1 (1) | `GetVolumeInformationW` | volumeInformation(), through a handle to the volume's root |
| existing | Descriptor I/O | 7: WasmKit, swift-build, swift-foundation, swift-log, swift-nio, swift-package-manager, swift-tools-support-core | 23 (19) | `off_t`, `_read`, `_write`, `_close`, `_O_RDWR`, `_SH_DENYNO` and 18 more | FileDescriptor open, close, read, write, seek, duplicate, pipe, resize |
| existing | errno and its values | 5: WasmKit, swift-foundation, swift-nio, swift-package-manager, swift-tools-support-core | 17 (14) | `errno`, `_get_errno`, `strerror`, `_set_errno`, `strerror_s`, `EAFNOSUPPORT` and 8 more | Errno, Errno.current, Errno.description |
| existing | Path syntax | 5: indexstore-db, sourcekit-lsp, swift-foundation, swift-tools-protocols, swift-tools-support-core | 8 (8) | `PathCchIsRoot`, `PathIsRelativeW`, `PathCchRemoveFileSpec`, `PathCchSkipRoot`, `PathCchStripToRoot`, `PathFindExtensionW` and 2 more | FilePath: root, isAbsolute, isRelative, lastComponent, extension, removingLastComponent |
| existing | Permissions for new files | 4: WasmKit, swift-foundation, swift-nio, swift-tools-support-core | 7 (5) | `_S_IWRITE`, `_S_IREAD`, `_S_IEXEC` | FilePermissions, through FileDescriptor.open |
| other | The C library: strings, memory, stdio, locales | 14: WasmKit, sourcekit-lsp, swift-argument-parser, swift-build, swift-certificates, swift-docc, swift-foundation, swift-llbuild, swift-log, swift-nio, swift-package-manager, swift-subprocess, swift-syntax, swift-tools-support-core | 41 (38) | `free`, `stderr`, `wcslen`, `strlen`, `memcmp`, `stdout` and 31 more | Swift's standard library and Foundation |
| other | Shell and COM: known folders, file info, MIME types | 5: swift-build, swift-docc, swift-foundation, swift-nio, swift-package-manager | 7 (7) | `KF_FLAG_DEFAULT`, `CoTaskMemFree`, `_GUID`, `KNOWNFOLDERID`, `SHGFI_EXETYPE`, `SHGetKnownFolderPath` and 17 more | the Shell; not System's |
| other | The registry | 1: swift-foundation | 2 (2) | `RRF_RT_REG_SZ`, `HKEY_LOCAL_MACHINE`, `RegGetValueW` | advapi32's registry; not System's |
| other | Hashing | 1: swift-build | 1 (1) | `BCRYPT_ALG_HANDLE`, `BCRYPT_HASH_HANDLE`, `BCryptCloseAlgorithmProvider`, `BCryptCreateHash`, `BCryptDestroyHash`, `BCryptFinishHash` and 2 more | bcrypt's hashes; swift-crypto's |
| other | User accounts (tests) | 1: swift-subprocess | 1 (0) | `NERR_Success`, `USER_INFO_1`, `NetUserAdd`, `NetUserDel`, `UF_DONT_EXPIRE_PASSWD`, `UF_SCRIPT` and 1 more | netapi32; test set-up |
| types | Windows' currency types and constants, and LocalFree | 13: WasmKit, indexstore-db, sourcekit-lsp, swift-build, swift-docc, swift-driver, swift-foundation, swift-llbuild, swift-log, swift-nio, swift-package-manager, swift-subprocess, swift-tools-support-core | 75 (66) | `DWORD`, `HANDLE`, `WCHAR`, `size_t`, `ULONG`, `MAX_PATH` and 23 more | follow the calls that take or return them |
| ignore | Swift names the survey can't see declared | 9: WasmKit, sourcekit-lsp, swift-certificates, swift-docc, swift-foundation, swift-llbuild, swift-nio, swift-package-manager, swift-subprocess | 32 (25) | `ChannelInitializerResult`, `DestinationType`, `CommandResult`, `ManagedAtomic`, `BuildValueFileTimestamp`, `BuildValueFileInfo` and 29 more | the packages' own types, and their dependencies' |
| ignore | Other C modules' names | 7: sourcekit-lsp, swift-driver, swift-foundation, swift-llbuild, swift-nio, swift-package-manager, swift-subprocess | 17 (14) | `CONNECT_DELAYER`, `MAX_DEPTH`, `SWIFT_SCANNER_LIB`, `CONNECT_RECORDER`, `LLBUILD_C_API_VERSION`, `NSEC_PER_SEC` and 19 more | CoreFoundation's and Foundation's shims, sourcekitd, swiftScan, llbuild |
| ignore | Darwin names on lines Windows also compiles | 1: swift-driver | 1 (1) | `QUASI_PID_START` | #if conditions the evaluator can't decide |

**The top gaps**, with where each would go. Four of them (standard handles, file information, HRESULT and
overlapped I/O) are the drafts' own future directions; most of the rest are areas System has for POSIX and not
for Windows:
1. **Processes** (12 packages, 27 files): `CreateProcessW` with `STARTUPINFOEXW` and an inherited-handle list,
   waiting (`WaitForSingleObject`, `GetExitCodeProcess`), `TerminateProcess`, `OpenProcess`, and the current
   process's ID. SYS-0011's owned-handle model extends to a `Win32.ProcessHandle`, which
   `Prototype/PlatformEnum` already sketches; `ProcessID` would need Windows' `DWORD` process IDs.
2. **Clocks and sleeping** (10 packages, 25 files, many of them tests calling `Sleep`): `QueryPerformanceCounter`,
   `GetTickCount64`, `GetSystemTimePreciseAsFileTime`, `Sleep`, and the C runtime's 64-bit time functions.
   Swift's `ContinuousClock` and `Task.sleep` cover much of it without System; ClockTime and Sleep on Windows
   would cover the rest.
3. **SRW locks and condition variables** (8 packages): each package's own lock type. `Synchronization.Mutex`
   covers the lock; condition variables have no Swift equivalent, so this is the Windows side of PThreadMutex
   and PThreadCondition.
4. **Consoles and standard handles** (8 packages): `GetStdHandle`, which SYS-0011 lists as a future direction,
   console modes and screen buffer sizes (the Terminal area's Windows side), and `SetConsoleCtrlHandler`.
5. **Well-known directories** (7 packages): the current, temporary, Windows and system directories, and the
   executable's path (`GetModuleFileNameW`): SystemPaths and Executable on Windows.
6. **Dynamic loading** (7 packages): `LoadLibraryW`, `GetProcAddress`, `FreeLibrary`: DynamicLibrary on Windows.
7. **Environment variables** (6 packages): `GetEnvironmentVariableW`, `SetEnvironmentVariableW`,
   `GetEnvironmentStringsW`, and the C runtime's `_putenv`: ProcessEnvironment on Windows.
8. **File information** (5 packages, 18 files): attributes, `BY_HANDLE_FILE_INFORMATION`, file IDs, times, and
   setting rename and delete dispositions with POSIX semantics: the next drafts in SYS-0010's roadmap.
9. **Long paths** (5 packages): the packages canonicalize for the path functions System doesn't wrap yet; this
   lane's `_withCanonicalPath` could be the public API, or go away as they're wrapped.
10. **Threads**, **HRESULT** (SYS-0010's `Win32.HResult`), **path operations** (create, remove, rename, copy,
    link), **overlapped I/O** (SYS-0011 and SYS-0013's future direction) and **system information**, 4 or 5
    packages each; **Winsock** is 2 packages but 23 files, nearly all NIO's.

## 9. Findings

- **Errno's `~=` must be disfavored too** (P1). Until then, even System's own code can't match a `Win32.Error`
  with an implicit-member pattern of a shared name, so it compares codes with `==`.
- **The Windows path code traps on failure.** In `FilePathWindows.swift`, `HRESULT_CODE`, `HRESULT_FACILITY` and
  `WIN32_FROM_HRESULT` convert a failed (negative) `HRESULT` with `DWORD(hr)`, which traps: a failing
  `PathAllocCanonicalize`, such as for a path over 32,767 characters, crashes `FileDescriptor.open` instead of
  throwing. `withCanonicalPathRepresentation` also forms `1..<dwLength`, which traps when `GetFullPathNameW`
  fails and returns 0. Patch P2. swift-foundation's `WinSDK+Extensions.swift` has the same `DWORD(hr)` (and
  shifts the wrong way for the facility).
- **ntdll isn't linked.** The WinSDK module map has `winternl.h` but no `link "ntdll"`; System code that calls the
  NT API must look it up, or `Package.swift` and CMake must link ntdll.
- **The Samples stand-ins don't clash.** `Sources/Samples/Platforms/StandIns/Win32*.swift` are compiled only with
  `SIMULATE_PLATFORMS`, and a real Windows build of the platform samples now reaches this API. In a simulated
  build on Windows, not a configuration anyone builds (the stand-ins run over POSIX), the Samples module's own
  `Win32` would shadow System's, and its `FileDescriptor` extensions (`TranslationMode`, `init(adopting:)`,
  `withWin32HandleIfAvailable`) would overlap System's.
- **`_MAX_PATH` is the UCRT's** (`stdlib.h`), so the internal constant is `_win32MaxPath`.
- **SYS-0014's range resolution would trap** for `..<(-1)` and `...(-2)`, which the draft says throw; the
  implementation checks those two range types first (section 5).
- **36 adopter files import a Windows module and use nothing the survey sees** (section 8): some re-export it,
  some use lowercase C functions it doesn't know, and some may use nothing, which would be the cheapest imports
  to drop.
- **Re-exports hide Windows users.** TSCLibc and SWBLibc re-export WinSDK and CRT (and SWBLibc ucrt), and
  NIOPosix re-exports ucrt, so a file that imports one of them, in SwiftPM or swift-driver through TSCLibc for
  instance, uses WinSDK without importing it, and the survey doesn't count it. A compiler-backed survey would
  need a Windows build's index store, as adopter-coverage uses a macOS one.

## 10. Patches for files outside the lane

**P1, `Sources/System/Errno.swift`: disfavor `Errno.~=`.** Verified on Darwin in a scratch copy: with it, `swift
build` (Samples included) and `swift test` give the same results as without it (XCTest 565 tests, 4 skipped;
swift-testing 496 tests in 80 suites). Errno patterns keep working on every platform: an untyped
`catch Errno.x` has no other candidate, and a typed one uses the standard library's `~=` for `Equatable` values.

```diff
--- a/Sources/System/Errno.swift
+++ b/Sources/System/Errno.swift
@@ -1593,6 +1593,7 @@
 @available(System 0.0.1, *)
 extension Errno {
   @_alwaysEmitIntoClient
+  @_disfavoredOverload
   public static func ~=(_ lhs: Errno, _ rhs: Error) -> Bool {
     guard let value = rhs as? Errno else { return false }
     return lhs == value
```

With it, add this test to `Win32ErrorTests`; without P1 it fails:

```swift
  func testTypedCatchOfASharedName() {
    XCTAssertTrue(catchesImplicitFileExists())
  }

@available(System 199, *)
private func catchesImplicitFileExists() -> Bool {
  do throws(Win32.Error) {
    throw .fileExists
  } catch .fileExists {
    return true
  } catch {
    return false
  }
}
```

**P2, `Sources/System/FilePath/FilePathWindows.swift`: don't trap on a failed HRESULT or a failed
`GetFullPathNameW`.** Not compiled here (the file is Windows-only); the conversions match `_win32Error(fromHRESULT:)`
in `Win32Open.swift`, which the harness compiles.

Both patches apply to `6a9833f` with `git apply`.

```diff
--- a/Sources/System/FilePath/FilePathWindows.swift
+++ b/Sources/System/FilePath/FilePathWindows.swift
@@ -479,6 +479,9 @@
     // of the registry or process setting to enable long paths (but it will also
     // not add the \\?\ prefix required by other functions under these conditions).
     let dwLength: DWORD = GetFullPathNameW(self, 0, nil, nil)
+    guard dwLength > 0 else {
+      throw Errno(rawValue: _mapWindowsErrorToErrno(GetLastError()))
+    }
     return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { pwszFullPath in
       guard (1..<dwLength).contains(GetFullPathNameW(self, DWORD(pwszFullPath.count), pwszFullPath.baseAddress, nil)) else {
         throw Errno(rawValue: _mapWindowsErrorToErrno(GetLastError()))
@@ -512,12 +515,12 @@
 
 @inline(__always)
 fileprivate func HRESULT_CODE(_ hr: HRESULT) -> DWORD {
-    DWORD(hr) & 0xffff
+    DWORD(bitPattern: hr) & 0xffff
 }
 
 @inline(__always)
 fileprivate func HRESULT_FACILITY(_ hr: HRESULT) -> DWORD {
-    DWORD(hr >> 16) & 0x1fff
+    (DWORD(bitPattern: hr) >> 16) & 0x1fff
 }
 
 @inline(__always)
@@ -533,6 +536,6 @@
     if HRESULT_FACILITY(hr) == FACILITY_WIN32 {
         return HRESULT_CODE(hr)
     }
-    return DWORD(hr)
+    return DWORD(bitPattern: hr)
 }
 #endif
```

## 11. windows-2: patches P1 and P2: `037de61`, `5d843d5`

What:
- **P1** (`037de61`), as section 10 has it: `@_disfavoredOverload` on `Errno.~=` in `Errno.swift`, and
  `testTypedCatchOfASharedName` in `Win32ErrorTests`. `Win32.Error.~=`'s doc comment and the harness's `Errno`
  stand-in follow.
- **P2** (`5d843d5`), section 10's diff applied with `git apply`: in `FilePathWindows.swift`,
  `withCanonicalPathRepresentation` throws when the sizing `GetFullPathNameW` returns 0, and `HRESULT_CODE`,
  `HRESULT_FACILITY` and `WIN32_FROM_HRESULT` convert with `DWORD(bitPattern:)`. A new test file,
  `Win32OverlongPathTests.swift`, opens a path of 40,007 characters through `FileDescriptor.open` and
  `Win32.FileHandle.open`.

Checks:
- Darwin, before (`4365f83`) and after each commit: XCTest 571 tests (5 skipped), swift-testing 502 tests in 82
  suites, all passing. `check-windows.sh` passes before and after.
- `Prototype/Verify/V16f_error_patterns.swift`, rerun with Swift 6.2: with only Win32's operator disfavored,
  `win32Typed` prints `other`, which is the new test failing; with both, every form matches.
- P2's region of `FilePathWindows.swift` isn't in the harness, so it was compiled once in a scratch copy: the
  function and the three helpers, against `WindowsModel` plus `S_OK` and System's own `ERROR_SUCCESS` overlay
  constant. It compiles.

A Windows run must check:
- `testTypedCatchOfASharedName`.
- `Win32OverlongPathTests`: both opens throw, and neither traps. `FileDescriptor.open` should throw ENOENT (the C
  runtime's mapping of `ERROR_FILENAME_EXCED_RANGE`, from whichever call fails); the test checks only that it's an
  `Errno`, and a Windows run should record which one.

## 12. Processes: `ProcessID` on Windows and `Win32.ProcessHandle`: `92a1dbd`

The first gap of section 8. The names most of its files use, by `survey-windows-imports.py names`, are
`GetCurrentProcess`, `TerminateProcess`, `OpenProcess`, `WaitForSingleObject`, `GetCurrentProcessId` and
`GetExitCodeProcess`; `CreateProcessW` is in two packages' files, and is section 13.

What:
- `ProcessIDWindows.swift`: `CInterop.ProcessID`, a `DWORD`, and `ProcessID` on Windows, with `current`
  (`GetCurrentProcessId`).
- `Win32Process.swift`: `Win32.ProcessAccess`, with the 13 process-specific rights, the five standard ones, `all`
  and `maximumAllowed`; and `Win32.ProcessHandle`, an owner like the file handles (`init?(unsafelyAdopting:)`,
  `unsafeRawHandle`, `relinquish()`, `close()`, a deinit that closes). On it: `current` (`GetCurrentProcess`),
  `open(_:access:inheritable:)` (`OpenProcess`), `processID()` (`GetProcessId`), `waitForExit()` and
  `waitForExit(timeout:)` (`WaitForSingleObject`), `exitCode()` (`GetExitCodeProcess`), `terminate(exitCode:)`
  (`TerminateProcess`), and `duplicate(access:inheritable:)`, `isInheritable()` and `setInheritable(_:)`.
- `Win32Wait.swift`: the internal wait, for this and the owners to come. A `Duration` rounds up to whole
  milliseconds; a time-out longer than `INFINITE - 1` milliseconds (49.7 days) waits in parts.

Which API: **Win32, and `ProcessID` shared.**
- A Windows process is a kernel object reached through handles: no fork, no reaping, no signals, no process
  groups, and any handle with the rights can wait or read the exit code. `ChildProcess`, `ExitStatus`,
  `sendSignal` and `RawSpawn` model none of that, so this is Win32 API in the drafts' style, and owned only: a
  process handle's value is reusable after it closes, as a file handle's is.
- A process ID is the same concept as POSIX's, spelled `DWORD` rather than `pid_t`, so it shares `ProcessID`, as
  `Next/Vision.md` allows. `ProcessID.parent` isn't there: Win32 has no call for it (it takes
  `NtQueryInformationProcess` or a Toolhelp snapshot), and Windows doesn't reparent, so the ID can already name
  another process. The rest of `ProcessID`'s POSIX API (waiting, signals, process groups) has no Windows concept;
  exiting does, and is a candidate below.

Design calls, with the alternatives rejected:
- **`current` is a computed property** that returns an owner of the pseudo handle. Closing that handle does
  nothing, so the owner is harmless. Rejected: a `static let`, as `OwnedFD`'s standard streams are, which would
  forbid closing it but needs a lazy global and can't be `@_alwaysEmitIntoClient`; and duplicating a real handle
  on each access.
- **`init?(unsafelyAdopting:)` rejects only `NULL`**, the failure value of `OpenProcess`. `(HANDLE)-1` is the
  pseudo handle, so rejecting it, as `FileHandle` does, would refuse `GetCurrentProcess()`.
- **`exitCode()` waits with a zero time-out first**, so it needs `.synchronize` and `.queryLimitedInformation`,
  as Rust's `try_wait` does. Rejected: `GetExitCodeProcess` alone, which reports `STILL_ACTIVE` (259) for a
  running process, so a process that exits with 259 would look alive; and waiting only when the code is 259,
  which makes the rights a call needs depend on the process's exit code.
- **`access` has no default.** An open fails if any requested right is denied, and each adopter asks for what it
  uses (`PROCESS_TERMINATE`, `SYNCHRONIZE`, `PROCESS_QUERY_INFORMATION`, `PROCESS_SET_INFORMATION`). The
  PlatformEnum stand-in's default, `[.synchronize, .queryLimitedInformation, .terminate]`, fails for a process the
  caller may watch but not end.
- **`processID()` is a throwing method**, since `GetProcessId` needs a query right. Rejected: storing the ID in
  the owner, which doubles it and can't be done for an adopted handle without a query right.
- **Two waits**, `waitForExit()` and `waitForExit(timeout:) -> Bool`, rather than an optional time-out whose
  result is always `true` without one. A time-out of zero or less polls.
- **Exit codes are `DWORD`.** Open: a `Win32.ExitCode` with names for the NTSTATUS codes a crash reports
  (`0xC0000005`, `0xC000013A`), or sharing POSIX's `ProcessID.ExitCode`, a `CInt` with `<sysexits.h>`'s codes.
- **No handle protocol.** SYS-0011 rejected a `Win32.Handle` protocol until a third handle type appeared; this is
  the third, and it repeats `duplicate`, `isInheritable` and `setInheritable` a third time. Left open: a `~Copyable`
  protocol for those, `close`, and `unsafeRawHandle`, with waiting as its next member.
- **Not wrapped**, though an adopter uses each: `SetPriorityClass` (sourcekit-lsp), `K32GetProcessMemoryInfo`
  (swift-docc), `IsProcessInJob` and `GetProcessHandleCount` (swift-subprocess), `RegisterWaitForSingleObject`
  (swift-build, swift-subprocess), and exiting the calling process with a `Never` result: `current.terminate`
  covers the adopters' `TerminateProcess(GetCurrentProcess(), code)` but returns `Void`. A Windows
  `ProcessID.exit(_:)` and `exitImmediately(_:)`, over the UCRT's `exit` and `TerminateProcess`, are the
  candidates.

Tests: `Win32ProcessTests`, XCTest, Windows-only. Children are started with raw `CreateProcessW`
(`win32RawSpawn` in `Win32TestSupport.swift`), so the tests don't depend on System's process creation: `cmd.exe
/c exit N` for exit codes, and `ping.exe -n 60 127.0.0.1` for a child that runs until it's ended. The millisecond
rounding also ran on macOS, copied into a scratch program.

A Windows run must check:
- `testConstantsMatchTheSDK` (`PROCESS_ALL_ACCESS` is spelled from its parts, in case the compound macro doesn't
  import) and `testInternalConstantsMatchTheSDK`.
- `testCurrentProcessID`; `testCurrentProcessHandle`: the pseudo handle's ID, no exit code, a 1 ms wait that times
  out, and a close that does nothing; `testDuplicatingTheCurrentProcess`: a real handle, and a
  `.synchronize`-only duplicate that can't read the ID.
- `testOpeningByID`; `testOpenFailures`: IDs 0 and `0xFFFFFFFC` give `invalidParameter`.
- `testExitCodeOfAChild`: 42, and the exited process's ID still opens it while a handle is open;
  `testExitCodeKeepsAll32Bits`: `cmd /c exit -1073741510` gives `0xC000013A`.
- `testTerminate`: before, the wait times out and there's no exit code; after, 99 from both handles, and a second
  `terminate` gives `accessDenied`, as documented. `testAccessRightsAreChecked`: which operations each right
  allows, and that the exit code needs both rights. `testNonpositiveTimeoutsCheckWithoutWaiting`,
  `testInheritance`, `testAdoption`.
- Not covered: ending the calling process, waits beyond 49.7 days, and a process of another user, where
  `queryLimitedInformation` is granted and `queryInformation` isn't.

## 13. Creating processes, and thread handles: `e84b953`

What:
- `Win32ProcessCreation.swift`: `Win32.ProcessCreationFlags` (`suspended`, `detached`, `newConsole`,
  `newProcessGroup`, `breakawayFromJob`, `defaultErrorMode`, `noWindow`), `Win32.CreatedProcess` (`process`,
  `thread`, `processID`, `threadID`), and `Win32.ProcessHandle.create(commandLine:application:environment:
  currentDirectory:standardInput:standardOutput:standardError:flags:)`, over `CreateProcessW` with a
  `STARTUPINFOEXW` and `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`.
- `Win32Thread.swift`, since a created process's first thread is its handle to resume: `Win32.ThreadID` (with
  `current`, `GetCurrentThreadId`), `Win32.ThreadAccess`, and `Win32.ThreadHandle`, an owner like
  `ProcessHandle`, with `current(access:inheritable:)` (a real handle, `DuplicateHandle` of `GetCurrentThread`'s),
  `open(_:access:inheritable:)` (`OpenThread`), `threadID()` (`GetThreadId`), `waitForExit()`,
  `waitForExit(timeout:)`, `exitCode()` (`GetExitCodeThread` after a zero wait), `resume()` and `suspend()`
  (`ResumeThread`, `SuspendThread`), and the duplicate and inheritance members.

Design calls, with the alternatives rejected:
- **A child inherits its standard handles and nothing else.** Given any standard handle, System passes
  `bInheritHandles` with a `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` of inheritable duplicates of the three, and closes
  the duplicates after the call; given none, it passes no inheritance. That's `POSIX_SPAWN_CLOEXEC_DEFAULT`'s
  behavior, and swift-subprocess's. Rejected: inheriting every inheritable handle, which is `bInheritHandles`
  alone and Rust's default (Rust takes a process-wide lock around it); and marking the caller's own handles
  inheritable, as swift-subprocess does, which changes them and races with other threads creating processes.
  The duplicates are inheritable during the call, so another thread's `CreateProcessW` that inherits without a
  list can receive them; that's inherent.
- **`nil` means the caller's own handle**, duplicated the same way, as Rust's `Stdio::inherit` does. If the caller
  has none of the three and passes none, `STARTF_USESTDHANDLES` stays off and Windows' default applies. Rejected:
  `nil` as no handle, which leaves a child given only an output without input or error; and setting the handles
  only when all three are given.
- **Standard handles are `borrowing Win32.FileHandle?`**, as `open`'s `templateFile` is, so callers pass them
  through optional bindings, as the doc comment shows; `Ref` (SE-0519) would remove that, as SYS-0011 says.
  Rejected: an overload for each combination, eight of them.
- **The command line is one string, unquoted**, as `CreateProcessW` takes it and the program receives it. Open: a
  helper that quotes arguments by the C runtime's rules, which swift-tools-support-core (`quote`),
  swift-subprocess (`quoteWindowsCommandLine`) and Foundation's `Process` each implement; a batch file needs
  cmd.exe's rules instead.
- **The environment is `[String]` of `NAME=value`**, as POSIX's `spawn` takes it, sorted by name ignoring case
  with `CompareStringOrdinal`, as Windows' documentation requires of an environment block and Rust does, with
  ties kept in order. A name ends at the first `=` after its first character, for the per-drive `=C:` variables.
  An empty string or a null character is `invalidParameter`, since either would end the block early. Rejected: a
  dictionary, which can't keep duplicate names or their order; and passing the strings unsorted.
- **`application` and `currentDirectory`** go through the namespace's path canonicalization, as `open`'s paths do:
  resolved against the current directory, and `\\?\`-prefixed past `MAX_PATH`, as swift-subprocess passes its
  application.
- **`ThreadHandle.current(access:inheritable:)` returns a real handle**, unlike `ProcessHandle.current`:
  `GetCurrentThread`'s pseudo handle means whichever thread uses it, and the owner is `Sendable`, so sending one
  would change the thread it names. For the same reason, `init?(unsafelyAdopting:)` rejects `NULL` and
  `INVALID_HANDLE_VALUE` (the process's pseudo handle), and its doc warns against the thread's.
- **No thread `terminate()`**: `TerminateThread` leaves its process inconsistent (locks held, a stack not freed),
  and no adopter calls it. `suspend()` is there, with a warning, for its counts' sake.
- **Not wrapped here**: the window members of `STARTUPINFOW` (swift-subprocess sets `wShowWindow`), security
  attributes for the returned handles, `CreateProcessWithLogonW`, and creating threads, which the threads gap
  covers. Jobs are their own gap.

Tests: `Win32ThreadTests` (suspended children from raw `CreateProcessW`) and `Win32ProcessCreationTests`. The
environment block's sorting also ran on macOS, copied into a scratch program with an ASCII stand-in for
`CompareStringOrdinal`.

A Windows run must check:
- `Win32ThreadTests`: the constants; `testCurrentThreadHandle` (a real handle with the current ID and no exit
  code, and a `.synchronize`-only one that's inheritable); `testOpeningByID`; `testSuspendAndResume` (the count
  starts at 1, `suspend` returns 1, the resumes 2 and 1, and the first thread's exit code is the process's);
  `testAdoptionRejectsSentinels`.
- `Win32ProcessCreationTests`: the constants, with `STD_*_HANDLE` through `truncatingIfNeeded`;
  `testExitCodeAndIDs`; `testSuspended`; `testStandardOutput` (a line through a pipe, and the caller's end still
  writable); `testStandardInputAndError` (sort.exe between two pipes, and `(echo oops) 1>&2`);
  `testOnlyStandardHandlesAreInherited`, the only check of `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`'s value, `0x20002`,
  whose macro doesn't import; `testUnspecifiedHandlesAreTheCallers` (`SetStdHandle` to a pipe, only input given);
  `testEnvironment` (cmd.exe expands a variable from the block); `testEnvironmentBlock`; `testCurrentDirectory`;
  `testApplication` (a full path runs; `cmd` isn't searched for: `fileNotFound`); `testFailures`.
- Not covered: consoles (`newConsole`, `detached`), breaking away from a job, a command line at the limit of
  32,767 characters, and callers whose standard handles are console handles.

## 14. Clocks and sleeping: `91b6894`

The second gap of section 8. Most of its files call `Sleep`, many of them tests; next come the system time
(`GetSystemTimePreciseAsFileTime`, `GetSystemTimeAsFileTime`) and `GetTickCount64`, then one file each for the
performance counter and the unbiased interrupt time. Time zones and the C runtime's broken-down time are in two
packages' files.

What: `Win32Time.swift`.
- `Win32.FileTime`, a count of 100-nanosecond intervals since 1601 (`rawValue: Int64`), `Comparable`, with
  `init(_:)` from a `FILETIME` and `fileTime` back, `durationSinceUnixEpoch` and `init?(durationSinceUnixEpoch:)`,
  and `now` (`GetSystemTimePreciseAsFileTime`) and `coarseNow` (`GetSystemTimeAsFileTime`).
- `Win32.tickCount()` (`GetTickCount64`), `interruptTime()` (`QueryInterruptTimePrecise`) and
  `unbiasedInterruptTime()` (`QueryUnbiasedInterruptTimePrecise`), each a `Duration` since the system started;
  `performanceCounter()` and `performanceFrequency()` (`QueryPerformanceCounter`, `QueryPerformanceFrequency`),
  as `Int64` ticks.
- `Win32.sleep(for:)` (`Sleep`), `noasync` like POSIX's `PThread.sleep(for:retryOnInterrupt:)`.

Which API: **Win32.**
- POSIX's `ClockID` wraps `clockid_t`, and its sleep is hosted on `PThread`. Windows has neither: its clocks are
  separate functions with their own epochs and units. A Windows `ClockID` would fake a POSIX type over the one
  clock the UCRT has (`timespec_get` with `TIME_UTC`), which `Next/Vision.md` rules out.
- Swift's `ContinuousClock` and `SuspendingClock` already measure elapsed time on Windows, and `Task.sleep`
  sleeps without blocking; these are for code that needs a particular Windows clock, or blocks on purpose, as
  the adopters' tests do.
- **Broken-down time is the cross-platform candidate**, not done here: the UCRT's `_gmtime64_s`,
  `_localtime64_s`, `_mkgmtime64` and `strftime` are POSIX-shaped, so `BrokenDownTime` could have a Windows
  implementation. Its `tm` has no `tm_gmtoff` or `tm_zone`, which `utcOffset` and `timeZoneAbbreviation` read, so
  those would come from `_get_timezone`, `_get_dstbias` and `_get_tzname`; and two packages use it.

Design calls, with the alternatives rejected:
- **`FileTime` is a signed count**, as `FILE_BASIC_INFO` stores times (`LARGE_INTEGER`), so the file information
  gap can share it. Rejected: `rawValue: FILETIME`, the C struct, as System's request types wrap theirs, since a
  time needs `Hashable` and `Comparable`; and `UInt64`, which no Windows time needs.
- **`durationSinceUnixEpoch` is the bridge**, the duration POSIX's `ClockID.realtime.currentTime()` returns. The
  way back rounds down to 100 nanoseconds, so a time maps to the interval that holds it, and returns `nil`
  outside about 29,000 years either side of 1601, rather than trapping.
- **`now` and `coarseNow` are properties**, like `Date.now`. Rejected: `Win32.systemTime()` functions, and a
  `now(precise:)`.
- **A sleep of zero or less calls `Sleep(0)`**, which yields, as NIO's spin loop uses it; POSIX's
  `PThread.sleep` returns at once for those. A positive duration rounds up to a millisecond. Windows can end a
  sleep shorter than the timer's period early, which the doc says. Rejected: a high-resolution waitable timer,
  which Rust's `thread::sleep` uses where Windows has one: a policy over `Sleep`, not its wrapper.
- **Not wrapped**: `SleepEx` (alertable sleeps), `SwitchToThread`, the coarse `QueryInterruptTime` and
  `QueryUnbiasedInterruptTime`, `timeBeginPeriod`, and `GetTimeZoneInformation`.

Tests: `Win32TimeTests`, with lower bounds only on elapsed times. The `FileTime` conversions and the interval
durations also ran on macOS, copied into a scratch program, including round trips at `Int64.min` and `Int64.max`.

A Windows run must check:
- `testFileTimeHalves`, `testUnixEpochConversions`, `testIntervalsAsDurations`.
- `testSystemTime`: after 2026; precise and coarse within a second; the C runtime's `_time64` within two seconds.
- `testMonotonicClocks`: each clock advances at least 20 ms across a sleep of 50 ms, the frequency is positive,
  and the unbiased interrupt time doesn't exceed the biased one. That the two precise interrupt-time functions
  link through the WinSDK module, as swift-foundation's call to the unbiased one does.
- `testSleepYieldsForNonpositiveDurations`.

## 15. SRW locks and condition variables: `a3eb00c`

The third gap of section 8. Every file in it takes an exclusive SRW lock (`InitializeSRWLock`,
`AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`), as each package's own lock type; a third of them wait on a
condition variable (`SleepConditionVariableSRW`, `WakeConditionVariable`); one takes the lock shared, one tries it,
and one uses a critical section.

What: `Win32Synchronization.swift`.
- `Win32.SRWLock`: `init()` (`InitializeSRWLock`); `lock()`, `tryLock()`, `unlock()` and `withLock(_:)` exclusively
  (`AcquireSRWLockExclusive`, `TryAcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`); `lockShared()`,
  `tryLockShared()`, `unlockShared()` and `withSharedLock(_:)` (the `Shared` functions); `unsafeAddress`.
- `Win32.ConditionVariable`: `init()` (`InitializeConditionVariable`); `wait(on:shared:)` and
  `wait(on:shared:timeout:) -> Bool` (`SleepConditionVariableSRW`, with `CONDITION_VARIABLE_LOCKMODE_SHARED` for
  `shared`); `wake()` and `wakeAll()` (`WakeConditionVariable`, `WakeAllConditionVariable`); `unsafeAddress`.

Which API: **Win32**, as the Windows side of `PThread.Mutex`, `PThread.ReadWriteLock` and `PThread.Condition`,
which wrap pthreads, a library Windows doesn't have. `Synchronization.Mutex` already covers a plain lock on
Windows (it's an SRW lock there), so these are for condition variables, shared holds, and C interop.

Design calls, with the alternatives rejected:
- **Heap storage**, as `PThread.Mutex` has: the C lock stays at one address while the owner moves, since Windows
  doesn't let a lock or condition variable in use move. Neither needs destroying, so `deinit` only frees. Rejected:
  inline storage with `@_rawLayout`, as `Synchronization.Mutex` has, which needs an experimental feature the package
  doesn't enable.
- **Nothing throws but the waits.** The lock functions and the wakes can't fail, so they return `Void` or `Bool`;
  `withLock(_:)` and `withSharedLock(_:)` are generic over the body's error, `throws(E)`, where
  `PThread.Mutex.withLock` throws untyped because locking can fail. The waits throw `Win32.Error` for a failure
  other than the time-out, which Windows documents as possible.
- **Exclusive and shared are separate methods**, as Win32 names them, rather than a mode parameter reusing
  `Win32.LockMode`, whose documentation is about byte-range locks. The condition variable's `shared: Bool` mirrors
  the C flag.
- **Windows names**: `wake()` and `wakeAll()`, not POSIX's `signal()` and `broadcast()`; and `lockShared()`, not
  `PThread.ReadWriteLock`'s `lockForReading()`.
- **Relative time-outs**, as Windows takes them; POSIX's `wait(on:until:)` takes a deadline. A time-out longer
  than `INFINITE - 1` milliseconds ends then and returns `true`, as a spurious wake-up, which the caller must
  handle anyway.
- `lock()`, `tryLock()` and `unlock()` and their shared forms are `noasync`, as `PThread.Mutex`'s are.
- **Not wrapped**: `CRITICAL_SECTION` and `SleepConditionVariableCS` (one file, swift-subprocess); and adopting a
  C-owned lock, as `PThread.Mutex.withUnsafeMutex(_:_:)` does.

Tests: `Win32SynchronizationTests`, with other threads from Dispatch, as `FileLockTests` has them. The time-out
tests retry until a wait times out, since a spurious wake-up returns `true`.

A Windows run must check: `testInternalConstantsMatchTheSDK`; `testExclusiveLock` (another thread can't take it
either way while it's held); `testSharedLock` (two shared holders; no exclusive one meanwhile);
`testWithLockRethrowsAndReleases`; `testConditionVariableWakesAWaiter`; `testWaitTimesOut` and `testSharedWait`
(the lock is held again, the same way, after a time-out); `testWakeAll` (three waiters).

## 16. Consoles and standard handles: `649fcd9`

The fourth gap of section 8. Its files read a standard handle (`GetStdHandle`), ask whether a stream is a
terminal (`isatty`), measure the console window (`GetConsoleScreenBufferInfo`), change console modes
(`GetConsoleMode`, `SetConsoleMode`: virtual terminal output, and line input without echo for a password), and
handle or ignore Ctrl+C (`SetConsoleCtrlHandler`). One file each attaches to another process's console, frees its
own, or reads the console directly.

What: `Win32Console.swift`.
- `Win32.StandardHandle` (`input`, `output`, `error`) and `Win32.FileHandle.withStandardHandle(_:_:)`, which lends
  the process's current standard handle (`GetStdHandle`).
- `Win32.ConsoleMode`, the input and output flags, and on `Win32.FileHandle`: `isConsole`, `consoleMode()`,
  `setConsoleMode(_:)`, and `withConsoleMode(_:_:)`, with a typed and an untyped overload as SYS-0014's `withLock`
  has (`GetConsoleMode`, `SetConsoleMode`).
- `Win32.ConsoleScreenBufferInfo`, over `CONSOLE_SCREEN_BUFFER_INFO`: the buffer's size, the cursor, the window's
  position and size, the maximum window size and the attributes; and
  `Win32.FileHandle.consoleScreenBufferInfo()` (`GetConsoleScreenBufferInfo`).
- `Win32.ConsoleControlEvent`, and `Win32.addConsoleControlHandler(_:)`, `removeConsoleControlHandler(_:)` and
  `setIgnoresConsoleInterrupt(_:)` (`SetConsoleCtrlHandler`).
- `FileDescriptor.isTerminal` on Windows: whether the descriptor's handle is a console's.

Which API: **Win32, and `isTerminal` shared.**
- A console is a Windows concept, with modes and a screen buffer rather than POSIX's termios and window size, so
  its API is Win32, on `FileHandle`, where SYS-0011 and SYS-0012's future directions put it.
- Whether a stream is a terminal is the same question on every platform, and swift-docc already spells it
  `FileDescriptor.standardError.isTerminal` on Darwin, so Windows gets the same property. Rejected: the UCRT's
  `_isatty`, the POSIX-shaped call, which reports every character device, `NUL` and serial ports included; the
  test shows it calling `NUL` a terminal. `GetConsoleMode` is what Rust's `IsTerminal` checks first.
  `FileDescriptor.asTerminal` and `TerminalDescriptor` stay POSIX-only, since they're termios.

Design calls, with the alternatives rejected:
- **Standard handles are lent, not owned**, like `withWin32HandleIfAvailable`'s: the process keeps them, so an
  owner would close a handle the process still uses. Each call reads `GetStdHandle`, so it sees `SetStdHandle`'s
  changes; it skips a missing handle and an overlapped one, as the bridge does. Rejected: immortal static owners,
  as the PlatformEnum stand-in has (`static let standardInput: Win32.FileHandle?`), which read the handle once.
  Not wrapped: `SetStdHandle`, whose ownership is unclear (the C runtime's descriptor 1 can hold the same handle).
- **One `ConsoleMode` for both kinds of handle**, with each input flag documented as the same bit as an output
  flag, as `AccessMask` documents its file and directory pairs. Rejected: two option sets and two pairs of
  methods, when the handle, not the type, decides what a bit means.
- **`withConsoleMode` restores the previous mode**, as `TerminalDescriptor.withRawMode` does on POSIX; the mode
  belongs to the console, so it would otherwise outlive the process.
- **The control handler is a `PHANDLER_ROUTINE`**, the C type, as `ProcessID.addExitHandler` takes a C function:
  Windows calls it on a thread of its own, and it can't capture context. Its event arrives as a `DWORD`, since a
  C function can't take a Swift struct.
- **Not wrapped**: `AttachConsole`, `FreeConsole`, `AllocConsole`, `GetConsoleWindow`, `GenerateConsoleCtrlEvent`,
  and `ReadConsoleW` and `WriteConsoleW`, one file each.

Tests: `Win32ConsoleTests`. The console tests open `CONOUT$` and `CONIN$`, and skip without a console.

A Windows run must check:
- `testConstantsMatchTheSDK`.
- `testLendingAStandardHandle`: `SetStdHandle` to a pipe, a write through the lent handle arrives, and a missing
  handle skips the body. This also checks that `_isSynchronous` accepts an anonymous pipe as a standard handle.
- `testOtherCharacterDevicesAreNotConsoles`: `NUL`, a pipe and a file aren't consoles; a file's `consoleMode()`
  throws `invalidHandle`; `isTerminal` is false for `NUL`, where `_isatty` is nonzero.
- `testConsoleOutput` and `testConsoleInput`, where there's a console: the modes are set and restored, after a
  throw too, and the screen buffer's sizes are consistent. Whether a console handle passes `_isSynchronous`, which
  `withStandardHandle` needs, is untested: lend a console's standard output to check it.
- `testControlHandlers`.

## 17. Well-known directories: `b63bce9`

The fifth gap of section 8. Its files ask for the Windows directory (`GetWindowsDirectoryW`), mostly to reach
`System32\where.exe`, the executable's path (`GetModuleFileNameW` with no module), the system directory, the
temporary directory (`GetTempPathW`, `GetTempPath2W`), and the current directory (`GetCurrentDirectoryW`,
`SetCurrentDirectoryW`, `getcwd`).

What: `PathsWindows.swift`.
- `FilePath.currentWorkingDirectory()`, and `setCurrentWorkingDirectory(_:retryOnInterrupt:)` for a `FilePath`
  and for a C string of `CInterop.PlatformChar`, over the UCRT's `_wgetcwd` and `_wchdir`.
- `FilePath.temporaryDirectory()`, over `GetTempPath2W` where kernel32 exports it, else `GetTempPathW`.
- `FilePath.currentExecutable()`, over `GetModuleFileNameW(NULL)`.
- `Win32.windowsDirectory()` and `Win32.systemDirectory()` (`GetWindowsDirectoryW`, `GetSystemDirectoryW`).

Which API: **System's cross-platform names for the first four, Win32 for the last two.**
- The current directory, the temporary directory and the executable's path are the same concepts everywhere, and
  System names them on POSIX (`FilePathOperations.swift`, `UniqueFiles.swift`, and `CurrentExecutable.swift` on
  Darwin), so Windows gets the same names and signatures: `throws(Errno)` for the working directory, and no
  `throws` for the other two, as on POSIX. The working directory uses the UCRT's POSIX-shaped calls, which report
  `errno` as the signature does, and which also record the drive's current directory in the `=C:` variable that
  drive-relative paths resolve against; `SetCurrentDirectoryW` alone doesn't.
- `FilePath.setCurrentWorkingDirectory(_:)` for a `FileDescriptor` (`fchdir`) isn't there: Windows can't set the
  current directory from a handle, and resolving the handle's path first would fake it.
- The Windows and system directories are Windows concepts, so they're Win32 API.

Design calls, with the alternatives rejected:
- **The non-throwing pair keeps the POSIX signature** and documents its fallbacks: `temporaryDirectory()` falls back
  to the Windows directory, then `.`, and `currentExecutable()` to an empty path, where Windows documents no
  failure. Rejected: throwing on Windows only, which cross-platform callers would have to `try` with a warning
  elsewhere.
- **`GetTempPath2W` is looked up at run time**, as `NtQueryInformationFile` is: linking it would stop System from
  loading on Windows 10. It gives a process running as SYSTEM `SystemTemp`, which other accounts can't reach;
  otherwise it's `GetTempPathW`'s answer.
- **`retryOnInterrupt` stays**, as on the other platforms' signatures and the `FileDescriptor` operations on
  Windows; Windows doesn't interrupt the call.
- **The paths come back as Windows gives them**: a short (8.3) name or a `\\?\` prefix the process was created
  with stays.
- The two Win32 calls share an internal helper for Win32's "the size you need" convention, with `finalPath`'s.

Tests: `Win32PathsTests`, which changes the process's working directory and restores it, and a mock test of the
`_wchdir` call.

A Windows run must check:
- `testCurrentWorkingDirectory`: the directory matches `GetCurrentDirectoryW`, before and after a change; a
  relative path resolves in the new directory; the C-string overload restores it.
- `testSettingAMissingWorkingDirectoryFails`: `ENOENT`, and the directory is unchanged.
- `testSettingTheWorkingDirectoryCallsTheCRuntime` (mock).
- `testTemporaryDirectory`: an existing directory, `GetTempPathW`'s unless the process runs as SYSTEM.
  `GetTempPathW` returns a trailing backslash, which `FilePath` drops; the comparison relies on both sides
  dropping it alike.
- `testCurrentExecutable`: matches `GetModuleFileNameW`, and is a file.
- `testWindowsAndSystemDirectories`: the Windows directory is `SystemRoot`, and the system directory is its
  `System32`, ignoring case.

## 18. Dynamic loading: `257fb78`

The sixth gap of section 8. Its files load a library by path (`LoadLibraryW`), look up a function
(`GetProcAddress`), free the library (`FreeLibrary`), or find one that's loaded already (`GetModuleHandleW`), such as
their own module, kernel32 or ntdll.

What: `DynamicLibraryWindows.swift`: `DynamicLibrary` on Windows, owning an `HMODULE` reference, with
`init(taking:)`, `init(_:options:)` for a `FilePath` and a C string of `CInterop.PlatformChar`
(`LoadLibraryExW`), `init(alreadyLoaded:)` and `mainProgram()` (`GetModuleHandleExW`), `address(of:)` for a
`String` and a C string (`GetProcAddress`), `handle`, `close()` (`FreeLibrary`), `relinquish()`, and a deinit that
frees; and `DynamicLibrary.LoadOptions`, `LoadLibraryExW`'s search flags. `Win32.Error` gains the two codes these
document, `moduleNotFound` (126) and `procedureNotFound` (127).

Which API: **System's `DynamicLibrary`, with Windows' errors and options.** A loaded library and its symbols are
the same concept as `dlopen`'s, so Windows shares the type and the shape of its API, and code that loads a
library and looks up a symbol spells it the same everywhere. What differs is Windows': the options are
`LoadLibraryExW`'s, and errors are `Win32.Error`.

Design calls, with the alternatives rejected:
- **Errors are `Win32.Error`**, where POSIX throws `DynamicLibrary.LoaderError`, `dlerror`'s message. Rejected: a
  Windows `LoaderError` holding the code and its message, which would keep the signatures identical but add a
  second error type for Win32 failures, which SYS-0010 argues against. Code that catches with a type needs an
  `#if`; most callers print the error. There's no `takePendingError()`: Windows' last error isn't a pending error
  to take, and SYS-0010 rejects a public last error.
- **`init(alreadyLoaded:)` takes a reference**, with `GetModuleHandleExW`, where the adopters call
  `GetModuleHandleW`, which takes none: the owner frees what it holds, and an unreferenced handle can be unloaded
  under it, the owned-only hazard again. POSIX spells the same request `OpenOptions.noLoad`; Windows has no such
  load flag, so it's an initializer rather than a faked option.
- **`mainProgram()` searches the executable's own exports**, which is what `GetProcAddress` does with its module;
  the doc says that it doesn't search the loaded libraries, as `dlopen(NULL)`'s handle does.
- **The default options are none**, `LoadLibraryW`'s search, which includes the current directory and `PATH`. The
  doc names the `search` options as the way to leave those out. Rejected: defaulting to
  `searchDefaultDirectories`, which would break the adopters' libraries that are found through `PATH`.
- **The shape follows POSIX's `DynamicLibrary`**, without the drafts' `@unsafe` annotations, since it's the same
  type's Windows side: `init(taking:)`, `handle` and `relinquish()`, as there.
- **Not wrapped**: `AddDllDirectory`, `SetDefaultDllDirectories`, lookup by ordinal, and data-file loads
  (`LOAD_LIBRARY_AS_DATAFILE`, whose module has no symbols to look up).

Tests: `Win32DynamicLibraryTests`, against kernel32 and ntdll, which every process has loaded.

A Windows run must check: `testConstantsMatchTheSDK`, and the two new codes in `testCodesMatchTheSDK`;
`testLoadingAndLookingUp` (a function looked up and called, a missing symbol `nil`);
`testLoadOptionsAndTheCStringOverload`; `testMissingLibraries` (`moduleNotFound` both ways); `testAlreadyLoaded`;
`testMainProgram` (the handle is `GetModuleHandleW(NULL)`'s); `testTakingAndRelinquishing`.

## 19. Environment variables: `0ed04ff`

The seventh gap of section 8. Its files read a variable (`GetEnvironmentVariableW`), set or remove one
(`SetEnvironmentVariableW`, and the C runtime's `_putenv`, `_putenv_s` and `_wputenv_s`), and copy the whole
environment (`GetEnvironmentStringsW`, `FreeEnvironmentStringsW`). SwiftPM's `Environment.set` already calls
`ProcessEnvironment` on POSIX, and on Windows calls `SetEnvironmentVariableW` and then `_putenv` to keep the C
runtime's copy in step.

What: `ProcessEnvironmentWindows.swift`: `ProcessEnvironment` on Windows, with `value(of:)`
(`GetEnvironmentVariableW`), `set(_:to:overwrite:)` and `remove(_:)` (`_wputenv_s`, then
`SetEnvironmentVariableW`), `entries()` (`GetEnvironmentStringsW`), and `withUnsafeEntries(_:)`, which lends the
block that `CreateProcessW` takes.

Which API: **System's `ProcessEnvironment`.** Environment variables are the same concept everywhere, and the
namespace's signatures carry over unchanged but one: `withUnsafeEntries` lends a Windows environment block, the
form `CreateProcessW` takes, where POSIX lends `environ`, the form `execve` takes.

Design calls, with the alternatives rejected:
- **Reads use the system's copy; writes change both copies**, as SwiftPM does by hand. The system's copy is what
  new processes inherit and what every writer, Win32 or C runtime, updates; the C runtime's copy is what C
  libraries' `getenv` reads, and only C runtime writes reach it. Rejected: the Win32 calls alone, as Rust's
  `std::env` does, which leaves `getenv` in the same process reading old values; and the C runtime alone, which
  can't hold an empty value and misses `SetEnvironmentVariableW`'s changes on reads.
- **An empty value is empty in the system's copy and absent from the C runtime's**, which can't hold one:
  `_wputenv_s` with an empty value removes the variable, so `set` calls it first and `SetEnvironmentVariableW`
  second. POSIX's `setenv` stores an empty value.
- **`overwrite: false` checks, then sets**, since Windows has no conditional set; another thread can set the
  variable in between. The doc says so.
- **Errors stay `Errno`**, the signature's type: the C runtime's errors are `errno` values already, and a Win32
  failure goes through the mapping the `FileDescriptor` adapters use.
- **`entries()` includes the variables whose names begin with `=`**, such as `=C:`, as `GetEnvironmentStringsW`
  returns them; a name ends at the first `=` after its first character, as the creation block's sort reads it.
- **Name rules as on POSIX**: not empty, no `=`, no null character.
- `_wputenv_s` has a mock hook, as the C runtime calls do; no mock test, since `set` also calls the unmocked
  `SetEnvironmentVariableW`.
- **Not wrapped**: `ExpandEnvironmentStringsW`, and `ProcessEnvironment.secureValue(of:)`, which is POSIX's
  set-user-ID rule.

Tests: `Win32EnvironmentTests`, each with variables of its own.

A Windows run must check: `testSetReadAndRemove` (case-insensitive names, both copies changed, `overwrite: false`,
removing a missing variable); `testEmptyValues` (empty in the system's copy and in `entries()`, absent from the C
runtime's, which relies on `_wputenv_s` removing a variable it's given an empty value for);
`testLongValues` (past the first buffer); `testInvalidNamesAndValues`; `testEntriesAndTheBlock`;
`testChildrenInherit` (a child created afterward sees the variable).

## 20. File information: this commit

The eighth gap of section 8, and the first two stages SYS-0010's roadmap leaves to future proposals. Its files test
attributes (`FILE_ATTRIBUTE_DIRECTORY`, `FILE_ATTRIBUTE_REPARSE_POINT`, `FILE_ATTRIBUTE_READONLY`), read
`BY_HANDLE_FILE_INFORMATION` (`GetFileInformationByHandle`) and `WIN32_FILE_ATTRIBUTE_DATA`
(`GetFileAttributesExW`), get and set attributes by path, set times (`SetFileTime`), and, in swift-foundation, read
`FileIdInfo`, `FileBasicInfo` and `FileAttributeTagInfo`.

What: `Win32FileInformation.swift`.
- `Win32.FileAttributes` gains the attributes that describe an existing file (`directory`, `reparsePoint`,
  `sparseFile`, `compressed`, and eight more); its doc says which ones creation applies.
- `Win32.FileInformation` (`BY_HANDLE_FILE_INFORMATION`): attributes, the three times as `Win32.FileTime`,
  volume serial number, size, link count, and file index. `Win32.FileBasicInformation` (`FILE_BASIC_INFO`),
  `Win32.FileStandardInformation` (`FILE_STANDARD_INFO`), `Win32.FileID` (`FILE_ID_INFO`, the 128-bit ID as a
  `UInt128`), `Win32.ReparseTag` (symbolic link, mount point, app execution alias, Unix domain socket, and the
  Microsoft and name-surrogate bits), and `Win32.FileAttributeTagInformation`.
- On both handle types: `information()`, `basicInformation()`, `fileID()`, `attributeTagInformation()`,
  `setTimes(creation:lastAccess:lastWrite:change:)` and `setAttributes(_:)`; on `FileHandle`,
  `standardInformation()` too.
- By path: `Win32.fileAttributes(of:)`, `Win32.fileAttributeData(of:)` and `Win32.setFileAttributes(_:of:)`
  (`GetFileAttributesW`, `GetFileAttributesExW`, `SetFileAttributesW`), with `open`'s path canonicalization.

Which API: **Win32.** SYS-0006 keeps `Stat` POSIX-only and calls for Windows types instead, and SYS-0010's roadmap
puts them in the namespace. A cross-platform `FileInfo` over both stays SYS-0006's future direction.

Design calls, with the alternatives rejected:
- **Information types wrap their C structs** with read-only properties, as `ConsoleScreenBufferInfo` and System's
  other C-struct wrappers do; `FileID` is a plain value instead, since an identity needs `Hashable`.
- **Times are `Win32.FileTime`**, section 14's type, from both `FILETIME` and `FILE_BASIC_INFO`'s
  `LARGE_INTEGER`s.
- **Setting goes through `FILE_BASIC_INFO`** with optional times, nil for "leave it", as POSIX's `setTimes` takes
  `nil` for `UTIME_OMIT`; `SetFileTime` would need a separate path for the change time. A zero time means "leave
  it" there, so the start of 1601 can't be set, which the doc says. Empty attributes become
  `FILE_ATTRIBUTE_NORMAL`, since zero means "leave them".
- **The path queries are namespace functions** taking a `FilePath`, as the drafts' API takes paths; they don't
  open the file, and report a reparse point's own attributes.
- **Not done**: the other information classes (names, streams, compression, alignment, remote protocol,
  directory enumeration), and setting the delete and rename dispositions with POSIX semantics
  (`FileDispositionInfoEx`, `FileRenameInfoEx`), which belong with the path operations gap.

Tests: `Win32FileInformationTests`.

A Windows run must check: `testConstantsMatchTheSDK` (the attributes and the four reparse tags);
`testFileInformation` (size, links, times, the three information classes agreeing, the same `FileID` for two
opens and a different one for another file); `testDirectoryInformation`; `testSettingTimesAndAttributes` (a
time set and the others left, attributes set and cleared); `testQueriesByPath` (`fileNotFound` and
`pathNotFound`); `testFileIDBytes` (the little-endian reading). `fileID()` on FAT, which throws, isn't covered.

## 21. windows-2: findings

- **The PlatformEnum samples' Windows arms now reach System's `Win32.ProcessHandle`** (the stand-ins compile only
  with `SIMULATE_PLATFORMS`), and differ from it: `Platform.Process` reads `processID` as a property, where
  System's is `processID()`, a throwing method, and its wait opens a process with `.synchronize` alone and then
  reads the exit code, which System's `exitCode()` refuses with `accessDenied`, as `GetExitCodeProcess` would.
  Those files are the platform-enum lane's.
- **Some SDK macros can't import, so the overlay must declare them.** In the model, spelled as the SDK spells
  them, `WAIT_OBJECT_0` (`((STATUS_WAIT_0 ) + 0 )`, a sum with a cast) doesn't import, and `STD_INPUT_HANDLE`
  (`((DWORD)-10)`) imports as a `DWORD` holding a negative literal, which is an error at every use. The adopters
  use both on Windows, so Swift's WinSDK overlay must declare them; the model's overlay does, and a Windows build
  of the tests confirms it. System's own code spells both as values.
- **Borrowed optional owners are awkward to pass**, as SYS-0011 found for `templateFile`: a pipe's end goes to
  `create` through a `var end: Win32.FileHandle? = pipe.writeEnd`, closed by assigning `nil`. `Optional.map` isn't
  available for a noncopyable wrapped type in Swift 6.2, and a closure that captures a partially consumed struct
  is "used after consume" even when it touches only a field that wasn't consumed.
- **`String.withCString` and `Array.withUnsafeBufferPointer` can't return a noncopyable value** in Swift 6.2: a
  closure whose one expression makes one, such as `try DynamicLibrary($0)`, is inferred to return `()`, with only
  a warning that the constant has type `()`. Callers of the C-string overloads that make owners have to get the
  pointer some other way; `Win32DynamicLibraryTests` allocates it.

## 22. windows-2: patches for files outside the lane

**P3, `Sources/System/CMakeLists.txt`: list the lane's new sources.** CI's CMake job fails when a SwiftPM source is
missing from the list. Kept current with each commit; it applies to this branch with `git apply`. system-next at
`70e1766` merged this branch at `b63bce9` without it, so system-next's list lacks the files through `b63bce9`; apply
P3 with the next merge of this branch, which brings the rest.

```diff
--- a/Sources/System/CMakeLists.txt
+++ b/Sources/System/CMakeLists.txt
@@ -355,5 +355,10 @@
   VectoredIO/VectoredIO.swift)
 target_sources(SystemPackage PRIVATE
+  Win32/DynamicLibraryWindows.swift
+  Win32/PathsWindows.swift
+  Win32/ProcessEnvironmentWindows.swift
+  Win32/ProcessIDWindows.swift
   Win32/Win32.swift
+  Win32/Win32Console.swift
   Win32/Win32Constants.swift
   Win32/Win32Error.swift
@@ -361,4 +366,5 @@
   Win32/Win32FileHandle.swift
   Win32/Win32FileIO.swift
+  Win32/Win32FileInformation.swift
   Win32/Win32FileType.swift
   Win32/Win32FinalPath.swift
@@ -366,7 +372,13 @@
   Win32/Win32Locking.swift
   Win32/Win32Open.swift
+  Win32/Win32Process.swift
+  Win32/Win32ProcessCreation.swift
   Win32/Win32SecurityDescriptor.swift
+  Win32/Win32Synchronization.swift
   Win32/Win32Syscalls.swift
-  Win32/Win32VolumeInformation.swift)
+  Win32/Win32Thread.swift
+  Win32/Win32Time.swift
+  Win32/Win32VolumeInformation.swift
+  Win32/Win32Wait.swift)
 target_link_libraries(SystemPackage PUBLIC
   CSystem)
```

## 23. windows-3: long paths: `315f25b`

The ninth gap of section 8. swift-foundation, swift-subprocess and swift-build each carry a copy of the
canonicalization that `FileDescriptor`'s Windows adapters use (`withCanonicalPathRepresentation`:
`GetFullPathNameW`, device paths left alone, then `PathAllocCanonicalize`), swift-build's with the traps that P2
fixed in System's. Foundation's always adds the `\\?\` prefix (`PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH`), "since we
don't know if this is a directory"; the other two add it past `MAX_PATH` (`PATHCCH_ALLOW_LONG_PATHS`). SwiftPM
calls `GetFullPathNameW` alone, and its comment expects the prefix from it. swift-tools-support-core's
`resolveSymlinks`, its `realpath`, and Foundation's `removingNTPathPrefix` remove the prefix with
`PathCchStripPrefix`.

What:
- `Win32LongPaths.swift`: `Win32.ExtendedLengthPrefix` (`never`, `whenNeeded`, `always`);
  `Win32.fullPath(of:extendedLengthPrefix:)` (`GetFullPathNameW`, then `PathAllocCanonicalize`); and
  `Win32.removingExtendedLengthPrefix(from:)` (`PathCchStripPrefix`).
- `FilePathResolutionWindows.swift`: `FilePath.canonicalized()`, and `canonicalized(_:)` for a C string of
  `CInterop.PlatformChar`, on Windows, over `GetFinalPathNameByHandleW`.
- The namespace's own canonicalization (`_withCanonicalPath`, in `Win32Open.swift`) adds the prefix by
  `whenNeeded`'s rule, and `ProcessHandle.create`'s current directory gets none.

Which API: **Win32, and `canonicalized()` shared.** A full path, with Windows' rules for the prefix, is a Win32
concept. `realpath`'s, the absolute path of an existing file with its links resolved, is the same on Windows, so it
shares `FilePath.canonicalized()`, which the packages-5 lane wants on Windows for indexstore-db's `URLUtils.swift`,
and which swift-tools-support-core implements by hand.

Design calls, with the alternatives rejected:
- **The public form returns a path.** A path can be resolved once and passed to many calls, as
  `FilePathWindows.swift`'s FIXME wishes the adapters did, and the call needs no closure. Rejected: a closure form,
  as System's internal one and the adopters' copies are, which saves an allocation but needs a typed and an
  untyped overload, since Swift 6.2 doesn't infer a closure's typed throws.
- **The prefix starts at 248 characters with the terminator, `CreateDirectoryW`'s limit, in every process**, which
  is Rust's rule (`get_long_path`'s `LEGACY_MAX_PATH`). Rejected: `PATHCCH_ALLOW_LONG_PATHS`'s rule, the adapters',
  which adds the prefix only past `MAX_PATH` and only where the process isn't long-path aware, so a directory of
  248 to 259 characters can't be created there; and Foundation's, always, which `.always` offers.
- **The namespace follows the same rule**, so a path from `fullPath(of:)` resolves to itself: paths of 247 to 259
  characters, and long paths in a long-path-aware process, now get the prefix where they didn't. File functions
  take either form. The exception is a current directory, for which Windows doesn't support the prefix (Rust's
  `Command::current_dir` removes it), so `ProcessHandle.create(currentDirectory:)` now passes the full path
  without one, `.never`; before, a current directory past `MAX_PATH` got the prefix where the process wasn't
  long-path aware.
- **Three cases, not a `Bool`**: `never` is the form for a current directory, and for display, and it's what
  SwiftPM's `_normalized` computes. A path that begins with `\\?\` or `\\.\` passes through in each, as it did.
- **`removingExtendedLengthPrefix(from:)` doesn't throw.** `PathCchStripPrefix` fails only for a buffer over
  32,768 characters, and the path comes back unchanged then, as from Foundation's `removingNTPathPrefix` on any
  failure.
- **`canonicalized()` opens the file with no access rights and backup semantics**, so an unreadable file and a
  directory resolve, and asks for its normalized DOS path. Its doc says how the result differs from `realpath`'s:
  `..` is removed before the lookup, so `link\..` is the link's own directory; a mapped drive's file gets a UNC
  path; the case is the file system's. Errors are `Errno`, the signature's, through `Errno(approximating:)`.
- **`canonicalized()` keeps the prefix only where `whenNeeded` would add it.** Rejected: removing it always, as
  swift-tools-support-core does, which gives long results that only a long-path-aware process can use; and keeping
  it, `finalPath`'s form, which no other platform's result resembles.

Tests: `Win32LongPathsTests`. They change the process's current directory, which XCTest allows.

A Windows run must check:
- `testInternalConstantsMatchTheSDK`.
- `testRelativePathsResolveAgainstTheCurrentDirectory`: dot segments, a forward slash, trailing dots and spaces; a
  full path resolves to itself; `.never` and `.always`.
- `testThePrefixStartsAtCreateDirectorysLimit` (246 characters get no prefix, 247 do) and
  `testDirectoriesAtTheLimitCanBeCreated` (`CreateDirectoryW` of a 250-character path from `fullPath(of:)`).
- `testUNCPaths`: `\\?\UNC\` for `.always`, lexically, with no server.
- `testVerbatimAndDevicePathsAreUnchanged`, in all three cases; `NUL` resolves to `\\.\NUL`, which relies on
  Windows still doing that for a bare device name.
- `testRemovingThePrefix`: a drive path and a UNC path lose it, and a volume GUID path keeps it, which assumes
  `PathCchStripPrefix` returns `S_FALSE` for one.
- `testCurrentDirectoriesOfNewProcessesHaveNoPrefix`: a 250-character current directory works for cmd.exe.
- `testCanonicalizedFiles` (relative, in the wrong case, through a missing directory's `..`, the C-string overload,
  and ENOENT), `testCanonicalizedResolvesJunctions` (a junction made with `mklink /J`), and
  `testCanonicalizedKeepsThePrefixWhereNeeded`.
- `Win32FileHandleTests.testLongAndVerbatimPaths`, and the other tests' paths, which now get the prefix from 247
  characters.
- Not covered: a long-path-aware process, network shares and mapped drives, drive-relative paths (`D:file`), and
  `fullPath(of:)` of an empty path.

## 24. windows-3: threads: `054e9e2`

The tenth gap of section 8, the first of its last group. NIO starts its threads with `_beginthreadex`, names them
(`SetThreadDescription`, `GetThreadDescription`), and keeps its thread-specific values in fiber-local storage
(`FlsAlloc` with a destructor, `FlsGetValue`, `FlsSetValue`, `FlsFree`), as Foundation's `_ThreadLocal` does
without a destructor; swift-subprocess starts its threads with `_beginthreadex`, and swift-tools-support-core
yields with `SwitchToThread`. The thread handles and IDs they also use are section 13's.

What:
- `Win32ThreadCreation.swift`: `Win32.ThreadHandle.create(stackSize:suspended:inheritable:_:)` (`_beginthreadex`),
  `name()` and `setName(_:)` (`GetThreadDescription`, `SetThreadDescription`), and `Win32.yield()`
  (`SwitchToThread`).
- `Win32FiberLocal.swift`: `Win32.FiberLocalKey<Value>`, with `init()` (`FlsAlloc`), `value()` (`FlsGetValue`),
  `setValue(_:)` (`FlsSetValue`), and a deinit that frees the index (`FlsFree`).
- `Win32.Error.notEnoughMemory` (8), which creating a thread can throw, and one of section 1's candidates.

Which API: **Win32.** `PThread` wraps pthreads, which Windows doesn't have, so Windows' threads are
`Win32.ThreadHandle`s, and its thread-specific storage is a Win32 type, both shaped like their `PThread`
counterparts where the concepts agree.

Design calls, with the alternatives rejected:
- **`_beginthreadex`, not `CreateThread`.** Microsoft's documentation of `CreateThread` says that a thread that
  calls the C runtime should come from `_beginthreadex`, or the C runtime can end the process when it can't
  allocate the thread's data, and Swift's runtime calls the C runtime; NIO and swift-subprocess follow it.
  Rejected: `CreateThread`, as Rust's standard library calls it. The errors are still Win32's: `_beginthreadex`
  leaves `CreateThread`'s last error, and its own failure, an allocation, leaves none, for which System throws
  `notEnoughMemory`.
- **The closure returns nothing, and the exit code is 0**, as `PThread`'s closure returns nothing. Rejected: a
  closure that returns the exit code, which swift-subprocess's helper takes, and whose callers all return 0.
- **The handle doesn't wait for the thread.** It's section 13's owner, whose deinit closes the handle and lets the
  thread run, where `PThread`'s deinit joins; waiting is `waitForExit()`. Rejected: a second thread owner that
  waits in its deinit, which would reopen `PThread`'s deinit question (`Prototype/ThreadDeinit`) for a type that
  section 13 settled.
- **`stackSize` is the stack's reservation** (`STACK_SIZE_PARAM_IS_A_RESERVATION`), as Rust passes it, since what
  a caller limits is how far the stack grows; without the flag, it's the initial commitment. `nil` is the
  executable's default, and a size a `DWORD` can't hold is `invalidParameter`.
- **No mock hook for `_beginthreadex`**, unlike the other C runtime calls: a mocked call would start no thread to
  run the closure. `PThread`'s hook releases the closure and reports the calling thread as the new one.
- **The names are `name()` and `setName(_:)`**, `PThread.ID`'s for the same concept, rather than Windows'
  "description", which reads as `CustomStringConvertible`'s. They need a handle, so there's no `setCurrentName`;
  `ThreadHandle.current()` gives one. They're linked directly, as NIO links them; Windows 10 1607 exports them
  from KernelBase.dll alone, which is why Rust looks them up at run time.
- **`FiberLocalKey` is fiber-local storage, not thread-local**: FLS calls a destructor, and TLS (`TlsAlloc`)
  doesn't, and both adopters use FLS. Its shape is `PThread.Key`'s, a boxed value per thread that the C callback
  releases, and what differs is documented: destroying a key destroys every thread's value, on the destroying
  thread, as `FlsFree` does, where POSIX leaks the other threads'. Rejected: nesting it in `ThreadHandle`, as
  `PThread.Key` is in `PThread`, since a key belongs to no handle; and a name for threads, which a thread that runs
  fibers contradicts.
- **`yield()` returns whether another thread ran**, as `SwitchToThread` reports, and is `@discardableResult`;
  `PThread.yield()` is its POSIX counterpart.
- **Not wrapped**: `ExitThread` and `_endthreadex`, `PThread.exit()`'s counterparts (a thread from `create` ends by
  returning); priorities and affinity; `CompareObjectHandles`, with which NIO compares thread handles, and which
  `threadID()` replaces; TLS; and fibers themselves.

Tests: `Win32ThreadCreationTests`, with threads from `create` itself, and Dispatch's semaphores.

A Windows run must check:
- `testInternalConstantsMatchTheSDK`, and `notEnoughMemory` in `Win32ErrorTests.testCodesMatchTheSDK`.
- `testCreatingAThread` (the closure runs on another thread, the exit code is 0, and `inheritable`),
  `testClosingTheHandleLetsTheThreadRun`, and `testSuspendedThreads` (nothing runs until `resume()`, which returns
  1).
- `testStackReservation`: a 4 MiB reservation is what `GetCurrentThreadStackLimits` reports, which assumes its
  limits span the whole reservation; `testInvalidStackSizesAreRejected`.
- `testNames`: an unnamed thread's name is empty, a name with a non-ASCII character round-trips, a null character
  is rejected, and a `.synchronize`-only handle gets `accessDenied`, through `E_ACCESSDENIED`'s Win32 code.
- `testYield`, only that it returns.
- `testFiberLocalValues`, `testReplacedValuesAreDestroyed`, `testValuesAreDestroyedWhenTheirThreadExits`, and
  `testDestroyingAKeyDestroysEveryThreadsValue`, which relies on `FlsFree` calling the callback for a value of
  another thread that's still running.
- Not covered: running out of FLS indexes, fibers, and a thread that ends through `ExitThread`.

## 25. windows-3: HRESULT: `b89b78c`

The next gap of section 8, and SYS-0010's future direction. swift-foundation, swift-build and swift-subprocess
each define `SUCCEEDED`, `HRESULT_CODE`, `HRESULT_FACILITY` and `WIN32_FROM_HRESULT` for themselves, Foundation's
and swift-build's with the conversions P2 fixed in System (`DWORD(hr)` traps on a failure, and their
`HRESULT_FACILITY` shifts left); they compare results with `S_OK`; SwiftPM and swift-build test `SHGetKnownFolderPath`'s
result with their own `SUCCEEDED`; and swift-subprocess's `WindowsError` has a case for an `HRESULT`.

What: `Win32HResult.swift`: `Win32.HResult`, a `@frozen` struct over `HRESULT` (`RawRepresentable`,
`Swift.Error`, `Sendable`, `Hashable`, `Codable`), with:
- `init(rawValue:)`, `init(_:)`, and `init(win32Error:)` (`HRESULT_FROM_WIN32`);
- `isSuccess` and `isFailure` (`SUCCEEDED`, `FAILED`), `facility` and `code` (`HRESULT_FACILITY`,
  `HRESULT_CODE`), and `win32Error`, the Win32 code of a failure in `FACILITY_WIN32`, as SYS-0010 sketches it;
- `ok` and `false` (`S_OK`, `S_FALSE`), and the ten failures of Microsoft's "Common HRESULT values":
  `aborted`, `accessDenied`, `unspecifiedFailure`, `invalidHandle`, `invalidArgument`, `noInterface`,
  `notImplemented`, `outOfMemory`, `invalidPointer` and `unexpectedFailure`;
- `description`, the system's message (`FormatMessageW`), and `debugDescription`, such as
  `E_ACCESSDENIED (0x80070005)`, or `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) (0x80070002)` for a Win32 code
  that `Win32.Error` names.

System's internal conversion of a failed `HRESULT` to a `Win32.Error` (`_win32Error(fromHRESULT:)`, for
`PathAllocCanonicalize` and the thread names) now goes through `win32Error`; its results are unchanged.

Design calls, with the alternatives rejected:
- **System's API keeps throwing `Win32.Error`**, as SYS-0010 has it, where a function it wraps returns an
  `HRESULT`: one error type for the namespace. `HResult` is for the functions System doesn't wrap, the Shell's and
  COM's, so it conforms to `Swift.Error` for code that throws what such a function returns, as swift-subprocess's
  error type holds one. Rejected: throwing `HResult` from System's `HRESULT`-returning wrappers, which would give
  callers two error types to catch from one namespace.
- **No `~=` for untyped catches**, unlike `Win32.Error`'s: `HResult` names `accessDenied` and `invalidHandle` as
  `Win32.Error` does, and a second disfavored operator would make `catch .accessDenied` depend on overload ranking
  again (section 1). A typed catch matches through `Equatable`; an untyped one casts.
- **The codes are literals**, as `Win32.Error`'s are, and here must be: Swift imports no failure code from
  `winerror.h`, which spells them through `_HRESULT_TYPEDEF_`, a function-like macro, and a negative `HRESULT`'s
  literal overflows even when cast directly (checked on macOS with the SDK's spelling). Only `S_OK` and `S_FALSE`
  import, so the tests check the others against `winerror.h`'s values and the Win32 codes they carry.
- **`facility` and `code` are `UInt16`**, the widths of the 13- and 16-bit fields, rather than a `Facility` type
  with names; `win32Error` covers the one facility the adopters test.
- **Names**: Swift names for the C ones (`unspecifiedFailure` for `E_FAIL`, `invalidPointer` for `E_POINTER`);
  `false` is `S_FALSE`'s, a success that means "no", spelled with backticks where it's declared.
- **`init(win32Error:)` is `HRESULT_FROM_WIN32`'s rule**: `success` becomes `ok`, and a code with bit 31 set, such
  as System's `incompleteTransfer`, stays as it is, which is why SYS-0010 gives System's codes that bit.

Tests: `Win32HResultTests`.

A Windows run must check: `testConstantsMatchTheSDK` (`S_OK` and `S_FALSE` against the SDK, the rest against
their values, and `E_OUTOFMEMORY`'s Win32 code against `ERROR_OUTOFMEMORY`); `testParts`; `testFromWin32Errors`;
`testDescriptions`, where `E_ACCESSDENIED`'s system message is `ERROR_ACCESS_DENIED`'s, which relies on
`FormatMessageW` resolving an `HRESULT` in `FACILITY_WIN32`, and a customer code (bit 29) has none;
`testTypedThrows`; and `testWin32ErrorsFromHRESULTs`.

## 26. windows-3: path operations: `8326373`

The next gap of section 8. swift-foundation's `FileManager` creates and removes directories (`CreateDirectoryW`,
`RemoveDirectoryW`), deletes, moves and copies files (`DeleteFileW`, `MoveFileExW`, `CopyFile2`, `CopyFileW`), makes
symbolic links (`CreateSymbolicLinkW`, with `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`), and replaces a file
atomically with `SetFileInformationByHandle(FileRenameInfoEx)` and POSIX semantics; NIO deletes a Unix domain
socket's file with `FileDispositionInfoEx` and POSIX semantics, and other files with `DeleteFileW`; NIO's and
WasmKit's tests make directories with `CreateDirectoryW` and the C runtime's `_mkdir`.

What: `Win32PathOperations.swift`.
- By path: `Win32.createDirectory(_:securityDescriptor:)` (`CreateDirectoryW`), `removeDirectory(_:)`
  (`RemoveDirectoryW`), `deleteFile(_:)` (`DeleteFileW`), `moveFile(_:to:flags:)` (`MoveFileExW`, with
  `Win32.MoveFileFlags`), `copyFile(_:to:flags:)` (`CopyFile2`, with `Win32.CopyFileFlags`),
  `createSymbolicLink(_:to:flags:)` (`CreateSymbolicLinkW`, with `Win32.SymbolicLinkFlags`), and
  `createHardLink(_:to:)` (`CreateHardLinkW`).
- By handle, on `FileHandle` and `DirectoryHandle`: `setDisposition(_:)` (`FileDispositionInfoEx`, with
  `Win32.DispositionFlags`) and `rename(to:flags:)` (`FileRenameInfoEx`, with `Win32.RenameFlags`).
- `Win32.Error` gains three of section 1's candidates, which these functions document: `notSameDevice` (17),
  `directoryNotEmpty` (145) and `privilegeNotHeld` (1314).

Which API: **Win32.** `FilePathOperations.swift` is POSIX-only, and its signatures carry POSIX's parameters
(`permissions:`, a `relativeTo:` descriptor, `ResolutionFlags`) and `Errno`; Windows' operations take security
descriptors and flags of their own, and fail in ways `Errno` can't tell apart, such as sharing violations and
files pending deletion. So they're Win32 functions, with Win32's verbs.

Design calls, with the alternatives rejected:
- **Win32 functions rather than `FilePath`'s POSIX names.** Open: the shared part, `removeDirectory()`,
  `unlink()`, `rename(to:)` and `makeHardLink(to:)`, under POSIX's names on Windows too, as the working directory
  shares them (section 17), with approximated errors.
- **The defaults are the C functions'**, no flags: `moveFile` and `rename(to:)` don't replace a destination, and
  `copyFile` does, as `MoveFileExW`, `FileRenameInfoEx` and `CopyFile2` behave without flags; each doc says so.
  Rejected: safer defaults, such as `failIfExists` for a copy or `allowUnprivilegedCreate` for a link, which an
  option set drops as soon as a caller passes another flag.
- **`CopyFile2`**, rather than `CopyFileW` or `CopyFileExW`: it takes every `COPY_FILE_*` flag, and Foundation
  calls it. Its `HRESULT` becomes a `Win32.Error` as section 25 describes. Not wrapped: its progress callback and
  cancellation.
- **A symbolic link's target isn't canonicalized**, as Foundation's `withNTPathRepresentation(relative: true)`
  leaves it, since the link stores the target as it's given and a relative one must stay relative. `FilePath` turns
  forward slashes into backslashes, which Windows' links need.
- **Deleting and renaming by handle** take the `SetFileInformationByHandle` classes that section 20 left for this
  gap. POSIX semantics are a flag, not a default, since FAT volumes and early Windows 10 releases don't support
  them. Rejected: an `unlink()`-like method that falls back to `FileDispositionInfo` where the `Ex` class fails,
  as Rust's `remove_dir_all` does, which hides which semantics applied.
- **The rename's destination is a canonical full path**, with the prefix when it's long, as Rust's `rename`
  passes one, and `RootDirectory` is NULL. Rejected: a `relativeTo:` directory handle, which `RootDirectory`
  allows and no adopter uses.
- **Not wrapped**: `CreateDirectoryExW` (template directories), `ReplaceFileW`, `MoveFileWithProgressW`, deleting
  at the next start (`MoveFileExW` with no new name), `FileDispositionInfo` and `FileRenameInfo`, and the C
  runtime's `_mkdir`, `_mktemp_s` and `_commit`.

Tests: `Win32PathOperationsTests`. The symbolic link test skips without developer mode or elevation.

A Windows run must check:
- `testConstantsMatchTheSDK` (`COPY_FILE_*` aren't in Rust's bindings, so the SDK is the only check of their
  values), and the three new codes in `Win32ErrorTests.testCodesMatchTheSDK`.
- `testDirectories` (`alreadyExists`, `pathNotFound`, `directoryNotEmpty`, `fileNotFound`) and
  `testCreatingADirectoryWithASecurityDescriptor`.
- `testDeletingFiles`: a read-only file and a directory give `accessDenied`, and an open without delete sharing
  `sharingViolation`.
- `testMovingFiles` (`alreadyExists` without `replaceExisting`; a directory moves) and `testCopyingFiles` (a copy
  replaces by default, `failIfExists` gives `fileExists` through `CopyFile2`'s `HRESULT`, the read-only attribute
  comes along).
- `testSymbolicLinks` (a relative file link and a directory link resolve; deleting a link leaves its target),
  where links can be made; `testHardLinks` (a link count of 2; a directory gives `accessDenied`).
- `testPOSIXDeletion` (the name goes when the deleting handle closes, a new file can take it, and another handle
  still reads the old one), `testDeletionOnLastClose` (`isDeletePending`, and opening the pending name gives
  `accessDenied`), `testClearingTheDisposition`.
- `testRenamingByHandle` (the handle's final path follows; `alreadyExists`; POSIX semantics replace an open
  destination, whose handle reads the old file), and `testDirectoryHandles`.
- Not covered: moves and hard links across volumes (`notSameDevice`), FAT volumes, `delayUntilReboot`,
  `ignoreReadOnlyAttribute`, and paths past `MAX_PATH`, beyond the canonicalization section 23 checks.

## 27. windows-3: overlapped I/O: `d479525`

The next gap of section 8, and SYS-0011 and SYS-0013's largest future direction. swift-subprocess reads and writes
its pipes with overlapped I/O: it opens them with `FILE_FLAG_OVERLAPPED`, associates them with a completion port
(`CreateIoCompletionPort`) that a thread of its own drains (`GetQueuedCompletionStatus`), wakes that thread with
`PostQueuedCompletionStatus`, cancels with `CancelIoEx`, settles a canceled operation with `GetOverlappedResult`
before freeing its `OVERLAPPED`, and keeps a completion off the port by setting the low bit of its event.
swift-tools-support-core waits on a completion port for a job's processes, and watches directories with
`ReadDirectoryChangesW` on an overlapped directory handle.

What: `Win32OverlappedIO.swift`.
- `Win32.OverlappedFileHandle`, an owner like `FileHandle`, whose `open` adds `FILE_FLAG_OVERLAPPED`, with
  `read(into:fromAbsoluteOffset:overlapped:)` and `write(_:toAbsoluteOffset:overlapped:)` (`ReadFile`, `WriteFile`),
  `result(of:wait:)` and `result(of:timeout:)` (`GetOverlappedResult`, `GetOverlappedResultEx`), `cancel(_:)` and
  `cancelAll()` (`CancelIoEx`).
- `Win32.CompletionPort`, an owner, with `create(concurrentThreads:)` and `associate(_:key:)`
  (`CreateIoCompletionPort`), `post(bytesTransferred:key:overlapped:)` (`PostQueuedCompletionStatus`), and
  `dequeue(timeout:)` (`GetQueuedCompletionStatus`), which returns a `Win32.Completion`: the bytes, the key, the
  `OVERLAPPED`, and the operation's error.

Which API: **Win32**, as SYS-0011 directs: "An overlapped handle should have its own type that applies
`FILE_FLAG_OVERLAPPED` implicitly", and withholds the synchronous operations, which fail on one.

Design calls, with the alternatives rejected:
- **The operations that take an `OVERLAPPED` are `@unsafe`, with raw pointers for it and the buffer.** Windows
  uses both until the operation finishes, which can be after the call returns, the handle closes, or the caller's
  scope ends, and no Swift lifetime says so; the inherent hazard stays visible, as the Vision asks, rather than
  being half-hidden. `IORing`'s unregistered buffers are raw buffer pointers for the same reason. The incidental
  hazards are removed: the last error is read at once, `ERROR_IO_PENDING` is a `nil` result rather than a failure,
  `ERROR_IO_INCOMPLETE` and `WAIT_TIMEOUT` mean "not yet", an offset can't be a sentinel, and a missing
  operation to cancel is `false`, not an error. Rejected: an owned operation object that holds the `OVERLAPPED`
  and the buffer and whose deinit cancels and waits, as swift-subprocess's `settlePendingOverlapped` does by hand,
  which can't work with a completion port, whose packets arrive on another thread, without a registry of
  operations; and a scoped `withOverlappedRead` that waits before returning, which is synchronous I/O again. Both
  are candidates for a layer above.
- **The `OVERLAPPED` isn't read after an operation starts**, not even for the count of one that finished in the
  call: a completion port's waiter can take the packet and free the structure first. The count comes from the
  call's own argument, which Windows writes during the call.
- **Reads report the end of the data as failures** (`endOfFile`, `brokenPipe`), where `FileHandle`'s return 0:
  `result(of:)` can't tell a read from a write, and a completion port reports them as failures too.
  `ERROR_MORE_DATA`, a longer message from a message-mode pipe, is a short read, as in SYS-0013.
- **The offset is a parameter**, which the method writes into the `OVERLAPPED` with its status cleared, since an
  overlapped handle has no file pointer; the event stays the caller's.
- **`Completion` carries the operation's error rather than throwing it**, since a packet for a failed operation is
  still the operation's result; `dequeue` throws only when the wait fails, and returns `nil` at its time-out.
  `Completion` isn't `Sendable`: it holds a raw pointer.
- **Only `GetQueuedCompletionStatus`.** An entry from `GetQueuedCompletionStatusEx` has no documented status:
  only a reserved field, or the `OVERLAPPED` itself, which System can't read for a posted packet whose pointer
  isn't one. libuv reads the `OVERLAPPED`'s status, since every packet it queues has a real one.
- **`associate` takes an `OverlappedFileHandle`.** Rejected for now: raw handles, for sockets and the like, which
  Winsock's API would bring.
- **Not wrapped**: `SetFileCompletionNotificationModes` (`FILE_SKIP_COMPLETION_PORT_ON_SUCCESS`),
  `ReadFileEx`/`WriteFileEx` and alertable waits, scatter/gather (`ReadFileScatter`, `WriteFileGather`), overlapped
  named pipes and directory handles (the pipes and directory-notification gaps), and the metadata queries of
  `FileHandle`, which an overlapped handle could take: open the file again synchronously for those.

Tests: `Win32OverlappedIOTests`, with an overlapped named pipe for pending operations.

A Windows run must check:
- `testInternalConstantsMatchTheSDK`; `testOpeningAddsTheFlag` (`_isSynchronous` is false for the overlapped
  handle and true for a `FileHandle` of the same file).
- `testFileReadsAndWrites` (a write at 0 and a read at 1, finishing at once or not, and `endOfFile` past the end)
  and `testInvalidRequestsAreRejected`.
- `testPendingReadsSignalTheirEvent`: a pending read, its event signaled by the client's write, and its result.
- `testCancelingAPendingRead`: `result(of:timeout:)` returns `nil`, `cancel` returns true, the result is
  `operationAborted`, and nothing is left to cancel.
- `testCompletionPort` (the packet's key, `OVERLAPPED` and count; a posted packet; a second association is
  `invalidParameter`) and `testCompletionPortReportsFailures` (cancellation's `operationAborted` and a closed
  writer's `brokenPipe` arrive as packets).
- Not covered: a port waiter woken by the port's closing, packets of operations that finish in the call,
  disk files read past 4 GiB, and concurrency limits.

## 28. windows-3: system information: `c04d6b1`

The next gap of section 8. swift-foundation reads the page size, the processor count and mask (`GetSystemInfo`),
the installed memory (`GetPhysicallyInstalledSystemMemory`), the host name (`GetComputerNameExW` with
`ComputerNameDnsHostname`) and the Windows version (`RtlGetVersion`, looked up in ntdll, for `wProductType` and
the build number); swift-subprocess reads the page size, swift-build the processor architecture, and NIO counts
cores (`GetLogicalProcessorInformation`, `RelationProcessorCore`).

What: `Win32SystemInformation.swift`.
- `Win32.ProcessorArchitecture`, and `Win32.SystemInformation` (`SYSTEM_INFO`: architecture, page size,
  allocation granularity, application addresses, processor mask and count, level and revision), from
  `Win32.systemInformation()` and `nativeSystemInformation()` (`GetSystemInfo`, `GetNativeSystemInfo`);
  `Win32.activeProcessorCount()` (`GetActiveProcessorCount` with `ALL_PROCESSOR_GROUPS`).
- `Win32.ProcessorRelationship` and `Win32.LogicalProcessorInformation`, from
  `Win32.logicalProcessorInformation()` (`GetLogicalProcessorInformation`).
- `Win32.installedMemory()` (`GetPhysicallyInstalledSystemMemory`), in bytes.
- `Win32.ComputerNameFormat` and `Win32.computerName(_:)` (`GetComputerNameExW`).
- `Win32.ProductType` and `Win32.OSVersion` (`RTL_OSVERSIONINFOEXW`), from `Win32.osVersion()` (`RtlGetVersion`).

Which API: **Win32.** `SystemConfig` is `sysconf`, and `SystemIdentity` is `uname`'s structure; neither has a
Windows counterpart to share a name with, and faking `sysconf`'s names or `uname`'s fields over these calls is
the emulation the Vision rules out. `SystemIdentity.hostName()` is the one shared concept, but it's a member of
`uname`'s structure, which Windows would have to declare without its fields; `computerName(.dnsHostName)` is
Windows' spelling.

Design calls, with the alternatives rejected:
- **C-struct wrappers**, as section 20's information types are: `rawValue` and named, read-only properties in
  Swift types (`Int` for sizes and counts, `UInt` for masks and addresses). `SystemInformation` is
  `@unchecked Sendable`: its two pointers are address bounds, never dereferenced.
- **Functions, not properties**, as `Win32.tickCount()` is: each call asks Windows again.
- **`installedMemory()` reports bytes**, where the C function reports kilobytes, so its unit matches every other
  size here; the doc says so.
- **`osVersion()` looks up `RtlGetVersion` at run time**, as Foundation does and System does for
  `NtQueryInformationFile` (section 2): ntdll isn't linked. It throws only if the lookup fails, which it
  doesn't on any Windows NT. Rejected: `GetVersionExW`, which reports no more than the version the program's
  manifest names.
- **`logicalProcessorInformation()` is the group-limited function**, as NIO calls it; a system with more than 64
  logical processors needs `GetLogicalProcessorInformationEx`, whose entries vary in size. Not wrapped yet.
- **Not wrapped**: `GlobalMemoryStatusEx`, `IsWow64Process2` and the PE machine types (`IMAGE_FILE_MACHINE_*`,
  which swift-driver reads from a file's header), processor groups and NUMA queries, and the registry's
  release names ("23H2").

Tests: `Win32SystemInformationTests`.

A Windows run must check: `testConstantsMatchTheSDK`; `testSystemInformation` (4 KiB pages, 64 KiB granularity, the
mask's bits equal to the count, the architecture matching the build's, the native architecture x64 or ARM64);
`testActiveProcessorCount`; `testLogicalProcessors` (cores and packages, and the cores' masks covering the group's);
`testInstalledMemory`; `testComputerName` (the NetBIOS name is `COMPUTERNAME`'s, and the fully qualified name begins
with the host name); and `testOSVersion` (10.0, from build 10240). Not covered: more than one processor group,
emulated processes, and clusters' virtual servers.

## 29. windows-3: Winsock, a design: `052ae8a`

The last gap of section 8: two packages, but 23 files, nearly all NIO's. Not implemented: its natural shape needs
files outside this lane, and its module structure waits on a decision (`../Claude outputs/decisions-triage.md`, item
74, "No `SystemSockets` module: Unix sockets move into `SystemPackage`; Winsock gets its own Windows-only module",
for after a meeting). This section is the design a later lane can start from.

**What the adopters do.** NIO's `BSDSocketAPIWindows.swift` puts its BSD-shaped socket layer over Winsock. It
aliases Winsock's structures to POSIX's names (`sockaddr = SOCKADDR`, `msghdr = WSAMSG`, `cmsghdr = WSACMSGHDR`,
`sa_family_t = ADDRESS_FAMILY`), calls Winsock's BSD functions (`socket`, `bind`, `listen`, `accept`, `connect`,
`shutdown`, `getpeername`, `getsockname`, and `getsockopt` and `recv` through C shims, since Winsock types their
buffers `char *`), and replaces what Winsock lacks or renames: `close` with `closesocket`, `fcntl(O_NONBLOCK)` with
`ioctlsocket(FIONBIO)`, `sendmsg` and `recvmsg` with `WSASendMsg` and `WSARecvMsg` (the latter found with
`WSAIoctl(SIO_GET_EXTENSION_FUNCTION_POINTER)` on every call), `poll` with `WSAPoll`, `sendfile` with
`TransmitFile`, and errno with `WSAGetLastError`. It deletes a Unix domain socket's file through its reparse point
(section 26's disposition). swift-certificates parses IP addresses with `inet_pton` into `in_addr` and `in6_addr`.

**The proposal.**
1. **Share SystemSockets' names and shapes.** A socket, its address, its options and its messages are the same
   concepts on Windows, and Winsock spells them as BSD does: the same functions, the same structure layouts and field
   names (`sin_family`, `sin_addr`), and nearly the same constants. What differs is the handle type, the close and
   control calls, and where errors come from. So Windows gets `SocketDescriptor`, `SocketAddress`,
   `SocketDescriptor.Option` and the rest, with SystemSockets' signatures, and code written against them compiles on
   both where the concept holds. A Windows-only API in a namespace, as `Win32` is for files, would make every NIO
   call site a `#if`, which the shared spelling avoids.
2. **Don't fake what Winsock lacks.** `socketpair`, `SCM_RIGHTS` over Unix domain sockets, abstract socket names,
   `SO_PEERCRED`, `MSG_NOSIGNAL`, VM sockets and `sendfile` don't exist on Windows, so their API stays off it, as the
   Vision draws the line; `TransmitFile`, `AcceptEx` and `ConnectEx` are Windows' own, under Windows names.
3. **The handle is `SOCKET`.** `SocketDescriptor.rawValue` is a `SOCKET` (`UINT_PTR`) on Windows, where it's a
   `CInt` elsewhere: the raw value is the one part of the shared type whose type differs, as `ProcessID`'s does
   (section 12). It stays copyable, the raw currency type; an owner is the `OwnedFD` direction's question on every
   platform.
4. **Errors are `Win32.Error`.** Winsock's codes are system error codes (`WSAEWOULDBLOCK` is 10035), which
   `FormatMessageW` describes, so the Windows module throws `Win32.Error`, and `Win32.Error` gains names for the
   Winsock codes NIO tests (`wouldBlock`, `inProgress`, `connectionReset`, `connectionRefused`, `notConnected`, and
   the like). The shared signatures then differ in their error type, as `DynamicLibrary`'s do (section 18).
   Rejected: `Errno`, which would need a table, since Winsock numbers its BSD codes as Berkeley's errno plus 10000
   (`WSAEWOULDBLOCK` is BSD's 35), not as the UCRT's errno (where `EWOULDBLOCK` is 140), and would lose the rest.
5. **Startup is lazy.** The module calls `WSAStartup(2.2)` once per process before its first socket, as Rust's
   standard library does, and doesn't call `WSACleanup`, which matters only to code that unloads Winsock (Rust's
   runtime calls it at exit).
6. **Sockets are created with `WSASocketW`**, with `WSA_FLAG_OVERLAPPED` and `WSA_FLAG_NO_HANDLE_INHERIT`, as Rust
   creates them: overlapped, so they can join section 27's completion ports (which needs `associate` for a raw
   handle), and not inherited, as `SOCK_CLOEXEC` gives POSIX. Winsock's own calls handle overlapped sockets, so
   blocking `send` and `recv` stay safe on them, unlike `ReadFile` on an overlapped file.
7. **Windows-only additions**: `WSAPoll` as `poll`'s counterpart, with the `POLLRDNORM` and `POLLWRNORM` events
   NIO maps; `ioctlsocket(FIONBIO)` behind the shared nonblocking option; the extension functions (`WSARecvMsg`,
   `WSASendMsg`, `AcceptEx`, `ConnectEx`, `TransmitFile`), looked up once per process and cached, where NIO looks
   them up on every call.

**How, in order.**
- P0: decide the module structure. Two forms fit the proposal: SystemSockets' sources compiled for Windows over a
  Winsock layer of `system_*` functions, as `FileDescriptor` reaches the UCRT through its adapters but without
  emulating anything; or a Windows-only module that declares the same names. The first shares the code, and the
  second the API alone, so the first is the default.
- P1: the BSD core over Winsock: creation, binding, connecting, accepting, sending and receiving, options,
  shutdown, closing, names, and `inet_pton`/`inet_ntop` for addresses, with tests that run on Windows.
- P2: messages through `WSASendMsg` and `WSARecvMsg`, polling, nonblocking control, overlapped I/O through
  completion ports, and Unix domain sockets as Windows has them.

**Outside this lane's files**: a target in `Package.swift` that links `ws2_32`, its CMake list, and SystemSockets'
`#error` for other platforms (`Sources/SystemSockets`), which a Windows port replaces.

## 30. windows-3: BrokenDownTime on Windows: this commit

Left within section 14, which named broken-down time the cross-platform candidate. swift-log's
`StreamLogHandler.timestamp()` formats the local time with `_time64`, `_localtime64_s` and `strftime` on Windows,
where its other platforms use System's `BrokenDownTime`, and Foundation's `Date.description` formats UTC with
`_gmtime64_s` and `strftime`.

What: `BrokenDownTimeWindows.swift`: `BrokenDownTime` on Windows, with the POSIX declaration's public API: the
fields and their initializer, `Weekday`, `weekday`, `dayOfYear`, `Zone`, `init(secondsSinceEpoch:in:)`
(`_gmtime64_s`, and `_localtime64_s` after `_tzset`), `secondsSinceEpoch(in:)` and `normalized(in:)`
(`_mkgmtime64`, `_mktime64`), and `formatted(_:)` (`strftime`). The four conversions have mock hooks, as their
POSIX counterparts do.

Which API: **System's `BrokenDownTime`.** The UCRT's time functions are POSIX's under other names (`_gmtime64_s`
for `gmtime_r`, `_mkgmtime64` for `timegm`), so the concept and its signatures carry over.

Design calls, with the alternatives rejected:
- **A second declaration of the type.** `BrokenDownTime.swift` is `#if !os(Windows)`, and isn't this lane's, so the
  Windows file declares the type again, with the same public API, and copies the arithmetic, `formatted`'s
  replacement of the zone conversions, and the docs, adapted. Proposed for later, without a patch, since it
  reshapes another lane's file: a shared file for the platform-neutral half (the type, `Weekday`, `Zone`, the
  arithmetic, the replacement), leaving each platform its conversions.
- **The zone's fields come from the C runtime's globals**, since Windows' `struct tm` has no `tm_gmtoff` or
  `tm_zone`: `utcOffset` from `_get_timezone`, and `_get_dstbias` in daylight saving time, and
  `timeZoneAbbreviation` from `_get_tzname`, which is `TZ`'s abbreviation, or the system zone's name, such as
  "Pacific Standard Time". UTC's is "UTC", as Darwin's is.
- **UTC has POSIX's range.** The C runtime converts 1970 through 3000 only, and reports other times as `EINVAL`;
  for UTC, System computes their fields with the arithmetic the type already uses for the weekday (Howard Hinnant's
  algorithms), as the POSIX file does on Darwin before 1900. Local times outside the range throw `EOVERFLOW`.
  Rejected: computing every UTC time in Swift, which would leave the C function unused, and throwing outside the
  range for UTC too, which would make Windows' range a hazard for cross-platform code.
- **`EOVERFLOW` has no name on Windows.** `Errno.overflow` is `#if !os(Windows)`, since the initial Windows port,
  though the UCRT defines `EOVERFLOW` (132), so the file throws `Errno(rawValue: EOVERFLOW)`. Patch P5 gives Windows
  the name.
- **`formatted(_:)` can't end the process.** The UCRT's `strftime` reports a conversion it doesn't know, and a field
  outside its range, to the invalid parameter handler, whose default ends the process. So System prints a
  conversion the UCRT doesn't support (`%k`, `%-d`) as it's written, installs a handler that returns during the
  call, and for fields outside their ranges formats the time they carry to, as UTC; a year before 0 or after
  9999, which the UCRT can't print, gives an empty string. The doc says each. Rejected: formatting fields outside
  their ranges in Swift, as POSIX prints them, which means writing strftime's numeric conversions again; and
  trapping.
- **`%z`, `%Z` and `%s` are the time's own**, as on POSIX; with a flag or a modifier, the UCRT's.

Tests: `Win32BrokenDownTimeTests`, which set `TZ` to `PST8PDT` and restore it. The arithmetic and the format scanner
also ran on macOS, copied into a scratch program: the UTC fields agree with Darwin's `gmtime_r` for 200,000 random
times within 3,000 years of 1970 and the edge cases (−1, the years 1 and 3001, 9999-12-31, a leap day), and
convert back to the same seconds.

A Windows run must check:
- `testInternalConstantsMatchTheSDK` (`EOVERFLOW`).
- `testUTC`, `testUTCOutsideTheCRuntimesRange` (−1, 3001, the year 1, and `EOVERFLOW` for `Int.max`), and
  `testNormalizing` (inside and outside the range).
- `testLocalTimes`: `PDT` and `PST`, their offsets and abbreviations, the fields against the UTC fields of the
  shifted time, the conversion back, and a week's arithmetic with `isDaylightSavingTime` `nil`. This relies on the
  UCRT reading `TZ` from the environment that `ProcessEnvironment.set` changes, and applying US rules to `PST8PDT`.
- `testLocalTimesOutsideTheCRuntimesRange`: `EOVERFLOW` both ways.
- `testFormatting`: the conversions, the `#` flag and the `E` and `O` modifiers, unsupported conversions printed as
  written, and a `%` in the abbreviation; `testFormattingFieldsOutsideTheirRanges`: the 32nd of January as
  `2026-02-01`, an empty string for the year 12000, and that a conversion that doesn't read the year still works,
  which assumes the UCRT validates fields per conversion.
- `testTheCRuntimeCalls` (mock).
- Not covered: zones without daylight saving time, zones east of UTC, a non-English system zone name (decoded as
  UTF-8 from the C runtime's code page), and `setlocale`.

## 31. windows-3: findings

- **`FileDescriptor`'s Windows canonicalization doesn't cover `CreateDirectoryW`'s limit** (P4).
  `withCanonicalPathRepresentation` passes `PATHCCH_ALLOW_LONG_PATHS`, so the `mkdir` adapter, which
  `withTemporaryFilePath`'s directories use on Windows, fails with `ERROR_FILENAME_EXCED_RANGE` for a path of 248
  to 259 characters where the process isn't long-path aware. swift-subprocess's and swift-build's copies pass the
  same flag; Foundation's adds the prefix always.
- **Windows doesn't support the `\\?\` prefix for a current directory**, which Rust's `Command::current_dir` and
  Foundation's `FileManager` both work around: `ProcessHandle.create` gave one to a current directory past
  `MAX_PATH`, and no longer does (section 23).
- **macOS's C library leaked into the harness's Windows modules.** The model's headers included the macOS SDK's
  `<stdint.h>` and `<wchar.h>`, which belong to its Darwin modules, so every file that imported the model saw
  Darwin's C library: a call to `gmtime_r`, or a read of `tm_gmtoff`, compiled as if Windows had them. The model now
  includes only the compiler's own headers, so a file that imports only `ucrt` sees none of it; a file that
  imports `WinSDK` still does, through the `ObjectiveC` module that `WindowsBool`'s stand-in needs, so for a name
  both have, such as `tm` and `strftime`, the code spells `ucrt.tm`, which Windows accepts too.
- **The UCRT's `strftime` ends the process for a field outside its range**, or a conversion it doesn't know: it
  reports them to the invalid parameter handler, whose default terminates. Code that passes it a `struct tm` it
  didn't get from the C runtime, as cross-platform code does, should install a handler that returns (section 30).
- **`Errno.overflow` is missing on Windows** (P5), though the UCRT defines `EOVERFLOW`.
- **Swift can't spell `winerror.h`'s failures.** `E_FAIL` and the rest come through `_HRESULT_TYPEDEF_`, a
  function-like macro, so they don't import, and a negative `HRESULT` cast directly, `((HRESULT)0x80004005)`,
  imports as an overflowing literal, an error at each use; only `S_OK` and `S_FALSE` work. That's why no adopter
  uses one, and why `Win32.HResult` names them (section 25).
- **macOS's CoreFoundation declares `S_OK` and `S_FALSE` too**, so the harness's tests spell `WinSDK.S_OK`; on
  Windows, where XCTest's Foundation is swift-corelibs-foundation, the bare names would do.

## 32. windows-3: patches for files outside the lane

**P3, continued: `Sources/System/CMakeLists.txt`.** The Win32 `target_sources` block as it should read with this
lane's files. P3 itself landed with coverage-4 (`8caa741`); this block replaces the one it left, and is kept current
with each commit.

```cmake
target_sources(SystemPackage PRIVATE
  Win32/BrokenDownTimeWindows.swift
  Win32/DynamicLibraryWindows.swift
  Win32/FilePathResolutionWindows.swift
  Win32/PathsWindows.swift
  Win32/ProcessEnvironmentWindows.swift
  Win32/ProcessIDWindows.swift
  Win32/Win32.swift
  Win32/Win32Console.swift
  Win32/Win32Constants.swift
  Win32/Win32Error.swift
  Win32/Win32FiberLocal.swift
  Win32/Win32FileDescriptorBridge.swift
  Win32/Win32FileHandle.swift
  Win32/Win32FileIO.swift
  Win32/Win32FileInformation.swift
  Win32/Win32FileType.swift
  Win32/Win32FinalPath.swift
  Win32/Win32HResult.swift
  Win32/Win32HandleOperations.swift
  Win32/Win32Locking.swift
  Win32/Win32LongPaths.swift
  Win32/Win32Open.swift
  Win32/Win32OverlappedIO.swift
  Win32/Win32PathOperations.swift
  Win32/Win32Process.swift
  Win32/Win32ProcessCreation.swift
  Win32/Win32SecurityDescriptor.swift
  Win32/Win32Synchronization.swift
  Win32/Win32Syscalls.swift
  Win32/Win32SystemInformation.swift
  Win32/Win32Thread.swift
  Win32/Win32ThreadCreation.swift
  Win32/Win32Time.swift
  Win32/Win32VolumeInformation.swift
  Win32/Win32Wait.swift)
```

**P4, `Sources/System/FilePath/FilePathWindows.swift`: give the adapters section 23's prefix rule.** The sizing
call's length counts the terminator. Not compiled by the harness (the file is outside `Win32/`); the patched
function compiled in a scratch copy against `WindowsModel`, with stand-ins for `Errno`, `_mapWindowsErrorToErrno`
and the overlay's `ERROR_SUCCESS`. It applies to this branch with `git apply`.

```diff
--- a/Sources/System/FilePath/FilePathWindows.swift
+++ b/Sources/System/FilePath/FilePathWindows.swift
@@ -497,9 +497,14 @@
       }
 
       // 2. Canonicalize the path.
-      // This will add the \\?\ prefix if needed based on the path's length.
+      // This adds the \\?\ prefix to a path that reaches CreateDirectoryW's
+      // limit of 248 characters, its terminator included, in any process.
+      // PATHCCH_ALLOW_LONG_PATHS alone adds it only past MAX_PATH, and only
+      // in a process that isn't long-path aware.
       var pwszCanonicalPath: LPWSTR?
-      let flags: ULONG = numericCast(PATHCCH_ALLOW_LONG_PATHS.rawValue)
+      let options = dwLength >= 248
+        ? PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH : PATHCCH_ALLOW_LONG_PATHS
+      let flags: ULONG = numericCast(options.rawValue)
       let result = PathAllocCanonicalize(pwszFullPath.baseAddress, flags, &pwszCanonicalPath)
       if let pwszCanonicalPath {
           defer { LocalFree(pwszCanonicalPath) }
```

A Windows run with P4 must check that `FileDescriptor.open` and `withTemporaryFilePath` work for paths of 248 to
259 characters, and that `Win32OverlongPathTests` still throws.

**P5, `Sources/System/Errno.swift` and `Sources/System/Internals/Constants.swift`: name `EOVERFLOW` on Windows.**
The UCRT defines it, 132, and `BrokenDownTime` throws it there (section 30), where cross-platform code catches
`Errno.overflow`. Not compiled here (the files are outside the harness); it removes two `#if !os(Windows)`. It applies
to this branch with `git apply`. With it, `BrokenDownTime._overflow` in `BrokenDownTimeWindows.swift` can become
`.overflow`.

```diff
--- a/Sources/System/Errno.swift
+++ b/Sources/System/Errno.swift
@@ -1134,7 +1134,6 @@
   public static var EDEVERR: Errno { deviceError }
 #endif
 
-#if !os(Windows)
   /// Value too large to be stored in data type.
   ///
   /// A numerical result of the function
@@ -1147,7 +1146,6 @@
   @_alwaysEmitIntoClient
   @available(*, unavailable, renamed: "overflow")
   public static var EOVERFLOW: Errno { overflow }
-#endif
 
 #if SYSTEM_PACKAGE_DARWIN
   /// Bad executable or shared library.
--- a/Sources/System/Internals/Constants.swift
+++ b/Sources/System/Internals/Constants.swift
@@ -376,10 +376,8 @@
 internal var _EDEVERR: CInt { EDEVERR }
 #endif
 
-#if !os(Windows)
 @_alwaysEmitIntoClient
 internal var _EOVERFLOW: CInt { EOVERFLOW }
-#endif
 
 #if SYSTEM_PACKAGE_DARWIN
 @_alwaysEmitIntoClient
```
