# api-graph: adopters for every carve-out

The `api-graph` lane (worktree `../api-graph`, branch `api-graph`) extends
`Utilities/api-graph` so each carve-out (cluster, part, batch) says which
adopters use its declarations and where, and which would benefit: the basis
for a strawperson adoption PR per pitch. Before this, the tool read only
System's sources, tests, samples, proposals and commits.

## Status and where to resume

- **Done** (commits `a33404f`..`c0fa578`): `scripts/adopters.py` (the
  adopters step), `scripts/reach.py` (aggregation, and a CLI to rank or
  filter by reach), the Adopters sections in `bundle.md`, `bundle.json` and
  `adopters.md`, the Adopters columns and the Adopter reach section in
  `API-GRAPH.md`, `regenerate.sh` wiring, README and method.
- **In progress**: the first full run on system-next `7b0875f` (it moved
  from `3d1e67d` during the session, which invalidated every cached
  adopter index, so all 14 migrations are being rebuilt), then merging
  local system-next, the spot-check, fixes, and the top 15 by reach.
- **To resume**: `Utilities/api-graph/regenerate.sh` (about 2 minutes with
  the adopter cache warm, 15-20 more when a migration or System's Sources
  moved), then read `.build/api-graph/API-GRAPH.md`'s Adopter reach section
  and `python3 Utilities/api-graph/scripts/reach.py`. Sections below marked
  *pending* are what's left.

## What

Two kinds of use sites for every new declaration (node of `graph.json`):

- **Adopted.** Packages migrated onto System on `migrate-darwin` in
  `../adopters` (14 so far: indexstore-db, swift-argument-parser,
  swift-async-algorithms, swift-certificates, swift-driver, swift-foundation,
  swift-log, swift-nio, swift-package-manager, swift-subprocess,
  swift-syntax, swift-tools-protocols, swift-tools-support-core, WasmKit; a
  15th clone, swift-build, has the branch with no commits yet). For each
  node: the files and lines of the branch that use it, and the hunk of the
  migration's diff (against the branch's merge base with the package's
  `main`) that introduced the use.
  - *Precise*: the branch's commit is exported and built against an export
    of the head commit, as the coverage tools' package file says, with an
    index store; the store's references to the node's USR are its sites.
  - *Lexical*: files the build doesn't compile (tests), added lines in `#if`
    branches Darwin doesn't take, and packages that don't build.
- **Would benefit.** Packages in `../ecosystem` (and clones in `../adopters`
  without a migration): the coverage tools' extraction of the C interfaces
  they use (`interfaces.json.gz` in `../coverage-results`), joined with the
  C names each declaration's doc comment gives, as adopter-coverage's
  `derive.py` reads them. Package, file, line, C interface.

