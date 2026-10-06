# Ledger lane: the ledger of sites left, and high-value carve-outs

Lane `ledger` (worktree `../ledger`, branch `ledger`, from `system-next` at `a3dbd4e`), 2026-10-05. Tools only:
nothing under `Sources/` changed. Two no-quota tools:

1. **The ledger**: `Prototype/Status/STATUS.md` section 5, *Sites left*, and `.build/status/ledger.json`. It lists
   every site in the update-checkout cluster that still uses a platform C module, each with one category and its
   reason, ranked by what filling it would unblock. The section's first line says whether the floor holds on each
   platform.
2. **High-value carve-outs**: the first section of api-graph's `SUGGESTIONS.md`, from `Utilities/api-graph/scripts/value.py`.

Status: done. Commits `d3aac7d` (the ledger, `modules.ini`, `exceptions.ini`), `a1c67d8` (the value ranking),
`6fe0d80` (files per gap), `6ea460a` (STATUS.md regenerated at `6fe0d80`), then this report. The api-graph output
(`.build/api-graph`, not tracked) was regenerated at `6fe0d80` too.

## 1. What

### The ledger (`Utilities/adopter-coverage`)

- **`scripts/ledger.py`** is called by `status.py` as section 5 and also writes JSON (`STATUS_LEDGER_JSON`, default
  `.build/status/ledger.json`, every site with its names, answers and holders).
  - **A site** is an import of a module that `modules.ini` counts or reports, at its file and line, with the
    platforms whose build compiles it and the C names it serves there. A `SYSTEM-GAP:` marker is a site of its own
    only when no such import sits under it; otherwise its interfaces join the imports' names.
  - **Scope**: every scheme repository but swift-system, at the commits section 4 reads (the newest migration
    branch, else the ecosystem clone). Every library, test and other file is read. The swift repository is read
    too, within its clone's sparse checkout.
  - **Categories**, in this order:
    1. `exceptions.ini`'s entries.
    2. A `[report]` module's import is *undecided*.
    3. Otherwise each C name is answered per platform against System at `system-next` (api-delta's scan and
       `derive.py` through `check.Derivation`, with WASI read without threads, as inventory.py reads it) and
       against mapping.ini's hand statuses, `swift` answers and `wrap = no`. The site takes the first of:
       System gap, queued, not System's, standard library, else *unexplained*.
  - **Ranking**: unexplained sites come first; System gaps follow in a greedy order of sites unblocked.
- **`modules.ini`**: Michael's three groups of 10-05 (count; report; not System's, reviewed). Section 4 and the
  ledger now read this one list (`ledger.Modules`); `status.py`'s `PLATFORM_MODULES` constant is gone.
