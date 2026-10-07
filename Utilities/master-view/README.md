# master-view

`regenerate.sh` writes one self-contained page, `Prototype/MasterView/master.html`, built around two universes and where they meet. The **API universe** is everything `system-next` adds to Swift System on top of `main`: the superset of what System could be, which only grows, and which System may never ship whole. The **user universe** is the adopters (three library clusters: update-checkout, swiftlang and apple, ecosystem) and the examples' Unix tools (`../swift-system-examples`). The top of the page counts only the **intersection**; the explorer below covers both universes. It's regenerated from commits and the sibling directories below; nothing on the page is typed by hand but `set-aside.tsv` and `non-swift.tsv`.

The top has three cards:

- **New API in use**: the new declarations real users use, in all and by cluster, and for the examples; how many both use.
- **Used, not yet in a pitch**: of those, the ones no pitch file includes, with the pitch states of the rest.
- **Platform C uses left, and whose work they are**: by cluster, what the adopters still use from C, split into *System covers it* (the adopters' work), *System lacks it* (System's work) and *other*.

Each says what moved since the run before, and why. The total of new API is context, a plain number, never progress. Below them, one search box and four filters, and two views over the same data:

- **By API**: area › type › declaration, for every public declaration `system-next` adds over `main`. Each shows the packages that use it (with each site, as file:line and the line itself) and its pitch state.
- **By package**: every package in the universe (below), by cluster. Each shows the System API it uses, new or already on main, what it still uses from C (and whose work it is), and which kind of data it has. The examples' rows are their tools and the library target they share, each one directory of the repository.

The page is one file: its CSS, JavaScript and data are inline, a Content-Security-Policy blocks every network request, and it works opened as a file. It follows the system's light or dark setting (the Theme button overrides it). The declaration lists render lazily: areas and types open on a click, and a search renders at most 300 rows until you ask for all.

## Running it

```sh
Utilities/master-view/regenerate.sh            # everything, then the check (about 8 minutes from a clean checkout, 2 to rerun)
Utilities/master-view/regenerate.sh --check    # reconcile the last run's page; non-zero on any mismatch
Utilities/master-view/regenerate.sh --shots    # also the screenshots in Prototype/MasterView/
open Prototype/MasterView/master.html
```

Settings are environment variables, or `NAME=value` arguments (so that a command-prefix allow rule matches the script):

