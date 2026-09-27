# api-graph

`regenerate.sh` maps the public API that one commit adds over another, by default what `system-next` adds over `main`, into pieces that small pitches can carve out. It builds a graph of the added declarations, and from it:

- the graph's clusters;
- the parts of each cluster that could be pitched separately;
- the open design questions (contingencies) each depends on;
- a ranking of carve-outs, easiest first, that never puts one ahead of something it needs;
- a bundle per carve-out, input for an AI pitch-writing session.

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
| `API_GRAPH_WORK` | `.build/api-graph-work` | Scratch: both exports, api-delta's run, and the indexed build, about 900 MB. The next run deletes it. |
| `API_GRAPH_DELTA` | (run api-delta) | An existing api-delta output directory for the same two commits, to use instead of running api-delta. |
| `API_GRAPH_DRAFTS` | `../win32-drafts` | Draft proposals searched for prior text, beside the repository if present. Set it empty to skip. |
| `API_GRAPH_PREVIOUS` | the output's `api-graph.json` | A previous run to compare with. |

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
  - `sources.md`, `tests.md` and `samples.md`, which quote the code.

  `bundles/index.json` lists them in rank order. A bundle isn't a pitch.
- `api-graph.json`: clusters, parts, batches, promoted types, contingencies and the ranking. `graph.json` has every node, edge, atom, test and sample.
- `clusters.dot` and `atoms.dot`, for Graphviz: `dot -Tsvg .build/api-graph/clusters.dot > clusters.svg`.
- `api-delta/`, the api-delta report this run used, and `logs/`.

To start a pitch, give a session a carve-out's `bundle.md`, with `sources.md` and `tests.md` if it needs the code. For a big cluster, start from one of its parts; the cluster's bundle lists them.

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

About 65 seconds on an M1 Max with Swift 6.2, and up to twice that while other builds compete for the CPU. Most of it is api-delta's run (about 45 seconds) at the same time as the indexed build of the head commit with tests and Samples (about 45 seconds). The graph, clusters, bundles and report take about 8 seconds.

## Requirements

- macOS with Xcode's toolchain: `swift`, `xcrun`, and `libIndexStore.dylib`, which the index reader finds next to the toolchain's `swiftc`. The package needs Swift 6.1 or later; the tool was written and checked with Swift 6.2.
- `python3`. The scripts use only the standard library, ctypes included. The macOS system Python 3.9 works.
- No network. `--skip-update` resolves swift-argument-parser from SwiftPM's local cache. When the cache doesn't have it, Samples are left out of the build, as api-delta leaves them out, and samples are matched by name.
- `--disable-sandbox`, for the reason api-delta's README gives.