- **`exceptions.ini`**: Michael's corrected list of 10-05, plus Coverage5's Needs design:
  - E1, the swift repo's standard library, is the only exception.
  - E2 and E4 are queued adopter work; both have ended (section 4 below).
  - E3 (Mach-O, `vm_prot_t`, ar.h) and E5 (dlopen in the caller's image, which answers N8) are System gaps kept by
    hand.
  - E6 is undecided. E7a–d are exclusions.
  - N1–N7 and N9 are queued, each as Coverage5 wrote it.
- **`status.py`**:
  - Section 3 reads markers at each adopter's newest migration branch (`marker_snapshots`). `--markers branch`, or
    `STATUS_MARKERS=branch`, keeps the old view at `--branch`. That brings in swift-crypto, swift-stress-tester
    and swift-testing, which have only `migrate-all` and whose markers section 3 never read.
  - Every git command runs with `GIT_NO_LAZY_FETCH=1` (also exported by `status.sh`).
  - The marker parser reads `unistd.h isatty on WASI`, `statfs on Linux`, `dlfcn.h dlsym with …` and
    `FreeBSD's copy_file_range` as their C names, and no longer reads platform names as C ones. Compared with
    HEAD's parser over all 83 markers, 32 parse better and none worse.
- **`platforms.py`**: WASI can import `wasi_pthread`, as wasip1's SDK can (PACKAGES-6-REPORT.md).

### High-value carve-outs (`Utilities/api-graph`)

- **`scripts/value.py`** ranks the carve-outs that pass the vision's three tests, as approximated:
  1. A potential adopter in the update-checkout cluster: `scheme-main.tsv`'s packages, matched by remote, with
     reach's adopted and would-benefit sites.
  2. No open question (direct or inherited) and no promoted shared-vocabulary type.
  3. 3 to 60 declarations (`config.json`'s new `valueSize`).
- They're ranked by the cluster's sites, then by the penalty score. A part is listed only when its cluster
  doesn't pass. The section ends with the carve-outs with the most sites that fail a test, and why.
- **Wiring**: `report.py --scheme` (passed by `regenerate.sh`) writes the section first and `highValue` into
  `suggestions.json`. `value.py --all` prints every carve-out with each test's result.
- **Docs**: `method.md` decision 42, with its limits under "Where it's wrong", and `Prototype/ApiGraph/REPORT.md`
  section 7.
- **Fix**: `cluster.py` crashed on `a3dbd4e`'s graph with a `KeyError`, when a loose alias's voter component had
  merged after it voted. Its users are now placed by their atom's cluster.

## 2. Design calls (each with the alternative rejected)

- **A site is an import line**, plus markers over no import. *Rejected*: inventory.py's unit, a C name on a line;
  one whole-module WinSDK import would be hundreds of sites, and the floor is about imports.
  - The cost: a scoped import is a site per declaration (swift-build's MachO.swift is 47). The gap table therefore
    gives files beside sites; the order stays by sites unblocked, as asked.
- **C names are found lexically**, with inventory.py's vocabulary and occurrence rules, plus Windows' names
  (WindowsModel and Rust's Win32 bindings, on Windows lines only). Names that Swift's own modules declare are
  dropped (Mach's asm macro `String` and libkern's typedef `UInt` had leaked in as gaps), as are the
  repository's own names and its `C<Target>_` shims.
  - *Rejected*: adopter-coverage's stored extractions, which exist for some repositories and at other commits;
    and a vocabulary of any capitalized name.
- **Order within a site**: a System gap outranks queued work, which outranks a lane's verdict, which outranks the
  standard library. A site with a gap nobody has queued must show as a gap. *Rejected*: queued first, which would
  hide such a gap behind work that won't free the site.
- **Gaps are ranked greedily**: next is the gap that unblocks the most sites given the ones above are filled; ties
  go to more platforms. *Rejected*: sites held, which counts a site once per gap and ranks gaps that free nothing
  alone above ones that do.
- **The floor** counts maybe platforms. It leaves out exceptions, excluded sites and `[report]` modules (as
  Michael said). E6's undecided sites count, since only exceptions are allowed. *Alternative*: leave all undecided
  sites out.
- **`ledger.json` is in `.build/status`, not `.build/adopter-coverage`**: `check.sh` deletes the latter on every
  run, and refuses to replace it once it lacks its marker file.
- **The hand-kept files are read at HEAD's commit**, as mapping.ini is, so STATUS.md stays "from commits only".
  The header says when they have uncommitted changes. *Alternative*: the working tree.
- **Every site is in STATUS.md**, in a collapsed list (the unexplained ones in the table above it), which makes
  STATUS.md about four times its old size. *Alternative*: a separate generated `Prototype/Status/LEDGER.md`, if the
  size gets in the way.
- **Users of a re-export aren't sites; the re-export is.** *Rejected*: tracing users as inventory.py does. Through
  corelibs Foundation's own re-exports, every Foundation importer on WASI and Windows would become a site.
- **Not System's**: mapping.ini's 14 `wrap = no` entries are all listed, each with its sites, as lane verdicts that
  Michael hasn't reviewed. "The Mach-O and ar.h ones" is read as both Mach-O entries (file format and
  architecture names) plus ar.h: E3's `mapping` rule. `[not System's]` modules' imports aren't sites; their
  counts are given.
- **value.py**:
  - *Rejected*: a weighted score of sites against the penalty; every package's sites; parts listed beside their
    passing cluster.
  - Left open: swift-corelibs-foundation counts as a cluster adopter while its status is undecided.

## 3. Tests

- **Before**:
  - api-graph: 14 tests, OK.
  - api-burndown: 45, OK.
  - adopter-coverage had none.
- **After**:
  - adopter-coverage: 30, OK. This is the new `scripts/test_ledger.py`: modules.ini's groups and import pattern,
    exceptions.ini's parsing and validation, System's answers, each category and the unexplained ones, the order
    of categories, the marker parser, the greedy ranking, files per gap, the floor, a scan of a fixture
    repository, and section 3's newest-branch read.
  - api-graph: 20, OK (the 14, plus 6 in the new `scripts/test_value.py`).
  - api-burndown: 45, OK.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/adopter-coverage/scripts -p 'test_*.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-graph/scripts -p 'test_*.py'
```

What I checked in the tests I added (Michael's rule of 10-05):

- **`test_ledger.py`**:
  - Deletes only the directories it made with `tempfile.mkdtemp` (`shutil.rmtree` on the returned path), and
    writes only inside them: fixture files, a mapping.ini copy, and the manifest cache path, which stays unused
    because the fixture has no `Package.swift`, so no `swift package` runs.
  - Its git commands run in its own repositories with `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` set to
    `/dev/null`, and `--no-verify`. So no hook, signing or credential helper runs.
  - Nothing is moved, no permissions are changed, nothing is signaled, and nothing reaches the network.
  - It doesn't call the functions that run `xcrun`, `rustc` or `git archive` (`swift_declared_names`,
    `rust_windows_bindings`, `system_api`).
- **`test_value.py`**: in-memory fixtures only; nothing on disk.

## 4. Findings

- **I fetched into a clone I don't own.** `../ecosystem/swift` is a blobless partial clone with a sparse checkout
  of the standard library. My `git grep HEAD` there lazily fetched 49 small promisor packs, about 0.4 MB, into
  its `.git/objects/pack` from its remote, over about 19 minutes, before I stopped it. Refs, index and working
  tree are unchanged, and I left the packs. The tools now run git with `GIT_NO_LAZY_FETCH=1` and read a partial
  clone only within its sparse checkout. The rest of the swift repository is listed as not read.
- **E2 and E4 have ended**: recollapse moved swift-syntax's SyntaxText.swift to `Memory.compare` (`20aa9126e`).
  SWBLibc and TSCLibc re-export nothing off Windows (`29fb659`, `6e9860c`).
  - Both entries now hold no site; they can go.
  - SWBLibc's and TSCLibc's Windows re-exports aren't covered by any entry, so they show as unexplained or as
    System gaps.
- **Many unexplained Windows sites are ones System could take now**: System at `system-next` names their Win32
  names (`Win32.createDirectory`, `Win32.FileTime`, `Win32.sleep`, …), but the adopters still call them through
  WinSDK.
- **BSD arms**: several `import Glibc` arms that only FreeBSD and OpenBSD compile have no C name used on those
  platforms (NIO, Foundation's tests). They're likely vestigial.
- **What the wider module list added** (relative to the original ten modules):
  - **MachO**: swift-build's `MachO.swift` (47 scoped imports), `Architecture.swift`, `MachOTests.swift` and a
    mergeable-libraries test; swift-syntax's `EditorExtension` `CommandDiscovery.swift`; Foundation's
    `AttributeScope.swift`, which is under `FOUNDATION_FRAMEWORK` and so excluded.
  - **`os`**: 44 imports in sourcekit-lsp, swift-build, swift-docc, swift-foundation, swift-subprocess,
    swift-syntax, swift-tools-protocols, swiftpm and WasmKit. They're undecided; 17 of Foundation's are under
    `FOUNDATION_FRAMEWORK` and excluded.
  - **swift-foundation's split C modules** (`unistd` ×5, `stdlib_h` ×4, `string_h`, `threads_h`): Android arms,
    and fallback arms after Darwin, Linux, Android and Glibc that no modeled platform reaches.
  - Section 4's tables show the effect.
- **Modules in no group that the cluster imports**: `EmscriptenLibc` (swift-foundation, 18 imports),
  `CoreFoundation_Private` (14), `DarwinPrivate` (6), `wasi_pthread` (4: swift-async-algorithms,
  swift-certificates, corelibs-foundation), `C` and `C.unistd` (4), `_FoundationDarwinExtras` (4), `threads` (1).
  - The macOS SDK's modulemaps also define modules in no group that nothing here imports: `sys_types`, `sys_wait`,
    `sys_resource`, `sys_qos`, `alloca`, `runetype`, `MacTypes`, `unwind`, `_DarwinFoundation1`–`3`, and others.
  - These are for Michael's module review.
- **`platforms.py`'s `canImport` sets** don't include the SDK's split C modules on Darwin or Android. No site in
  the cluster depends on that today: every such arm follows a Darwin, Android or Glibc arm.
- **Run time**: the ledger builds in about a minute. One run took 46 minutes at a load average of 93; the next,
  at 33, took 58 seconds.
- **Disk**: free space fell to 18 GiB during the lane. The api-graph build directories here are 14 GB; I deleted
  them at the end, so this worktree's next api-graph run is cold.

## 5. Next

- **For Michael**:
  - E6's status.
  - Each `[report]` module (`os` holds most of those sites).
  - Whether `wasi_pthread`, `EmscriptenLibc` and `C` should be counted.
  - Whether undecided sites should count toward the floor.
  - The 12 `wrap = no` verdicts that remain lane proposals.
- **For whoever keeps `exceptions.ini`**: delete E2 and E4, which have ended; add new decisions as entries.
- **For the adopter lanes**: the unexplained list is the work list. It holds the sites System covers now and the
  imports with no use found.
- **Not needed now**: if STATUS.md's size gets in the way, move the every-site list to a generated `LEDGER.md`.
