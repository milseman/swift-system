# coverage-7 report

Lane `coverage-7`, worktree `../coverage-7`, branch `coverage-7`, from `system-next` at `dd30d5c` (2026-10-06),
which didn't move during the lane. Eleven System and tooling items from the 10-05 round.

## Resume here

- Done. All eleven items are committed (table below), with tests; the runs are in "Runs". `system-next` hasn't
  moved since `dd30d5c`, so there's been nothing to merge.
- Open: the design calls below are defaults with their alternatives noted, for Michael; "Needs outside these files"
  lists what other owners would change; "Next" lists what was left out.
- Outside the listed files: one line in the Windows model, `Prototype/Win32/WindowsModel/ucrt.h` (`abort`'s
  declaration, section 3), which every Win32 addition's commit extends.
- `Prototype/Status/STATUS.md` is regenerated once, at `020aa90` ("Status").

| # | Item | Commit | State |
|---|---|---|---|
| 1 | `Memory.compare` and `CString.compare` the client can inline | `1f2c8f9` | done (section 1) |
| 2 | SystemSockets on Musl | `0f863c1` | done (section 2) |
| 3 | `ProcessID.abort()` on Windows | `7ff8cdb`, `f5bd21d` | done (section 3) |
| 4 | `O_RSYNC` | `7ef58c6` | done (section 4) |
| 5 | mach-o/utils.h's architecture names, provisional, Darwin | `d7c17c8` | done (section 5) |
| 6 | dyld's `_dyld_get_image_header` and `getsectiondata` | `38f0fb6` | done (section 6) |
| 7 | The ABI-stable test build | `4c4a808` | done (section 7) |
| 8 | api-graph's operator kinds | `1f6e3e2` | done (section 8) |
| 9 | `Utilities/adopter-coverage`'s mapping and exceptions | `2d9201a` | done (section 9) |
| 10 | `Prototype/Directories/README.md`'s `FTS_XDEV` line | `7e8688b` | done (section 10) |
| 11 | `.gitignore`: `__pycache__/` | `020aa90` | done (section 10) |

