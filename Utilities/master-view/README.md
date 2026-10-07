# master-view

`regenerate.sh` writes one self-contained page, `Prototype/MasterView/master.html`, that shows what `system-next` adds to Swift System on top of `main` and lets you explore it from the demand side: pick an API and see which packages use it; pick a package and see all the System API it uses and what it still needs from C. It's regenerated from commits and the sibling directories below; nothing on the page is typed by hand.

The page has three burn-down charts at the top, one search box and four filters, and two views over the same data:

- **By API**: area › type › declaration, for every public declaration `system-next` adds over `main`. Each shows the packages that use it (with each site, as file:line and the line itself) and its pitch state.
- **By package**: every package in the universe (below), by cluster. Each shows the System API it uses, new or already on main, what it still uses from C, and which kind of data it has.

The page is one file: its CSS, JavaScript and data are inline, a Content-Security-Policy blocks every network request, and it works opened as a file. It follows the system's light or dark setting (the Theme button overrides it). The declaration lists render lazily: areas and types open on a click, and a search renders at most 300 rows until you ask for all.

## Running it

```sh
Utilities/master-view/regenerate.sh            # everything, then the check (about 8 minutes from a clean checkout, 2 to rerun)
Utilities/master-view/regenerate.sh --check    # reconcile the last run's page; non-zero on any mismatch
Utilities/master-view/regenerate.sh --shots    # also the three screenshots in Prototype/MasterView/
open Prototype/MasterView/master.html
```

Settings are environment variables, or `NAME=value` arguments (so that a command-prefix allow rule matches the script):

| Variable | Default | |
|---|---|---|
| `BASE_REF`, `HEAD_REF` | `main`, `system-next` | The commits compared, as api-burndown takes them. |
| `MASTER_VIEW_OUT` | `.build/master-view` | Scratch, and the runs of api-burndown and status.sh. Must be ignored by git; the script refuses a directory it didn't make. |
| `MASTER_VIEW_PAGE` | `Prototype/MasterView/master.html` | The page. |
| `MASTER_VIEW_UNIVERSE` | `Utilities/master-view/universe.tsv` | The packages, rewritten each run. |
| `MASTER_VIEW_HISTORY` | `Prototype/MasterView/history.tsv` | The charts' points, one per chart per day. |
| `MASTER_VIEW_BURNDOWN` | (run it) | An api-burndown output directory to use instead of running api-burndown. |
| `MASTER_VIEW_STATUS` | (run it) | A directory with status.sh's `ledger.json` and `STATUS.md` to use instead of running status.sh. |
| `MASTER_VIEW_GRAPH_CACHE` | this worktree's `.build/api-graph-cache`, else `../swift-system/.build/api-graph-cache` | api-graph's adopter cache. |
| `MASTER_VIEW_ADOPTERS`, `_ECOSYSTEM`, `_EXAMPLES`, `_COVERAGE_RESULTS` | `../adopters`, `../ecosystem`, `../swift-system-examples`, `../coverage-results` | The sibling directories. |
| `MASTER_VIEW_TODAY` | today | The day the run counts as. |

The tracked files a run writes are the page, `universe.tsv` and `history.tsv`; commit them together when you publish the page. api-burndown runs with its output, scratch and page under `MASTER_VIEW_OUT`, so its own page (`Prototype/Burndown/burndown.html`) is left alone, and status.sh runs with `STATUS_OUT`, `STATUS_WORK` and `STATUS_LEDGER_JSON` there, so `Prototype/Status/STATUS.md` is too (if a run rewrote it anyway, the script restores it, provided it had no changes before). Nothing is fetched: git runs with lazy fetching off, and the tools it runs say the same of themselves.

## What it reads

From this repository, at its commits: the tools it runs or imports (below), `Prototype/Pitches/` and `Prototype/Burndown/states.json` (through api-burndown), and `Prototype/Status/STATUS.md`'s git history.

