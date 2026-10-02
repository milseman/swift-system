# api-burndown

`regenerate.sh` writes a burn-down of the public API that one commit adds over another, by default what `system-next` adds over `main`. The unit is a public declaration in `SystemPackage` or `SystemSockets`, exactly as `Utilities/api-delta` lists it as added. Each one is in one of five states:

1. **Not in a pitch.**
2. **In a pitch draft:** a pitch file in `Prototype/Pitches` matches it.
3. **Pitched**, and 4. **PR open:** its pitch's entry in `Prototype/Burndown/states.json` says so, from a date on.
5. **Merged:** it was in an earlier day's set and is now in `main`'s public API.

There's one point per day for history, from the branch's first day to today. At each point, the scope is the total to land that day: what the head ref added over the base ref then, plus what had merged by then.

The page, `Prototype/Burndown/burndown.html`, is one self-contained file: all of its CSS, JavaScript and data are inline, it makes no network request, and it works opened as a file. It shows the totals, a column per day stacked by state with the scope line over it, and the declarations grouped six ways: by Darwin header (C name, then the header that declares it, then the SDK module), System area, pitch, platform, kind, and adopter reach. For each declaration it shows the state, the C names and header, the pitch, and which files in which packages use it, with line numbers.

## Running it

```sh
Utilities/api-burndown/regenerate.sh               # main vs system-next
Utilities/api-burndown/regenerate.sh --check       # reconcile the last run with api-delta; non-zero on a mismatch
open Prototype/Burndown/burndown.html
API_BURNDOWN_GRAPH=run Utilities/api-burndown/regenerate.sh   # build a new API graph first (slow)
```

| Variable | Default | |
|---|---|---|
| `BASE_REF`, `HEAD_REF` | `main`, `system-next` | The two commits, spelled as api-delta takes them. |
| `API_BURNDOWN_OUT` | `.build/api-burndown` | `burndown.json`, `history/` (the scans, by commit, kept between runs), `cache/` (the SDK's header index), `api-delta/` (api-delta's last run, and `api-delta.stamp`), `logs/`. |
| `API_BURNDOWN_WORK` | `.build/api-burndown-work` | Scratch: exports and api-delta's scratch directory. Deleted at the end. |
| `API_BURNDOWN_PAGE` | `Prototype/Burndown/burndown.html` | The page. |
| `API_BURNDOWN_DELTA` | (reuse or run) | An api-delta output for the same two commits. Without it, the last run's is reused when its commits, api-delta's committed tree and the compiler are unchanged; otherwise api-delta runs. |
| `API_BURNDOWN_GRAPH` | `auto` | `auto`: the newest API graph there is, from this worktree's `.build/api-graph` or the snapshot store: the head commit's if there is one, else the nearest ancestor's. `run`: run `Utilities/api-graph/regenerate.sh` first, with this run's api-delta. Or a `graph.json.gz`, an api-graph output directory, or a commit the store has. |
| `API_BURNDOWN_SNAPSHOTS` | `../api-graph-snapshots` | The api-graph snapshot store, read only. |
| `API_BURNDOWN_PITCHES` | `Prototype/Pitches` | The pitch files, read from the working tree, as api-graph reads them. |
| `API_BURNDOWN_STATES` | `Prototype/Burndown/states.json` | The pitched and PR-open dates (below). |
| `API_BURNDOWN_COVERAGE_RESULTS` | `../coverage-results` | The coverage tools' results store, for its SDK vocabulary. |
| `API_BURNDOWN_VOCAB` | the store's newest `vocab/macosx*.json.gz` | A vocabulary file. |
| `API_BURNDOWN_UPSTREAM` | `origin/main` | A ref the base should contain. When it doesn't, the page says how far behind the base is, and flags the declarations the ref already has. Empty skips it. |
| `API_BURNDOWN_TODAY` | today | The last day, `YYYY-MM-DD`. |

Refs resolve as in api-delta: in the worktree you run the script from. Commits are read with `git archive` and `git show`, never from a working tree, except the pitch files and `states.json`. The page is the only tracked file the script writes; commit it when you want to publish it. Nothing is fetched from the network. A run of `API_BURNDOWN_GRAPH=run` runs api-graph, whose adopter builds resolve their dependencies as `swift build` does.

### states.json

A hand-kept object, committed empty (`{}`): pitch ID → `{state, date, link}`, or a list of them, oldest first, for a pitch that has gone through both:

```json
{
  "process-id": {"state": "pitched", "date": "2026-10-05", "link": "https://forums.swift.org/t/…"},
  "kernel-queue": [
    {"state": "pitched", "date": "2026-10-05"},
    {"state": "pr", "date": "2026-10-12", "link": "https://github.com/apple/swift-system/pull/…"}
  ]
}
```

`state` is `pitched` or `pr`. A pitch's declarations are in that state from its date on, on the page and on every day of the chart. Merged isn't an entry: it comes from `main`. The page lists entries it can't use (an unknown state, a bad date, a date after today, a pitch with no file).

## What it reads

- **api-delta** (`Utilities/api-delta/regenerate.sh`): `api-delta.json`, for the added declarations, their kinds, platforms and availability. `scripts/scan_sources.py`, api-delta's source scanner, runs on each day's commit.
- **The API graph** (`Utilities/api-graph`): `graph.json.gz` (schema: `Prototype/ApiGraph/REPORT.md`, section 1), for each declaration's node, its C names (`wraps` links) and its adopters (`usedBy` links, with each site's file, line and column). The pitch files (section 2) are resolved with api-graph's own `scripts/pitches.py`. The page records the graph's commit.
- **The snapshot store** (`../api-graph-snapshots`): the graph of each commit it has, for those days.
- **The SDK vocabulary** (`../coverage-results/vocab/macosx26.0-*.json.gz`, from `Utilities/adopter-coverage/scripts/vocab.py`): `{clang module: {name: [kind mask, language mask]}}`, from one package's index store. With the macOS SDK's module maps and headers (`xcrun --show-sdk-path`), it gives each C name's header and module.
- **git**: the first-parent history of both refs, and the pitch files at each day's commit.

## What it writes

- `.build/api-burndown/burndown.json`:
  - `meta`: the commits, and each input with its commit, path or problems;
  - `totals`: by state, in and outside the main count;
  - `declarations`: one per api-delta entry, with its state, pitch and pitches, flags, C names and primary C name, header, SDK submodule and module, area, adopters (`usedBy`: package, then `[file, line, column, resolution]` sites), and `couldUse` (how many packages call a C name it wraps);
  - `merged`: the declarations merged by now, from history;
  - `history.days`: one per day, with the commit, the method, the counts by state, and a code per declaration (`.` absent, `1`–`5` its state, `a`–`e` the same but outside the main count), against `historyUnits`, every declaration any day had;
  - `digest`, which the page embeds.
- `Prototype/Burndown/burndown.html`: about 1.3 MB; the tool refuses to write one over 5 MB.
- `.build/api-burndown/history/`: `scan-<commit>-<tool>.json.gz`, each commit's scan, keyed by the scanner's contents and this tool's scan format, so a rerun scans only new commits.

## Run time

Measured on an M1 Max with Swift 6.2, on 2026-10-02, with other builds keeping the load average between 20 and 140:

- **From a clean checkout:** about 3 minutes. api-delta's run takes 1.5 to 2 minutes of that, and the first scans of the days' commits and of the SDK's headers about 40 seconds.
- **A rerun at the same commits:** about 10 seconds; api-delta's run and every scan are reused.
- **After system-next moves:** api-delta runs again (1.5 to 2 minutes) and the new day's commit is scanned (2 to 3 seconds).
- **`API_BURNDOWN_GRAPH=run`:** api-graph adds 4 to 14 minutes, or about 25 with cold adopter builds (its README).

## Checks and tests

`regenerate.sh` ends with the check that `--check` runs on its own. It fails if any of these doesn't hold:

- every one of api-delta's added entries, in the graphs and only in the scan, is exactly one declaration, and the counts by module agree;
- the totals, by state and in and outside the main count, are the declarations';
- the last day's scope is the main count, and each day's codes sum to its scope;
- the page embeds this `burndown.json`'s digest, is under 5 MB, and loads nothing from the network.

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'` tests the logic on its own: signatures, the enum-case marking, the set difference, merges, `states.json`, areas, days, module maps and header lookup on a small fake SDK, and the page's encoding.

## How this was generated

### Pipeline