Names: every new public name is a member (`MachOFile.architectureName`, `programArchitectureName`,
`cpuType(forArchitectureName:)`, `DynamicLibrary.loadedImageHeader(at:)`, `sectionData(segment:section:inImageAt:)`,
`OpenOptions.readSync`, `StatusFlags.readSync`, and Windows' `ProcessID.abort()`); no new top-level name. Grepped in
`Sources/` and the four sister clones: only NIO's private `NonBlockingFileIO.readSync(...)`, a method of another
type.

## 1. `Memory.compare` and `CString.compare` the client can inline (`1f2c8f9`)

**What.** `Memory.compare(_:_:)`, both overloads, were `@_alwaysEmitIntoClient` but called `Memory._compare`, which
wasn't inlinable, so `memcmp` ran in System's image behind two calls. `_compare` is now `@_alwaysEmitIntoClient`
and calls `memcmp` itself (`Sources/System/Memory/MemoryBytes.swift`, which imports the C library for it), and it
and both public overloads are `@inline(__always)`. `system_memcmp`, its only caller gone, is deleted; the header of
`Internals/Syscalls+Memory.swift` says why there's no wrapper. `CString.compare(_:_:)` and
`compare(_:_:maxLength:)` (`Provisional/Provisional+StringH.swift:173`, `:207` before) had the same pattern: their
`_compare` helpers are `@_alwaysEmitIntoClient` and call `strcmp` and `strncmp`, and `system_strcmp` and
`system_strncmp` go (`Internals/Syscalls+Provisional.swift` says why).

**Design calls.**
- Default taken: the C call in client-emitted code. No mock hook is lost: `system_memcmp`, `system_strcmp` and
  `system_strncmp` had none.
- `@inline(__always)` on `_compare` and on both `compare`s is needed, as the probe below showed. With
  `@_alwaysEmitIntoClient` alone, the client's optimizer kept `_compare` a function of its own, a client-local
  function-signature specialization (`…_compareySiSW_SWtFZTf4nnd_n`) that takes the buffers' starts and ends, so
  the count was hidden again. With it on `_compare` only, `compare` became that function instead. `CString`'s
  helpers are small enough to inline without it.
- Rejected: `@inlinable` `_compare` and `system_memcmp`, which keeps the three layers but exports both as ABI, and
  still doesn't guarantee the inlining. An equality form (`Memory.isEqual(_:_:)`), which recollapse-b said would
  also do: `compare(...) == 0` now folds to the same code, so it isn't needed for speed. A Swift byte loop, with no
  C at all: slower than the C library's `memcmp` for long buffers.
- Left as they are, the same pattern without a measured cost: `Memory.firstIndex(of:in:)` (`memchr`) and
  `CString.length` (`strlen`). Secure zeroing must stay opaque.

**Evidence** (the cheapest): a client compiled with `-O` against a release build of SystemPackage, and its
assembly. `swift build -c release --target SystemPackage`, then
`swiftc -O -S -parse-as-library -swift-version 6 -target arm64-apple-macosx26.0 -I .build/release/Modules
-Xcc -fmodule-map-file=Sources/CSystem/include/module.modulemap Client.swift`:

```swift
import SystemPackage
public func equal8(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Bool {
  Memory.compare(UnsafeRawBufferPointer(start: a, count: 8), UnsafeRawBufferPointer(start: b, count: 8)) == 0
}
public func order8(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Int {
  Memory.compare(UnsafeRawBufferPointer(start: a, count: 8), UnsafeRawBufferPointer(start: b, count: 8))
}
@available(macOS 15, *)
public func equalSpan4(_ a: RawSpan, _ b: UnsafeRawPointer) -> Bool {
  guard a.byteCount == 4 else { return false }
  return Memory.compare(a, RawSpan(_unsafeStart: b, byteCount: 4)) == 0
}
public func hasXMLPrefix(_ s: UnsafePointer<CChar>) -> Bool { CString.compare(s, "<?xml", maxLength: 5) == 0 }
public func isEmpty(_ s: UnsafePointer<CChar>) -> Bool { CString.compare(s, "") == 0 }
```

| Function | Before (`dd30d5c`) | After |
|---|---|---|
| `equal8` | `bl` System's `Memory._compare` | `ldr x8, [x0]`; `ldr x9, [x1]`; `cmp x8, x9`; `cset w0, eq`: no call |
| `order8` | tail call to `Memory._compare` | the two loads, `rev` of each, a compare: no call |
| `equalSpan4` | `bl` System's `Memory._compare` | the count check, then a 4-byte load and compare: no call |
| `hasXMLPrefix` | `bl` System's `CString._compare(_:_:maxLength:)` | `bl _strncmp` |
| `isEmpty` | `bl` System's `CString._compare(_:_:)` | `ldrb w8, [x0]`; `cmp`; `cset`: no call |

The same functions calling `memcmp`, `strncmp` and `strcmp` themselves (a `Direct.swift` that imports Darwin)
compile to the same instructions, `strncmp`'s call included: the compiler can't expand it without knowing that
`s` has five bytes.

**Adopter change.** None in swift-syntax: `Sources/SwiftSyntax/SyntaxText.swift:283-299`, `compareMemory`, already
calls `Memory.compare(...) == 0`, and the comment at `:202-209` (a comparison with a short static text becomes a
`cmp`) holds again. `SyntaxText ==` (`:194`) isn't `@inlinable`; the static text's count reaches `memcmp` only
when the release build inlines `==` into the parser (cross-module optimization), now through System too. The next
adopter round reruns swift-syntax's `PerformanceTest` in release (`tools-rb/mac-runs.sh` with `RELEASE=1`, from
`../adopters/RECOLLAPSE-B-REPORT.md`, "Next"); this lane didn't run swift-syntax's tests.

## 2. SystemSockets on Musl (`0f863c1`)