| Input | What for |
|---|---|
| **api-burndown** (`Utilities/api-burndown/regenerate.sh`, run) | `burndown.json`: every declaration api-delta lists as added, with its pitch state, area, C name, platforms, flags, and the per-day history (each declaration's state on each day). Its `api-delta/` directory: `api-delta.json` (the added count, each declaration's type) and the base commit's symbol graphs (main's public API). api-burndown's `unit_nodes` (imported) maps each declaration to its API graph node. |
| **The API graph** (the snapshot api-burndown chose, from `../api-graph-snapshots` or `.build/api-graph`) | `usedBy` links: each declaration's uses, by package, with their sites; each package's migration branch and commit (`adopted`). |
| **api-graph's adopter cache** (`../swift-system/.build/api-graph-cache`) | The index references of each migration's build, at the commit the graph read: the API already on main each migrated package uses. |
| **The ledger** (`Utilities/adopter-coverage/status.sh`, run) | `ledger.json` and its `STATUS.md`: every site in the update-checkout cluster still on a platform C module, with its category, C names and reason; and `STATUS.md`'s section 5, which the check compares with. |
| **`../adopters`** | Each migrated clone's branches (`migrate-all`, `migrate-unix`, `migrate-darwin`, `no-darwin`) and commits. |
| **`../ecosystem`** | `scheme-main.tsv`, `org-swiftlang.json`, `org-apple.json` and the clones, for the universe; `survey-popular.json`, the Darwin imports of the packages outside update-checkout. |
| **`../coverage-results`** | The coverage tools' newest ecosystem runs (`runs/*/POPULAR.json`, `ECOSYSTEM.json`), for the C names those packages use from Darwin. |
| **`../swift-system-examples`** | Its `main`: the tools (`Package.swift`'s `tools` table) and `GAPS.md`. |

## The universe

`scripts/universe.py` writes `universe.tsv`: one row per package, with its cluster, the list it comes from, its clone here (or `none`), its GitHub repository, whether it has Swift code (`yes`, `no`, or `?` with no clone to look in), and a note. A package's cluster:

- **update-checkout**: the repositories of `../ecosystem/scheme-main.tsv` (swift's `update-checkout`, main scheme), but swift-system. One with no `.swift` file but package manifests in its clone (cmark), or that `non-swift.tsv` lists (a hand-kept list of the C and C++ projects with no clone here: boringssl, llvm-project and the rest), is listed as having no Swift code, not dropped. Its clone is `../adopters`' if it has one, else `../ecosystem`'s.
- **swiftlang and apple**: the repositories of `org-swiftlang.json` and `org-apple.json` (snapshots of 2026-10-01), less archived ones, forks (unless update-checkout has the fork), System itself and anything update-checkout has. GitHub's `primaryLanguage` isn't used; a repository with no clone here is "not scanned yet". A name both organizations use (`.github`) becomes `owner/name`.
- **ecosystem (not yet picked)**: the clones in `../ecosystem` in neither list, labeled provisional.
- **Unix tools**: the tools in `../swift-system-examples`' `Package.swift`, on its `main`.

What's left out (archived repositories, forks, System itself) follows the rows, with cluster `excluded` and the reason; the page lists them under About.

## What each number on the page means

In the page's own words:

- **New API**: a public declaration in SystemPackage or SystemSockets that system-next has and main doesn't, exactly as api-delta lists it as added: the macOS symbol graphs' added entries, and the declarations its source scan finds besides (compiled only on other platforms, or renaming stubs). Overloads and per-platform variants count separately.
- **Counted**: the new API in the charts' count: all of it but renaming stubs (unavailable declarations that point from a C name to the Swift one) and deprecated, underscored and SPI declarations, as api-burndown counts.
- **Pitch states**: *not in a pitch*; *in a pitch draft* (a file in `Prototype/Pitches` includes it); *pitched* and *PR open* (dated in `Prototype/Burndown/states.json`); *merged* (main has it now).
- **Used by** a package: its migration branch uses the declaration. A **site** is a file and line where it does: found by the compiler's index of the migration's build, or "found by name" in code the build didn't compile. A type named only to qualify another name (`PThread` in `PThread.Mutex`) is a site "naming the type to qualify another name".
- **Already on main**: API main already has that a migrated package uses, from the same build's index (with `FileDescriptor.close()`, which system-next changed: "its signature changed on system-next"). It counts toward nothing but itself.
- **C uses left** (chart 3, and each update-checkout package): the ledger's sites, each import of a platform C module that `modules.ini` counts, at its file and line, or a `SYSTEM-GAP:` marker over none, excluded ones (test data, Apple's internal build) aside. Each has one category: *unexplained: System may cover it already*, *System lacks it*, *work queued*, *approved to stay on C* (exceptions), *undecided*, *not System's (a lane's verdict)*, *the standard library has it*. "C names System lacks here" are the names of a package's sites whose category is System lacks it.
- **Darwin C use** (packages outside update-checkout): the library files that import Darwin (the ecosystem survey), and the C names they use, as the coverage tools' newest ecosystem run found each then: *System has it*, *System lacks it*, *the standard library has it*, *another module has it*.
- **The kind of data** a package has: *migrated: real usage* (a migration branch with commits: its use of System, and what's left on C at its newest branch); *scanned: C use only* (no migration, but a scan of what it uses from C); *not scanned yet*; *no Swift code*.

The charts, one point per day, each counting down:

1. **New API not yet in a pitch**: counted declarations in no pitch file.
2. **Pitched, not yet merged**: counted declarations pitched or with a PR open. Flat at zero until the first pitch goes out.
3. **Platform C uses left in the toolchain's packages**: C uses left in the update-checkout cluster.

A chart's rise is never drawn as progress. **Scope added** is the part of a day's change that's new to what the chart counts: new API on system-next (charts 1 and 2), or a package read for the first time (chart 3); it's drawn as an orange riser of its own size from the day before's count, and the largest is labeled. The largest rise that isn't scope is labeled too ("not new scope"). Each chart's numbers, with every day's changes in words, are under "Show the numbers".

## The history file

`Prototype/MasterView/history.tsv` has one row per chart per day: the date, the chart, the count, the scope added, where it came from, the commit, and the day's details as JSON (the moves in words for charts 1 and 2; each repository's count, and their changes, for chart 3). Each run writes today's points (replacing an earlier run's today) and back-fills the days it has no point for: charts 1 and 2 from api-burndown's history, from the head ref's first day; chart 3 from `STATUS.md`'s git history, from the first day it had the ledger's section 5 (2026-10-05), the day's last commit. A point already in the file stands: it records what an earlier run showed.

