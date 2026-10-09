# The winsock-2 lane: system-next ready for the first Windows run

Makes `system-next` ready for Michael's first Windows run and makes the tools see `SystemWinSocks`, after winsock-1
(`Prototype/Winsock1/REPORT.md`). Base: system-next at `5d0b151` (coverage-9 and winsock-1 merged). Nothing here
builds or runs real Windows: the Windows-only code is compiled on macOS against a model of the SDK
(`Prototype/Win32/check-windows.sh`, `check-winsock.sh`), and the Windows host's manifest was checked by loading and
building a copy of the package whose manifest has `os(Windows)` replaced by `true`.

**Resume here:** items 1 and 2's tool changes are committed (`dda94d2`, and the tools commit after it); next is
`mapping.ini`'s coverage (item 2), then `Win32.Error`'s Winsock names (item 3), the first-run script (item 4), and
item 5 if time remains; STATUS.md is regenerated once, at the end.

## 1. What

- **The manifest** (`dda94d2`): every host declares `SystemWinSocks` and `SystemWinSocksTests`, empty but on Windows,
  with `ws2_32` linked only for Windows. On a Windows host, SystemSockets is built from
  `Sources/SystemSockets/WindowsHost/WindowsHost.swift` alone, a file that declares nothing, and SystemSocketsTests,
  the samples and their package dependency are left out.
- **The tools** see the third module:
  - api-delta: `scan_sources.py`'s `MODULE_DIRS`; `regenerate.sh`'s source diff and `@_spi` count; `report.py`, whose
    summary says where each module's declarations compile and splits the count compiled only on other platforms by
    module; `patch_manifest.py`, which removes the swift-argument-parser `.package` call wherever the manifest has it;
    `method.md`'s decision 13.
  - adopter-coverage: `status.py`'s `SYSTEM_SOURCES` and `SWIFT_NAMES`, and its method's definition of covered;
    `extract.py`'s `SYSTEM_MODULES`.
  - lint: the cmake check's `MODULES` (SystemWinSocks' CMake list); the api check's `SYSTEM_DIRS`, with helpers looked
    up in the declaration's own module; the markers check, which places a module where it declares API; the
    conditionals check's System names.

## 2. Design calls, with the alternatives rejected

- **SystemSockets stays declared on a Windows host, built from one empty file.** The request said to leave
  SystemSockets out of a Windows host's manifest. Its sources are left out, but its target and product stay, for the
  reason the request gives for declaring SystemWinSocks everywhere: SwiftPM looks a product dependency up whatever its
  condition, so NIO's, swift-certificates' and WasmKit's dependencies on the SystemSockets product, whose conditions
  leave Windows out, would fail to resolve on a Windows host if its manifest didn't declare the product. Checked with
  a scratch package: a dependency `.product(name: "Missing", package: "dep", condition: .when(platforms:
  [.windows]))` on macOS fails with "product 'Missing' required by package 'root' target 'R' not found in package
  'dep'". The target's `path:` is `Sources/SystemSockets/WindowsHost` on a Windows host, so SwiftPM sees no other
  file (a `sources:` list would leave the rest "unhandled", with a warning). *Rejected*: leaving the target and
  product out, as asked, which breaks those three adopters' manifests on Windows; and making every SystemSockets file
  empty on Windows, 35 files' worth of `#if` for the same result.
  - What it doesn't fix: `canImport(SystemSockets)` is true on Windows for a target that depends on the product
    there, and the module is empty. swift-certificates' X509Tests depends on SystemSockets without a condition and
    tests `canImport(SystemSockets)`, so its socket branches would compile on Windows and fail; with the product left
    out, its manifest would fail to load instead. An adopter should condition on the platform, not on `canImport`.
  - The alternative left for the naming question (winsock-1's section 2): a Windows host's SystemSockets could
    re-export SystemWinSocks (`@_exported import SystemWinSocks` in that one file), so that `import SystemSockets` and
    `SystemSockets.SocketAddress` work on every platform. Not done: the module's name is Michael's call.
- **The samples are left out of a Windows host's manifest, with their package dependency.** The request said to leave
  out the samples' dependency on SystemSockets; 14 of their files import SystemSockets without a condition, so without
  it, or with the empty module, the samples can't compile, and `swift build` and `swift test` (which builds every
  target, executables included, unless given `--test-product`) would fail there. Leaving out the executable also
  leaves swift-argument-parser unused, which SwiftPM warns about, so the dependency is left out too, and a Windows
  build fetches nothing. *Rejected*: keeping the samples with the dependency removed, which fails at their first
  `import SystemSockets`; and excluding the socket samples' files by name, which ties the manifest to the demos
  lane's file list. The demos lane can bring the samples back to Windows by conditioning those imports (section 5).
