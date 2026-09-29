# api-graph

`regenerate.sh` maps the public API that one commit adds over another, by default what `system-next` adds over `main`, into pieces that small pitches can carve out. It builds a graph of the added declarations, and from it:

- the graph's clusters;
- the parts of each cluster that could be pitched separately;
- the open design questions (contingencies) each depends on;
- a ranking of carve-outs, easiest first, that never puts one ahead of something it needs;
- a bundle per carve-out, input for an AI pitch-writing session;
- for each carve-out, which other packages use its declarations on their migration branch, and which call the C interfaces it wraps: the basis for a strawperson adoption PR per pitch.

It's built on `Utilities/api-delta`: it runs api-delta for the same two commits, and imports its source scanner and diff parser.

## Running it

```sh
Utilities/api-graph/regenerate.sh                                     # main vs system-next
BASE_REF=main HEAD_REF=HEAD Utilities/api-graph/regenerate.sh         # main vs your HEAD
BASE_REF=main HEAD_REF=posix-more Utilities/api-graph/regenerate.sh   # the map after a lane merges
open .build/api-graph/API-GRAPH.md
```

| Variable | Default | |
|---|---|---|
| `BASE_REF` | `main` | The commit to compare against. |
| `HEAD_REF` | `system-next` | The commit to map. |
| `API_GRAPH_OUT` | `.build/api-graph` | The output. Each successful run replaces it. |
| `API_GRAPH_WORK` | `.build/api-graph-work` | Scratch: both exports, api-delta's run, and the indexed build, about 1.3 GB, and one adopter's build at a time, up to 6 GB (SwiftPM's). It's deleted when the run succeeds, and by the next run when it doesn't. |
| `API_GRAPH_DELTA` | (run api-delta) | An existing api-delta output directory for the same two commits, to use instead of running api-delta. |
| `API_GRAPH_DRAFTS` | `../win32-drafts` | Draft proposals searched for prior text, beside the repository if present. Set it empty to skip. |
| `API_GRAPH_PREVIOUS` | the output's `api-graph.json` | A previous run to compare with. |
| `API_GRAPH_ADOPTERS` | `../adopters` | Clones of packages migrated onto System, each on a branch. |
| `API_GRAPH_ECOSYSTEM` | `../ecosystem` | Clones of packages that might be. Set this and `API_GRAPH_ADOPTERS` empty to skip the adopters step. |
| `API_GRAPH_COVERAGE_RESULTS` | `../coverage-results` | The coverage tools' results store (`Utilities/adopter-coverage`), for the packages' C interfaces. |
| `API_GRAPH_ADOPTER_BRANCH` | `migrate-darwin` | The migration branch. |
| `API_GRAPH_ADOPTER_BUILDS` | `build` | `build` builds a migration whose index isn't cached; `reuse` takes any cached index of its commit and builds nothing; `none` matches lexically only. |
| `API_GRAPH_CACHE` | `.build/api-graph-cache` | The migrations' cached index references, a few MB. Deleting it costs a rebuild. |
| `API_GRAPH_MIN_FREE_GB` | `15` | No adopter build starts with less free disk than this; the package is then matched lexically. |
| `API_GRAPH_KEEP_WORK` | unset | `1` keeps the scratch directory after a successful run; otherwise it's deleted. |

Refs resolve as in api-delta: in the worktree you run the script from, so `HEAD` is that worktree's. Only commits count, since each one is exported with `git archive`. Nothing tracked is modified, and the script deletes only directories it created.

## What it produces

In `API_GRAPH_OUT`:

- `API-GRAPH.md`, the map:
  - a summary;
  - the pitch order, with the top 15 and their reasons;
  - the clusters and their parts;
  - the open questions, with what settling each would free;
  - the shared vocabulary;
  - a cluster map;
  - this run's uncertain spots;
  - changes since the previous run;
  - "How this was generated" (`scripts/method.md`), which records each design decision with the alternative it rejected, and where the tool is wrong.
- `bundles/<id>/`, one per cluster, ranked part and batch:
  - `bundle.md`, the brief: size, platforms, what's been checked off Darwin, the open questions it depends on and why, what it needs, its declarations with their C counterparts, the source ranges (the API's blocks and the new internal code they reach), tests, samples, prior text (proposals, prototype write-ups, Win32 drafts, and the full messages of the commits that wrote the code), and the house format of `Proposals/`;
  - `bundle.json`, the same data, machine-readable;
  - `sources.md`, `tests.md` and `samples.md`, which quote the code;
  - `adopters.md`, every adopted and would-benefit site and every hunk (see Adopters below).

  `bundles/index.json` lists them in rank order. A bundle isn't a pitch.
- `api-graph.json`: clusters, parts, batches, promoted types, contingencies and the ranking, with each carve-out's adopter reach. `graph.json` has every node, edge, atom, test and sample, and `adopters.json` every package, build and site.
- `clusters.dot` and `atoms.dot`, for Graphviz: `dot -Tsvg .build/api-graph/clusters.dot > clusters.svg`.
- `api-delta/`, the api-delta report this run used, and `logs/`.

To start a pitch, give a session a carve-out's `bundle.md`, with `sources.md` and `tests.md` if it needs the code. For a big cluster, start from one of its parts; the cluster's bundle lists them.

## Adopters

Each bundle's Adopters section says, per package:

