# views-2: the master view says what matters, and the data under it

**Status: done, 2026-10-07.** Nothing to resume. Commits on `views-2`, made from `system-next` at `7c545cc` (which hadn't moved by the end): `d45771b` (lanes), `4516473` (api-graph), `ce65945` (master-view's tool), and the commit with this report, the page, its data files and the screenshots. The page is `Prototype/MasterView/master.html`, from a run against `system-next` at `7c545cc` and the API graph snapshot of that same commit.

## 1. What

**The page** (`Utilities/master-view/`, `Prototype/MasterView/master.html`). The top counts only where the API universe (the 5,204 declarations `system-next` adds) meets the user universe (the adopters, in three library clusters, and the examples' Unix tools), in three cards:

- **New API in use**: the new declarations real users use, in all, by cluster and for the examples, and the overlap between adopters and examples.
- **Used, not yet in a pitch**: of those, the ones no pitch file includes, with the pitch states of the rest, and a meter.
- **Platform C uses left, and whose work they are**: by cluster, one bar each, split into *System covers it* (the adopters' work), *System lacks it* (System's work) and *other*, with hover details and a table one level down.

Each card says what moved since the run before, and why. The total API added is in the lede as a plain number, never as progress. The burn-down charts over the whole added set and their scope risers are gone. The explorer (By API, By package) is as it was, with the **Use** filter now *used by anyone / by adopters / by the examples / by no one*. The examples' tools (and the library target they share) are rows of the universe with real usage, read from api-graph's index of a build of `../swift-system-examples` at its `main` (decision 6). swift-corelibs-foundation and swift-corelibs-xctest are shown, tagged "set aside", with Michael's words, and kept out of every figure at the top (`Utilities/master-view/set-aside.tsv`). The page is one file (1.8 MB), works opened as a file, follows light and dark, and `--check` reconciles both views, the headline and the inputs (96 checks).

**api-graph** (`Utilities/api-graph/`; its report's section 8): each clone is read at its newest migration branch (`migrate-all` > `migrate-unix` > `migrate-darwin`, recorded as `adopted.branch`); the examples' repository is read as a package written on System; `qualifier` is set only when the referenced symbol is a type, so the 147 member links master-view found count now. The cold run took 17 min 21 s and filed the snapshot `7c545cc…` in `../api-graph-snapshots`; the page was regenerated from it.

**lanes** (`Utilities/lanes/`): when `git merge-tree --write-tree` answers with its usage (git before 2.38), the trial merge falls back to the three-argument form against the merge base and counts the files with conflict markers, plus modify/delete conflicts; such a count is marked `*` with a note under the table.

## 2. Design calls

Each with the alternatives rejected. Open questions stay open; the default is what's built.

1. **Figures at the top, not time charts; each with a "since" line that separates work from what isn't.** For new API in use, each package's change and why it can have moved: *its branch moved* (adopter work), *read for the first time*, or *same commit* (System or the reading changed). For C uses, update-checkout's change by repository (work), and what's *newly counted, not new C* (a repository read for the first time, a `SYSTEM-GAP` marker over C already used). The history file records every figure from today on. *Rejected:* keeping a chart per figure (one point today: nothing to draw); back-filling the new figures from older snapshots (they read `migrate-darwin` only and the old qualifier rule, so the line would jump today for no work); re-basing a series so that only work moves it (the drawn count would differ from the true figure); a burn-up of work done. *Open:* small charts once the history has a few days, drawn so that a line connects only across work (newly counted steps marked apart).
2. **"In use" is any real user's use: an adopter's (three library clusters) or the examples'.** Set-aside packages count nowhere; lexical (found by name) uses count, as everywhere on the page. *Rejected:* precise uses only (Linux-only `#if` branches and tests would vanish); counting the set-aside packages.
3. **"Not yet in a pitch" is in use, in no pitch file, and in the main count** (not deprecated, underscored or SPI: none of the 1,149 is). *Rejected:* every state of every used declaration (pitches leave those out).
4. **The C-use split follows the ledger's own precedence** (`assemble.py`'s `ledger_bucket`): an unexplained site whose names System all covers (or a marker the ledger finds covered) is *covers*; a System gap, a `SYSTEM-GAP` marker the ledger can't tie to a C name (the marker is the adopter's own note that System lacks something), or work queued with `work = System` is *lacks*; the rest is *other*, its parts named (standard library, queued for the adopter, approved to stay, undecided, not System's, no C name found, no build compiles it). Scanned files (`scan_split`) go the same way: a gap, then the standard library's or another module's answer, then covered. *Rejected:* the ledger's seven categories as they are (its *unexplained* mixes covered sites, unreadable markers and unknowns); the standard library under *covers* (adopter work, but not System's API, and the label would be false); markers under *other* (162 of the 211 name SystemSockets on FreeBSD, or on FreeBSD and Windows: System's work).
5. **Each cluster in its own unit, each bar its own whole.** update-checkout: the ledger's sites (imports and gap markers, every platform); swiftlang and apple, ecosystem: library files that import Darwin or use its C names, from the coverage tools' newest scans (2026-09-30), labeled with the date and how many packages have a scan; the examples: GAPS.md's gaps, each once. *Rejected:* one scale across clusters (the units differ); re-scanning the other clusters with the ledger's reader (new data; their scans are the coverage tools'); re-answering their C names against today's System with the ledger's `Coverage` (doable from master-view; left as next, since their scans show no gap on Darwin today).
6. **The examples are read by api-graph's index, not lexically**, as the task allowed: api-graph exports `swift-system-examples` at `main`, points it at the head commit's System, builds it with an index store, and matches by name only the lines its Darwin build skips (method.md decision 44). The page splits the examples' one graph package among the universe's rows by directory (`universe.tsv`'s new `subdir`: each tool's `Sources/<Target>`, and `ExamplesSupport`, the library target they share, as a row of its own). *Rejected:* a lexical pass in master-view (can't tell overloads or receivers apart); one row for the whole repository (the explorer and GAPS.md are per tool); charging `ExamplesSupport`'s uses to every tool (each site would count up to eleven times, and the views would stop agreeing with the graph). Tests aren't read: the tools' sources are what show the API they need.
7. **A new kind of data, "written on System: real usage"**, for the examples' rows, between migrated and scanned. *Rejected:* counting them as migrated (they have no migration branch).
8. **Set aside by a hand-kept file, applied to the headline only**, with Michael's words verbatim for both packages. *Rejected:* dropping them from the universe (the task says shown); a column in `universe.tsv` (the universe is about clusters; this is a page decision). The words given for swift-corelibs-xctest are the same as for swift-corelibs-foundation ("likely superseded by swift-foundation"), as the task gave them.
9. **History**: `used` and `unpitched-used` rows from today; `cuses` keeps its back-fill from STATUS.md and gains the split by cluster and the set-aside counts; the old `unpitched` and `pitched` rows stay, through 2026-10-06, with no new ones, and old days keep their row order. *Rejected:* deleting the old rows (they record what the earlier page showed).
10. **api-graph reads the newest branch that exists, not the newest with commits**, as status.py does, so that a package's uses and its C uses left are of one commit. *Rejected:* skipping a branch just made from main (the ledger would read it anyway).
11. **The qualifier rule uses the index's symbol kind of the reference** (enum, struct, class, protocol, union, type alias). *Rejected:* the graph node's kind (a type alias's references are the alias's own symbol; the index has it per reference already, cached, so no rebuild).
12. **lanes detects an old git by its usage message, not its version**, and counts files (as `--name-only` does): those with `+<<<<<<< .our` markers, and those one side deleted and the other changed. *Rejected:* a version check (a git that backports the option would lose it); counting conflict hunks; leaving the column empty.
13. **Colors**: the page's categorical slots 1 and 2 (blue, orange) for covers and lacks, its muted gray for other, validated with the dataviz validator in both modes (adjacent CVD ΔE 24.7 light, 26.8 dark; the gray fails only the chroma floor, by design, and stays ΔE ≥ 9.8 from both); the meter's track is blue step 100 in light and step 700 in dark (fill against track 3.3:1 in both). Every bar has a table one level down, and hover and focus details.

## 3. What the intersection shows today

At `7c545cc`, from the final run (2026-10-07):

- **New API in use: 1,149 of 5,204** (22%). Adopters use 1,029, all of them in update-checkout (21 packages read, of 25 with a migration branch); the examples use 225, in all 12 of their targets; 105 both, 924 only the adopters, 120 only the examples. No package in swiftlang and apple (181) or ecosystem (34) has a migration yet. The areas the examples alone drive are SystemConfig (42), LibProc (17), OwnedFD (14) and Processes (11).
- **Used, not yet in a pitch: 1,092 of the 1,149.** The other 57 are in pitch drafts; none is pitched, in a PR or merged. The drafts hold 179 declarations, so 122 drafted declarations have no user yet: kernel-queue has 104, 37 of them used; terminal-attributes-members 41, 4 used; process-id 11, 6 used.
- **Platform C uses left:**
  - update-checkout: **967 sites**, set-aside packages left out (96 more there). **152** System covers (adopter work, swift-nio 69 and swift-foundation 20 the most), **592** System lacks (376 C names it lacks, 211 gap markers, 5 queued for System; swift-nio has 387 of them, and 162 of the markers name SystemSockets on FreeBSD, or on FreeBSD and Windows), **223** other.
  - swiftlang and apple: 66 files in the 28 packages with a scan: **43** covers, **0** lacks, 23 other.
  - ecosystem: 37 files in its 34 packages: **33** covers, **0** lacks, 4 other.
  - the examples: **20** gaps in GAPS.md.
  - Outside update-checkout, then, System lacks nothing their scanned Darwin library code uses: what's left there is all adopter work, or other.
- **Since the earlier run** (2026-10-06): update-checkout went 1,066 → 1,063 sites: swift-format −2 and swift-foundation-icu −1, both from migrations other lanes started today.

## 4. Where the views, and the inputs, disagree

- **By API and By package agree**: 2,008 declaration–package pairs at 4,515 sites, the same in all and per package under every filter (each cluster, kind, pitch state, use value, adopters within update-checkout, each package, the most-used declaration). These are the graph's `usedBy` sites, each once, less `FileDescriptor.close()`'s (counted as already on main). Each of the examples' sites falls in one of its rows' directories.
- **The headline agrees three ways**: `assemble.py`'s count from the packages' side, a recount from the declarations' side, and the page's own model on the page's data; update-checkout's split adds up to `ledger.json`'s 1,063 with the set-aside sites.
- **The graph lags live branches**: other lanes are migrating while this ran. Four packages have a migration whose use isn't read: swift-experimental-string-processing, swift-format and swift-foundation-icu (migrations begun after the api-graph run), and swift-stress-tester (its manifest is in `SourceKitStressTester/`, which api-graph doesn't read). swift-subprocess's `migrate-unix` moved after the run, so its uses are one commit older than its C uses. The page lists each under About.
- **The page and the ledger word *unexplained* differently.** The page puts the ledger's 211 unexplained gap markers under *System lacks it*, and its 114 sites with no C name found under *other*. Each site's row in By package shows both the ledger's category and the page's part.
- **api-graph's `value.py` still counts the set-aside packages** in the update-checkout cluster (its report's section 7 left that open; the 10-07 decision is noted in its section 8).
- **api-burndown still copies a variant's uses** to the off-Darwin declarations that share its graph node (138 here); the page counts each use once. This is unchanged from the master-view lane.
- **Each build's index and the graph agree** on the new declarations every package uses.
- **Commit `4516473`'s message miscounts the branches**: it says 13 clones read at `migrate-all` and 9 at `migrate-unix`. The snapshot says 11 and 10 (the dry run I counted from included three branches with no commits). The api-graph report's section 8 has the right numbers.

## 5. Tests

Before this lane's code, and after (Python 3.9.6, node 24.8, Swift 6.2):

| Suite | Before | After |
|---|---|---|
| `swift test`, XCTest | 579 tests, 5 skipped, 0 failures | 579 tests, 5 skipped, 0 failures |
| `swift test`, swift-testing | 528 tests in 86 suites passed | 528 tests in 86 suites passed |
| `Utilities/master-view/scripts` | 23 tests, OK | 29 tests, OK |
| `Utilities/api-graph/scripts` | 23 tests, OK | 27 tests, OK |
| `Utilities/lanes/scripts` | 9 tests, OK | 11 tests, OK |
| `Utilities/api-burndown/scripts` | 51 tests, OK | 51 tests, OK |
| `Utilities/adopter-coverage/scripts` | 30 tests, OK | 30 tests, OK |
| `master-view/regenerate.sh --check` | | 96 checks passed |
| api-burndown's verify (in the run) | | 0 fail, 1 warn (origin/main fetched 11 days ago), 21 pass |

No Swift source or test changed. The tests added or changed, and what I checked before running each:

- **`Utilities/api-graph/scripts/test_adopters.py`** (new, 4 tests): the newest branch per clone and `--branch`'s single branch, the examples as a package, the qualifier rule, and the examples' whole-Sources lexical pass. It makes git repositories under one `tempfile.mkdtemp` directory and deletes only that directory (`shutil.rmtree`). Git runs with `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` (no hooks, no signing); `os.environ` gets those for adopters.py's own git calls and is restored in `tearDown`. The remotes are URLs in the config, never fetched. adopters.py runs only read-only git on the fixtures (`rev-parse`, `merge-base`, `rev-list`, `log`, `diff`, `ls-tree`, `cat-file`). No build runs, nothing is moved or signaled, and no permission changes.
- **`Utilities/lanes/scripts/test_lanes.py`** (2 tests added): `test_trivial_conflicts` reads text only. `test_git_without_write_tree` writes a shell script named `git` into the test's temporary directory and makes it executable (the one permission change, on its own file). It puts that script first on the `PATH` of `lanes.ENV` only, restored in `finally`. The script prints git 2.37's usage for `--write-tree` and `exec`s the real git otherwise. The test checks that no object reaches the fixture repository. All of it is under the temporary directory the class deletes; nothing reaches the network.
- **`Utilities/master-view/scripts/test_master_view.py`** (fixture rewritten; 7 tests added, the burn-down's 1 removed): the split of ledger sites and scanned files, the headline, routing by directory, the history's changes, the examples' rows in the universe, and the check failing on a headline the views don't have and on an examples' site outside its rows. Everything is under a `tempfile.mkdtemp` directory deleted in `tearDown`. The git fixtures are as before (local, no global configuration). `check.run_model` writes one input file to its own temporary directory and runs node on it with a timeout.

## 6. Next, and needs outside this lane

- **Utilities/README.md** (utilities lane): it still has no row for `master-view/regenerate.sh` (the master-view lane asked for one) or for `lanes/lanes.sh`.
- **api-graph** (mine for this lane, left for its owner):
  - read a package whose manifest is in a subdirectory (swift-stress-tester);
  - lower the tools version and retry when a plain `swift build` fails on it, as the `:libraries` path already does (swift-testing's `migrate-all` needs 6.3);
  - decide whether `value.py` leaves out the set-aside packages.
- **adopter-coverage** (its owner): the ecosystem scans are from 2026-09-30. A new `ecosystem.sh run` would refresh the other two clusters' figures. Until then, master-view could re-answer those scans' C names against today's System with the ledger's own `Coverage`. I didn't build that, since no Darwin gap is left in those scans today.
- **The examples' tests** aren't read. If they should count, the examples' build needs `--build-tests` (an api-graph setting).
- **Re-run api-graph after each merge into system-next**, so the graph doesn't lag the branches (section 4). The run is cold now: I deleted the 15 GB of build directories, and the next run rebuilds them (about 13 minutes of builds today).

Disk: I deleted `.build/api-graph-builds` (15 GB), `swift test`'s build products, and status.sh's scratch. What's kept is what `--check` reads: `.build/master-view` without its scratch, `.build/api-graph` (the output, 105 MB), and `.build/api-graph-cache` (496 KB). The snapshot in `../api-graph-snapshots` is the deliverable.

## 7. Screenshots

Taken with `regenerate.sh --shots` (a WKWebView), 1440 CSS pixels wide:

- `shot-top.png` and `shot-top-dark.png`: the top of the page, light and dark.
- `shot-package.png`: one package, swift-log: its new and on-main API, and its C uses with the split.
- `shot-used-by.png`: a declaration's users (`ProcessID.exit(_:)`, 11 packages).

The earlier `shot-charts.png` is gone with the charts.
