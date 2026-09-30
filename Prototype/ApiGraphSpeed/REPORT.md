# api-graph-speed: regenerate.sh fast after a System change

Lane `api-graph-speed`, base `3f9f9e1` (system-next), merged with system-next `6a9833f` at `943c479` and `4365f83` at `2c474b4`. Owns `Utilities/api-graph/` and `Prototype/ApiGraphSpeed/`.

## Resume here

Stopped 2026-09-30, waiting for a permission rule. The auto mode classifier denied the lane's runs twice before Michael approved them in chat, and denied b1 again after he did: the classifier goes by permission rules, not by the conversation. Every remaining step needs these runs.

**Committed:**
- `943c479`: the merge of system-next `6a9833f` (coverage-2: `Utilities/adopter-coverage` and `Prototype/Status` only). It touched none of this lane's files, so it went in over the uncommitted step 1 work, without a WIP commit.
- `f12d631`: step 1, and the measurement tools `pin.sh`, `measure.sh`, `summarize.sh` and `compare.py`.
- `ae57686`: step 2, and `check_builds.py`.
- `279c229`: the scratch commit for c, which rewords one comment in `Syscalls.swift`, so its Sources differ from 3f9f9e1's by that line. `cdb9e87` reverts it. The measurements keep using `279c229` as a head commit.
- `2c474b4`: the merge of system-next `4365f83` (windows-api and others, which change Sources). It came after the scratch commit, so that commit's Sources are still 3f9f9e1's plus one comment. Its Utilities changes don't touch anything the api-graph tool reads: `derive.py`, `check.py`, `pathdeps.py`, `package.py` and `packages/` are unchanged.
- `e4a2730`: `measure.sh NAME [COMMIT] [VAR=value ...]`. Settings go as arguments, so that every run's command starts with the script.

**Uncommitted in the working tree:** step 3, parallel builds (`adopters.py`, `regenerate.sh`, `README.md`, `method.md` decision 39). It passes `bash -n`, `py_compile` and pyflakes, but it has never run.

**Denied** ("Blocked by fast classifier"). None of these was retried in another form:
1. `API_GRAPH_KEEP_WORK=1 Prototype/ApiGraphSpeed/measure.sh b1-step1 .build/speed/tools/step1`: the b run for step 1, with a copy of the step 1 tool in `.build`.
2. `python3 Prototype/ApiGraphSpeed/check_builds.py .build/speed/check-builds`: the rerun that checks the step 2 fix.
3. After the approval in chat, `Prototype/ApiGraphSpeed/measure.sh b1 f12d631`.

Earlier in the session, `measure.sh a-old HEAD` (the 23-minute baseline) and the first `check_builds.py` run went through. The runs need allow rules, which are the user's to add, in this worktree's `.claude/settings.local.json` (ignored by git):

```json
{
  "permissions": {
    "allow": [
      "Bash(Prototype/ApiGraphSpeed/measure.sh:*)",
      "Bash(python3 Prototype/ApiGraphSpeed/check_builds.py:*)",
      "Bash(python3 Prototype/ApiGraphSpeed/compare.py:*)"
    ]
  }
}
```

**Next, once they're allowed:**
1. `python3 Prototype/ApiGraphSpeed/check_builds.py .build/speed/check-builds`. Expect every check to pass, including the build against the other System commit, which failed before the fix.
2. b and c for step 1, then the comparison with the baseline's snapshot:
   - `measure.sh b1 f12d631`: 3f9f9e1 with the baseline's cache. Expect all 18 reused, and their entries upgraded.
   - `measure.sh c1 f12d631 HEAD_REF=279c229`: expect all 18 revalidated.
   - `compare.py .build/speed/runs/a-old/out/graph.json.gz .build/speed/runs/<run>/out/graph.json.gz` for each run.
3. Step 2:
   - `measure.sh s2-cold ae57686 API_GRAPH_CACHE=<fresh>`, which fills `.build/speed/builds`.
   - Then `measure.sh s2-incr ae57686 API_GRAPH_CACHE=<same> API_GRAPH_ADOPTER_VALIDATE=tree HEAD_REF=279c229`: a forced rebuild, incremental. That's what step 2 buys. Report the builds directory's size.
4. Step 3, the working tree's tool:
   - The cold case with `API_GRAPH_ADOPTER_JOBS=4`, then `=18`, each with a fresh cache and builds directory. Commit step 3 after the first one passes.
   - Then (b), nothing changed, and (c), `HEAD_REF=279c229`.
   - Update the README's "Run time".
5. At the stop, delete `.build/speed` and `${TMPDIR}api-graph-speed`. The exception is a persistent builds directory: keep it, and say where it is and how big.

**Kept for those runs** (scratch; delete it all if the lane stops here):
- `.build/speed/cache`: the baseline's old-format entries for 3f9f9e1's tree, which b1 upgrades.
- `.build/speed/runs/a-old/out`: the baseline's output and snapshot, which `compare.py` compares against.
- `.build/speed/snapshots`.
- `${TMPDIR}api-graph-speed`: the pinned inputs, as APFS clones that take almost no disk. The cache keys hold the pinned adopters' absolute paths, so a pin made anywhere else would miss the cache.

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

## Step 1: validate cached indexes instead of keying on System's tree (committed `f12d631`; b and c pending)

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
- (b) and (c): pending (denied).

## Step 2: persistent per-adopter build directories (committed `ae57686`)

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
- The fix is to date the root manifests now before an incremental build, which makes SwiftPM plan again. Its check is the denied rerun.

**Check** (`check_builds.py`, first run; the load at its start was 17.5, 26.9 and 34.7 over 1, 5 and 15 minutes). The references were the same in every build that indexed. The two build directories took 583 MB.

| Build | swift-log | swift-driver |
|---|---|---|
| cold, kept | 16 s | 49 s |
| again, nothing changed | 2 s | 4 s |
| System at 3f9f9e1's first parent (6 files under `Sources` differ) | failed, missing inputs | failed, missing inputs |
| back to 3f9f9e1 | 9 s | 12 s |
| cold, scratch (as before) | 17 s | 50 s |

## Step 3: parallel adopter builds (uncommitted; never run)

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