- **The manifest keeps the forms the manifest patchers look for**: the `.executableTarget(` call, the `.executable(name:
  "system-samples", ...)` line, and the swift-argument-parser `.package(url:)` call, now in host-conditional variables
  (`sampleTargets`, `sampleProducts`, `sampleDependencies`), as the plugin targets already are. import-probe's patcher
  handles the new form as is (checked); api-delta's matched `dependencies: [.package(...)]`, so it now removes the call
  wherever it is, which also handles the older manifests (checked on HEAD's, the new one and main's: each loads).
- **SystemWinSocks is read from the source scan alone** (api-delta's decision 13): on macOS the module is empty, so the
  symbol graphs, the digester and DocC have none of it, and its 543 public declarations are those api-delta lists as
  compiled only on Windows. *Rejected*: graphs from `check-winsock.sh`'s model build, which would mix the model's
  types into the API.
- **lint looks a helper up in the declaration's own module.** SystemWinSocks repeats SystemSockets' helper names
  (`_bind`, `_accept`), which would otherwise stop being unique and stop being followed. Same findings as the global
  lookup on this tree (both 0), checked by running the check both ways. *Rejected*: excluding SystemWinSocks from the
  helper index, which would leave its own declarations' wrappers unread.
- **A module counts, in the markers check, where it builds and declares API**: SystemWinSocks builds everywhere but
  is empty outside Windows, so a marker naming it is covered only on Windows.

## 3. Tests and runs

- Before (`5d0b151`): `swift build` succeeds; `swift test`: XCTest 582 tests (5 skipped), swift-testing 538 tests in
  90 suites, all passing.
- After the manifest (`dda94d2`): the same counts. The Windows host's manifest, by the copy with `os(Windows)`
  replaced by `true`: products SystemPackage, SystemSockets and SystemWinSocks, targets CSystem, SystemPackage,
  SystemTests, MemberImportVisibility, SystemSockets (path `Sources/SystemSockets/WindowsHost`), SystemWinSocks and
  SystemWinSocksTests, no package dependencies; it builds SystemSockets from WindowsHost.swift alone and the empty
  Windows modules (its MemberImportVisibility probes fail there, since macOS has Darwin; on Windows they're empty).
- `Utilities/lint/lint.sh cmake api` with the tools reading SystemWinSocks: 0 errors, 0 warnings. It judged SystemWinSocks'
  546 added public declarations (3 skipped: two fix-it stubs and one underscored); all 543 others have `System 199`;
  its 95 typed-throws findings are exempted by the allowlist's proposed `throws:Win32.Error` and
  `throws:AddressResolutionError` entries, and `closeAfter(_:)` by its path. So there was nothing to fix.
- lint's unit tests (17, two new: helpers per module, a module's platforms where it declares API) and
  adopter-coverage's (32) pass.

## 4. What the Windows run must check

(Filled in with the first-run script.)

## 5. Needs outside the lane's files

- **CLAUDE.md** says SystemSockets' `#error`s stop a Windows build and that only a Windows host declares SystemWinSocks;
  both changed here.
- **The demos lane**: the socket samples import SystemSockets without a condition, so the samples are left out of a
  Windows host's manifest; conditioning those imports would let them come back.
- **api-graph, api-burndown and master-view** list two modules (`cluster.py`'s `place`, `build_graph.py`,
  `index_refs.py`'s `KEEP_SWIFT`, `adopters.py`'s `SYSTEM_MODULES`, `source_index.py`'s `MODULES`, `verify.py`'s
  directories); they get SystemWinSocks' declarations from api-delta's output, but their own source and index reads
  don't see the module.

## 6. Next

(Filled in at the end.)