1. **api-delta** for the two commits, or its last run when nothing it depends on changed.
2. **The graph**: the newest one there is, or a new one.
3. **The declarations**: api-delta's added entries, each given the ID its declaration has in the source scan (module, path, signature), so that the same declaration has the same ID on every day.
4. **Pitches, C names, headers, adopters**, from the graph, the pitch files, the vocabulary and the SDK.
5. **History**: for each day, the scan of that day's commit against the scan of the base ref's commit that day; the pitch files at that commit; `states.json`'s dates; and merges.
6. **The page** from `burndown.json`, and **the check**.

### Design calls

Each is listed with the alternative it rejected.

1. **The unit is api-delta's entry, with no merging.** That means every added symbol-graph entry and every entry in `hiddenFromGraphs.added`. Overloads count separately, and so do the per-platform variants of a declaration: `CInterop.MountFlags` is two declarations, one for FreeBSD and one for the other Unixes, and `FileWatcher.add(_:events:)` is two overloads. Both are flagged `overload` on the page.
   *Rejected:* api-graph's nodes. These merge a scan-only declaration into another with the same path, which merges overloads with the same labels (12 groups now) and per-platform variants (53 entries).
2. **Outside the main count: deprecated, underscored and SPI declarations, and fix-it stubs.** They're shown, flagged, and counted separately. A stub (`@available(*, unavailable, renamed:)`, 240 now) can't be called; api-delta classes it as unavailable, and api-graph's pitch totals leave it out too. A stub follows the declaration it renames into a pitch. A stub named after a C constant (`_SC_ARG_MAX`) is a stub, not underscored API.
   *Rejected:* counting stubs as API to land, which adds about 5% that no one calls.
3. **Pitched and PR open come from a hand-kept, dated `states.json`.**
   *Rejected:*
   - Reading GitHub or the forums: that's a network fetch and a rate quota.
   - The pitch file's own `status`: it has no date or link, and `accepted` doesn't separate a PR that's open from one that's merged.
4. **Merged is measured from history.** A declaration seen on an earlier day counts as merged on a later day if it has left the delta there and the base gained a declaration with its module and path. Counts are compared, so an overload that lands beside an existing one counts.
   *Rejected:*
   - Matching the whole signature: an availability edit on landing (`System 199` to `System 1.9`) would hide the merge.
   - Counting everything that leaves the delta: removals and renames would count as merges.
5. **The base is `main`, as in api-delta, with a warning when `origin/main` isn't in it.** The page counts against `main` and flags the declarations `origin/main` already has. Today local `main` is 27 commits behind `origin/main`, which system-next merged on 2026-09-25, so 17 io_uring `PollEvents` declarations are counted as added and flagged `upstream`.
   *Rejected:* defaulting to `origin/main`. Its totals wouldn't match what api-delta and api-graph report by default, and a remote-tracking ref moves only when someone fetches.
6. **One point per day.** Each is the head ref's last first-parent commit that day, from the day of its first commit not on the base, to today. A day with no commit repeats the day before. The base is the base ref's last first-parent commit that day. A commit's day is its committer date, in its own time zone.
   *Rejected:*
   - One point per commit: 11 commits on 2026-10-01 alone, at uneven spacing.
   - Only days with commits: that hides the time nothing happened.
7. **History comes from api-delta's source scan, the snapshot store where it has the commit, and api-delta itself at the head.**
   - A day's set is the scan's public declarations, less those the base's scan has (by module, path and signature, as a multiset).
   - The scan never sees an enum case, because a case has no `public`. So the scratch export marks each case at the top level of an enum's body `public` before the scan. A case counts if its enum is public and it compiles on Darwin, as api-delta's symbol graphs see it.
   - With that marking, the scan finds 4,641 of api-delta's 4,643 declarations at `87c3fc6`. One of the two is an implicit `init(rawValue:)`; in the other, main already has `Errno.notCapable` on another platform, and system-next adds it on Darwin.
   - On the day the store has a graph for (`6a9833f`), that graph adds declarations of both kinds.

   *Rejected:*
   - A full api-delta run per day: exact, but 1.5 minutes and two builds per commit.
   - The scan without marking enum cases: it missed 28 at the head, a step of 30 in the scope line where the method changes.
8. **A declaration's identity across days is its module, path and normalized signature.** The signature has its attributes and access modifiers dropped, and a counter separates identical declarations.
   *Rejected:*
   - USRs, which the scan doesn't have.
   - File and line, which change whenever code moves.
9. **Each day's pitches are the pitch files at that day's commit.** They're resolved against that commit's snapshot when the store has one, and against the newest graph otherwise. Pitch files first appeared on 2026-09-29.
   *Rejected:* today's matches applied to every day, which would show drafts before any pitch file existed.
