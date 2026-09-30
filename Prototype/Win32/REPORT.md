# The windows-api and windows-2 lanes

System's Win32 namespace, from the drafts in `../win32-drafts/` (SYS-0010 to SYS-0016), in their order: the
`Win32` namespace and `Win32.Error`, file handles, file types, file I/O, byte-range locking, volume information,
and final path names. Then a ranking of what the adopters' Windows code imports from WinSDK, ucrt, CRT and
visualc, against System's API. Base: system-next at `6a9833f`. Nothing here compiles Windows code, so the code is
written from the Win32 documentation, compiled on macOS against a model of the SDK (see *How it was checked*), and
kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

Darwin, before any change (`6a9833f`): XCTest 565 tests (4 skipped), swift-testing 496 tests in 80 suites, all
passing. After each commit: the same, since every new file compiles to nothing on Darwin.

The windows-2 lane (sections 11 on, base system-next at `4365f83`) applies patches P1 and P2 of section 10, then
adds API for the adopters' top Windows gaps of section 8, in its order, checked the same way.

**Resume here:** windows-api's parts are done (sections 1 to 10). windows-2: P1 and P2 are applied (section 11);
processes have `ProcessID` and `Win32.ProcessHandle` (section 12), creation and thread handles (section 13). Next:
clocks and sleeping, the second gap, then the rest of section 8's gaps in order. Findings and patches for other lanes' files are the last two sections;
patch P3 (the CMake source list) grows with each new file.

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
  pointer the SDK annotates), runtime behavior, or a name that collides with a Windows-only internal in a file it
  doesn't compile; the new internal names were checked against all of `Sources/` and `Tests/` by grep. A
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

## 13. Creating processes, and thread handles: this commit

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

## 14. windows-2: findings

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

## 15. windows-2: patches for files outside the lane

**P3, `Sources/System/CMakeLists.txt`: list the lane's new sources.** CI's CMake job fails when a SwiftPM source is
missing from the list. Kept current with each commit; it applies to this branch with `git apply`.

```diff
--- a/Sources/System/CMakeLists.txt
+++ b/Sources/System/CMakeLists.txt
@@ -355,4 +355,5 @@
   VectoredIO/VectoredIO.swift)
 target_sources(SystemPackage PRIVATE
+  Win32/ProcessIDWindows.swift
   Win32/Win32.swift
   Win32/Win32Constants.swift
@@ -366,7 +367,11 @@
   Win32/Win32Locking.swift
   Win32/Win32Open.swift
+  Win32/Win32Process.swift
+  Win32/Win32ProcessCreation.swift
   Win32/Win32SecurityDescriptor.swift
   Win32/Win32Syscalls.swift
-  Win32/Win32VolumeInformation.swift)
+  Win32/Win32Thread.swift
+  Win32/Win32VolumeInformation.swift
+  Win32/Win32Wait.swift)
 target_link_libraries(SystemPackage PUBLIC
   CSystem)
```
