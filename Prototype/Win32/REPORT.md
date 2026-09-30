# The windows-api lane

System's Win32 namespace, from the drafts in `../win32-drafts/` (SYS-0010 to SYS-0016), in their order: the
`Win32` namespace and `Win32.Error`, file handles, file types, file I/O, byte-range locking, volume information,
and final path names. Then a ranking of what the adopters' Windows code imports from WinSDK, ucrt, CRT and
visualc, against System's API. Base: system-next at `6a9833f`. Nothing here compiles Windows code, so the code is
written from the Win32 documentation, compiled on macOS against a model of the SDK (see *How it was checked*), and
kept inside `#if os(Windows)`; its tests are Windows-only and haven't run.

Darwin, before any change (`6a9833f`): XCTest 565 tests (4 skipped), swift-testing 496 tests in 80 suites, all
passing. After each commit: the same, since every new file compiles to nothing on Darwin.

**Resume here:** SYS-0010 is done (section 1). Next is SYS-0011, file handles: the code for all seven drafts was
written and compiled together in the harness before this commit, so each later commit adds one draft's files, its
sections of `Win32Syscalls.swift`, `Win32Constants.swift` and `Win32TestSupport.swift`, its tests, and its CMake
lines. The adopter ranking (part 2) comes after SYS-0016.

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

## 1. SYS-0010: the Win32 namespace and Win32.Error: this commit

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

## 9. Findings

- **Errno's `~=` must be disfavored too** (P1). Until then, even System's own code can't match a `Win32.Error`
  with an implicit-member pattern of a shared name, so it compares codes with `==`.

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
