# api-graph-speed: regenerate.sh fast after a System change

Lane `api-graph-speed`, base `3f9f9e1` (system-next), merged with system-next `6a9833f` at `943c479` and `4365f83` at `2c474b4`. Owns `Utilities/api-graph/` and `Prototype/ApiGraphSpeed/`.

## Resume here

2026-09-30: steps 1 and 2 are measured and checked; step 3 is committed, and its timed runs are in progress. The runs go through now, since Michael put the allow rules this report proposed into the worktree's `.claude/settings.local.json`. Before that, the auto mode classifier had denied three runs, one of them after Michael approved them in chat, because it goes by allow rules, not by the conversation.

**Committed:**
- `943c479`: the merge of system-next `6a9833f`.
- `f12d631`: step 1, with `pin.sh`, `measure.sh`, `summarize.sh` and `compare.py`.
- `ae57686`: step 2, with `check_builds.py`.
- `279c229`: the scratch commit for c. It rewords one comment in `Syscalls.swift`, so its Sources differ from 3f9f9e1's by that line. `cdb9e87` reverts it, and the measurements keep using `279c229` as a head commit.
- `2c474b4`: the merge of system-next `4365f83`. It came after the scratch commit, so that commit's Sources are still 3f9f9e1's plus one comment. None of the merge's Utilities changes touch what the api-graph tool reads.
- `e4a2730`: `measure.sh NAME [COMMIT] [VAR=value ...]`, so that every run's command starts with the script.
- `d1f856c`: step 3, parallel builds, with the docs' build sizes corrected to what step 2 measured.
- `1f204c8`: each run records its power source and its start and end, and `summarize.sh` flags a run the machine slept through.

**Done:**
- `check_builds.py` passes all 16 checks, the fix included.
- b1 and c1 match the baseline (step 1, below).
- s2-cold and s2-incr match it too (step 2, below). s2's builds directory is deleted.
- The first d4 run (step 3 cold, 4 jobs) built all 18, and its links match the baseline's. That's what step 3's commit rests on. Its time isn't a measurement, because the machine slept through it (step 3, below).

**Next:**
1. Step 3, the tool at `d1f856c` or later:
   - d4 again (in progress at 20:05): `measure.sh d4 API_GRAPH_ADOPTER_JOBS=4 API_GRAPH_CACHE=<speed>/cache-d4 API_GRAPH_BUILDS=<speed>/builds-d4`, after deleting both directories. Then delete `builds-d4`.
   - The same with `=18`, into `cache-d18` and `builds-d18`.
   - Then (b), nothing changed, (c), `HEAD_REF=279c229`, and a forced rebuild with 4 jobs, `API_GRAPH_ADOPTER_VALIDATE=tree HEAD_REF=279c229`, all three against `d18`'s cache and builds.
   - Update the README's "Run time".
2. At the stop, delete `.build/speed` and `${TMPDIR}api-graph-speed`, except a persistent builds directory, whose place and size go here.

**Scratch in use:**
- `.build/speed/cache`: the baseline's entries, upgraded by b1.
- `.build/speed/runs/*/out`: the runs' outputs and snapshots. `compare.py` compares against `a-old`'s.
- `.build/speed/snapshots`.
- `${TMPDIR}api-graph-speed`: the pinned inputs, as APFS clones, almost no disk. The cache keys hold the pinned adopters' absolute paths, so a pin anywhere else would miss the cache.

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

## Step 3: parallel adopter builds (committed `d1f856c`; being measured)

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

## Tests

- `swift build && swift test` before: XCTest ran 565 tests with 4 skipped and 0 failures; swift-testing ran 496 tests in 80 suites, all passed.
- After, with steps 1 and 2 committed and step 3 in the working tree: the same. The lane changes no Swift.
- Script checks:
  - `bash -n`, `py_compile` and pyflakes. pyflakes caught a duplicated `builds` key in adopters.json's meta, which would have dropped the build directories' sizes. It was fixed before the step 2 commit, and the key is now `buildDirectories`.
  - `sync_export` against a scratch repository. Unchanged files kept their dates. It handled changed, removed and relinked files, a file that became a directory and back, and a cleared executable bit, and it kept `Package.resolved`.
  - `check_builds.py`, as above.

## Findings

- SwiftPM's incremental builds and path dependencies: see step 2.
- The adopters' own extension members on System types, such as `s:13SystemPackage14FileDescriptorV5NIOFSE…`, carry System-prefixed USRs, but System's symbol graphs don't list them, so revalidation treats them as not System's. Implicit accessor references map to their properties.