**What.** `SocketDescriptor.TCPState`'s internal `init(_:)` took `CInt` on Darwin and `Int` elsewhere
(`Sources/SystemSockets/Sockets/SocketTCPInfo.swift:44-50` at `dd30d5c`). One `init<T: BinaryInteger>(_ value: T)`, as
recollapse-a's scratch patch had it (`../adopters-unix/logs-ra/swift-system-musl-tcpstate.diff`), replaces both
arms, with a comment saying why: the C states' type isn't the platform's. Darwin's `TSI_S_` states and Musl's
`TCP_` ones are macros, which import as `Int32` (checked in the static Linux SDK's `netinet/tcp.h`); glibc's and
Bionic's are an enum's, which imports as `Int` (Bionic's `libc/include/netinet/tcp.h`, read through
api.github.com). It's internal and `@_alwaysEmitIntoClient`: no API changes.

**Design calls.** Default: the diff's generic initializer, for every platform. Rejected: a third arm,
`#elseif canImport(Musl)` with `CInt`, which keeps the `#if` and has to know each C library's spelling; or
converting at each of the eleven call sites.

**Adopter change.** None: swift-certificates' Static Linux SDK build, which failed on SystemSockets before and after
recollapse-b (`../adopters/RECOLLAPSE-B-REPORT.md`, "Needs"), should build; the adopter round reruns it.

## 3. `ProcessID.abort()` on Windows (`7ff8cdb`, `f5bd21d`)

**What.** `Sources/System/Win32/ProcessExitWindows.swift` gets `abort()`, the same shape as the other platforms':
`@_alwaysEmitIntoClient public static func abort() -> Never` over a `@usableFromInline _abort()`, over
`system_abort()` in `Win32/Win32Syscalls.swift`, which calls `ucrt.abort()` (qualified, as `exit` and `_exit` are,
so that the macOS harness can't call Darwin's). No mock hook: it never returns. The doc comment says what Windows
does: the C runtime raises `SIGABRT` only if a handler was installed with `signal`; then, with the release runtime
that Swift programs link, it ends the process with a fast fail, which no exception handler sees, and which Windows
Error Reporting records as a crash, after a dialog where one can be shown (`f5bd21d` added the dialog); the exit
code is `STATUS_STACK_BUFFER_OVERRUN` (`0xC0000409`). With the debug runtime, which first shows "abort() has been
called", or once `_set_abort_behavior` clears `_CALL_REPORTFAULT`, it exits with code 3. Exit handlers don't run
and the C streams aren't flushed.

**Design calls.**
- Default: the C runtime's `abort`, as on the other platforms, so "The corresponding C function is `abort`" holds,
  and a program's `SIGABRT` handler and `_set_abort_behavior` work as they do for C.
- Rejected: calling `__fastfail(FAST_FAIL_FATAL_APP_EXIT)` directly, which is what the release runtime does in the
  end and what Rust's `process::abort` does, but which skips the program's `SIGABRT` handler and abort settings;
  and `raise(SIGABRT)` followed by `TerminateProcess(..., 3)`, a POSIX imitation that Windows Error Reporting
  wouldn't see as a crash.
- Sources, since nothing here runs Windows: Microsoft's documentation of `abort` (`MicrosoftDocs/cpp-docs`,
  `docs/c-runtime-library/reference/abort.md`, read through api.github.com) for the `SIGABRT` handler, the error
  reporting that `_CALL_REPORTFAULT` turns on by default in release builds, its dialog, and exit code 3 without
  it. It gives the reported crash's code only as "defined by the operating system". `0xC0000409` is the fast
  fail's, which the UCRT's `abort.cpp` uses (`__fastfail(FAST_FAIL_FATAL_APP_EXIT)`, from memory of that source,
  which isn't here to read) and which Rust's test harness expects after its own `__fastfail`
  (`library/test/src/test_result.rs`, in the local Rust sources). The test pins `0xC0000409`. The alternative is to
  expect only `.failure`, which can't be wrong about the code but checks less. The test's child gets no dialog:
  swift-testing's exit tests call `SetErrorMode(SEM_NOGPFAULTERRORBOX)` and `WerSetFlags(WER_FAULT_REPORTING_NO_UI)`
  there (`Sources/Testing/ExitTests/ExitTest.swift:247-248`).
- `Prototype/Win32/WindowsModel/ucrt.h` declares `abort` (one line, beside `_exit`), since the harness compiles
  against the model; each Win32 addition's commit has added its declarations there.

**Adopter change.** swift-build (`../adopters/swift-build` at `1dce162`),
`Sources/SwiftBuild/SWBBuildServiceConnection.swift`: the `#if canImport(Darwin)` block at `:22-26` (its
`SYSTEM-GAP: abort on Windows` comment and `import func Darwin.abort`) goes, and `:157`'s `abort()` becomes
`ProcessID.abort()` on every platform; `import SystemPackage` is at `:20` already. That closes coverage-5's row 12,
which recollapse-b left open.

## 4. `O_RSYNC` (`7ef58c6`)

**What.** `OpenOptions.readSync` and `StatusFlags.readSync`, each with an unavailable `O_RSYNC` fix-it, beside `sync`
and `dataSync` in `Sources/System/SynchronizedIO/SynchronizedIO.swift`, on Linux, Android and OpenBSD, with
`_O_RSYNC`. The doc comments say what the flag means with `sync` or `dataSync` (each read waits until writes still
pending for the data it reads are written), and that on these platforms it's `sync`'s flag, so it makes writes wait
as `sync` does and does nothing more for reads.

**Which headers declare it:**

| C library | `O_RSYNC` | Read where |
|---|---|---|
| glibc 2.39 | `O_SYNC` ("Linux has no separate synchronicity options for read operations") | `bits/fcntl-linux.h`, the `swift:6.2-noble` image |
| Musl 1.2.5 | `04010000`, `O_SYNC`'s value | `bits/fcntl.h`, the static Linux SDK |
| Bionic | `#define O_RSYNC O_SYNC` | `libc/include/fcntl.h`, via api.github.com |
| OpenBSD | `O_SYNC` ("synchronicity is all or nothing in OpenBSD") | `sys/sys/fcntl.h`, via api.github.com |
| Darwin | none | the macOS 26.0 SDK and the CommandLineTools 26.3 SDK, all of `usr/include` |
| FreeBSD | none ("XXX missing O_RSYNC.") | `sys/sys/fcntl.h`, via api.github.com |
| WASI | `__WASI_FDFLAGS_RSYNC`, `1 << 3`, a flag of its own | `wasm32-wasip1/__header_fcntl.h`, the WebAssembly SDK |

**Design calls.**
- Name `readSync`, beside `sync` and `dataSync`, as WasmKit's markers spell it.
- WASI left out (default). System has no synchronized I/O on WASI at all, and `O_RSYNC` means nothing without
  `O_SYNC` or `O_DSYNC`. Alternative: all three on WASI, which takes three `_getConst_` shims in
  `CSystemWASI.h`, as System reads wasi-libc's other `O_` flags, and a WasmKit run to see which runtimes honor
  them. WasmKit's markers ask for `dataSync` and `sync` on WASI too.

**Adopter change.** WasmKit (`../adopters-unix/WasmKit` at `0c557c4`),
`Sources/WASI/Platform/PAL/PALFileDescriptor.swift`: on Linux (Glibc and Musl), the Linux arms of `open`
(`:129-135`), `open(at:)` (`:410-416`), `statusFlags` (`:298-301`) and `setStatus` (`:316-318`) go, and their System
arms take Linux, with `os(Linux)` added to the conditions at `:122`, `:403`, `:295` and `:312` and to the System
helpers' block (`:599-626`), whose `_systemOpenOptions` and `_neutralOpenOptions(systemFlags:)` then map `.readSync`
both ways. The C flags' block (`:701-765`) keeps only its WASI arm, and the `import Glibc` at `:8-9` (whose comment
says it's for `O_RSYNC`) goes if nothing else uses it. WASI stays on its own flags.

## 5. mach-o/utils.h's architecture names, provisional, Darwin (`d7c17c8`)

**What.** In `Sources/System/Provisional/Provisional+MachO.swift`, as statics of coverage-6's `MachOFile`, over
`system_` wrappers in the new `Internals/Syscalls+MachO.swift` (which imports `MachO.dyld.utils`, an explicit
submodule that `import MachO` doesn't bring):
- `architectureName(cpuType:cpuSubtype:) -> String?`: `macho_arch_name_for_cpu_type`.
- `architectureName(ofHeaderAt:) -> String?`: `macho_arch_name_for_mach_header`.
- `programArchitectureName: String?`: the same function with a null header, which is the main executable's.
- `cpuType(forArchitectureName:) -> (cpuType: Mach.CPUType, cpuSubtype: Mach.CPUSubtype)?`:
  `macho_cpu_type_for_arch_name`.

**Availability.** The header's: macOS 13, iOS 16, tvOS 16, watchOS 8 (visionOS by `*`), on the extension beside
`System 199`, so each build applies the stricter (the extension, not its members, carries both: a member's OS floor
inside a `System 199` scope fails the ABI-stable build); and on the `system_` wrappers. No `canImport` gate: every
SDK that Swift 6.1's tools support has `mach-o/utils.h` (swift-build gates on `canImport(MachO.dyld.utils)` for
older ones).

**Design calls.**
- Host values, typed: `Mach.CPUType` and `Mach.CPUSubtype`. Unlike coverage-6's header accessors, which keep the
  file's byte order and C's widths, these take and return values in the host's order. The doc of
  `architectureName(cpuType:cpuSubtype:)` says to swap a swapped file's fields first.
- The header is an `UnsafeRawPointer`: `#dsohandle`, a `SymbolInfo`'s `libraryAddress`, and typed
  `CInterop.MachHeader` or `MachHeader64` pointers all pass, and the C function reads a 64-bit header's type and
  subtype where a 32-bit one's are. Rejected: typed overloads for the two headers, which make `#dsohandle` callers
  bind memory.
- The main executable's name is a property, not a `nil` header. Rejected: an optional parameter, C's convention,
  where `nil` would mean "the program" rather than "omit".
- `String?`, since the C strings are static. Rejected: `UnsafePointer<CChar>?`.
- A labeled tuple for the type and subtype, as `FileDescriptor.pipe()` returns one. Rejected: a
  `MachOFile.Architecture` structure, a new type for one function's result.

**Adopter change.** swift-build (at `1dce162`), `Sources/SWBUtil/Architecture.swift`: the
`#if canImport(MachO.dyld.utils)` block at `:21-26` (the `SYSTEM-GAP` comment and the three `import func`s) goes,
and the conditions at `:38` and `:122` become `#if canImport(Darwin)`. In `host` (`:39-45`), the body becomes
`if let name = MachOFile.programArchitectureName, let found = MachOFile.cpuType(forArchitectureName: name)
{ return Self(cputype: found.cpuType.rawValue) }`. In `stringValue(cputype:cpusubtype:)`, `:123`'s call is
`MachOFile.architectureName(cpuType: Mach.CPUType(rawValue: cputype), cpuSubtype: Mach.CPUSubtype(rawValue:
cpusubtype))`. swift-build's floor is macOS 15 and iOS 18 (`Package.swift:79-81`), so it needs no `#available`.

## 6. dyld's image calls, Darwin (`38f0fb6`)

**What.** Beside `loadedImageCount` (`_dyld_image_count`) in `Sources/System/DynamicLoading/LoadedImages.swift`, over
`system_` wrappers in `Internals/Syscalls+LoadedImages.swift` (which now also imports `MachO.getsect`):
- `DynamicLibrary.loadedImageHeader(at:) -> UnsafePointer<CInterop.MachHeader>?`: `_dyld_get_image_header`,
  `nil` for an index no image has, a negative one or one past `UInt32` included. The doc comment says the program
  is image 0, that a 64-bit image's header is a `CInterop.MachHeader64` whose fields begin with these and after
  which the load commands start, and that indexes go stale as images load and unload, pointing to
  `symbolInfo(containing:)`.
- `DynamicLibrary.sectionData(segment:section:inImageAt:) -> UnsafeRawBufferPointer?`: `getsectiondata`, `nil` if
  the image has no such section. The bytes stay mapped while the image is loaded.

**Design calls.**
- The returned header is C's type, coverage-6's `CInterop.MachHeader`, the prefix every header has. Rejected:
  `UnsafePointer<CInterop.MachHeader64>` where pointers are 64 bits and `MachHeader` where they're 32 (arm64_32),
  which spares 64-bit readers a rebind but changes the signature with the pointer width.
- `sectionData` takes the header as an `UnsafeRawPointer`, as item 5's `architectureName(ofHeaderAt:)` does, so
  `loadedImageHeader(at:)`'s result, `#dsohandle` and a `SymbolInfo`'s `libraryAddress` pass unchanged;
  `system_getsectiondata` gives `getsectiondata` the type `getsect.h` declares, `mach_header_64` or, where
  pointers are 32 bits, `mach_header`. The doc says it must be a loaded image's of the process's own kind:
  `getsectiondata` finds a section's address from the image's slide.
- `UnsafeRawBufferPointer` rather than a `RawSpan`: the bytes live as long as the image is loaded, which no Swift
  value's lifetime stands for.
- Not added: `_dyld_get_image_name`, `_dyld_get_image_vmaddr_slide`, `getsegmentdata` and the add-image callbacks;
  no adopter asked.

**Adopter change.** swift-syntax (`../adopters/swift-syntax` at `e6918103d`),
`EditorExtension/SwiftRefactorExtension/CommandDiscovery.swift`: `:13` and `:15` (`import Darwin`, `import MachO`)
become `import SystemPackage`, and `:20-34` become
`guard let header = DynamicLibrary.loadedImageHeader(at: 0), let section = DynamicLibrary.sectionData(segment:
"__TEXT", section: "__swift5_proto", inImageAt: header), let start = section.baseAddress else { return }` with the
loop's `stride(from: start, to: start + section.count, by: 4)`; the `withMemoryRebound` to `mach_header_64` goes.
The extension is built by `SwiftRefactorExtension.xcodeproj`, not SwiftPM, so its target also needs a dependency
on swift-system's `SystemPackage` product.

swift-testing's `Sources/_TestDiscovery/SectionBounds.swift:44` (`migrate-all`) asks for the same calls in a
`SYSTEM-GAP` marker, but `_TestDiscovery` "depends on no package", as the marker says, and it also uses
`_dyld_get_dlopen_image_header` and `MH_DYLIB_IN_CACHE`, which System doesn't have: nothing to change there now.

## 7. The ABI-stable test build (`4c4a808`)

**What.** Availability only; no test's body changed. With `SYSTEM_ABI_STABLE`, where `System 199` is a future OS,
SystemTests had 22 errors at `dd30d5c` (`Prototype/TestHygiene/abi-check.sh`); now it has none:
- `@available(System 199, *)` on the helpers outside annotated tests that use `System 199` API: `KernelQueueTests`'
  `spawn` (`OwnedFD`, `ProcessID`), `MachVirtualMemoryTests`' `VM` typealias, the private `pageSize` of
  `MemoryMappingTests`, `MemoryTests` and `MemoryZoneTests` (`SystemConfig`; a global `let` can carry
  `@available` in library mode), `NetworkInterfaceTests`' `Summary`, `PThreadKeyTests`' `Tracked` (`Locked`), and
  `UnfairLockTests`' `Counter`.
- A test method with an OS floor inside a `System 199` class is "more available than enclosing scope" there, even
  with `System 199` on the method too (a probe: the member's floor is checked against the enclosing scope by
  itself). An extension that carries both attributes is accepted by both builds, so `VectoredIOMockTests`'
  `testSyscalls` and `testWriteAllResumesAcrossVectors`, and `FileLockTest`'s `testLockTimeout` (the one error the
  `be8a64f` baseline already had, outside the nine files), are in such extensions, each method where it was in its
  file.