| Variable | Default | |
|---|---|---|
| `BASE_REF`, `HEAD_REF` | `main`, `system-next` | The commits compared, as api-burndown takes them. |
| `MASTER_VIEW_OUT` | `.build/master-view` | Scratch, and the runs of api-burndown and status.sh. Must be ignored by git; the script refuses a directory it didn't make. |
| `MASTER_VIEW_PAGE` | `Prototype/MasterView/master.html` | The page. |
| `MASTER_VIEW_UNIVERSE` | `Utilities/master-view/universe.tsv` | The packages, rewritten each run. |
| `MASTER_VIEW_HISTORY` | `Prototype/MasterView/history.tsv` | The figures' points, one per figure per day. |
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
| **The API graph** (the snapshot api-burndown chose, from `../api-graph-snapshots` or `.build/api-graph`) | `usedBy` links: each declaration's uses, by package, with their sites; each package's branch and commit (`adopted`): a migrated package's newest migration branch, and the examples' `main` (api-graph reads the examples as a package written on System). |
| **api-graph's adopter cache** (this worktree's `.build/api-graph-cache`, else `../swift-system`'s) | The index references of each build, at the commit the graph read: the API already on main each package uses. |
| **The ledger** (`Utilities/adopter-coverage/status.sh`, run) | `ledger.json` and its `STATUS.md`: every site in the update-checkout cluster still on a platform C module, with its category, C names and reason; and `STATUS.md`'s section 5, which the check compares with. |
| **`../adopters`** | Each migrated clone's branches (`migrate-all`, `migrate-unix`, `migrate-darwin`, `no-darwin`) and commits. |
| **`../ecosystem`** | `scheme-main.tsv`, `org-swiftlang.json`, `org-apple.json` and the clones, for the universe; `survey-popular.json`, the Darwin imports of the packages outside update-checkout. |
| **`../coverage-results`** | The coverage tools' newest ecosystem runs (`runs/*/POPULAR.json`, `ECOSYSTEM.json`), for the C names those packages use from Darwin. |
| **`../swift-system-examples`** | Its `main`: the tools (`Package.swift`'s `tools` table), the library targets they share, and `GAPS.md`. |
| **`set-aside.tsv`** (hand-kept) | Packages the page shows but keeps out of every figure at the top, with who set them aside, when, and why: swift-corelibs-foundation and swift-corelibs-xctest (Michael, 10-07). |

## The universe

`scripts/universe.py` writes `universe.tsv`: one row per package, with its cluster, the list it comes from, its clone here (or `none`), its GitHub repository, whether it has Swift code (`yes`, `no`, or `?` with no clone to look in), a note, and, for a row that's one target of a package, its directory (`subdir`). A package's cluster:

- **update-checkout**: the repositories of `../ecosystem/scheme-main.tsv` (swift's `update-checkout`, main scheme), but swift-system. One with no `.swift` file but package manifests in its clone (cmark), or that `non-swift.tsv` lists (a hand-kept list of the C and C++ projects with no clone here: boringssl, llvm-project and the rest), is listed as having no Swift code, not dropped. Its clone is `../adopters`' if it has one, else `../ecosystem`'s.
- **swiftlang and apple**: the repositories of `org-swiftlang.json` and `org-apple.json` (snapshots of 2026-10-01), less archived ones, forks (unless update-checkout has the fork), System itself and anything update-checkout has. GitHub's `primaryLanguage` isn't used; a repository with no clone here is "not scanned yet". A name both organizations use (`.github`) becomes `owner/name`.
- **ecosystem (not yet picked)**: the clones in `../ecosystem` in neither list, labeled provisional.
- **Unix tools** (the examples): the tools in `../swift-system-examples`' `Package.swift`, on its `main`, each `Sources/<Target>`, and the library targets they share (`ExamplesSupport`). The graph has the examples as one package; the page splits its uses among these rows by file.

What's left out (archived repositories, forks, System itself) follows the rows, with cluster `excluded` and the reason; the page lists them under About.

## What each number on the page means

In the page's own words:

- **New API**: a public declaration in SystemPackage or SystemSockets that system-next has and main doesn't, exactly as api-delta lists it as added: the macOS symbol graphs' added entries, and the declarations its source scan finds besides (compiled only on other platforms, or renaming stubs). Overloads and per-platform variants count separately. Its total is context: the universe only grows.
- **In use**: a new declaration a real user's code uses: an adopter (a package of the three library clusters, read at its newest migration branch, `migrate-all`, else `migrate-unix`, else `migrate-darwin`) or the examples (their tools and shared code, at `main`). A **site** is a file and line where it does: found by the compiler's index of the build, or "found by name" in code the build didn't compile. A type named only to qualify another name (`PThread` in `PThread.Mutex`) is a site "naming the type to qualify another name"; api-graph marks only types so.
- **Not yet in a pitch**: in use, in no pitch file, and not deprecated, underscored or SPI (which pitches leave out). The **pitch states**: *not in a pitch*; *in a pitch draft* (a file in `Prototype/Pitches` includes it); *pitched* and *PR open* (dated in `Prototype/Burndown/states.json`); *merged* (main has it now).
- **Already on main**: API main already has that a package uses, from the same build's index (with `FileDescriptor.close()`, which system-next changed: "its signature changed on system-next"). It counts toward nothing at the top.
- **C uses left**, by cluster, each in its own unit:
  - *update-checkout*: the ledger's sites, each import of a platform C module that `modules.ini` counts, at its file and line, or a `SYSTEM-GAP:` marker over none, on any platform, excluded ones (test data, Apple's internal build) aside.
  - *swiftlang and apple*, *ecosystem*: the library files that import Darwin or use its C names, from the coverage tools' newest ecosystem scans (Darwin and library targets only, dated on the page).
  - *the examples*: the gaps `GAPS.md` lists, each once however many tools need it.
- **The split** of C uses (`assemble.py`'s `ledger_bucket` and `scan_split`):
  - *System covers it* (the adopters' work): every C name the site or file uses, System covers. In the ledger, an unexplained site whose names System all covers, or a marker the ledger finds System now covers.
  - *System lacks it* (System's work first): a C name System lacks; a `SYSTEM-GAP` marker the ledger can't tie to a C name (the marker is the adopter's own note that System lacks something); work queued for System (`exceptions.ini`'s `work = System`); a gap in `GAPS.md`.
  - *Other*, neither yet: the standard library has it; work queued for the adopter; approved to stay on C; undecided; not System's (a lane's verdict); another module or the package's own C shim has it; no C name found; no build compiles it.
  
  A site or file takes the first of these that applies to any name it uses, as the ledger decides a site: a gap, then the standard library's or another module's answer, then covered.
- **Set aside**: a package of `set-aside.tsv`. The explorer shows it, marked, with the reason; it's in none of the figures at the top, which say how many of their sites they left out.
- **Since**: each figure's change from the history's point before, in words. For new API in use, each package's change and why it can have moved: *its branch moved* (adopter work), *read for the first time*, or *same commit* (System or the reading changed). For C uses, update-checkout's change by repository, and what's newly counted but not new C: a repository read for the first time, a `SYSTEM-GAP` marker added over C a package already used.
- **The kind of data** a package has: *migrated: real usage* (a migration branch with commits: its use of System, and what's left on C at its newest branch); *written on System: real usage* (the examples' tools); *scanned: C use only* (no migration, but a scan of what it uses from C); *not scanned yet*; *no Swift code*.
- **Use**, the explorer's filter: used by anyone, by adopters (any package of the three library clusters), by the examples, or by no one, among the packages the other filters leave in.

## The history file

`Prototype/MasterView/history.tsv` has one row per figure per day: the date, the figure, the count, what of it is newly counted but not new C (`scope_added`: for `cuses`, a repository read for the first time and markers over C already used; 0 for the others), where it came from, the commit, and the day's details as JSON. The figures are `used` (new API in use; with each group's count, and each package's count and commit), `unpitched-used` (in use, not in a pitch; with the pitch states) and `cuses` (the ledger's sites in update-checkout, set-aside packages too; with each repository's count, its markers, and from 2026-10-07 the split by cluster and the set-aside packages' counts). Each run writes today's points, replacing an earlier run's today, and back-fills `cuses` for the days it has no point for from `STATUS.md`'s git history (from 2026-10-05, the first day it had the ledger's section 5; the day's last commit). A point already in the file stands: it records what an earlier run showed. The earlier page's burn-down charts (`unpitched`, `pitched`) keep their rows, through 2026-10-06, and get no new ones.

## Checks and tests

`regenerate.sh` ends with the check that `--check` runs on its own (`scripts/check.py`). It fails if any of these doesn't hold:

1. The page is one file under 8 MB, with a Content-Security-Policy, loading nothing from the network, and it embeds `master.json`'s digest (and the digest is `master.json`'s content's).
2. New API: the page's declarations are api-delta's added set: as many, in each module, and each by module, path, file and line.
3. C uses left: the page's update-checkout total and each category's are `ledger.json`'s, and those are its `STATUS.md`'s section 5's (the excluded count too).
4. The two ways in agree: every declaration's uses (package and sites) appear under that package, and the reverse; and the page's uses are the API graph's `usedBy` sites, each once, less those of `FileDescriptor.close()`, a changed declaration, which the page counts as already on main, and less the examples' sites outside their rows' directories.
5. The headline, three ways: `master.json`'s, as `assemble.py` counts it from the packages' side; recounted from the declarations' side (who uses each), and update-checkout's split from `ledger.json`'s sites; and the page's own, which `model.js` counts from the page's data. The history's points for today are the headline's.
6. The page's own counts: `model.js`, run in node on the page's own data, gives By API and By package the same uses and sites, in all and for each package, with no filter and with each cluster's, kind's, pitch state's and use's filter (and adopters within one cluster); by anyone and by no one add up to all. Without node, the page's data is still recounted in Python, and the check says it didn't run the model.
7. The packages are `universe.tsv`'s, in order, and the history file has today's point for each figure, equal to the page's.

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/master-view/scripts -p 'test_*.py'` tests the universe (clusters, the examples' tools and shared target with their directories, exclusions, Swift-code detection, name clashes, on git repositories it makes), the STATUS.md and ledger readers, the split of ledger sites and of scanned files, the headline, the routing of a package's sites to the rows of its directories, the history's changes and merge, use ownership, type groups, the main-API reader, GAPS.md, the Darwin scans, the page's encoding and one-pass rendering, and the check, passing and failing (a use missing from one view, a wrong ledger total, a declaration api-delta lacks, a network load, a stale digest, an edited `master.json`, a headline the views don't have, an examples' site outside its rows). Each test writes only under a temporary directory it deletes; its git repositories have remotes by URL only, and no global or system git configuration.

`scripts/snapshot.swift` renders the page in a WKWebView and writes a PNG (headless Chrome can't start here); it fails on any JavaScript error. `--shots` builds and runs it: the top, light and dark, a declaration's users, and a package.

## Files

| File | |
|---|---|
| `regenerate.sh` | The driver. |
| `non-swift.tsv` | Repositories with no Swift code and no clone here (hand-kept). |
| `set-aside.tsv` | Packages kept out of the headline, with who, when and why (hand-kept). |
| `universe.tsv` | The packages (written by `scripts/universe.py`). |
| `scripts/assemble.py` | `master.json` from the inputs, and the history. |
| `scripts/page.py`, `page.html`, `page.css`, `model.js`, `ui.js` | The page. |
| `scripts/check.py` | The check. |
| `scripts/test_master_view.py` | The tests. |
| `scripts/snapshot.swift` | Screenshots. |

`Prototype/MasterView/REPORT.md` has the design calls, with the alternatives rejected, the data's known limits, and what the two ways in disagree about.
