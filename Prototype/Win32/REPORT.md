# The windows-api lane

System's Win32 namespace, from the drafts in `../win32-drafts/` (SYS-0010 to SYS-0016), in their order: the
`Win32` namespace and `Win32.Error`, file handles, file types, file I/O, byte-range locking, volume information,
and final path names. Then a ranking of what the adopters' Windows code imports from WinSDK, ucrt, CRT and
visualc, against System's API. Base: system-next at `6a9833f`. Nothing here compiles Windows code, so the code is
written from the Win32 documentation, compiled on macOS against a model of the SDK (see *How it was checked*), and
kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

Darwin, before any change (`6a9833f`): XCTest 565 tests (4 skipped), swift-testing 496 tests in 80 suites, all
passing. After each commit: the same, since every new file compiles to nothing on Darwin.

**Resume here:** SYS-0010 to SYS-0012 are done (sections 1 to 3). Next is SYS-0013, file I/O, then SYS-0014 to
SYS-0016; then the adopter ranking.

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

## 3. SYS-0012: Win32.FileType: this commit

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

## 10. Patches for files outside the lane

**P1, `Sources/System/Errno.swift`: disfavor `Errno.~=`.** Verified on Darwin in a scratch copy: with it, `swift
build` (Samples included) and `swift test` give the same results as without it (XCTest 565 tests, 4 skipped;
swift-testing 496 tests in 80 suites). Errno patterns keep working on every platform: an untyped
`catch Errno.x` has no other candidate, and a typed one uses the standard library's `~=` for `Equatable` values.

```diff
 @available(System 0.0.1, *)
 extension Errno {
   @_alwaysEmitIntoClient
+  @_disfavoredOverload
   public static func ~=(_ lhs: Errno, _ rhs: Error) -> Bool {
     guard let value = rhs as? Errno else { return false }
     return lhs == value
   }
 }
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

```diff
     let dwLength: DWORD = GetFullPathNameW(self, 0, nil, nil)
+    guard dwLength > 0 else {
+      throw Errno(rawValue: _mapWindowsErrorToErrno(GetLastError()))
+    }
     return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { pwszFullPath in
@@
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
@@
     if HRESULT_FACILITY(hr) == FACILITY_WIN32 {
         return HRESULT_CODE(hr)
     }
-    return DWORD(hr)
+    return DWORD(bitPattern: hr)
 }
```