10. **The graph is the newest one there is, chosen automatically.** That's the head commit's if there is one, otherwise the nearest ancestor's; `run` makes a new one. The page names the graph's commit and warns when it isn't the head's.
    *Rejected:* always running api-graph. That takes 4 to 25 minutes, and its adopter builds can fetch dependencies.
11. **A declaration in more than one pitch counts under the first pitch file by name, and is flagged.** Its state follows that pitch.
    *Rejected:* the most advanced state among its pitches, which counts the declaration's progress twice.
12. **Each C name's header comes from the vocabulary and the SDK together.**
    - A macro or constant is found by its `#define`, and a struct, union or enum by its definition, in the SDK's headers.
    - Anything else, functions above all, comes from the vocabulary's module, confirmed against that module's headers in the SDK's module maps.
    - A header in no module, but included by one of a module's headers, is in that module: `netinet6/in6.h` from `netinet/in.h`.
    - A header outside Darwin's directories and in no module isn't Darwin's, so a name it defines (`environ`, in `apache2/`) is "not in the macOS SDK".

    *Rejected:*
    - The vocabulary alone. A name gets the module of the first declaration the index saw: `sockaddr_in` lands in `bsm/audit_record.h` from a forward declaration. It also lacks macros the index didn't record, such as `O_SYNC`.
    - The headers alone, which can't tell a function's prototype from a use.
13. **The C name a declaration is grouped by** is the first of its C names the macOS SDK declares, taken in role order (subject, alternative, argument), then in the order the sentence names them. Only declarations that compile on Darwin get one; the rest are "not on Darwin". `int` and the other built-in types don't count.
    *Rejected:* looking up every declaration's C name. A Windows-only declaration's `TRUE` would land in `curses.h`.
14. **The System area** is the directory under `Sources/System` or `Sources/SystemSockets`. A file at the top goes in its file group: the shortest top-level file stem or directory name its own stem starts with. So `FileControlCommand.swift` is in `FileControl`, `ErrnoWindows.swift` in `Errno`, and `Util+StringArray.swift` in `Util`.
    *Rejected:* api-delta's `area`, its top-level type, which puts `FileDescriptor`'s new members, from 22 files, in one group.
15. **Adopter reach is the number of packages whose migration branch uses the declaration**, from the graph's `usedBy`. The packages that call a C name it wraps (`couldUse`) are in each declaration's details, not a grouping.
16. **A platform grouping counts a declaration under every platform it compiles on.**
    *Rejected:* one group per platform set, which makes 38 groups and hides the per-platform totals.
17. **The page is one file with the data inline, in a compact form**: a string table, bit masks for platforms and flags, and one code string per day. It sets a Content-Security-Policy that allows nothing from the network.
    *Rejected:* a separate data file that the page fetches. Browsers block `fetch` from `file://`, and any fetch is a request.
18. **The chart is stacked columns by state, one per day, with the scope line over them.** Merged sits at the baseline, then PR open, pitched, pitch draft and not in a pitch. The states are ordered, so they take one blue ramp, light to dark (dark mode reverses it), validated with the dataviz skill's `validate_palette.js --ordinal` in both modes. The table view lists the same numbers.
    *Rejected:*
    - A stacked area, which makes large saturated blocks.
    - Categorical hues, which drop the order of the states.

### Limitations

- **Days other than the head's** come from a lexical scan, so each can be short of api-delta by:
  - an implicit member (an enum's `init(rawValue:)`);
  - a declaration main has on another platform that the commit adds on Darwin;
  - the second case on a line (`case a, b`).

  That's 2 of 4,644 at the head today. The day the store has a graph for matches api-delta's method.
- **Pitches on days the store has no graph for** are resolved against the newest graph, so a declaration that graph no longer has counts as in no pitch that day.
- **The SPI flag** sees `@_spi` on a declaration, not on its enclosing extension. There's no SPI in either module today.
- **A declaration renamed as it lands** counts as removed, and its new name, being in main, is in no state.
- **A struct field's header** is the first that the vocabulary gives, since field names aren't unique.
- **States follow the pitch files in the working tree**, as api-graph's do. The page warns when they have uncommitted changes.
- **The header index covers the macOS SDK's `usr/include`.** A framework's name maps to the framework's header of the same name.
