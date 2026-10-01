# api-graph

`regenerate.sh` builds the **graph** of the public API that one commit adds over another, by default what `system-next` adds over `main`: every new declaration, the base and external types they build on, typed links between them (membership, nesting, extension, conformance, signature use, the C functions they wrap, shared implementation, blocks, tests, samples), and each declaration's adopter reach: which packages already use it on their migration branch, with file, line and the hunk that introduced the use, and which call the C interface it covers. The graph is the product, saved as a snapshot per commit, with diffs and a query command.

On top of it:

- **Pitches** are hand-curated files, `Prototype/Pitches/<id>.json`, each naming a set of the graph's declarations by rules. The tool checks them together (coverage, overlaps, prerequisites, pattern fit, what changed since the last snapshot) and writes a bundle per pitch for a pitch-writing session, with real adopter examples.
- **Suggestions**: the automatic clustering this tool started with proposes carve-outs, ranks them, and drafts pitch files for the leading ones no pitch covers. It never overrides the pitch files.
- **Domains**: a hand-kept grouping of C families by task, after *Advanced Programming in the UNIX Environment*, suggests related API the links don't connect.

The graph's schema and the pitch file format are in `Prototype/ApiGraph/REPORT.md`, sections 1 and 2. The tool is built on `Utilities/api-delta` (it runs api-delta, and imports its scanner and diff parser) and on `Utilities/adopter-coverage` (it imports its C-name derivation and package files, read-only).

## Running it

```sh
Utilities/api-graph/regenerate.sh                                     # main vs system-next
BASE_REF=main HEAD_REF=HEAD Utilities/api-graph/regenerate.sh         # main vs your HEAD
BASE_REF=main HEAD_REF=posix-more Utilities/api-graph/regenerate.sh   # the graph after a lane merges
open .build/api-graph/API-GRAPH.md                                    # the index
```

| Variable | Default | |
|---|---|---|
| `BASE_REF` | `main` | The commit to compare against. |
| `HEAD_REF` | `system-next` | The commit to map. |
| `API_GRAPH_OUT` | `.build/api-graph` | The output. Each successful run replaces it. |
| `API_GRAPH_WORK` | `.build/api-graph-work` | Scratch: both exports, api-delta's run, and the indexed build, about 1.3 GB (and, with `API_GRAPH_BUILDS` empty, one adopter's build at a time, up to about 2 GB). It's deleted when the run succeeds, and by the next run when it doesn't. |
| `API_GRAPH_KEEP_WORK` | unset | `1` keeps the scratch directory after a successful run. |
| `API_GRAPH_SNAPSHOTS` | `../api-graph-snapshots` | The snapshot store: one graph per head commit, and an index. It sits beside the repository, so it outlives worktrees. Set it empty to keep only the output's copy. |
| `API_GRAPH_SNAPSHOT_PREVIOUS` | the store's previous snapshot of the same head ref | A snapshot to diff with, and to check the pitches' changes against. |
| `API_GRAPH_PITCHES` | `Prototype/Pitches` | The pitch files, read from the working tree, since pitch chats edit them between commits. |
| `API_GRAPH_DELTA` | (run api-delta) | An existing api-delta output directory for the same two commits, to use instead of running api-delta. |
| `API_GRAPH_DRAFTS` | `../win32-drafts` | Draft proposals searched for prior text, beside the repository if present. Set it empty to skip. |
| `API_GRAPH_PREVIOUS` | the output's `suggestions.json` | A previous run's suggestions to compare the clustering with. |
| `API_GRAPH_ADOPTERS` | `../adopters` | Clones of packages migrated onto System, each on a branch. |
| `API_GRAPH_ECOSYSTEM` | `../ecosystem` | Clones of packages that might be. Set this and `API_GRAPH_ADOPTERS` empty to skip the adopters step. |
| `API_GRAPH_COVERAGE_RESULTS` | `../coverage-results` | The coverage tools' results store, for the packages' C interfaces. |
| `API_GRAPH_ADOPTER_BRANCH` | `migrate-darwin` | The migration branch. |
| `API_GRAPH_ADOPTER_BUILDS` | `build` | `build` builds a migration whose index isn't cached; `reuse` takes any cached index of its commit and builds nothing; `none` matches lexically only. |
| `API_GRAPH_ADOPTER_JOBS` | `4` | How many migrations are built at a time, longest first by each one's last recorded build. Each build runs as many compiler jobs as SwiftPM does on its own. |
| `API_GRAPH_ADOPTER_VALIDATE` | `declarations` | When System has moved since a migration's index was cached: `declarations` reuses the index if every System declaration it names is unchanged (revalidated), `interface` if System's whole public interface is, and `tree` never does, rebuilding whenever System's sources change. |
| `API_GRAPH_CACHE` | `.build/api-graph-cache` | The migrations' cached index references, a few MB: one entry per package commit, build settings and System tree built against. Deleting it costs a rebuild. |
| `API_GRAPH_BUILDS` | `.build/api-graph-builds` | The migrations' build directories, kept so that a rebuild is incremental: one per package, with its export, SwiftPM's scratch directory and the last build's log, and System's export, which every build points at. Up to about 2 GB each; `GRAPH.md` gives the total. Deleting it costs cold builds. Set it empty to build each migration in the scratch directory and delete the build once it's read. |
| `API_GRAPH_MIN_FREE_GB` | `15` | No adopter build starts with less free disk than this; the package is then matched lexically. |

