# Master view: what system-next adds, and who needs it

**Status: done, 2026-10-06.** The page is `Prototype/MasterView/master.html`, from a run against `system-next` at `0e339dc` and `main` at `1b452c2`. The tool is `Utilities/master-view/` (its README says how to run it, what it reads, and what every number on the page means). Nothing is left to resume; section 7 lists what's needed outside this lane.

## 1. What

- **The page**: three burn-down charts (new API not yet in a pitch; pitched, not yet merged; platform C uses left in the toolchain's packages), one search box and four filters (packages' cluster, their kind of data, pitch state, use), and two views over the same data. *By API* is area › type › declaration for all of api-delta's added set; each declaration shows its users, each site with its line of code, and its pitch state. *By package* is every package of the universe by cluster; each shows the System API it uses (new, and already on main), what it still uses from C, and its kind of data. A declaration's detail can show "only these packages", a package's "these in By API", as a filter chip. Links (`#pkg=swift-nio`, `#decl=SystemPackage:ProcessID.current`) open either.
- **The tool**: `regenerate.sh` runs api-burndown and status.sh into its own scratch (`.build/master-view`), rebuilds `universe.tsv`, assembles `master.json` (`scripts/assemble.py`), writes the page (`scripts/page.py`: `page.html`, `page.css`, `model.js`, `ui.js`), and checks it (`scripts/check.py`, also `--check`). `--shots` takes the screenshots (`scripts/snapshot.swift`, a WKWebView).
- **Tracked outputs**: the page (1.7 MB), `Utilities/master-view/universe.tsv`, and `Prototype/MasterView/history.tsv` (the charts' points). A clean run took 473 s (api-burndown 144 s, status.sh with its release builds most of the rest); a rerun at the same commits, 136 s; one that reuses both runs (`MASTER_VIEW_BURNDOWN`, `MASTER_VIEW_STATUS`), about 15 s.

## 2. Design calls

Each with the alternatives rejected.

1. **The other tools run into this tool's scratch, not their defaults.** api-burndown gets `API_BURNDOWN_OUT`, `_WORK` and `_PAGE` under `.build/master-view`, and status.sh `STATUS_OUT`, `STATUS_WORK` and `STATUS_LEDGER_JSON`, so neither rewrites its tracked page or `STATUS.md`. api-burndown's `unit_nodes` is imported, not copied, to map declarations to graph nodes. *Rejected:* reading their last outputs in other worktrees (`../swift-system/.build`, `../coverage-7/.build/status`): they're for other commits, and owned by other lanes; recomputing the added set or the ledger.
2. **The unit of new API is api-delta's added entry** (graph entries plus hidden declarations, 5,204 at `0e339dc`), all of them in By API. The charts count api-burndown's main count, without renaming stubs and deprecated, underscored and SPI declarations; the page says how many it leaves out. *Rejected:* counting stubs in chart 1 (about 5% no one can call).
3. **A use belongs to one declaration.** api-burndown gives a declaration compiled only off Darwin its Darwin sibling's uses (they share a graph node); here they're counted once, under the Darwin declaration, and the variant says "uses counted under its variant", with a link. *Rejected:* api-burndown's copying, which counts 451 sites twice (3,677 against the graph's 3,226 at `dd30d5c`) and would make By package's sums twice By API's for those declarations.
4. **`FileDescriptor.close()`'s uses are "already on main".** api-delta lists it as changed (`throws` became `throws(Errno)`, so its USR changed), not added; api-graph makes it a head declaration with 37 uses in 10 packages. The page has no such new declaration, and counts those uses under each package's API already on main, marked "its signature changed on system-next". *Rejected:* adding it to By API (main has it); dropping the uses.
5. **API already on main comes from api-graph's adopter cache**: the index references of the very build the graph's uses come from (the cache file for the migration's commit built against the graph's System commit). A reference counts if main's symbol graphs have its USR, or it's a changed declaration's; implicit references are left out, as api-graph leaves them. *Rejected:* a lexical scan for main's names (`read`, `open`: too common to attribute); a new index build (minutes per package, and api-graph's job).
6. **"As a qualifier" is shown only for types.** api-graph marks any reference followed by `.` and another reference as a qualifier, so `ProcessID.current` in `ProcessID.current.rawValue` is one; the page counts every site and marks only a type's (the declaration's kind decides). *Rejected:* hiding qualifier sites (the type is used), or showing the flag as recorded (it tells the reader a property call isn't a use).
7. **Chart 3 counts every ledger site but excluded ones** (1,066 at `0e339dc`), exceptions and undecided sites included, so its total is the ledger's in `STATUS.md` (the check compares them); the subtitle says how many are approved to stay. *Rejected:* the floor's per-platform counts (eight figures, a site counted once per platform); leaving exceptions out (a total the ledger never states).
8. **Scope added is drawn, sized and labeled, never subtracted.** An orange riser of the day's scope added rises from the day before's count; the blue line is the count itself, so a day with both scope and progress shows both. The largest riser is labeled "+N scope added", and the largest rise that isn't scope "+N, not new scope". Every day's moves are in words under "Show the numbers" and in the tooltip. *Rejected:* a scope line over the count (charts growth); re-basing to a fixed scope (hides what was added: section 3); stacked columns per day (api-burndown's first page, which Michael dropped).
9. **For chart 3, scope added is a newly read package and newly marked C**: the sites of a repository the day before didn't read, and the SYSTEM-GAP markers over no import a repository gained (C it already used, which the ledger counts once marked). On 2026-10-06 that's 229 (swift-nio 192, swift-foundation 28, WasmKit 9), while 104 sites went (swift-build 63, swift-foundation 16, WasmKit 15, swift-nio 10): 941 → 1,066. *Rejected:* counting markers as ordinary sites, which drew the day as "+125, not new scope", a regression that didn't happen. Markers come from `ledger.json` today and from `STATUS.md`'s text for back-filled days (`markers_by_repo`; it matches `ledger.json` on today's file).
10. **The history file keeps each run's points.** A run writes today's points (replacing an earlier run's today), back-fills only the days the file lacks, and fills in only details a standing point lacks (when it counts the same). *Rejected:* recomputing every day each run (a day between two `STATUS.md` commits would lose the run's figure); several points a day.
11. **Each day is a band** in the step charts, so the last day's count is drawn too (with two days, chart 3's step would otherwise sit on the right edge).
12. **The universe file is regenerated each run**, rows in cluster order, then the excluded repositories with their reason. A name both organizations use (`.github`) becomes `owner/name`. "No Swift code": a clone with no `.swift` file but manifests, or `non-swift.tsv`, a hand-kept list of update-checkout's C and C++ projects with no clone. *Rejected:* survey.json's `package` flag (it says swift and libdispatch aren't packages, and they have Swift code); GitHub's `primaryLanguage` (the coordinator's rule: it mislabels Swift repositories).
13. **"Migrated" needs commits.** A package is migrated when its newest migration branch has a commit past its merge base with main; swift-corelibs-xctest's `migrate-darwin` has none, so it's "scanned: C use only". *Rejected:* any migration branch (a migrated package with no migration).
14. **Packages outside update-checkout show their Darwin C use from existing scans only**: the survey's library files that import Darwin, and the newest clean ecosystem run's names, as that run found them (2026-09-30, System at `cddd4d2`), dated on the page. *Rejected:* running the ledger's scan on their clones (new data, where the task says to use what exists); the coverage results' per-package `coverage.json`, which mixes in vendored C targets' interfaces.
15. **The search filters each view's own rows** (declarations by name, type, area, C name and kind; packages by name and repository), and says how many of the other view's rows match; a declaration or package scopes the other view through a chip. *Rejected:* matching across (a package's name pulling in its declarations), which made the same box mean two things.
16. **The filters are global**: cluster and kind of data scope which packages count (By package's rows, and By API's users); pitch state and use scope which declarations count (By API's rows, and By package's new API).
17. **The check runs the page's own model.** `model.js` (the data, indexes and filters, no DOM) is run in node on the data the page embeds, and its sums for both views, for each filter, are compared with each other and with the inputs. *Rejected:* rendering the page for the check (a browser engine; the WKWebView is used only for screenshots); recounting `master.json` alone (it wouldn't test the page).
18. **Web links only where GitHub has the commit**: a file at a clone's commit that a remote-tracking branch contains. Migration commits are local, so use sites and migrated packages' ledger sites have none.
19. **A declaration's link names it by module and name** (`SystemPackage:ProcessID.current`, `~2` for a second overload), not by position, so it survives a regeneration.

## 3. The scope-added question, for Michael

Chart 1 isn't flat: since 2026-09-22, new API has landed faster than pitches took it, and the chart rises from 263 to 4,780 in steps that are nearly all scope added (each labeled). Its falls are 2026-09-29's 171 declarations into pitch drafts, and a few a day that left system-next (renamed or removed), which aren't progress either. Chart 3 rose on its second day for the same kind of reason (design call 9). The page draws the count as it is, with scope added sized and labeled (design call 8). Open, with that as the default:

- **(a) As drawn**: the count, scope risers in orange.
- **(b) A fixed baseline**: count only what existed on a chosen day; new scope listed beside the chart as "added since". A classic burn-down, but the count stops being "what's left".
- **(c) A burn-up**: two lines, scope and done, on one axis. Shows both, but charts the scope growing.

Also open for chart 3: whether newly marked C (design call 9) is scope, as drawn, or a regression.

## 4. Known limits

- **Uses come only from `migrate-darwin` branches.** api-graph reads one branch name (`API_GRAPH_ADOPTER_BRANCH`, default `migrate-darwin`), so each migrated package's uses are older than its newest branch: all 22 migrated packages' newest branch is `migrate-unix` or `migrate-all`, and swift-crypto, swift-stress-tester and swift-testing, with no `migrate-darwin`, have none. The page lists them under About and says on each package which branch was read. *What api-graph would need:* `adopters.py`'s `discover` to take a newest-first list (`migrate-all,migrate-unix,migrate-darwin`, as status.sh's `STATUS_PLATFORM_BRANCHES`) and try each per clone (it records the branch it used already); `regenerate.sh` to pass it. Every package whose newest branch is past `migrate-darwin` would then rebuild (about 25 minutes cold, by its README); its lexical pass already covers lines in `#if` branches Darwin doesn't take, which the Unix branches add.
- **The graph lags the head**: the newest snapshot is `dd30d5c`, 17 commits before `0e339dc`; the 10 declarations added since show no uses (the page says so in its lede).
- **API already on main is the Darwin build's index only**; new API also has uses found by name outside the build.
- **Packages outside update-checkout** were scanned for Darwin imports in library targets only, on 2026-09-29 and 2026-09-30.
- **The Unix tools' use of System isn't scanned**; their gaps are GAPS.md's.
- **Chart 3 starts on 2026-10-05**, the first `STATUS.md` with the ledger; it moves when adopters' branches move, not only when System does.
- **No link for local commits** (design call 18).

## 5. Where the two ways in, and the inputs, disagree

At `0e339dc`, with the graph of `dd30d5c`:

- **By API and By package agree**: the check finds every use (1,403 declaration–package pairs, 3,189 sites) under its declaration and under its package, the same in all and per package, with no filter and with each cluster's, kind's, pitch state's, "used" and each package's and the most-used declaration's filter; and those sites are the graph's `usedBy` sites, each once, less `FileDescriptor.close()`'s 37.
- **api-burndown and this page count uses differently**: it gives 64 off-Darwin variants their Darwin sibling's uses (138 declarations share a node); this page counts them once (design call 3).
- **api-graph and this page differ on `FileDescriptor.close()`**: new API there, already on main here (design call 4).
- **api-graph's qualifier rule leaves real users out of its reach.** 261 of its 815 qualifier sites are on members, not types, and 147 `usedBy` links on members are all-qualifier (`qualifierOnly`), such as `FileStream.standardError` and `KernelEvent.fileDescriptor`; `snapshot.py`'s reach, and `graphq.py`'s users, skip `qualifierOnly` links, so those packages don't count as users there. This page counts them (design call 6).
- **The migration builds' indexes and the graph agree**: each references exactly the new declarations the graph says the package uses.
- **The universe and the inputs agree**: every package in the graph is in the universe; every repository the ledger reads is in the update-checkout cluster, and the reverse (16 of them not cloned, so not read, and swift read only within its sparse checkout); every use is by a package in the universe.
- **Migrated, with no use read**: swift-crypto, swift-stress-tester, swift-testing (section 4).
- **Two declarations named `CInterop.IOVec`**, one in SystemPackage and one in SystemSockets, both used by swift-nio. Not a page error; the page shows the module beside a SystemSockets declaration's name in package lists.
- **The universe moved during the session**: swift-system-examples' main went from 5 tools to 11 (other lanes merged find, du and the rest). The tools feed no chart, so it's no scope step.

## 6. Tests

`Utilities/master-view/scripts/test_master_view.py`, 23 tests: the universe on git repositories they make (clusters, exclusions, Swift-code detection, name clashes), the `STATUS.md` reader (categories, repositories, excluded ones, markers), the ledger reader, the charts' moves and scope (charts 1 to 3), the history merge, use ownership, type groups, the main-API reader, GAPS.md, the Darwin scans, the page's encoding and one-pass rendering, and the check passing (with node, running the page's model) and failing (a use missing from one view, a wrong ledger total, a declaration api-delta lacks, a network load, a stale digest, an edited `master.json`).

What they can touch, checked: every file goes under a `tempfile.mkdtemp` directory the test deletes in `tearDown` (`shutil.rmtree` of that directory only); the git repositories they make are `git init` there, with an `origin` that's a URL in their config (no fetch, push or clone), and run with `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` (no hooks, no signing); `check.run_model` writes one input file to its own temporary directory, runs node on it with a timeout, and deletes it; nothing signals a process or changes a permission. `snapshot.swift` writes only the PNG it's given; `regenerate.sh` deletes nothing but its own temporary files (`*.tmp` it renames into place) and restores `Prototype/Status/STATUS.md` only if a status.sh run changed it from a clean state.

Results, before this lane's code and after (Python 3.9.6, node 24.8):

| Suite | Before | After |
|---|---|---|
| `Utilities/master-view/scripts` | (none) | 23 tests, OK |
| `Utilities/api-burndown/scripts` | 51 tests, OK | 51 tests, OK |
| `Utilities/adopter-coverage/scripts` | 30 tests, OK | 30 tests, OK |
| `Utilities/api-graph/scripts` | 20 tests, OK | 23 tests, OK (the merge of system-next `0e339dc` added `test_build_graph.py`) |
| `regenerate.sh --check` | | 68 checks passed |

No Swift source or test changed in this lane, so `swift test` wasn't rerun.

## 7. Needs outside this lane

- **`Utilities/README.md`** (utilities lane): a row for `master-view/regenerate.sh`: the question it answers ("what does system-next add, who uses it, and what does each package still need"), about 8 minutes from a clean checkout and 2 to rerun, its outputs.
- **api-graph** (its owner): read each adopter's newest migration branch (section 4); apply the qualifier rule only to types: in `adopters.py`'s `migration_sites`, set `qualifier` only when the referenced symbol's index kind is a type, so that `reach.usedBy` counts the 147 links section 5 names.
- **api-burndown** (its owner): count a use once, under the declaration whose node it is, not under each variant that shares the node (design call 3), if its "used by" figures are meant to agree with this page's.
- **A newer api-graph snapshot** after each merge into system-next (the store's newest is `dd30d5c`), so that new API shows its users.

## 8. Screenshots

Taken with `regenerate.sh --shots` (a WKWebView; headless Chrome can't bind its singleton socket here), at 1440 by 700 to 1500 CSS pixels:

- `shot-charts.png`: the three charts.
- `shot-used-by.png`: a declaration's "used by" (`ProcessID.current`, in a pitch draft, 9 packages).
- `shot-package.png`: a migrated package's view (swift-nio).
