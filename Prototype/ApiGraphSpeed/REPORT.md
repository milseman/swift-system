# api-graph-speed: regenerate.sh fast after a System change

Lane `api-graph-speed`, base `3f9f9e1` (system-next). Owns `Utilities/api-graph/` and this report.

## Resume here

Stopped 2026-09-29 on a quota warning, partway through step 1.

**Committed:** only this report. No step is committed.

**In progress (uncommitted in the working tree): step 1, validating cached indexes.** The code is finished but hasn't run end to end.
- `scripts/adopters.py`:
  - `SystemDeclarations` fingerprints each public declaration in api-delta's head symbol graphs (`symbolgraphs/head`), by USR. A fingerprint covers the declaration fragments, availability, SPI, access, generics, extension constraints, and a type's conformances. An accessor USR maps to its property.
  - `Builder.plan` sets each migration's decision (`reused`, `revalidated` or `rebuild`) and the reason. `invalid` holds the checks, `system_block` is what an entry records about the System it was built against, and `store` writes one entry per commit, key and tree.
  - `follow_dependencies`: a migration that compiles another migration is revalidated only if that one is too.
  - `index(pkg, plan)`, the one-line log per migration, and `meta.decisions`.
  - The cache key no longer includes System's tree (`swift-system` rather than `swift-system@<tree>`). Entries from the old tool for the same tree are reused and upgraded with fingerprints.
- `regenerate.sh`: passes `--symbolgraphs "$DELTA/symbolgraphs/head"`, and `--validate` from `API_GRAPH_ADOPTER_VALIDATE` (`declarations`, the default, `interface` or `tree`).
- `scripts/graphq.py`: `GRAPH.md` gets a section, "The migrations' indexes" (decision, why, build).
- `README.md`: the new variable, and revalidation under Adopters. `scripts/method.md`: decision 19 rewritten, decision 37 added (what validation can't see, and the rejected alternatives), and an entry in "Where it's wrong".

**Checked so far:**
- `bash -n` and a Python compile of the edited scripts.
- `plan()` offline, against a copy of the baseline run's cache and 3f9f9e1's symbol graphs:
  - Old entries for the same tree were reused and upgraded.
  - Entries for eee1da2's tree were rebuilt, with the reason "cached by the previous version of this tool, which keyed on System's tree".
- The fingerprints cover every System-prefixed USR the 18 cached indexes reference, except the adopters' own extension members (NIO's `FileDescriptor.readChunk`, swift-build's `closeAfter`, Subprocess's `openDevNull`, …). That exception is intended.
- Against eee1da2's entries, one real change turned up: swift-foundation's `DirectoryWalk.init(_:path:order:opening:)` is gone in 3f9f9e1, so validation would rebuild swift-foundation after foundation-gaps.
- `swift test` hasn't been run yet, neither before nor after. I held it back so it wouldn't compete with the baseline run. My changes are Python, shell and docs only.

**Next:**
1. Finish step 1:
   - Pin the adopters and run the baseline, as described under the measurement setup below. That rebuilds the old-format cache for 3f9f9e1.
   - `b1`: the new tool on 3f9f9e1 with that cache. Expect all 18 migrations reused and upgraded.
   - `c1`: a scratch commit on this branch that changes one comment under `Sources`, then reverted. Expect all 18 revalidated.
   - Compare the snapshot's `usedBy` and `calls` links, with their sites, against the baseline's. Run `swift test`. Commit.
2. Step 2 (not started). Persistent builds under a new `API_GRAPH_BUILDS` (default `.build/api-graph-builds`, kept apart from the small cache):
   - `sync_export(repo, commit, dest, transform)`: `git archive` into a stage beside `dest`, apply the manifest rewrites (and the tools-version lowering, if the state records it; lower only when newer), then move in only the files that differ. Remove files the commit doesn't have, but keep a root `Package.resolved`.
   - A `state.json` per package: commit, dependency commits, compiler, settings, lowered, notes. Re-export only when the commit or the dependencies change. Wipe the build directory when the compiler, the settings or the root manifest change, because stale index units would otherwise remain.
   - `read_store` should skip units whose main file is gone.
   - One System export, `<builds>/system/swift-system`, synced under a lock.
   - Report each package's disk use (`du`) and the total.
3. Step 3 (not started):
   - Work out all the plans first, then run a `ThreadPoolExecutor` of `API_GRAPH_ADOPTER_JOBS` (default 4) over the builds, longest first by the newest cache entry's `build.seconds`, packages with no entry first.
   - Each worker builds and extracts its sites. Merge the per-package sites and hunks in sorted key order, so the output stays deterministic, and print one line per migration.
   - Give each worker its own `Conditions()`, since its parser state isn't thread-safe.
