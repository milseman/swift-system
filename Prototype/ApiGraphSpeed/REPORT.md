# api-graph-speed: regenerate.sh fast after a System change

Lane `api-graph-speed`, base `3f9f9e1` (system-next), merged with system-next `6a9833f` at `943c479` and `4365f83` at `2c474b4`. Owns `Utilities/api-graph/` and `Prototype/ApiGraphSpeed/`.

## Resume here

Stopped 2026-10-01. All three steps are committed and measured, every run's adopter links match the old tool's, and the scratch is deleted.

**Commits** (base `3f9f9e1`):
- Merges of system-next:
  - `943c479`, of `6a9833f`;
  - `2c474b4`, of `4365f83`.
- The three steps:
  - `f12d631`, step 1;
  - `ae57686`, step 2;
  - `d1f856c`, step 3.
- `279c229`: the scratch change to one comment under Sources, used as the head of the trivial-change runs. `cdb9e87` reverts it.
- Measurement tools: `e4a2730`, `1f204c8`, and the last commit (the README's "Run time", `verify_pin.py`, the re-pin and this report).

**Deleted at the stop:**
- `.build/speed`, 24 GB: two kept builds directories, of 12 GB and 11 GB, the runs' outputs, and the caches.
- `${TMPDIR}api-graph-speed`: the pin, made of APFS clones, 3.4 GB apparent.

No persistent builds directory is kept. The measurement builds were against pinned copies whose commits, and whose path dependencies' absolute paths, a real run doesn't share, so a real run would start most of them over anyway. A real run's builds go in `.build/api-graph-builds`, about 12 GB.

**Possible next steps,** none of them started:
1. **The would-benefit scan.** It's now most of a run with nothing to build: 55 to 134 s of an adopters step of 77 to 163 s. It's outside this lane's three steps.
2. **Fewer manifest datings.** Date the manifests only when a dependency's list of files changed, so a change inside existing files doesn't make SwiftPM plan again (step 2).
3. **A run on a real merge**, such as system-next `4365f83`, to see how few migrations revalidation rebuilds when declarations change.
4. **Longest-first on a quiet machine.** The run with history (d4h) was inconclusive at a load of 148.
5. **Pin outside `$TMPDIR`**, or re-pin with `pin.sh` every few days (see Measurement setup).

## Measurement setup

- `pin.sh` copies what the runs read from outside the repository into `${TMPDIR}api-graph-speed`:
  - each adopters clone's git directory, as APFS clones, so refs, reflogs, the shallow boundary and the origin URL come along;
  - APFS clones of `../ecosystem` and `../coverage-results`.

  It then checks each copy's refs, HEAD and migration merge base against the original.
  - On 2026-09-30 the 18 `migrate-darwin` tips were the ones the previous session recorded.
  - sourcekit-lsp and swift-corelibs-xctest still have no migration commits.
  - `../ecosystem` and `../coverage-results` had changed since 2026-09-29 noon, which is why they're pinned too.
- `measure.sh NAME [TOOL]`:
  - It copies the tool from a commit (`git archive`) or a directory, then runs it with the pinned inputs, a cache, builds directory and snapshot store under `.build/speed`, `BASE_REF=1b452c2` and `HEAD_REF=3f9f9e1`.
  - regenerate.sh's output goes to `runs/NAME/regenerate.log`, each line stamped with seconds since the start. The load average is sampled every minute.
  - `summarize.sh` writes `summary.txt`.
  - The body is one bash block, so editing the script during a run can't change the run. An edit during the baseline broke its summary step, not the run itself, and that summary was rebuilt from the log.
- The Sources and manifest of 3f9f9e1 and of system-next's tip, 6a9833f, are the same.
- `verify_pin.py ADOPTERS_JSON [--fix]` checks a pin against a run's `adopters.json`. With `--fix` it puts the pin back to that run's state:
  - each migration's tip and main;
  - an adopters clone's branch, and an ecosystem clone's HEAD;
  - clones the run didn't have;
  - coverage extractions that would now be picked instead of the recorded one, or of a lexical scan, including one of a migration's merge base, which is tried first.
- Three hazards turned up, each now caught:
  - **`$TMPDIR` cleanup.** macOS deleted files from the pin overnight, between 2026-09-30 21:34 and 2026-10-01 06:06: files under `$TMPDIR` not accessed for a few days, and an APFS clone keeps its original's access time. swift-nio's and swift-subprocess's copies lost their git `HEAD` and `config`, and the coverage results lost about 1500 of 5311 files. A run that morning saw 16 migrations instead of 18, so it was stopped. `pin.sh` now sets the copies' access times to now.
  - **Live clones move.** Re-pinned, nine `migrate-darwin` tips had moved overnight, sourcekit-lsp had grown a migration, and the coverage lanes had added 100 extractions that would have been picked. `verify_pin.py --fix` against the baseline's `adopters.json` put all of it back. The next run's links matched the baseline's exactly, which checks the restored pin.
  - **A closed lid.** The machine sleeps, and a run's wall time then includes the sleep. Each run now records its power source and its start and end, and `summarize.sh` counts the power log's Sleep entries in between. Only the first d4 run had any.

## The runs

Every run is regenerate.sh with `BASE_REF=1b452c2` on the pinned inputs. The head is 3f9f9e1, or `279c229` (one comment changed under Sources). Load is the mean of the one-minute load average, sampled each minute, from other lanes' builds as well as this run's. Every run's adopter links, sites and hunks are identical to a-old's.

| Run | Tool | What | Wall | Adopters step | Load | Power |
|---|---|---|---|---|---|---|
| a-old | old (`943c479`) | (a): cold, one build at a time | 1375.8 s | 1252 s | 47.4 | AC |
| b1 | step 1 | (b): unchanged tree, the old cache: 18 reused | 221.1 s | 82 s | 57.5 | AC |
| c1 | step 1 | (c): `279c229`: 18 revalidated | 287.2 s | 95 s | 76.1 | AC |
| s2-cold | step 2 | cold, serial, filling the builds | 1966.4 s | 1804 s | 116.9 | AC |
| s2-incr | step 2 | forced rebuild (`tree`) on `279c229`: 18 incremental | 540.8 s | 421 s | 23.7 | AC |
| d4 | step 3 | (d): cold, 4 jobs | 1059.2 s | 907 s | 129.4 | battery |
| d18 | step 3 | (d): cold, 18 jobs | 973.9 s | 791 s | 194.0 | battery |
| b3 | step 3 | (b): unchanged tree, d18's cache: 18 reused | 382.8 s | 163 s | 66.2 | battery |
| c3 | step 3 | (c): `279c229`: 18 revalidated | 242.1 s | 77 s | 43.2 | battery |
| i3 | step 3 | forced rebuild (`tree`), 4 jobs: 18 incremental | 330.5 s | 183 s | 36.5 | battery |
| d4h | step 3 | cold, 4 jobs, with history: 17 built, 1 reused | 1205.4 s | 896 s | 148.2 | battery |

Not in the table: the first d4 run, which slept, and a stopped run on the damaged pin (Measurement setup).

**What each step bought:**
- **Step 1 is most of it.** After a System change that leaves the migrations' declarations alone, the run is 4 to 5 minutes and builds nothing: c1 took 287 s and c3 242 s, where the old tool's (a) took 1376 s.
- **Step 2** makes the rebuilds that remain incremental. s2-incr's 18 builds took 337 s, where they took 1125 s cold in (a); each recompiled only SystemPackage. The builds directory takes about 12 GB.
- **Step 3**:
  - It overlaps the builds. The cold adopters step at a load of 117 to 129 fell from 1804 s serially (s2-cold) to 907 s with 4 jobs (d4), and to 791 s with 18 (d18, at a load of 194). The forced incremental rebuild fell from 421 s (s2-incr) to 183 s (i3).
  - Under this load, the order mattered less than the total CPU work. d4h, longest first, and d4, alphabetical, spent about the same 810 s building.
- **(b), nothing changed, isn't faster than before.** Nothing builds either way. b3 took longer than b1 because its would-benefit scan, unchanged code, ran at about twice the load.

## Step 1: validate cached indexes instead of keying on System's tree (committed `f12d631`; measured)

**What:**
- The cache key no longer includes System's tree.
- Each entry records the System commit, tree and manifest it was built against, and a fingerprint and name for each System declaration its references name.
- On another tree, an entry is revalidated when three things hold: its build succeeded, the manifest is unchanged, and every recorded fingerprint is unchanged. Otherwise the migration is rebuilt, and the reason lists what changed or is gone.
- The old tool's entries for the same tree are reused and upgraded.

**Design calls:** see `scripts/method.md`, decisions 19 and 37.
- The declarations come from api-delta's symbol graphs, since graph.json holds only the delta.
- A failed build is rebuilt whenever System moves.
- A manifest change means a rebuild.
- A migration whose build compiles another migration is revalidated only with it.
- Entries are kept per tree.
- Rejected:
  - a whole-interface hash as the default (it's kept as `interface`);
  - overload-set checks (a possible next step);
  - lexical name matching;
  - trusting the cache unchecked (`--builds reuse` does that).

**Fixed in review this session:**
- The reason given for a failed build.
- A `--builds reuse` hit on an old-format entry, which has no System block.
- Decision 36's "Rejected" line, which sat under decision 37.

**Measurements:**
- (a), the old tool: 3f9f9e1, with an empty cache (every migration rebuilt, as with eee1da2's cache), on the pinned inputs.
  - 1375.8 s wall (22 min 56 s); user 3416 s, sys 696 s.
  - The adopters step took 1252 s of that: 18 builds, one after another, from 13 s (swift-log) to 182 s (swift-foundation).
  - Load: 28.7 at the start. The one-minute averages, sampled each minute, had a median of 44.5 (min 23.7, max 90.7, mean 47.4).
  - The previous session's (a), with eee1da2's cache, took 29 min 9 s at a load of 11 to 45.
  - It exited 0, so it's also the "before" api-graph check.
- (b), the step 1 tool (`f12d631`) on 3f9f9e1 with the baseline's cache.
  - 221.1 s wall (3 min 41 s); user 387 s, sys 94 s. The adopters step took 82 s.
  - All 18 migrations were reused ("built against this System tree, by the previous version of this tool"). Each entry was upgraded to the new format, a second file beside the old one.
  - Load: 61.0 at the start and 47.5 at the end; the per-minute mean was 57.5.
- (c), the step 1 tool on `279c229`, which differs from 3f9f9e1 by one comment under Sources.
  - 287.2 s wall (4 min 47 s); user 397 s, sys 100 s. The adopters step took 95 s.
  - All 18 migrations were revalidated. swift-nio, for one: "its 516 System declarations are unchanged".
  - Load: 47.5 at the start and 68.2 at the end; the per-minute mean was 76.1, max 109. System's own indexed build took 117 s under that load, against 73 s in b1.
  - With the old tool, (c) is (a), a full rebuild: 1375.8 s.
- Both runs' adopter links are identical to the baseline's (`compare.py`): every `usedBy` and `calls` link, with its sites, and every hunk.
- What step 1 bought: after a change under Sources that leaves the declarations alone, 287 s instead of 1376 s, 4.8 times faster, and nothing is built.
  - With nothing to build, the adopters step's time is about a third site extraction for the 18 migrations (31 s in c1) and two thirds the would-benefit scan of 99 packages (64 s). That scan is outside this lane's steps.
  - The rest of the run is fixed costs, mostly api-delta and System's indexed build: 75 to 120 s, depending on load.

## Step 2: persistent per-adopter build directories (committed `ae57686`; measured)

**What:**
- `API_GRAPH_BUILDS` (default `.build/api-graph-builds`) holds, per migration:
  - the export of its commit;
  - the exports of the clones its path dependencies name;
  - SwiftPM's scratch directory;
  - the last build's log;
  - `state.json`: commit, dependencies, compiler and settings, the manifest digest, the tools-version lowering, the size.
- System's export (`system/swift-system`) is shared.
- Re-exports and the build directory:
  - A package is re-exported only when its commit or a dependency's commit moves, and System's export only when the head commit moves.
  - `sync_export` stages a fresh `git archive`, rewrites the manifests in the stage, and moves in only the files that differ, dated now.
  - The build directory starts over when the compiler, the settings or the manifest changes.
- `read_store` skips records of files that are gone.
- A lock makes one run at a time build in a builds directory.
- Setting `API_GRAPH_BUILDS` empty keeps the old scratch builds.

**Design calls:** see `method.md`, decision 38.
- Rejected:
  - the builds under the cache directory;
  - fresh exports into a kept build directory (every file would look changed);
  - `git worktree` checkouts of the clones, which would write into the clones' repositories;
  - one export of each dependency clone shared by every package that builds it.
- The tools-version lowering now applies only to manifests newer than the toolchain. The old code set every manifest to 6.2 when `dump-package` failed, which raised older ones too. In the baseline only WasmKit was lowered, and it declares 6.3, so today's migrations build the same.

**Finding: SwiftPM doesn't plan an incremental build again when a path dependency's files come or go.**
- Its package-structure check covers only the root packages' targets.
- Against a System commit without a file the last build compiled, the build failed with "couldn't build …/SystemPackage.build/sources because of missing inputs".
- A file System adds would be left out of the build silently.
- The fix is to date the root manifests now before an incremental build, which makes SwiftPM plan again. The rerun below confirms it.

**Check** (`check_builds.py`). The references were the same in every build that indexed.
- First run, before the fix. The load at its start was 17.5, 26.9 and 34.7 over 1, 5 and 15 minutes. The two build directories took 583 MB.
- Rerun, with the fix. The load was 83.3 at the start and 68.1 at the end. It passed all 16 checks, and the build directories took 582 MB.

| Build | swift-log, first | swift-log, rerun | swift-driver, first | swift-driver, rerun |
|---|---|---|---|---|
| cold, kept | 16 s | 19 s | 49 s | 42 s |
| again, nothing changed | 2 s | 2 s | 4 s | 4 s |
| System at 3f9f9e1's first parent (6 files under `Sources` differ) | failed, missing inputs | 13 s | failed, missing inputs | 27 s |
| back to 3f9f9e1 | 9 s | 12 s | 12 s | 20 s |
| cold, scratch (as before) | 17 s | 16 s | 50 s | 45 s |

These two packages are small, so an incremental build after a real System change saves little: most of it is recompiling SystemPackage and what imports it.

**Measurements** (the tool at `ae57686`, serial builds):
- s2-cold: every migration built cold into a fresh builds directory, with a fresh cache.
  - 1966.4 s wall (32 min 46 s); user 3712 s, sys 808 s. The adopters step took 1804 s.
  - Load: the per-minute mean was 116.9 (median 102, max 201), two and a half times the baseline's 47, and each build ran 1.2 to 2 times as long as the baseline's (swift-build 161 s against 91 s). So this time says nothing about step 2 against (a). It's the same cold builds, plus the build directories' `du`.
  - The 18 build directories take 11.8 GB. The largest are swift-package-manager's 1.7 GB, swift-foundation's 1.2 GB and swift-nio's 1.1 GB. That's less than the "several GB each" the design assumed.
- s2-incr: every migration rebuilt (`API_GRAPH_ADOPTER_VALIDATE=tree`) on `279c229`, the one-comment change, in the build directories s2-cold left.
  - 540.8 s wall (9 min 1 s); user 660 s, sys 159 s. The adopters step took 421 s.
  - All 18 builds were incremental, 8 to 54 s each (swift-foundation 54 s, swift-package-manager 43 s, wasmkit 37 s), 337 s in all. The same 18 builds took 1125 s cold in (a).
  - Each build recompiled one thing, SystemPackage. The rest of the time is SwiftPM planning again (the manifests are dated now) and checking the package's files.
  - Load: the per-minute mean was 23.7, half the baseline's.
- All three runs' adopter links (s2-cold, s2-incr and the check's builds) are identical to the baseline's.
- What step 2 bought: a rebuild that step 1 can't avoid (a failed build, a changed declaration, `tree`) costs what SwiftPM's incremental build costs, about a third of the cold builds here, instead of a cold build. It doesn't help the cold case, and it keeps 11.8 GB on disk.
- A possible next step: date the manifests only when System's or a dependency's list of files changed since the package's last build. Then a change inside existing files wouldn't make SwiftPM plan again. Not tried.

## Step 3: parallel adopter builds (committed `d1f856c`; measured)

**What:**
- Every plan is made first.
- A `ThreadPoolExecutor` then runs `API_GRAPH_ADOPTER_JOBS` workers (default 4, `--jobs`). The builds go first, longest first by the newest cache entry's `build.seconds`, with packages that have no entry ahead of them. The cached indexes follow.
- Each worker:
  - builds or reads one migration's index;
  - finds its sites with `migration_sites`, the old loop body, using its own `Conditions()`;
  - prints one line when it finishes.
- Sites and hunks are merged in key order, so adopters.json doesn't depend on which build finishes first.
- Index stores are read one at a time, and log lines are written whole.
- System's export is synced before the workers start.

**Design calls:** see `method.md`, decision 39.
- Rejected:
  - processes rather than threads;
  - ordering the builds by the migrations' path dependencies (each build compiles its own exports);
  - limiting each build's `-j` (not tried).
- A known gap: the free-disk check runs at each build's start, so builds running at once can together take the disk below the minimum.

**Measurements:**
- First d4: the working tree's tool before the commit, cold, 4 jobs, fresh cache and builds directory.
  - It built all 18, and its adopter links, sites and hunks are identical to the baseline's. Its build directories took 11.8 GB, as s2-cold's did.
  - 12466 s wall, but this isn't a measurement. The power log shows the machine entering clamshell sleep at 12:35, three minutes in, then dark wakes on and off until the run finished. Over the run, the power log has 24 Sleep entries, and the machine was on battery afterwards.
  - The load samples have gaps of up to 50 minutes, and their "load" of 191 (max 377) is the backlog at each wake.
  - With no cache entries, the order was alphabetical, as designed: unknown builds first.
- The runs before it, a-old to s2-incr, had no sleep in the power log, all on AC power.
- d4, rerun with the tool at `d1f856c`: cold, 4 jobs, fresh cache and builds directory.
  - 1059.2 s wall (17 min 39 s); user 3761 s, sys 855 s. The adopters step took 907 s.
  - No sleep, on battery throughout. Links identical to the baseline's.
  - Load: 45.4 at the start; the per-minute mean was 129.4 (median 108, max 268), about s2-cold's 117. At that load, 4 jobs cut the cold adopters step from s2-cold's 1804 s to 907 s, by about half, and the run from 1966 s to 1059 s.
  - Each build took 1.3 to 3.7 times as long as alone in the baseline (swift-foundation 485 s against 182 s), sharing the CPUs.
  - With no history the builds went alphabetically. wasmkit started last, at about 795 s, and ended the builds at 951 s; swift-foundation (485 s) and swift-package-manager (428 s) started in the middle. Longest-first needs a recorded build: the run with history checks what it buys.
- d18: cold, all 18 builds at once, fresh cache and builds directory.
  - 973.9 s wall (16 min 14 s); user 3878 s, sys 918 s. The adopters step took 791 s.
  - No sleep, on battery throughout. Links identical to the baseline's.
  - The builds finished between 344 s and 886 s into the run, with swift-foundation last (713 s).
  - Load: 33.2 at the start; the per-minute mean was 194.0 (median 209, max 395), the highest of any run. Swap reached 8.2 GB.
  - The build directories took 12.1 GB.
  - Against d4: 85 s less wall time at half again d4's load. Most of the gain is that no build waits to start.
- b3, (b) for the final tool: d18's cache and builds, nothing changed.
  - 382.8 s wall; the adopters step took 163 s, and all 18 were reused. Load 66.2.
  - Its migrations part took 27 s, as b1's did (26 s): the extraction is Python, which runs one thread at a time. The would-benefit scan took 134 s against 55 s at about twice the load.
  - b3 was the first run on the restored pin, so its matching links also check the pin.
- c3, (c) for the final tool, on `279c229`: 242.1 s wall; the adopters step took 77 s, and all 18 were revalidated. Load 43.2.
- i3, a forced rebuild (`tree`) on `279c229`, 4 jobs, in d18's build directories.
  - 330.5 s wall; the adopters step took 183 s.
  - All 18 were incremental, from swift-argument-parser's 9 s to swift-foundation's 76 s, all done within about 120 s. Serially, s2-incr's builds took about 370 s.
  - Load 36.5.
- d4h, cold with history: `cache-d4` for the order, a fresh builds directory, `tree` on `279c229`.
  - 1205.4 s wall; the adopters step took 896 s. Load 148.2.
  - It built 17, not 18: swift-syntax was reused from an entry the stopped run on the damaged pin had stored for `279c229`'s tree.
  - Longest first put swift-foundation (620 s) and swift-package-manager (559 s) in the first group. The builds still spanned about 810 s, as d4's alphabetical ones did. With the CPUs saturated by other lanes, order changed little, and this one run is no measurement of it.

## Tests

- `swift build && swift test` before: XCTest ran 565 tests with 4 skipped and 0 failures; swift-testing ran 496 tests in 80 suites, all passed.
- After, with steps 1 and 2 committed and step 3 in the working tree: the same. The lane changes no Swift.
- At the stop, on the merge of system-next `4365f83` with all three steps: XCTest ran 571 tests with 5 skipped and 0 failures; swift-testing ran 502 tests in 82 suites, all passed. The merge brought the extra tests.
- Script checks:
  - `bash -n`, `py_compile` and pyflakes. pyflakes caught a duplicated `builds` key in adopters.json's meta, which would have dropped the build directories' sizes. It was fixed before the step 2 commit, and the key is now `buildDirectories`.
  - `sync_export` against a scratch repository. Unchanged files kept their dates. It handled changed, removed and relinked files, a file that became a directory and back, and a cleared executable bit, and it kept `Package.resolved`.
  - `check_builds.py`, as above.
  - `compare.py` on every run (the table above).

## Findings

- SwiftPM's incremental builds and path dependencies: see step 2.
- macOS's `$TMPDIR` cleanup, live clones that move, and a closed lid: see Measurement setup.
- The auto mode classifier goes by allow rules, not by the conversation. Three runs were denied, the last after Michael approved them in chat. The allow rules for `measure.sh`, `check_builds.py` and `compare.py` in the worktree's `.claude/settings.local.json` cleared it. `measure.sh` takes its settings as `VAR=value` arguments, so that each command starts with the script.
- At these loads, a build sharing the CPUs took 1.3 to 4 times as long as it did alone. Parallel builds still won: at about the same load, 4 jobs halved the cold adopters step.
- The adopters' own extension members on System types, such as `s:13SystemPackage14FileDescriptorV5NIOFSE…`, carry System-prefixed USRs, but System's symbol graphs don't list them, so revalidation treats them as not System's. Implicit accessor references map to their properties.