**Design calls.** Annotating the helpers rather than their callers' scopes keeps the change to declarations that use
the API. Rejected: removing the classes' `System 199` and annotating every method, a bigger diff for the same result.
SystemSocketsTests' 8 ABI-stable errors are all in SystemSockets' own sources (finding F3), not in its tests.

## 8. api-graph's operator kinds (`1f6e3e2`)

**What.** `Utilities/api-graph/scripts/build_graph.py` gave scan-only declarations the old kinds:
an operator was a type method or a function, a `class` member an instance member, a static subscript an
instance subscript. The rule is now a function, `scan_kind(x)`, beside `SCAN_KIND`, with
`history.scan_kind`'s body and the same `OPERATOR_NAME_RE`, and the node builder calls it.

**Design calls.** Picked: one function holding the rule in api-graph, which the burn-down could import as it
imports `pitches.py`. Rejected: the report's five inline lines, the same rules with nothing to share. The
burn-down still keeps its own copy. Making it import this one is api-burndown's to do. A small module of its own
would make that import easier than `build_graph.py`, whose `from report import parse_diff` takes api-delta's
`report` and would collide with api-graph's `report.py` in the burn-down's path.

**Test.** `Utilities/api-graph/scripts/test_build_graph.py` scans a Swift text fixture with api-delta's scanner, in a
temporary directory it removes, and checks each declaration's kind against what Swift 6.2's symbol graphs give the
same source (checked with `swiftc -emit-symbol-graph`): static, global and prefix operators, static and `class`
members, both subscripts, an initializer, a typealias, a global function. On the fixture's 19 scanned declarations
the old rule got 8 wrong (the commit message says "8 of 20"; it's 19). The scanner lists only declarations with an
access modifier, so an enum case is never a scan-only declaration and isn't in the fixture's expectations.

## 9. `Utilities/adopter-coverage` (`2d9201a`)

One line each:
- `exceptions.ini` E2 and E4 deleted: ended (`Prototype/Status/LEDGER-REPORT.md`, Findings).
- E3 deleted: its end, "System wrapping them", is met by coverage-6's Mach-O structures, `vm_prot_t` and `ar.h`
  and this lane's item 5. Kept, it would hold those names at its sites as System gaps.
- E5 deleted: its end, "DynamicLibrary's form emitted into the caller", is met by coverage-6's section 1.
- N1: its System half, `.sameDevice`, is done, so it's the adopter's work now, ending with Foundation's Linux
  comparison run.
- `mapping.ini` [Mach-O file format], [Mach-O architecture names], [ar archive header]: `wrap = no` goes (Michael's
  10-05 answer), and the note says what System has. ar.h's `swift` answer goes with the rejected alternative it
  gave.
- `vm_prot_t` moves from [C scalar types] to [Mach-O file format]: `Mach.VirtualMemory.Protection` wraps it.
- [dlopen]: a note on the initializers emitted into the caller.
- [fts]: `DirectoryWalk.Options: static var sameDevice: Options` joins the `system` list as `FTS_XDEV`. The note
  had said the walk stays on one file system unless asked, which it never did.
- [loaded images], new: `_dyld_image_count`, `_dyld_get_image_header`, `getsectiondata`.
- [synchronized I/O flags], new: `O_SYNC`, `O_DSYNC`, `O_RSYNC`.
- [termination]: `ProcessID.abort()` on Windows. [string functions]: the comparisons call C in the client.
- `scripts/ledger.py` counts the `wrap = no` entries (11 now) and names the gap entry that holds one, where it had
  "14" and "E3" in its text.

Design call: E3 and E5 go with E2 and E4, which goes beyond the task's list. Their ends are System's, and both are
met. Rejected: keeping them until the adopter round moves the sites, which would show sites that System now
covers as System gaps; without them, the ledger puts those sites where they belong, on the adopters' work list
("unexplained": System covers every C name they serve).

Checks: `check.py`'s loader reads the mapping with no problem and no symbol in two entries; `derive.py` on this tree
derives each new C name as covered where it's built (the Mach-O names and `getsectiondata` on Darwin, `O_RSYNC` on
Linux, Musl, Android and OpenBSD, `abort` on every platform, Windows included); the `.sameDevice` line matches the
scanned declaration.