4. The measurements the lane asks for (a to d), plus an incremental forced rebuild (`API_GRAPH_ADOPTER_VALIDATE=tree` on the scratch commit) to show what step 2 buys.

**Measurement setup** (deleted at stop; recreate it like this):
- Why pin: `../adopters` is live. sourcekit-lsp and swift-corelibs-xctest were cloned into it at 14:42 during this session. So pin the adopters:
  - Run `git clone --no-checkout` of each clone into `${TMPDIR}api-graph-speed/adopters/<dir>`.
  - `git remote set-url origin` to the original clone's origin URL.
  - `update-ref` each of its local branches.
  - Check that each copy's merge base matches the original's.
- Keep the path the same: cache keys contain the path dependencies' absolute paths, so a moved adopters directory misses the cache too.
- Refs: `BASE_REF=1b452c2`, `HEAD_REF=3f9f9e1`. `API_GRAPH_SNAPSHOTS` should point at a store of your own (the shared `../api-graph-snapshots` must not be touched).
- Run the old tool from a `git archive` of `Utilities` inside this worktree's `.build`, so the working tree can change while it runs.
- `migrate-darwin` tips at the time: indexstore-db cc966b8901, swift-argument-parser 0fbda2766c, swift-async-algorithms bd5f6f4447, swift-build 56ad2d9772, swift-certificates 0df6bd14aa, swift-docc 6b1bfaa1fa, swift-driver ddb51ccd98, swift-foundation 763e42cd4a, swift-llbuild f7a0650b70, swift-log 4d6d77fe5c, swift-nio e1623fbfbe, swift-package-manager dbe05ec1e6, swift-sdk-generator 5956672b0e, swift-subprocess d6b586691b, swift-syntax 961f0b7231, swift-tools-protocols 18e8a9f93f, swift-tools-support-core 1ad4129f6c, WasmKit 4917e060cb. sourcekit-lsp and swift-corelibs-xctest had no migration commits.

**Baseline (a, old tool):** 29 min 9 s wall. Details are under "Step 1, measurements" below.

**Disk:** no persistent build directories exist yet (step 2 isn't started). `.build` and the scratch directory were deleted at stop.

## Step 1: validate cached indexes instead of keying on System's tree (in progress)

**What.**
- The cache key no longer includes System's tree.
- Each entry records the System commit and tree it was built against, System's manifest blob, and a fingerprint and name for each System declaration its references name.
- On a different tree, an entry is revalidated if the build succeeded, the manifest is unchanged, and every recorded fingerprint is unchanged. Otherwise the migration is rebuilt, and the reason lists the changed and gone declarations.

**Design calls:** `scripts/method.md`, decisions 19 and 37.
- The source is api-delta's symbol graphs, which cover the whole public API. graph.json only has the delta.
- A failed build is rebuilt whenever System moves.
- A manifest change forces a rebuild, since a platform or product change isn't in the symbol graphs.
- A path dependency on another migration is revalidated only if that migration is.
- Entries are kept per tree, so alternating between two heads doesn't thrash the cache.
- Rejected alternatives:
  - A whole-interface hash as the default. It would rebuild every migration on almost any merge. It's kept as the `interface` option.
  - Overload-set checks. A possible next step.
  - Lexical name matching.
  - Trusting the cache unchecked. That's `--builds reuse`.

**Measurements:** only the baseline so far.
- (a) with the old tool: 3f9f9e1 with eee1da2's cache and the pinned adopters. `time regenerate.sh` took 29 min 9 s wall (user 59 min 40 s, sys 12 min 34 s). The adopters step was 1570 s of that. All 18 migrations were rebuilt cold, one after another, since the tree changed.
- The machine was shared: the load average was 11 to 19 at the start and 15 to 45 at the end, from other lanes' builds. That's why this is slower than the 23 minutes measured earlier on eee1da2.
- The run exited 0, so it doubles as the "before" api-graph check.
- (b), (c) and (d) haven't been measured.

**Findings:**
- The adopters' own extension members on System types, such as `s:13SystemPackage14FileDescriptorV5NIOFSE…`, carry System-prefixed USRs. System's symbol graphs don't have them, so they're treated as not System's.
- Implicit accessor references map to their properties.

**Next:** see "Resume here".

## Step 2: persistent per-adopter build directories (not started)

Design notes are under "Resume here", item 2.

## Step 3: parallel adopter builds (not started)

Design notes are under "Resume here", item 3.
