# coverage-6 report

Lane `coverage-6`, worktree `../coverage-6`, branch `coverage-6`, from `system-next` at `a3dbd4e` (2026-10-05),
which didn't move during the lane. Four gaps that adopters hit, decided by Michael on 10-05.

## Resume here

- Done. All four items are committed (table below), with tests; the runs are in "Runs". Nothing is uncommitted, and
  `system-next` hasn't moved since `a3dbd4e`, so there's been nothing to merge.
- Open: the design calls below are defaults with their alternatives noted, for Michael; "Needs outside these files"
  lists what other owners would change; "Next" lists what was left out.

| # | Item | Commits | State |
|---|---|---|---|
| 1 | `dlopen` in the caller's image | `6c06afe` | done (section 1) |
| 2 | `DirectoryWalk.Options.sameDevice` (`FTS_XDEV`) | `e8ffe94` | done (section 2) |
| 3 | Mach-O structures, provisional, Darwin; `vm_prot_t` | `6f35c61` | done (section 3) |
| 4 | `ar.h`, provisional, every platform but Windows | `dfe3490`, `18ad52a` | done (section 4) |

## 1. `dlopen` in the caller's image (`6c06afe`)

**What.** `DynamicLibrary.init(_:options:)` (both overloads) and `mainProgram(options:)` were
`@_alwaysEmitIntoClient`, but called `DynamicLibrary._open`, an `@usableFromInline` function, so `dlopen` ran in
System's image. `_open` is now `@_alwaysEmitIntoClient` and calls `dlopen` itself
(`Sources/System/DynamicLoading/DynamicLibrary.swift`), which needed the file to import the C library;
`system_dlopen`, whose only caller it was, is gone (`Internals/Syscalls+DynamicLoading.swift`, whose header comment
says why). `_loaderError()` is `@usableFromInline`, so the error is still read in System's image: `dlerror`'s state
is the calling thread's, whichever image reads it. The `FilePath` initializer's doc comment says how paths resolve:
on Darwin `@loader_path` is the calling image's directory and `@rpath`, like a name without a `/`, searches its run
paths and then the program's (`dlopen(3)`: "if the calling mach-o file or the main executable specify an
LC_RPATH"); with glibc `$ORIGIN` and the run paths are the calling object's. The C-string overload points to it.