## 10. `Prototype/Directories/README.md` and `.gitignore` (`7e8688b`, `020aa90`)

The README's "Not included" paragraph says that staying on one file system (`FTS_XDEV`) came later, as
`DirectoryWalk.Options.sameDevice` (coverage-6's F5). `.gitignore` has `__pycache__/`, which the main clone has
untracked in `Utilities/adopter-coverage/scripts/`, and which makes `check.sh` store its runs as dirty (`git status`
shows no ignored file).

## Tests added or changed, and what each can touch

Every test was checked before it ran for what it can delete, move, overwrite, change permissions on, signal, or
reach on the network. None signals another process or uses the network.

| Test (file) | Touches |
|---|---|
| `abortEndsTheProcessWithAFastFailAndNoHandlers` (`Win32ProcessExitTests.swift`, added; Windows, unrun) | aborts in swift-testing's exit-test child, which the test spawns and waits for; the child's exit handler writes to the child's own standard output, a pipe to the test |
| `SmallLinuxGapsTest.testSynchronizedIO` (`SmallLinuxGapsTests.swift`, changed) | opens a file in its own temporary directory, read-only, with `.readSync`, and reads it; the fixture removes the directory |
| `SmallBSDGapsTests.testSynchronizedIO` (changed; OpenBSD, unbuilt) | two comparisons of constants, no I/O added |
| `namesForTypesAndSubtypes`, `namesForHeaders` (`ProvisionalMachOTests.swift`, added) | calls on values; reads the test image's mapped header at `#dsohandle` |
| `theProgramIsImageZero`, `theProgramsArchitecture`, `theTestImageIsLoaded`, `sectionsOfTheTestImage` (`LoadedImagesTests.swift`, added) | reads the process's own mapped headers and load commands; loads and unloads nothing |
| Item 7's ten files (changed) | availability attributes, extension lines and braces, and comments only (the diff has no other line) |
| `test_build_graph.py` (added, Python) | writes its fixture into a `tempfile.mkdtemp` directory and removes it |

## Runs

- macOS, before (`dd30d5c`): XCTest executed 579 tests, 5 skipped, 0 failures; swift-testing 522 tests in 85
  suites passed. After (`020aa90`): XCTest 579, 5 skipped, 0 failures; swift-testing 528 tests in 86 suites
  passed. That's the 6 new Darwin tests and 1 new suite; XCTest's changes this lane are Linux-only.
- Linux (`Utilities/linux/build.sh`, Swift 6.2, noble), at `020aa90`: XCTest executed 491 tests, 6 skipped, 0
  failures; swift-testing 493 tests in 83 suites passed; no `error:` lines. Log
  `../linux-logs/coverage-7-020aa90-test.log`. The same counts as coverage-6's last (`18ad52a`): this lane changed
  a Linux test and added none there. Also on item 4's tree (committed as `7ef58c6`), `--filter SmallLinuxGapsTest`:
  6 tests passed. `f5bd21d`, after these runs, changes a Windows doc comment only.
- Musl (`cross.sh musl build -- --target SystemSockets`, which builds SystemPackage too): 11 errors at `1f2c8f9`
  (`SocketTCPInfo.swift:60-180`), 0 at `0f863c1` and at `020aa90`. The whole package (`cross.sh musl build`)
  fails in Samples only (F2).
- WASI (`cross.sh wasi build -- --target SystemPackage`): 0 errors at `020aa90`. Under WasmKit,
  `cross.sh wasi test -- --disable-xctest --filter MemoryFunctionTests --filter ProvisionalStringTests`: 11 tests
  in 3 suites passed (the comparisons item 1 moved into client code).
- Windows (`Prototype/Win32/check-windows.sh`): the Win32 files and the 36 Windows test files compile, before item 3
  (at `0f863c1`), at `020aa90` and at `f5bd21d`.
- ABI-stable (`abi-check.sh`): before, at `dd30d5c`, SystemTests 22 errors and 32 warnings, SystemSocketsTests 8
  errors and 5 warnings. After, on a commit object of item 7's tree (`e1ea36c`, the tree of `4c4a808`),
  SystemTests 0 errors and the same 32 warnings, SystemSocketsTests the same 8 errors (F3). SystemPackage has the
  same 21 known OS-floor errors (`FilePathOperations.swift`, `FileTimes.swift`) before and after, and, patched,
  builds clean: this lane's extensions with both attributes add none.
- Explicit availability (`-require-explicit-availability=warn`, `--target SystemPackage`): no warning in this
  lane's files (the warnings are `Syscalls.swift`'s and `Syscalls+ProcessExit.swift`'s, as before).
- CMake list check: every `Sources/System` Swift file is listed (`Internals/Syscalls+MachO.swift` added, sorted).
- Python: api-graph's tests, 20 passed before, 23 after; adopter-coverage's, 30 passed before and after.
- `status.sh`: one run, with `STATUS_SYSTEM_NEXT=coverage-7`, so that the ledger reads System as `system-next` will
  be once this merges (it hasn't moved): see "Status" below.

## Findings

- **F1. `@_alwaysEmitIntoClient` doesn't make a C call visible to the client's optimizer by itself.** The client's
  optimizer can still outline the emitted function, as a specialization of its own, and the C call's arguments
  are its parameters again. A wrapper that exists so that the client sees the C call needs `@inline(__always)` at
  every level down to it (section 1). coverage-6's `DynamicLibrary._open` didn't need this: what mattered there was
  which image calls `dlopen`, not what the optimizer sees.
- **F2. The whole package doesn't build for Musl**, in `Sources/Samples/Platforms/` only:
  `Platforms/Samples/Processes.swift` and `Platforms/Enums/PlatformProcess.swift` find no `posix_spawn`, `kill`,
  `SIGTERM`, `environ` or `errno` (no Musl import). SystemPackage and SystemSockets build.
- **F3. SystemSocketsTests' ABI-stable errors are SystemSockets' own:** `SocketMessages.swift:54` and `:88` use
  `CMsgHdr` unannotated; `SocketMessages+IP.swift:214`, `:282`, `:332` and `SocketOperations.swift:410`, `:486`,
  `:530` have OS floors inside `System 199` scopes. The fix is the one in section 7: annotations on the users, and
  extensions that carry both attributes.
- **F4. `O_RSYNC` is `O_SYNC` on every platform where System has it** (section 4). The only C library with a flag
  of its own is wasi-libc's, where System has none of the synchronized I/O flags yet.
- **F5. api-delta's scanner never reports an enum case** (cases have no access modifier), so `SCAN_KIND`'s `case`
  entry can't apply to a hidden declaration.
- **F6. The ledger compiles swift-syntax's editor extension for every platform.** `CommandDiscovery.swift`, built
  only by an Xcode project for macOS, has no `#if`, so STATUS.md's section 5 lists its `[loaded images]` and
  `[Mach-O file format]` names as System gaps off Darwin. On Darwin they're covered now.
- **F7. The Mach-O entry's Darwin gap is `LC_MAIN` and `LC_SYMTAB`**, which coverage-6 left out and swift-build's
  `Tests/SWBUtilTests/MachOTests.swift:22-23` imports.

## Needs outside these files

- **api-burndown**: `history.scan_kind` can become an import of api-graph's `build_graph.scan_kind`, or both can
  import a small module of their own (section 8).
- **Samples' Platforms** (F2), for the platform-enum and demos lanes: Musl imports for the Processes sample and
  `Platform.Process`.
- **SystemSockets** (F3), for whoever owns its ABI-stable build.
- **The adopter round**: the per-item adopter changes above (sections 1 to 6), and swift-syntax's release
  `PerformanceTest`.

## Status

`Utilities/adopter-coverage/status.sh`, once, at `020aa90`, with `STATUS_SYSTEM_NEXT=coverage-7` (`system-next` hasn't
moved, so this is what it will be after the merge): `Prototype/Status/STATUS.md`, committed after this report, has
the figures. What changed in its section 5 ("Sites left") with this lane: E2 to E5 hold no site; the `wrap = no`
table lists 11 entries, none a gap; `[Mach-O file format]` is a System gap only for `LC_MAIN` and `LC_SYMTAB` on
Darwin (F7) and off Darwin (F6); `[loaded images]` is a gap only off Darwin; `[synchronized I/O flags]` only on
WASI (WasmKit's markers, section 4).

## Next

- Item 1: `Memory.firstIndex(of:in:)` and `CString.length` with the same treatment, if an adopter measures them.
- Item 3: a Windows run, which would confirm the test's `0xC0000409`.
- Item 4: synchronized I/O on WASI, the three flags together (section 4's alternative).
- Item 6: `_dyld_get_image_name` and `_dyld_get_image_vmaddr_slide`, if an adopter reads them; swift-testing's
  `_dyld_get_dlopen_image_header` and `MH_DYLIB_IN_CACHE`, if `_TestDiscovery` takes a dependency.
- coverage-6's Mach-O constants: `LC_MAIN` and `LC_SYMTAB` (F7).
