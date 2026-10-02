# burndown: a burn-down of the API system-next adds

Lane `burndown`, worktree `../burndown`, branch `burndown`. It was made from system-next `87c3fc6` and fast-forwarded to system-next `71211bc` on 2026-10-02. It owns `Utilities/api-burndown/` and `Prototype/Burndown/`, plus one row of `Utilities/README.md`.

## Resume here

Done, 2026-10-02. Every item of "done" is built and checked:

- `Utilities/api-burndown/regenerate.sh` writes `.build/api-burndown/burndown.json` and `Prototype/Burndown/burndown.html` from a clean checkout. The page is one self-contained file under 5 MB, with no network requests, and it works opened as a file.
- `Utilities/api-burndown/README.md` covers running it, inputs, outputs, run time, and "How this was generated": 18 design calls, each with the alternative it rejected, and the limitations.
- `--check` reconciles the output with `api-delta.json` and the page, and exits non-zero on a mismatch.
- The page in this commit comes from a run at the branch's tip (section 3).

**Commits:**
- `a40d4ae`: the tool, its README and tests, the empty `states.json`, and the `Utilities/README.md` row.
- `60228aa`: a README limitation (finding 2).
- `4796980`: a page layout fix.
- The last commit: this report, and the page from a run at `4796980`, the tip then. That run's graph is at system-next `71211bc`, the head commit.

**To rerun:** `Utilities/api-burndown/regenerate.sh`, then open `Prototype/Burndown/burndown.html`.
- It takes about 3 minutes from a clean checkout and 10 seconds at the same commits.
- After a pitch goes out or gets a PR, add its dated entry to `Prototype/Burndown/states.json` (format in the README) and rerun.
- For a graph at a new head commit, run `Utilities/api-graph/regenerate.sh` first, or set `API_BURNDOWN_GRAPH=run`.

**Kept in `.build`:**
- `api-burndown/`: the output, the history scans and api-delta's last run, so a rerun is fast.
- `api-graph/`: the graph at the tip, which the tool's `auto` choice reads.
- `api-graph-cache/`: a few MB.

**Deleted at the stop:**
- `api-graph-builds/` (14 GB). The next api-graph run in this worktree builds its 19 migrations cold, in about 14 minutes.
- My scratch directories.

**Possible next steps,** none started:
1. **Fill `states.json`** as pitches are posted and PRs opened. It's the only hand-kept input.
2. **Update local `main`** (finding 1). Until then the base is stale, and 17 declarations upstream already has are counted as to land.
3. **The first real merge into main.** Check the merged count against it: so far only the tests have exercised the merged logic (`MergedTests`), since nothing has landed.
4. **Store a snapshot per day.** Pitch history is exact only on days the snapshot store has a graph for, and it has one of the 11 (finding 4).
5. **Keep filters in the page's URL**, so a link can open a view, such as one pitch.

## 1. What

- **The unit.** Each public declaration that api-delta lists as added for `SystemPackage` and `SystemSockets`: symbol-graph entries and scan-only entries, overloads and per-platform variants counted apart.
- **The five states:**
  - not in a pitch;
  - in a pitch draft, when a `Prototype/Pitches` file's rules match it (api-graph's resolver);
  - pitched, and PR open, from a dated entry in `Prototype/Burndown/states.json`;
  - merged, when it was on an earlier day and is now in main.

  Deprecated, underscored and SPI declarations and fix-it stubs are shown, flagged, outside the main count.
- **The scope line.** One point per day, from 2026-09-22 to today. Each day is the last first-parent commit of system-next that day, scanned with api-delta's scanner and cached by commit. The snapshot store's graph is used where it has the commit, and api-delta's own list at the head.
- **The page.** Totals; the chart (columns stacked by state, the scope line, a tooltip per day, a table view); the six groupings; the declaration list, with each declaration's state, C names, header, pitch and adopter sites; light and dark themes.
- **The groupings:**
  - Darwin header: SDK module, then header, then C name;
  - System area;
  - pitch;
  - platform;
  - kind;
  - adopter reach.

  The page's filters (module, kind, platform, area, search, a group) scope the totals, the chart, the groups and the list together.
- **Files:**
  - `regenerate.sh`: the driver.
  - `scripts/burndown.py`: the data and `--check`.
  - `scripts/history.py`: the days, the scans and merges.
  - `scripts/headers.py`: the C name lookup.
  - `scripts/choose_graph.py`: the graph choice.
  - `scripts/page.py`, with `page.html`, `page.css` and `page.js`: the page.
  - `scripts/test_burndown.py`: the tests.

## 2. Design calls

The README's "How this was generated" has all 18, each with the alternative it rejected. These are the ones that go past the task's defaults, or decide something it left open:

- **Fix-it stubs are outside the main count**, with deprecated, underscored and SPI declarations (240 stubs at `71211bc`). Each one follows the declaration it renames into a pitch. *Rejected:* counting them as API to land; nobody can call one, and api-graph's pitch totals leave them out too.
- **The history scan marks enum cases `public` in its scratch export.** api-delta's scanner records only declarations spelled `public`, and a case never is. Without the marking, every day but the head's was short by the new cases, a step of 30 in the scope line. With it, the scan finds 4,641 of api-delta's 4,643 at `87c3fc6`: an implicit `init(rawValue:)`, and a declaration main has on another platform that system-next adds on Darwin. *Rejected:* a full api-delta run per day, which is exact but takes 1.5 minutes and two builds per commit.
- **Identity across days is module, path and signature**, with attributes and access dropped. Merged is a declaration that left the delta while main gained one with its path, so an availability edit on landing doesn't hide the merge. *Rejected:* matching whole signatures; counting everything that leaves the delta as merged.
- **The header lookup uses the SDK as well as the vocabulary.** It reads the macOS SDK's module maps and the headers' `#define`s and struct definitions. *Rejected:* the vocabulary alone (finding 3).
- **The base stays `main`**, as in the task and api-delta, with a notice and an `upstream` flag when `origin/main` isn't in it (finding 1). *Rejected:* defaulting to `origin/main`, which would disagree with what api-delta and api-graph report by default.
- **The graph is chosen automatically:** the newest graph there is, or `API_BURNDOWN_GRAPH=run` to build one. *Rejected:* always running api-graph, which takes up to 25 minutes and can fetch adopter dependencies.
- **The chart** is a stacked column per day on one ordinal blue ramp, which `validate_palette.js --ordinal` passes in both modes. It has a legend, a tooltip on hover and keyboard focus, and a table view. *Rejected:* a stacked area (large saturated blocks), and categorical hues for ordered states.

## 3. Tests

**The package tests,** `swift test --disable-sandbox`, are the same before and after; this lane changes no Swift code:

| | XCTest | swift-testing |
|---|---|---|
| Before (`87c3fc6`) | 575 tests, 5 skipped, 0 failures | 504 tests in 82 suites passed |
| After (`4796980`, system-next `71211bc`) | 575 tests, 5 skipped, 0 failures | 504 tests in 82 suites passed |

**The tool's own checks:**
- **Unit tests:** 14, all passing, run with `ResourceWarning` as an error: `PYTHONDONTWRITEBYTECODE=1 python3 -W error::ResourceWarning -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'`.
- **`--check`** passes on every run. On a copy of `burndown.json` with one declaration removed, it reports 6 problems and exits 1.
- **Cache:** a run with empty scan caches and one with warm caches give identical data.
- **Rendering:** WebKit, from a scratch Swift script (finding 5), with no JavaScript errors in light and dark. Checked: the hover and focus tooltip, a declaration's details with its adopter sites, and a test `states.json` with pitched and PR-open entries and an invalid one (shown as a notice). The final page was looked at the same way.

## 4. Findings

1. **Local `main` is 27 commits behind `origin/main`.**
   - system-next merged `origin/main` (`b62bce1`, io_uring `pollAdd`) on 2026-09-25, at `0d91e78`. Local `main` is still `1b452c2`.
   - So api-delta, api-graph and this page count 17 `IORing.Request.PollEvents` declarations, already upstream, as system-next's to land. The page flags them `upstream` and says so at the top.
   - Updating local `main` (outside this lane) fixes all three tools.
2. **api-delta can't see an enum case compiled only off Darwin.** Its symbol graphs are macOS's, and its scanner never records cases. At `71211bc` there are five such public cases, new in system-next, all Windows-only: `Win32.LockMode.shared` and `.exclusive`, and `Win32.ExtendedLengthPrefix.never`, `.whenNeeded` and `.always`. The burn-down follows api-delta's unit, so it doesn't count them. Its history scan could, but drops them too, so every day agrees with the head.
3. **The coverage tools' vocabulary misattributes struct names.**
   - A name gets the module of the first declaration the index saw, so `sockaddr_in` is in `Darwin.bsm.audit_record` and the struct `kevent` in the same module, both from forward declarations.
   - It also lacks macros its index didn't record, such as `O_SYNC`.
   - The header lookup works around both. `vocab.py` could keep the defining module instead, as `indexstore.py` already does for its `decls`.
4. **The snapshot store has one of the 11 days** (`6a9833f`, 2026-09-29), because its three snapshots are all from that day. Pitch files arrived the same day, so other days' pitch matches are resolved against the newest graph.
5. **Headless Chrome won't start in this environment.** It can't `bind()` its singleton socket under `$TMPDIR`, whether the command sandbox is on or off. A Swift script that snapshots a `WKWebView` renders the page instead.
6. **Copying the main checkout's api-graph cache didn't help.** Every entry was keyed for another tool version or commit, so the first api-graph run here built all 19 migrations cold, in 13m44s. The second, at `71211bc`, revalidated 18 and rebuilt sourcekit-lsp incrementally, since its last build had failed partway. It still took 23m21s: the load went up to 170, and most of the time was the would-benefit scan.

## 5. Needs outside this lane's files

- **Local `main`** (finding 1): `git fetch origin main:main`, or `git branch -f main origin/main`, by whoever owns the refs.
- **api-delta** (finding 2): record enum cases in `scan_sources.py`, so cases compiled only off Darwin are counted.
- **adopter-coverage** (finding 3): `vocab.py` could record a name's defining module rather than its first declaration's.
- **The snapshot store** (finding 4): this lane ran api-graph with `API_GRAPH_SNAPSHOTS=` empty, since the store is outside its files. Its newest snapshot is still `6a9833f`.