Refs resolve as in api-delta: in the worktree you run the script from, so `HEAD` is that worktree's. System's commits are exported with `git archive`, and the adopters' with `git archive` and `git show`, never from a working tree; only the pitch files are read from the working tree. Nothing tracked is modified, and the script deletes only directories it created.

## What it produces

In `API_GRAPH_OUT`:

- `API-GRAPH.md`: the index, one line per report.
- **The graph**:
  - `graph.json.gz`, the snapshot: nodes, links and the adopters' hunks (schema: `Prototype/ApiGraph/REPORT.md`, section 1), also filed in the snapshot store;
  - `GRAPH.md`: counts by node and link kind, the declarations the most packages use and could use, the packages, the domains, and how to query it;
  - `DIFF.md` and `diff.json`: nodes and links added, removed and changed since the store's previous snapshot of the same head ref.
- **The pitches**:
  - `PITCHES.md` and `pitches.json`: every pitch file resolved and checked;
  - `pitches/<id>/`, a bundle per pitch file: `bundle.md` (the brief, including the pitch file's rules and what they matched, open questions, prerequisites, declarations, source ranges, tests, samples, adopter examples with the hunks that introduced them, related API by domain, prior text and commit messages), `bundle.json`, `sources.md`, `tests.md`, `samples.md` and `adopters.md`.
- **The suggestions**:
  - `SUGGESTIONS.md` and `suggestions.json`: the clustering's carve-outs (clusters, parts, batches), their open questions, a suggested order, how much of each the pitch files already cover, candidate pitches, adopter reach, and "How this was generated" (`scripts/method.md`, every design decision with the alternative it rejected, and where the tool is wrong);
  - `suggestions/<id>/`, a bundle per suggested carve-out, and `suggestions/drafts/<id>.json`, a draft pitch file for every suggestion no pitch covers yet;
  - `clusters.dot` and `atoms.dot`, for Graphviz.
- `adopters.json`: the packages, their builds, and every adopted and would-benefit site; `api-delta/`, the api-delta report this run used; `logs/`.

## Querying the graph

```sh
python3 Utilities/api-graph/scripts/graphq.py show 'PThread.Mutex.lock()'        # a node and its links, by kind
python3 Utilities/api-graph/scripts/graphq.py type ProcessID --members --sites   # a type, its members, their reach
python3 Utilities/api-graph/scripts/graphq.py neighbors KernelQueue --kind memberOf,usesInSignature --depth 2
python3 Utilities/api-graph/scripts/graphq.py family chmod                       # chmod, fchmod, lchmod, fchmodat
python3 Utilities/api-graph/scripts/graphq.py cname getpid                       # who wraps getpid; who calls it
python3 Utilities/api-graph/scripts/graphq.py package swift-nio                  # what swift-nio uses, and could
python3 Utilities/api-graph/scripts/graphq.py domain signals                     # a domain's declarations
python3 Utilities/api-graph/scripts/graphq.py diff OLD_COMMIT NEW_COMMIT         # two snapshots from the store
```

`--snapshot` picks a snapshot file or a commit the store has one of; the default is the last run's. `--json` prints any answer as JSON. The derived link kinds (`sameCFamily`, `sameImplementation`, `sameBlock`, `sameMark`, `couldUse`) are computed at query time.

## Pitch files

A pitch chat edits `Prototype/Pitches/<id>.json`, reruns `regenerate.sh`, and reads `PITCHES.md` and `pitches/<id>/bundle.md`. The format, the rules (IDs, paths, types with or without their members, the members of a type, a C function family, C names, a regular expression; any narrowed by file or MARK) and the patterns are in `Prototype/ApiGraph/REPORT.md`, section 2. The examples there, one per pattern, are real files in `Prototype/Pitches`. The tool never writes pitch files; `suggestions/drafts/` holds drafts to copy.

## Adopters

For each declaration, and so for each pitch and suggestion:

- **Adopted**: where a package's migration branch (`migrate-darwin`) uses the declaration, file and line, with the hunk of the migration's diff (against the branch's merge base with the package's `main`) that introduced each use. A site is `precise` when the compiler's index resolved it: the tool exports the branch's commit, points its swift-system dependency at an export of the head commit, and builds it with an index store as the coverage tools build that package. Files the build doesn't compile (tests), lines in `#if` branches Darwin doesn't take, and packages that don't build are matched by name, `lexical`.
  - The index is cached. When System has moved since, it's *revalidated*: kept if System's manifest and every System declaration it names are unchanged in the head commit's symbol graphs, and rebuilt otherwise. A use that would now resolve to a declaration System added isn't seen until the migration is rebuilt (`scripts/method.md`, decision 37). `GRAPH.md` lists each migration's index as reused, revalidated or rebuilt, and why.
  - A rebuild is incremental: the build directory is kept, and the exports it builds are updated in place, only the files that changed (decision 38).
- **Could use**: where a package calls a C interface the declaration newly wraps, from the coverage tools' extraction (`interfaces.json.gz` in their results store) joined with the C names in the declarations' doc comments. C names the base commit already covers don't count.

**To add a package, clone it into `../ecosystem`, or, with a migration branch, into `../adopters`.** The next run picks it up. A clone's identity is its origin URL, so a package cloned in both is one package. A migration is built as the coverage tools' package file for it says (`Utilities/adopter-coverage/packages/`), or with a plain `swift build` when there's none. Its C interfaces are the coverage tools' extraction of its commit when their store has one, and a lexical scan of its library sources until then; `Utilities/adopter-coverage/ecosystem.sh survey` and `run` produce the extraction.

`scripts/reach.py` ranks or filters the suggestions by reach: `--package swift-nio`, `--min 3`, `--kind part`, `--sort using|benefit|sites|rank`, `--json`.

## How the graph changes as lanes merge

Each run files a snapshot of the head commit, and `DIFF.md` compares it with the store's previous snapshot of the same head ref: declarations added and removed, declarations whose signature, availability, platforms or reach changed, and links added, removed and changed. `PITCHES.md` says, for each pitch, which declarations its rules match now and didn't, which they no longer match, and which it includes changed.

To see what a lane will change before it merges, map its branch: `HEAD_REF=<lane>`, and diff the two snapshots with `graphq.py diff`.

The suggestions move too, and `SUGGESTIONS.md` compares its clusters with the previous run's:

- **New API joins an existing cluster, or makes a new one.** If it names an existing new type, it joins that type's cluster. If it uses a type from several other places, that type gets promoted to shared vocabulary and becomes a cluster of its own; this is how ProcessID became vocabulary. (Promotion and link cutting apply to the suggestions only, not to the graph.)
- **Contingencies follow the code.** When a lane adds an owned type, a Span signature, or API that compiles on Windows, the declarations involved gain the question, and so does everything that needs them.
- **When a question is settled, edit `contingencies.json`.** Remove its entry, or narrow its rules.
- **When a lane builds or runs code off Darwin, add it to `evidence.json`.** Otherwise every platform other than Darwin stays "unverified".

## Tuning

- `domains.json`: the domains, each a list of C families or C names as shell globs. `GRAPH.md` lists the families no domain names.
- `contingencies.json`: the open questions, their decision numbers, and their rules. Each rule is one of the kinds its comment lists, with a weight, and `inherit: false` for platform facts.
- `evidence.json`: what's been checked on which platform, and how.
- `config.json`: the suggestions' promotion threshold, types to promote or never promote, the size above which a cluster's parts are ranked too, and the ranking weights.

Each is read at run time; nothing else needs editing.

## Run time

About four minutes on an M1 Max with Swift 6.2 when every adopter index is cached, and up to twice that while other builds compete for the CPU: api-delta's run and the indexed build of the head commit (about 45 seconds each, at the same time), the adopters step (one to three minutes: 58 packages' interface data, some of it scanned lexically), and the snapshot, pitches, suggestions and bundles (about 40 seconds). A migration whose index isn't cached is built: 20 seconds to 5 minutes each (swift-foundation's and SwiftPM's are the longest), about 25 minutes for all 15.

## Requirements

- macOS with Xcode's toolchain: `swift`, `xcrun`, and `libIndexStore.dylib`, which the index reader finds next to the toolchain's `swiftc`. The package needs Swift 6.1 or later; the tool was written and checked with Swift 6.2.
- `python3`. The scripts use only the standard library, ctypes included. The macOS system Python 3.9 works.
- No network for System's side. `--skip-update` resolves swift-argument-parser from SwiftPM's local cache. When the cache doesn't have it, Samples are left out of the build, as api-delta leaves them out, and samples are matched by name. An adopter's build resolves its dependencies as `swift build` does, from SwiftPM's cache or the network.
- For swift-foundation's migration, a swift.org toolchain in `~/Library/Developer/Toolchains` (its package file says it needs a newer compiler than Swift 6.2); `FOUNDATION_SWIFT_EXEC` names another `swiftc`, as for the coverage tools.
- `--disable-sandbox`, for the reason api-delta's README gives.