## Checks and tests

`regenerate.sh` ends with the check that `--check` runs on its own (`scripts/check.py`). It fails if any of these doesn't hold:

1. The page is one file under 8 MB, with a Content-Security-Policy, loading nothing from the network, and it embeds `master.json`'s digest (and the digest is `master.json`'s content's).
2. New API: the page's declarations are api-delta's added set: as many, in each module, and each by module, path, file and line.
3. C uses left: the page's update-checkout total and each category's are `ledger.json`'s, and those are its `STATUS.md`'s section 5's (the excluded count too).
4. The two ways in agree: every declaration's uses (package and sites) appear under that package, and the reverse; and the page's uses are the API graph's `usedBy` sites, each once, less those of `FileDescriptor.close()`, a changed declaration, which the page counts as already on main.
5. The page's own counts: `model.js`, the page's data model, run in node on the page's own data, gives By API and By package the same uses and sites, in all and for each package, with no filter and with each cluster's, kind's, pitch state's and "used" filter; its headline figures (declarations, the main count by state, declarations used, C uses left) and each chart's last point are the totals above. Without node, the page's data is still recounted in Python, and the check says it didn't run the model.
6. The packages are `universe.tsv`'s, in order, and the history file has today's point for each chart, equal to the chart's.

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/master-view/scripts -p 'test_*.py'` tests the universe (clusters, exclusions, Swift-code detection, name clashes, on git repositories it makes), the STATUS.md and ledger readers, the charts' moves and scope, the history merge, use ownership, type groups, the main-API reader, GAPS.md, the Darwin scans, the page's encoding and one-pass rendering, and the check, passing and failing (a use missing from one view, a wrong ledger total, a declaration api-delta lacks, a network load, a stale digest, an edited `master.json`). Each test writes only under a temporary directory it deletes; its git repositories have remotes by URL only, and no global or system git configuration.

`scripts/snapshot.swift` renders the page in a WKWebView and writes a PNG (headless Chrome can't start here); it fails on any JavaScript error. `--shots` builds and runs it.

## Files

| File | |
|---|---|
| `regenerate.sh` | The driver. |
| `non-swift.tsv` | Repositories with no Swift code and no clone here (hand-kept). |
| `universe.tsv` | The packages (written by `scripts/universe.py`). |
| `scripts/assemble.py` | `master.json` from the inputs, and the history. |
| `scripts/page.py`, `page.html`, `page.css`, `model.js`, `ui.js` | The page. |
| `scripts/check.py` | The check. |
| `scripts/test_master_view.py` | The tests. |
| `scripts/snapshot.swift` | Screenshots. |

`Prototype/MasterView/REPORT.md` has the design calls, with the alternatives rejected, the data's known limits, and what the two ways in disagree about.