Output: a per-bundle Adopters section (`bundle.md`, `bundle.json`, and
`adopters.md` with everything); in `API-GRAPH.md`, an Adopters column
(packages using / packages that would benefit) in the pitch order and the
cluster list, and an Adopter reach section (the packages, the carve-outs by
reach, each package's carve-outs); `reach.py` to rank or filter a run by
reach. Adding a package is a clone into `../ecosystem` or `../adopters`.

## Design calls

Each with the alternative it rejected; `Utilities/api-graph/scripts/method.md`
(decisions 18-25) has the full list.

1. **Precise sites from an indexed build of each migration against the
   head commit.** USRs tell overloads apart and see what the text doesn't
   spell (a use through a variable whose type the migration changed; an
   existing `sockaddr_storage()` that now resolves to System's
   `init(family:)` with a defaulted parameter).
   *Rejected:* name matching in the diff alone (can't tell `.lock()`s
   apart); the adopters' own `.build` index stores (working trees, not
   commits, and other lanes rebuild them); the coverage store's index dumps
   (only the packages' main commits).
2. **Build settings from the coverage tools' package files, read-only.**
   Targets (`:libraries`), flags, environment, and a newer compiler where
   the file says the default can't build it: swift-foundation builds with
   the swift.org snapshot in `~/Library/Developer/Toolchains` (Swift
   6.5-dev), and Xcode 6.2's libIndexStore reads its store.
   *Rejected:* a settings file of this tool's own, which would drift from
   the coverage lane's.
3. **Path dependencies point at commits**: swift-system at the head
   export, another migrated clone (swift-driver's swift-tools-support-core)
   at an export of its branch. The export's directory is named as the clone
   is, since a root package's identity is its directory's name and
   swift-argument-parser is also swift-system's dependency.
   *Rejected:* the coverage tools' `pathdeps.py rewrite` as is, which points
   non-System clones at their working trees.
4. **Cache the references, not the builds.** Keyed by package commit,
   System's Sources and manifest trees, the path dependencies' commits,
   compiler and settings; the build is deleted as soon as it's read.
   *Rejected:* keeping builds (SwiftPM's is 6 GB); rebuilding every run.
5. **Lexical matching is deliberately narrow**: added lines only; qualified
   type paths; unqualified names only when no base-commit declaration, no
   package declaration and no Swift-library declaration has them; a member
   only when all its fitting declarations are of one type; a call only when
   its labels supply the parameters, less defaulted ones.
   *Rejected:* building tests too (tens of minutes and gigabytes for NIO and
   SwiftPM, for code an adoption PR cares least about); broad matching,
   which attributed `.union(...)` to `SignalSet` and `.unspecified` to
   `PThread.QoSClass` in the first run.
6. **Would benefit joins the coverage tools' derivation, less what the base
   commit covers.** A package calling `read` or `stat` needs nothing new, so
   those don't make it a reason for the Span or Stat carve-outs. Restricted
   subjects (`fcntl` for one command) and derivation artifacts (`nil`,
   parameter names) are left out.
   *Rejected:* build_graph's own C names (every backticked name); joining
   everything the head covers.
7. **The interfaces come from the commit that matches best**: a
   migration's merge base when the store has it (NIO's does), else the
   ecosystem's clone. A package with no stored extraction is scanned
   lexically, so a new clone counts at once.
   *Rejected:* running the coverage tools from here, which needs package
   files in the coverage lane's directory.
8. **Reach is a view, not a score term.** Reach = packages using or
   benefiting; the pitch order is unchanged.
   *Rejected:* weighting the score by reach, which favors big clusters.

## Runtime

On an M1 Max, Swift 6.2, with other lanes building:

- First adopters run (nothing cached, system-next `3d1e67d`): 14.5 minutes,
  13 of 14 migrations built (swift-foundation then failed on a bad
  toolchain path, fixed); SwiftPM's build 221 s, the rest 22-63 s each.
- Second run (cache warm except swift-foundation and swift-argument-parser):
  8 minutes, 5 of them swift-foundation's build with the snapshot compiler.
- The would-benefit phase (two derivations, 37 packages' interface data):
  about a minute. *Pending:* the warm-cache full run's time.

## Spot-check

*Pending*: 10 sites across 3 packages, checked by hand against the commits.

## Known misses

- Adopted sites are precise only where the macOS build compiles; tests and
  other platforms' branches are lexical, and the narrow rules miss common
  member names there (`try mutex.lock()`).
- A migration branch moves while other lanes work; each run records the
  commit it read (swift-subprocess and SwiftPM moved during this session).
- Would-benefit sites are at the extraction's commit; when that's the
  ecosystem clone's rather than the merge base, lines are mapped to the
  branch by a diff that says only whether the line survives.
- *Pending*: what the spot-check finds.

## For the coverage lane

Nothing needed yet. (Noted: `derive.py` reads `nil` in "with `UTIME_OMIT`
for a `nil` time" and `value` in "the 8 bytes of `value`" as argument C
names; harmless for the coverage checks, filtered here.)