- **Adopted**: where the package's migration branch (`migrate-darwin`) uses the carve-out's declarations, file and line, with the hunk of the migration's diff (against the branch's merge base with the package's `main`) that introduced each use. A site is `precise` when the compiler's index resolved it: the tool exports the branch's commit, points its swift-system dependency at an export of the head commit, and builds it with an index store as the coverage tools build that package. Files the build doesn't compile (tests), lines in `#if` branches Darwin doesn't take, and packages that don't build are matched by name, `lexical`.
- **Would benefit**: where the package calls a C interface the carve-out newly wraps, from the coverage tools' extraction (`interfaces.json.gz` in their results store) joined with the C names in the declarations' doc comments. C names the base commit already covers don't count.

`API-GRAPH.md` has an Adopters column (packages using / packages that would benefit) in the pitch order and the cluster list, and an Adopter reach section: the packages, the carve-outs by reach, and each package's carve-outs. To rank or filter a run's carve-outs by reach:

```sh
python3 Utilities/api-graph/scripts/reach.py                       # all of them, widest reach first
python3 Utilities/api-graph/scripts/reach.py --package swift-nio   # what one package uses or would
python3 Utilities/api-graph/scripts/reach.py --min 3 --kind part   # parts reaching three packages or more
python3 Utilities/api-graph/scripts/reach.py --sort rank --json    # the pitch order, machine-readable
```

**To add a package, clone it into `../ecosystem`, or, with a migration branch, into `../adopters`.** The next run picks it up. A clone's identity is its origin URL, so a package cloned in both is one package. A migration is built as the coverage tools' package file for it says (`Utilities/adopter-coverage/packages/`), or with a plain `swift build` when there's none. Its C interfaces are the coverage tools' extraction of its commit when their store has one, and a lexical scan of its library sources until then; `Utilities/adopter-coverage/ecosystem.sh survey` and `run` produce the extraction.

The tool reads the clones' commits only (`git show`, `git archive`), never their working trees, and never writes to them.

## How the map changes as lanes merge

Each run compares itself with the previous run's `api-graph.json`, which is in the output directory until the run replaces it. The report's "Changes since the previous run" lists:

- new clusters, and clusters that are gone (merged into others, or removed);
- clusters that gained or lost declarations;
- clusters that now depend on an open question, or no longer do;
- moves of five or more places in the ranking, and moves into or out of the top 15.

Clusters are matched by id, and failing that by the declarations they share, so a renamed cluster isn't reported as a new one.

To see what a lane will change before it merges, map its branch: `HEAD_REF=<lane>`. To compare two such runs, point `API_GRAPH_OUT` at separate directories and `API_GRAPH_PREVIOUS` at the other one's `api-graph.json`.

What moves the map:

- **New API joins an existing cluster, or makes a new one.** If it names an existing new type, it joins that type's cluster. If it uses a type from several other places, that type gets promoted to shared vocabulary and becomes a cluster of its own; this is how ProcessID became vocabulary.
- **Contingencies follow the code.** When a lane adds an owned type, a Span signature, or API that compiles on Windows, the clusters involved gain the question, and so does everything that needs them.
- **When a question is settled, edit `contingencies.json`.** Remove its entry, or narrow its rules. The clusters that depended on it only (the report's "Would free" column) move up.
- **When a lane builds or runs code off Darwin, add it to `evidence.json`.** Otherwise every platform other than Darwin stays "unverified".
- **When the processes lane lands an owned child process, the reaping question (item 28) starts matching.** Its rules are already there.

## Tuning

- `config.json`: the promotion threshold, types to promote or never promote, the size above which a cluster's parts are ranked too, and the ranking weights.
- `contingencies.json`: the open questions, their decision numbers, and their rules. Each rule is one of the kinds its comment lists, with a weight, and `inherit: false` for platform facts.
- `evidence.json`: what's been checked on which platform, and how.

Each is read at run time; nothing else needs editing.

## Run time

About two minutes on an M1 Max with Swift 6.2, and up to twice that while other builds compete for the CPU. Most of it is api-delta's run (about 45 seconds) at the same time as the indexed build of the head commit with tests and Samples (about 45 seconds), and the adopters step, which takes about a minute when every migration's index is cached. A migration whose index isn't cached is built: 20 seconds to 4 minutes each (swift-foundation's and SwiftPM's are the longest), about 15 minutes for all 14. The graph, clusters, bundles and report take about 20 seconds.

## Requirements

- macOS with Xcode's toolchain: `swift`, `xcrun`, and `libIndexStore.dylib`, which the index reader finds next to the toolchain's `swiftc`. The package needs Swift 6.1 or later; the tool was written and checked with Swift 6.2.
- `python3`. The scripts use only the standard library, ctypes included. The macOS system Python 3.9 works.
- No network for the map itself. `--skip-update` resolves swift-argument-parser from SwiftPM's local cache. When the cache doesn't have it, Samples are left out of the build, as api-delta leaves them out, and samples are matched by name. An adopter's build resolves its dependencies as `swift build` does, from SwiftPM's cache or the network.
- For swift-foundation's migration, a swift.org toolchain in `~/Library/Developer/Toolchains` (its package file says it needs a newer compiler than Swift 6.2); `FOUNDATION_SWIFT_EXEC` names another `swiftc`, as for the coverage tools.
- `--disable-sandbox`, for the reason api-delta's README gives.