**Design calls.**
- Default taken: `_open` emitted into the client, calling `dlopen` directly. The mocking hook the task mentions
  doesn't exist: the dynamic-loading wrappers have none (they report through `dlerror`, not `errno`), so no mock
  test is lost. Rejected: a separate client-emitted entry point (`DynamicLibrary(callerRelative:)` or similar)
  beside the existing ones, which would leave the existing initializers resolving against System's image, the
  surprising default; and a `#dsohandle` parameter, since `dlopen` has no public form that takes the caller
  (Darwin's `dlopen_from`, which does, is private).
- `dlsym`, `dlclose` and `dladdr` stay in System's image: only `dlsym` with the pseudo-handles `RTLD_NEXT` and
  `RTLD_SELF` depends on the caller, and `DynamicLibrary` doesn't vend those.
- Musl's `dlopen` searches the program's run paths whoever calls it (it passes the program to `load_library` as
  the object that needs the library), so the change is moot there, and harmless.
- **Windows** (`Win32/DynamicLibraryWindows.swift`) is unchanged: `LoadLibraryExW`'s search (the program's
  directory, the system directories, `PATH`, or the directories its `LOAD_LIBRARY_SEARCH_*` flags name; for
  `LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`, the loaded library's own) doesn't depend on the calling module.

**Evidence** (the cheapest): `nm -u` on the client object `.build/debug/SystemTests.build/DynamicLibraryTests.swift.o`,
demangled. Before: `static SystemPackage.DynamicLibrary._open(_:options:)` undefined, no `_dlopen`. After:
`_dlopen` undefined, no `_open`, and `SystemPackage._loaderError()` (the error, from System). A behavior test can't
tell the two apart here: SwiftPM links System into the test image. `loaderPathIsTheCallersImage` (Darwin) checks the
behavior anyway: it finds the test image by `dladdr(#dsohandle)` and opens `@loader_path/<its name>` with
`.noLoad`, which passes only if `@loader_path` is the test image's directory; it distinguishes where System is a
library of its own, as in the SDK.

**Adopter change.** swift-build (`../adopters/swift-build` at `1dce162`), `Sources/SWBUtil/Library.swift`:
- `:18-28`: the `SYSTEM-GAP` comment and the four `public import func <libc>.dlopen` lines go.
- `:48-58`, `Library.open`'s non-Windows branch: instead of `dlopen(p, flags)` and `takePendingError()`,
  `try DynamicLibrary(FilePath(...), options: [.lazy, .first])` (`.lazy` off Darwin), then
  `LibraryHandle(rawValue: library.relinquish())`, mapping a `DynamicLibrary.LoaderError` to
  `LibraryOpenError(message: error.message)`. `Library.open` stays `@_alwaysEmitIntoClient`: the initializer is
  emitted into it, and it into its caller, so `dlopen` still runs in the caller's image.

## 2. `DirectoryWalk.Options.sameDevice` (`e8ffe94`)

**What.** A walk with the option doesn't go into a directory on another device than the root's. It visits such a
directory as it visits an empty one: before its contents, after them, or both, as the order says, with nothing
between; a postorder walk's one visit is its postorder visit (`isPostorderVisit`), and in a
preorder-and-postorder walk the second visit comes right after the first. `skipDescendants()` after the first visit
skips the second, as for any directory.

**fts's semantics, matched.** The man page says only "prevents fts from descending into directories that have a
different device number than the file from which the descent began". The implementations (FreeBSD's and Darwin's
`fts_read`, and glibc's, all the same) say the rest: at a directory's `FTS_D`, `if (instr == FTS_SKIP ||
(ISSET(FTS_XDEV) && p->fts_dev != sp->fts_dev))` it sets `FTS_DP` and returns the directory again, without reading
it; `sp->fts_dev` is the root's (`fts_load`). So the mount point itself is visited, twice, and its contents aren't.
That's what swift-foundation's Linux removal relies on: the mount point's `FTS_DP` `rmdir` fails with `EBUSY`.

**Design calls.**
- Name: `sameDevice`, beside `boundedDescriptors`, `includesRoot`, `includesStatus`. Alternatives:
  `staysOnDevice`, `oneFileSystem` (GNU's `--one-file-system`), `crossesNoDevices`.
- When the device is read (default): before the walk opens a directory, from the entry's status with
  `.includesStatus`, or else an `fstatat` without following a link, relative to the parent, as fts stats a directory
  before it descends. So the walk never opens a directory on another device, which on Linux would trigger an
  automount (`fstatat` doesn't, since Linux 4.11). With `.whenEntered`, the check happens when the walk would open the
  directory, so a skipped directory costs nothing. Rejected: `fstat` on the opened descriptor, which is race-free (a
  mount between the check and the `openat` can't slip through, as it can with fts) but opens, and so triggers, every
  mount point; and Linux's `openat2` with `RESOLVE_NO_XDEV`, race-free and free, but Linux 5.6 and later only, and
  System's `openat` isn't `openat2`.
- A failure getting the status is the entry's `error`, as a failure to open would be (on the second visit, with
  `.whenEntered`), and the walk doesn't go in: it can't tell whether it may.
- The root's device comes from an `fstat` on the first `next()`; if that fails, `next()` throws and the walk ends,
  as when reading the root fails. The initializer from a `DirectoryStream` can't throw, so this was the place.
- No marker on the entry saying it's on another device (fts has none either; with `.includesStatus` a caller can
  compare `status.deviceID`). `rm --one-file-system`'s "skipping …, since it's on a different device" would want
  one: an `Entry.isOnAnotherDevice` is the alternative.
- Bind mounts of the same file system have the same `st_dev`, so the option doesn't stop at them, as `FTS_XDEV`
  doesn't.

**Adopter change.** swift-foundation (`../adopters-unix/swift-foundation` at `2bca6e08`, which recollapse-a is
moving, so the lines can shift), `Sources/FoundationEssentials/FileManager/FileOperations.swift`, `_removeFile`'s
non-Darwin branch (`:451-537`): the `_FTSSequence(path, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT)` loop
(`:487-535`, under the `SYSTEM-GAP` marker that asks for this option) becomes a `DirectoryWalk` over the root with
`order: .preorderAndPostorder, opening: .whenEntered, options: [.sameDevice, .boundedDescriptors, .includesRoot]`:
the root's first visit (depth 0) is the `isFirst` `FTS_D` that's already approved; another directory's first
visit is `FTS_D`, where `skipDescendants()` is `skipDescendants(of:skipPostProcessing: true)`; `isPostorderVisit`
is `FTS_DP` (`rmdir`, or `removeDirectory(relativeTo: walk.parentDirectory)` on the name); files and links are
`unlink`; `entry.error`, and `next()` throwing, are `FTS_DNR`/`FTS_ERR`/`FTS_NS`. `FTS_PHYSICAL`, `FTS_NOCHDIR` and
`FTS_NOSTAT` are what a walk does anyway. The other Linux fts sites need no new option: subpaths
(`FileManager+Directories.swift:280`) and copy and link (`FileOperations.swift:1171`) don't use `FTS_XDEV`, and
Darwin already walks them with `DirectoryWalk` (`FileOperations+Enumeration.swift:303`, `_subpathsOfDirectory`, and
`:363`, the copy and link walk). Once all three move, `_FTSSequence` (`FileOperations+Enumeration.swift:138-295`)
can go. coverage-5's N1 asked for this option and for a comparison run on Linux like Darwin's; the run is still to
do.

## 3. Mach-O structures, provisional, Darwin (`6f35c61`)

**What.** `Sources/System/Provisional/Provisional+MachO.swift` and `Internals/Constants+MachO.swift`, Darwin only
(no other platform's headers declare them). The file's header says why it's provisional: a file format, whose
lasting home is a library for object files or a Swift overlay of the C module `MachO`.
- Types, as `CInterop`'s other C types: `CInterop.MachHeader`, `MachHeader64`, `LoadCommand`, `SegmentCommand`,
  `SegmentCommand64`, `Section`, `Section64`, `Dylib`, `DylibCommand`, `UUIDCommand`, `RPathCommand`,
  `BuildVersionCommand`, `VersionMinCommand`, `FatHeader`, `FatArch`, `FatArch64`.
- Accessors, `@_alwaysEmitIntoClient`, under Swift names that differ from the C fields (so a file that imports
  both sees no ambiguity), each "The corresponding C field is `x`.": `magicNumber`, `cpuType`, `cpuSubtype`,
  `fileType`, `loadCommandCount`, `loadCommandsSize`, `headerFlags`; `commandType` and `commandSize` on every
  command; `segmentName`, `virtualAddress`, `virtualSize`, `fileOffset`, `fileSize`, `maximumProtection`,
  `initialProtection`, `sectionCount`, `segmentFlags`; `sectionName`, `address`, `sectionSize`,
  `alignmentExponent`, `relocationsOffset`, `relocationCount`, `sectionFlags`; `Dylib`'s `nameOffset`
  (`name.offset`), `buildTimestamp`, `currentVersion`, `compatibilityVersion` and `DylibCommand.library`;
  `uuidBytes` (the tuple `UUID(uuid:)` takes); `pathOffset`; `targetPlatform`, `minimumOSVersion`, `sdkVersion`,
  `toolCount`; `architectureCount`.
- Constants, `@_alwaysEmitIntoClient` statics of the namespace `MachOFile`: `MachOFile.Magic` (`MH_MAGIC`,
  `MH_CIGAM` and their `_64`s as `machHeader`, `swappedMachHeader`, …; `FAT_MAGIC`, `FAT_CIGAM` and theirs as
  `fatHeader`, `swappedFatHeader`, …), `FileType` (`object`, `execute`, `dylib`, `bundle`), `LoadCommandType`
  (`segment`, `segment64`, `idDylib`, `loadDylib`, `loadWeakDylib`, `reexportDylib`, `lazyLoadDylib`,
  `loadUpwardDylib`, `uuid`, `rpath`, `buildVersion`, `versionMinMacOS`, `versionMinIOS`, `versionMinTVOS`,
  `versionMinWatchOS`), `ArchiveMemberName` (`SYMDEF`, `SYMDEF_SORTED`, `SYMDEF_64`, `SYMDEF_64_SORTED`).
- `vm_prot_t` (item 4's, here since it's a segment's): `Mach.VirtualMemory.Protection`, an `OptionSet` over
  `vm_prot_t`, `read`, `write`, `execute`, `default` and `all`. `VM_PROT_ALL` isn't importable (an OR of three
  casts; `VM_PROT_DEFAULT`'s two are), so `all` is the three. Linux has no `vm_prot_t` (mmap's `PROT_` flags are
  `MemoryMapping.Protection`), so it's Darwin only.
- `cpu_type_t` and `cpu_subtype_t`: System has them, as `Mach.CPUType` and `Mach.CPUSubtype`'s raw values
  (`MachCPU/MachCPUType.swift`), and swift-build's aliases (`MachO.swift:542-543`) use them; nothing added.

**Design calls.**
- Namespace `MachOFile`: `MachO` is the C module's name, and swift-build's class (`MachO.swift:820`). Alternatives:
  `MachOFormat`, `Mach.ObjectFile` (under System's `Mach`, the kernel's namespace), `MachOImage`. Grepped in
  `Sources/`, the four sister clones, `../adopters/swift-build` and `../adopters-unix/swift-foundation`: no
  `MachOFile` or `ArchiveFile` anywhere.
- Accessors return the fields as the file stores them, in its byte order, with the C field's width (`UInt32`,
  `UInt64`, `cpu_type_t`, `vm_prot_t`): a file for the other byte order (`swappedMachHeader64`), and every fat
  header on a little-endian host, needs each field swapped, which a typed value would make awkward
  (`Mach.CPUType(rawValue: x.rawValue.byteSwapped)`). swift-build's `byteSwappedIfNeeded` maps over unchanged.
  Rejected: typed accessors (`Mach.CPUType`, `Protection`) and accessors that convert fat headers from big-endian,
  both nicer for the common case, but a second byte-order convention. Names are the 16 bytes up to a NUL, as
  `String`s (swift-build parses them the same way, `parseMachOFixedSizeString`).
- Constants are raw (`UInt32`, the fields' type, though Swift imports the `LC_` macros without `LC_REQ_DYLD` as
  `Int32`; `String` for `SYMDEF`), in caseless sub-namespaces named for the field they're values of. Rejected:
  `RawRepresentable` types (`MachOFile.FileType: RawRepresentable` with `header.fileType: MachOFile.FileType`),
  System's usual form for C constants, which goes with typed accessors.
- No zero initializers. A probe (two modules, `swiftc`, MemberImportVisibility): an `init()` that System declared
  on `mach_header` works for a client that imports only System, but in a file that imports System and `MachO`, a
  conformance to a protocol requiring `init()` fails with "multiple matching initializers named 'init()'". So it
  would break swift-build's own conformances while it still imports `MachO` (finding F3). The all-zero-defaults
  memberwise `init` that `CInterop+Accessors.swift` uses doesn't witness `init()`, and building these structures
  isn't what readers do; none added. Readers lay them over bytes with `loadUnaligned(as:)`.
- `Mach.VirtualMemory.Protection` is marked provisional, the task's default, though its lasting home is where it
  already is, Mach's virtual memory API; un-marking it is the alternative, with a `vm_protect` wrapper to use it.
- Left out: `LC_ATOM_INFO` (the 26.3 SDK has it, older SDKs don't, which is why swift-build defines it under
  `DONT_HAVE_LC_ATOM_INFO || SWIFT_PACKAGE`), the `PLATFORM_` values of `targetPlatform`, `build_tool_version`,
  the header's `MH_` flags and the other `MH_` and `LC_` values, and the `reserved` fields.

**Adopter change.** swift-build (at `1dce162`), `Sources/SWBUtil/MachO.swift`:
- `:16-68`: the `SYSTEM-GAP` comment and the `public import struct/var MachO.*` lines go; `:76`'s
  `public import SystemPackage` stays. Types: `mach_header` → `CInterop.MachHeader`, and so on for the sixteen.
- Constants: on Darwin, `fileprivate let MH_MAGIC = MachOFile.Magic.machHeader` and so on keep the rest of the file
  as it is, beside the non-Darwin `fileprivate let`s at `:519-534`; or each use changes: `case UInt32(LC_…)` at
  `:1155-1194` → `case MachOFile.LoadCommandType.…`; `switch Int32(cmd.cmd)` at `:1354-1364` →
  `switch cmd.commandType`; `header.filetype == MH_OBJECT` at `:1393` → `header.fileType ==
  MachOFile.FileType.object`; the `FileType` statics at `:866-869`; `StaticArchive.symbolTables` at `:1528` →
  `MachOFile.ArchiveMemberName`'s four.
- `:582-596`: the `BinaryDataType` conformances need `init()` (`:260-262`), which C's structures have only with
  `import MachO` under MemberImportVisibility, and System doesn't add (above). Either `BinaryDataType` drops
  `init()` and the readers (`:429`, `:451`) load with `loadUnaligned(as:)`, or swift-build keeps a
  `public import struct MachO.…` per structure for the initializer.
- `:633-816`: the protocols `MachOFatHeader`, `MachOHeader`, `MachOSegmentLoadCommand` and `MachOSection` name
  their requirements after the C fields, which the structures satisfy with their own; without `import MachO` they
  take System's names: `magic` → `magicNumber`, `cputype` → `cpuType`, `cpusubtype` → `cpuSubtype`, `filetype` →
  `fileType`, `ncmds` → `loadCommandCount`, `sizeofcmds` → `loadCommandsSize`, `flags` → `headerFlags`,
  `segmentFlags` or `sectionFlags`, `cmd` → `commandType`, `cmdsize` → `commandSize`, `segname` → `segmentName`
  (a `String`, so `segname()` goes), `vmaddr`, `vmsize`, `fileoff`, `filesize` → `virtualAddress`, `virtualSize`,
  `fileOffset`, `fileSize`, `maxprot`, `initprot` → `maximumProtection`, `initialProtection`, `nsects` →
  `sectionCount`, `sectname` → `sectionName`, `addr` → `address`, a section's `size` → `sectionSize` and a fat
  arch's → `fileSize`, `offset` → `fileOffset`, `align` → `alignmentExponent`, `reloff` → `relocationsOffset`,
  `nreloc` → `relocationCount`.
- `:1057`, `:1084`: `cmd.dylib.name.offset` → `cmd.library.nameOffset`; `:1125`: `ulc.uuid` → `ulc.uuidBytes`;
  `:1346-1366`: `cmd.platform`, `minos`, `sdk`, `version` → `targetPlatform`, `minimumOSVersion`, `sdkVersion`;
  `:1689-1712`: `fh.magic`, `nfat_arch` → `magicNumber`, `architectureCount`, and the fat arch readers.
- `:70`: `vm_prot_t` → `Mach.VirtualMemory.Protection.RawValue`, as `:542-543` do for the CPU types (or the typed
  `Protection`); `:537`'s non-Darwin alias stays.

## 4. `ar.h`, provisional (`dfe3490`, `18ad52a`)

**What.** `Sources/System/Provisional/Provisional+Ar.swift` and `Internals/Constants+Archive.swift`, on every
platform but Windows (whose SDK has no `ar.h`). `CInterop.ArchiveHeader` is `struct ar_hdr`; its fields are text,
so its accessors parse them: `name` (`ar_name`, without the spaces that pad it), `modificationTime` (`ar_date`,
`Int64`), `userID`, `groupID` (`UserID`, `GroupID`), `mode` (octal, `FileMode`), `size` (`Int64`), each `nil`
when the field isn't a number in its radix that fits its type, and `trailer` (`ar_fmag`). Constants, statics of
`ArchiveFile`: `magic` (`ARMAG`), `magicSize` (`SARMAG`), `headerTrailer` (`ARFMAG`), and on Darwin, FreeBSD and
OpenBSD, whose headers have it, `extendedNamePrefix` (`AR_EFMT1`, BSD's `#1/` names). `vm_prot_t` is in section 3.

**Where each platform gets `ar.h`.** Darwin: the explicit submodule `Darwin.ar` (`import Darwin` doesn't bring it).
Musl and Android: their Swift modules include it (`SwiftMusl.h`, `SwiftAndroidNDK.h` with `module ar`). glibc,
FreeBSD, OpenBSD and WASI: their modules don't (`SwiftGlibc.h.gyb`'s list, which the BSDs' modules share, and
`wasi-libc.modulemap`), so CSystem's headers include it: `CSystemLinux.h` under `__GLIBC__` only (not for Musl or
Bionic, so that `ar_hdr` has one owner), `CSystemShared.h`'s FreeBSD and OpenBSD block, and `CSystemWASI.h`, beside
its `<sys/statvfs.h>`. The header declares only `ar_hdr` and macros, so no other type's members move to CSystem;
`ar_hdr` itself is CSystem's there, whose fields a client can't name, and the accessors are how it reads them
(the test file imports no C library, and passed on glibc and WASI).

**Design calls.**
- `ArchiveFile` for the namespace (`Archive` is SwiftPM's, in `Workspace+BinaryArtifacts.swift`, and too wide;
  `StaticArchive` is swift-build's). Alternatives: `ArArchive`, `UnixArchive`. Its own file, as the task allowed,
  since its platforms differ from Mach-O's.
- Parsed accessors rather than the raw `char` arrays: every reader parses them the same way (decimal, octal for the
  mode, padded with spaces). Rejected: text accessors per field, which leave the parse to each client. A GNU name's
  `/`, a `/18` reference, and a BSD `#1/` length stay in `name`, which System doesn't interpret.
- `size` and `modificationTime` are `Int64` (`18ad52a`): on wasm32 `Int` is 32 bits, and `ar_date`'s 12 digits and
  `ar_size`'s 10 don't fit in one (the WASI test build failed on the test's literals). `Int64` is System's file
  size and offset type (`Stat.size`, `read(fromAbsoluteOffset:)`).

**Adopter change.** swift-build (at `1dce162`), `Sources/SWBUtil/MachO.swift`:
- `:71-74`: the `SYSTEM-GAP` comment and the `Darwin.ar` imports go; `ar_hdr` → `CInterop.ArchiveHeader`,
  `SARMAG` → `ArchiveFile.magicSize` (`:1591`), `AR_EFMT1` → `ArchiveFile.extendedNamePrefix` (`:1663-1664`).
- `:604-608`: `#if canImport(Darwin.ar)` can be `#if !os(Windows)`, with the `BinaryDataType` caveat of section 3.
- `:1651-1684`, `extension ar_hdr`: `rawArchiveName` → `name`, which has no trailing spaces (theirs, through
  `FileManager`, kept them until the `#1/` parse trimmed); `extendedFormatArchiveNameSize` →
  `Int(name.dropFirst(ArchiveFile.extendedNamePrefix.count))` under `name.hasPrefix(…)`; `objectSize` →
  `size.map { Int($0) - (extendedNameSize ?? 0) }`; `structSize` → `MemoryLayout<CInterop.ArchiveHeader>.size`.
- `:1530-1534`, `ARMAG1` and `ARMAG2` (the magic as two words): could compare the bytes with
  `ArchiveFile.magic.utf8`.

## Tests added, and what each can touch

Every test was checked before it ran for what it can delete, move, overwrite, change permissions on, signal, or
reach on the network. None signals or uses the network.

| Test (file) | Touches |
|---|---|
| `loaderPathIsTheCallersImage` (`DynamicLibraryTests.swift`, Darwin) | opens another handle to the loaded test image with `RTLD_NOLOAD` (loads nothing), and closes it |
| `aTreeOnOneDeviceIsWalkedWhole` (`DirectoryWalkSameDeviceTests.swift`) | a tree it makes in its own temporary directory, then only reads; the fixture removes it |
| `aDirectoryOnAnotherDeviceIsntEntered` (same) | reads `/` and, without the option, `/dev`'s first entry: `opendir`, `readdir`, `fstatat`, `fstat`; skips every other directory; stops at the first entry deeper than `/`'s, so a broken walk reads a path's worth |
| `aPostorderWalkVisitsItOnce` (same; runs where `/dev` has a mount in it, as on Linux) | reads `/dev`'s tree on `/dev`'s device, opening only directories (`O_DIRECTORY|O_NOFOLLOW`), never a device node; bounded at 100,000 entries |
| `aDirectoryWhoseStatusCantBeRead` (same; not as root, not WASI) | sets its own temporary subdirectory to `r--------` and back in a `defer`, before the fixture removes it |
| `ProvisionalMachOTests` (5 tests, Darwin) | opens the test image's own file read-only and reads it with `pread`; reads the mapped header at `#dsohandle`; the rest is bytes in memory |
| `ProvisionalArchiveTests` (6 tests) | bytes in memory only |

The cross-device tests mount nothing: they find a directory the system already has on another device with C's
`stat` (`/dev` in `/` on Darwin, devfs; on Linux, `/dev` and the mounts in it), and are skipped where there's none
(WASI).

## Runs

- macOS, before (`a3dbd4e`): XCTest executed 579 tests, 5 skipped, 0 failures; swift-testing 506 tests in 82 suites
  passed. After (`18ad52a`): XCTest 579, 5 skipped, 0 failures; swift-testing 522 tests in 85 suites passed (16
  tests and 3 suites added; no XCTest).
- Linux (`Utilities/linux/build.sh`, Swift 6.2, noble), at `18ad52a`: XCTest executed 491 tests, 6 skipped, 0
  failures; swift-testing 493 tests in 83 suites passed; no `error:` lines. Log
  `../linux-logs/coverage-6-18ad52a-test.log` (and `coverage-6-dfe3490-test.log`, the same counts, before the
  `Int64` fix). For comparison, coverage-5's last (`68bb779`): 491 and 484 in 81. The cross-device tests ran and
  passed there, the postorder one included; the permissions one skipped (root).
- Musl (`cross.sh musl build -- --target SystemPackage`), at `18ad52a`: 0 errors. `build-tests` fails outside these
  changes (F1).
- WASI (`cross.sh wasi test -- --disable-xctest --filter ProvisionalArchiveTests --filter
  DirectoryWalkSameDeviceTests`, under WasmKit), at the `18ad52a` code: 8 tests in 2 suites passed, the two that
  need a directory on another device skipped.
- Explicit availability (`-require-explicit-availability=warn`, `--target SystemPackage`): no warning in these
  files (the warnings are `Syscalls.swift`'s and `Syscalls+ProcessExit.swift`'s).
- ABI-stable (`SYSTEM_ABI_STABLE`): SystemPackage alone shows only the known failures. In a patched copy (the
  `abi-stable-test-targets` recipe: manifest patched, `Syscalls.swift`'s `uid_t`/`gid_t`, 21 OS-floor lines
  deleted), SystemPackage builds clean and SystemTests' errors are all in other files (F2).
- CMake list check: every `Sources/System` Swift file is listed.
- Not built: Android (no NDK), FreeBSD, OpenBSD. Their `ar.h` arms are the glibc and Musl ones'.

## Findings

- **F1. SystemSockets doesn't build for Musl** (outside these files, before this lane): `SocketTCPInfo.swift:60-180`,
  `Self(TCP_CLOSE)` and the other states, "cannot convert value of type 'Int32' to expected argument type 'Int'",
  from `4d2b1e64` (2026-09-27). And the static Linux SDK has no XCTest, so `cross.sh musl build-tests` can't link
  SystemTests' XCTest files.
- **F2. The ABI-stable build of SystemTests has grown errors** beyond the be8a64f baseline (whose one was
  `FileLockTests.swift`'s OS floor): unannotated uses of `System 199` API in `KernelQueueTests.swift` (`OwnedFD`,
  `ProcessID`), `MachVirtualMemoryTests.swift`, `MemoryMappingTests.swift`, `MemoryTests.swift`,
  `MemoryZoneTests.swift` (`SystemConfig`), `NetworkInterfaceTests.swift`, `PThreadKeyTests.swift`,
  `UnfairLockTests.swift` and `VectoredIOMockTests.swift`; 22 distinct errors. None in this lane's files.
- **F3. A zero `init()` on a C structure can't be System's** (probe in section 3): a file that imports both System
  and the C module can't conform the structure to a protocol requiring `init()`. The accessor pattern's
  all-defaults memberwise `init` doesn't witness `init()` either, so a protocol like swift-build's
  `BinaryDataType` needs the C module, or another way to make a value.
- **F4. APFS's system and data volumes share a device number**, so on macOS a `.sameDevice` walk of `/` does enter
  `/Users`, `/Applications`, `/private` and the other firmlinks; among `/`'s directories only `/dev` (devfs) is on
  another device, as with `find -x /`. `/System/Volumes`'s other volumes (`Preboot`, `VM`, `Update`, …) are.
- **F5.** `Prototype/Directories/README.md:355` still lists "staying on one file system (`FTS_XDEV`)" as not
  included.

## Needs outside these files

- `Prototype/Directories/README.md:355`: `FTS_XDEV` is now `.sameDevice` (F5).
- `Utilities/adopter-coverage`'s mapping, for whoever owns it: the Mach-O structures and constants, `ar.h`'s,
  `vm_prot_t`, and the caller-image `dlopen` now map to System API (sections 1, 3 and 4); `FTS_XDEV` to
  `.sameDevice`.
- `Tests/MemberImportVisibility`: a probe that reads `CInterop.ArchiveHeader`'s accessors would guard, on glibc,
  that clients can read the CSystem-owned structure; `ProvisionalArchiveTests.swift` does it now from SystemTests,
  under MemberImportVisibility, without a C import.
- F1 and F2, for their files' owners.
- swift-build's `SYSTEM-GAP` markers at `Library.swift:18` and `MachO.swift:16, 69, 71`, and swift-foundation's
  at `FileOperations.swift:487` (removal's `FTS_XDEV`), are answered, for the adopter round.

## Next

- Item 2: the Linux comparison run of Foundation's removal on `DirectoryWalk` against fts (N1's other half), once
  the adopter round moves it; `Entry.isOnAnotherDevice` if a caller wants to report skipped mount points.
- Item 3: the `PLATFORM_` constants for `targetPlatform`, `build_tool_version`, `LC_ATOM_INFO` when every SDK has
  it, and the rest of `loader.h`'s structures (`symtab_command`, `nlist_64`, `linkedit_data_command`) if an adopter
  reads them; a `vm_protect` wrapper, and un-marking `Mach.VirtualMemory.Protection`, if wanted.
- Item 4: Android, FreeBSD and OpenBSD builds, when there are SDKs.
