# lanes

Two read-only tools over every lane: `lanes.sh`, a table for a glance, and `snapshot.sh`, everything a coordinator's check-in reads, written to a directory of the caller's. [CHECKS.md](CHECKS.md) lists every check a check-in makes and where `snapshot.sh` answers it.

## lanes.sh

`lanes.sh` prints the state of every lane, read-only: one row per worktree of swift-system and of swift-system-examples, per adopter clone in `../adopters` and worktree in `../adopters-unix`, and per adopter workspace (`../adopters`, `../adopters-unix` themselves, where the recollapse and packages lanes keep their reports). A lane is whatever exists. Nothing about lanes is configured here, so the list can't go stale.

```sh
Utilities/lanes/lanes.sh                          # a Markdown table per group
Utilities/lanes/lanes.sh --json                   # everything, untruncated
Utilities/lanes/lanes.sh --only 'tools-*' adopters/swift-nio
Utilities/lanes/lanes.sh --root ~/development/base_dir/system-next
```

| Option | Default | |
|---|---|---|
| `--root DIR` | the folder that holds this worktree | The folder with `swift-system`, its worktrees, `swift-system-examples`, `adopters`, `adopters-unix` and `linux-logs`. |
| `--claude DIR` | `~/.claude` | Claude Code's directory, for the sessions column. |
| `--json` | off | JSON instead of Markdown. |
| `--only NAME...` | every lane | Lanes to show, by name or shell glob (`adopters/*`). |
| `--timeout S` | 20 | Seconds for one git call; a lane whose call takes longer is skipped and says so. |
| `--deadline S` | 45 | Seconds after which lanes not yet read are skipped, so a run stays under a minute. |
| `--no-merge-tree` | off | Skips the trial merges. |

### What each row says

- **Branch, head**: the checked-out branch, the head commit and its committer time.
- **vs the integration branch**: commits ahead and behind `system-next` for swift-system's worktrees, `origin/main` for a swift-system worktree on a `pitch/` branch (a pitch lane, in a table of its own), and `main` for the examples'. An adopter's migration branch records no base, so its row gives the last commit time instead.
- **Uncommitted**: files `git status --porcelain --untracked-files=all` lists.
- **In progress**: a merge (`MERGE_HEAD`), cherry-pick, revert or rebase.
- **Conflicts**: files a trial merge of the integration branch and the lane conflicts in (`git merge-tree --write-tree`), when the lane is both ahead and behind; 0 when one side is an ancestor of the other. A git older than 2.38 has no `--write-tree`, which its usage (`git merge-tree --write-tree` with no commits) shows; the trial merge is then the three-argument form, `git merge-tree <merge base> <integration> <lane>` (the trivial merge), and the count, marked `*`, is the files whose merged text has git's conflict markers (`+<<<<<<< .our`) plus those one side deleted and the other changed. That mode can't follow renames, so a conflict through one isn't counted.
- **Report**: the newest report the lane owns, with its modification time and the first line under "Resume here". Reports are `REPORT*.md`, `*-REPORT.md` (`RECOLLAPSE-*-REPORT.md` among them) and `Prototype/*/REPORT.md`. A lane owns the ones its branch changed since its merge base with the integration branch, plus any uncommitted ones. An adopter or a workspace owns every one in its working tree, since there's no base to diff against.
- **Linux log**: the newest log in `../linux-logs` named for the lane, with its last `Executed N tests` and `Test run with` lines. A log is named for a worktree lane when its name starts with the worktree's directory or branch name and a `-`. It's named for an adopter when its name has `-<package>-` (`recollapse-b-swift-log-musl-….log`). It's named for a workspace when its name starts with its newest report's lane (`RECOLLAPSE-C-REPORT.md` is `recollapse-c`).
- **Session**: the newest `~/.claude/projects/<path>/*.jsonl`, where `<path>` is the lane's path with every character but a letter or a digit replaced by `-`. That's Claude Code's encoding, as this machine's directory names show (`/Users/m/development/base_dir/system-next/tooling-1` is `-Users-m-development-base-dir-system-next-tooling-1`). A session is *active* if its transcript changed in the last 15 minutes. *none* means there's no directory or transcript, and *unknown* means `~/.claude` can't be read, as from the coordinator's shell.
- **Free disk**: `df -h` of the root, once, at the top.

### Read-only, and mounted elsewhere

- Every git call has `--no-optional-locks` (no index refresh is written) and runs with `GIT_NO_LAZY_FETCH=1`, so a partial clone fetches nothing (git 2.44 and later; an older git ignores it, and none of the lanes is a partial clone). The trial merges run with `GIT_OBJECT_DIRECTORY` set to a copy of the repository's objects in a temporary directory, made once per run and deleted after. The trees and blobs `merge-tree` writes go there, and so do the time updates git makes to an object it finds it already has ("freshening"), which it makes in an alternate too: that's why it's a copy rather than the repository's objects as an alternate (tooling-2 found a probe merge touching a repository's object this way). The tests check that no file under the folder changes, not even its time.
- A worktree's `.git` file and its main clone's `worktrees/*/gitdir` record absolute paths. When the folder is seen at another path, as in the coordinator's shell, those paths don't exist. A recorded path that's missing is then looked up under the root by its last components, longest suffix first: `/Users/m/…/system-next/adopters-unix/swift-nio` is found at `<root>/adopters-unix/swift-nio`. Git then runs with `--git-dir` (the worktree's directory under the main clone, found the same way) and `--work-tree`. Sessions are looked up at the path the lanes were recorded at, which is where Claude Code ran.
- A worktree whose directory is gone is listed with its recorded path. `git worktree prune` would drop it; this tool doesn't.

### Speed

About a second on this machine for 45 lanes: the lanes are read eight at a time, and the slowest git call is `git status` in the largest adopter clones. A lane past `--timeout` or `--deadline` is skipped, and the table says which, and why.

### Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'
```

That runs both tools' tests. lanes.sh's cover the path encoding, the report patterns, the "Resume here" reader, the log matcher and the trivial merge's reader, over text fixtures. They also build a folder of fixture repositories in one temporary directory: a main clone with an integration branch and three worktrees (ahead, conflicting with a merge in progress, deleted), an adopter clone and its worktree, a workspace report, Linux logs and a stand-in for `~/.claude`. The tests read it, move it and read it again from the new place, and read it once more with a stand-in for an old git first on the `PATH` (a shell script in the temporary directory that prints git 2.37's usage for `--write-tree` and runs the real git for everything else). Git runs with no global or system configuration. Nothing outside the temporary directory is written, and it's deleted.

### Design calls

- **Discovered, not configured.** Lanes come from `git worktree list` and the adopter directories. *Rejected*: a list of lanes in a file, which goes stale the day a lane closes. `examples-info` was removed while this tool was written, and its stale worktree entry is the case the "gone" row covers.
- **Owned reports by the branch's diff.** *Rejected*: the newest report anywhere in the worktree. Every worktree has every lane's merged `Prototype/*/REPORT.md`, so the newest by modification time would be whichever the last checkout touched.
- **Workspaces as lanes.** The adopter lanes (recollapse-a to -d, packages-N, uc-adopt) work across many clones from `../adopters` or `../adopters-unix`. Their reports and sessions are the workspace's, so the workspace gets a row.
- **merge-tree into a scratch object directory.** *Rejected*: plain `git merge-tree --write-tree`, which leaves loose objects in the repository (harmless, but a write); and the old trivial-merge mode, which needs no writes but misses renames. The trivial merge is kept as the fallback for a git without `--write-tree` (the coordinator's shell has one), detected by its usage message rather than by its version, so a git that backports the option uses it. *Rejected for the fallback*: counting conflict hunks (the column counts files, as `--name-only` does); leaving the column empty (a lane that conflicts would look clean).

### Next

- A `--since` view: lanes whose head, report or session changed since a time, for a coordinator's catch-up.
- Read the lane's own `STATUS.md` or `MIGRATION.md` totals where a report has none.
- For adopters, the migration branch's base could be recorded (a tag per lane) so that "commits ahead" means something there too.

## snapshot.sh

`snapshot.sh` gathers, in one run, everything a coordinator's check-in reads by hand, at full fidelity, and makes no judgment of what matters: paring it down is for later, by which parts get read. It writes each section to a directory of the caller's as JSON and as Markdown, and prints only an index: each section's files, their sizes and one line on what they hold, then every part the deadline skipped, each with the command that gets it alone.

```sh
Utilities/lanes/snapshot.sh --out /tmp/snap                          # every section; prints the index
Utilities/lanes/snapshot.sh --out /tmp/snap --since '2 days ago'
Utilities/lanes/snapshot.sh --out /tmp/snap --section integration    # one section, printed; nothing written
Utilities/lanes/snapshot.sh --out /tmp/snap --section activity --only adopters/swift-nio --json
```

| Option | Default | |
|---|---|---|
| `--out DIR` | required | Where the snapshot goes: outside the folder read, and empty, new, or holding an earlier snapshot (which the new one replaces, after `since-previous` compares them). |
| `--since TIME` | the earlier snapshot's time in DIR, else 7 days ago | Any form git's `--since` takes. The start of the integration branches' history and of the adopters' commits; commits after it are marked new. |
| `--section NAME` | every section | Computes and prints only this section (Markdown, or JSON with `--json`); writes nothing to DIR but scratch, which it deletes. |
| `--only NAME...` | every lane | Lanes to read, by name or shell glob, for every section that's per lane (lint's adopter checks included). |
| `--root DIR` | the folder that holds this worktree | As for lanes.sh. |
| `--claude DIR` | `~/.claude` | As for lanes.sh. |
| `--deadline S` | 85 | Seconds after which unfinished parts stop and are listed as skipped (0: none). Then up to 5 s for parts to hand in what they have, and about a second to write. |
| `--timeout S` | 30 | Seconds for one git call. |
| `--jobs N` | 8 | Parts read at once, and threads for the tree walk. |

### The sections

| Section | What it holds |
|---|---|
| `environment` | The root and the root the lanes were recorded under; every worktree path and git directory mapped to the folder as seen, and every mapping that failed; the git version and the trial-merge mode; `df -h`; `du -sh` of `../linux-logs` (skipped, with its command, if it doesn't fit the time); each part's time; and the checks this tool can't run (builds, tests, the Windows checks, lint's api check) with the command Michael runs, from the recorded root. |
| `lanes` | One row per lane, as lanes.sh finds them (the main clones included): kind, branch, head and time, base and ahead/behind (`origin/main` for a pitch lane; the clone's `main` for an adopter), commits new since `--since`, uncommitted files, an operation in progress, trial-merge conflicts, the newest write in the tree and in `.build`, the newest report, the newest Linux log and whether it names the head, the session. |
| `branches` | Per repository (swift-system, the examples, each adopter clone): every local branch with its head, time, subject, upstream and the worktree it's checked out in (as recorded and as seen); every remote-tracking branch; every worktree, with missing or prunable ones; an adopter's newest migration branch (`migrate-all`, then `migrate-unix`, then `migrate-darwin`). |
| `commits` | Per lane: every commit since its base (the integration branch; `origin/main` for a pitch lane; for an adopter, `--since` on its branch), with hash, time, subject and parents. |
| `changed-files` | Per lane: every file changed since its merge base (with `main` for an adopter), with status and line counts, and a diffstat by top-level directory. |
| `git-state` | Per lane: uncommitted and untracked files, unmerged index entries, the lines of git's conflict markers in each uncommitted file, a merge, cherry-pick, revert or rebase in progress (with the commit being merged and its subject). Per repository: every `*.lock` file under its git directory, worktrees' included, with its time. |
| `trial-merges` | Each lane against its base, and every two lanes ahead of the same base, with the conflicting files and the mode. |
| `names` | For the lanes ahead of each base: each lane's added declarations (from a scan of its changed Swift files at both ends: type and extension members by their type, top-level names by module, private names by file), the keys more than one lane adds, the public top-level names more than one lane adds, and the keys a lane and its integration branch (since their merge base) both add. Each with its file, line and source line. |
| `activity` | The newest file in each lane's tree (`.git` excluded), in `.build` and outside it; each workspace directory that isn't a clone (`logs-*`, `tools-*` and the rest) and its newest file; the newest transcript of the lane's Claude Code session. |
| `reports` | Each report a lane owns (as lanes.sh finds them) and each adopter's `MIGRATION.md`: modification time, size, every heading with its line, the whole "Resume here" section, and every hash it names: a commit in the lane's repository or not, on the lane's branch or not, the local branches that have it, and the other repositories that do. |
| `linux-logs` | Every log in `../linux-logs`, newest first: the lane, package, variant and commit its name gives, and the repository that has the commit; time and size; the first line; the last `Executed N tests` and `Test run with` lines; how many lines have `error:`, the distinct ones (source excerpts left out) and the first ten; the exit-status line. |
| `integration` | `system-next` and the examples' `main`: first-parent history since `--since`; per merge, the lane, its branch and worktree present or gone (and the branch's commits past the merge), its change split into `Sources/` with `Package.swift` and the rest (every file listed), and the logs a Close writes for it (`system-next-<commit>-*.log`, `examples-<commit>-*.log`) with any other log naming it; the last first-parent commit with such a log, and each commit since with whether it touches `Sources/` or `Package.swift`; the handoff's CMake list check at the head. |
| `status` | `Prototype/Status/STATUS.md` on `system-next`: its last commit, section 5's gap table as data (rank, gap, platforms lacking, *Unblocks* and its files, *Holds*, repositories, C names, System), sums of *Unblocks* and *Holds* per platform lacking, for the rows lacking only Windows and the rows lacking another platform, each platform's sites left, and the ledger's per-category counts. |
| `lint` | `Utilities/lint/lint.sh` at `system-next`'s head: cmake, pitches and api (which runs only with a current api-delta output in the main clone's `.build`, which needs `swift`); then markers and conditionals for each adopter clone at its newest migration branch, split by clone. |
| `since-previous` | Only when DIR held an earlier snapshot: lanes that appeared or vanished, worktrees removed, heads moved (fast-forward by how many commits, or rewritten), lane fields changed, branches appeared, vanished or moved, integration branches' new first-parent commits, new, changed and gone logs, reports that appeared, vanished or changed (with the headings added and removed and whether "Resume here" changed), lock files new and gone, STATUS.md's commit, and lint's counts. |

Every time is in the zone of the shell that ran it, labeled: JSON has ISO 8601 with the offset, and each Markdown file says the zone once at the top (a time whose offset differs, across a change of daylight time, carries its own).

### Read-only

- The folder isn't written: not a file, not a file's time. Every git call has `--no-optional-locks` and `GIT_NO_LAZY_FETCH=1`. Trial merges run on a copy of the repository's objects, as lanes.sh's do; with a git before 2.38, they're trivial merges, which write nothing.
- lint writes scratch under `.build/lint` in the checkout it runs from, so it runs from a scratch checkout of `system-next`'s head: a repository made in scratch, with the clone's objects as alternates and its branches in a `packed-refs`, checked out with `read-tree` (no object is written). `ADOPTER_COVERAGE_RESULTS` points lint at the folder's `coverage-results`, a symbolic link beside the checkout at `api-graph-snapshots`, and lint runs in the folder, so its paths are the folder's (the snapshot maps any scratch path back).
- Scratch is `DIR/.scratch-<pid>` (Python's temporary files go there too), deleted at the end. DIR is refused if it's inside the folder, or if it holds files but no snapshot; only the snapshot's own files in it are replaced.
- A part past the deadline is stopped: a git call by its timeout, lint by stopping its process group (lint and the git calls it started, nothing else), the tree walk between directories. Python reads the tool's scripts with bytecode off, so no `__pycache__` appears in the folder.

### Mounted elsewhere

As lanes.sh: recorded paths are looked up under the root by their last components. The index says how many worktree paths and git directories were mapped, and which mappings failed; `environment` lists each. Branches' worktree paths are mapped the same way.

### Speed

On this machine (2026-10-09, load average 60 to 150 from other lanes), a whole run took 58 to 71 s. The long poles are the tree walk and lint. The walk reads about 650,000 entries, 480,000 of them in the main clone's `.build` (mostly `api-graph-builds`); that clone alone takes 16 to 21 s, about the same with 1, 4 or 8 threads, since it's bound by the file system's stat calls. lint takes about 30 s: cmake and pitches about a second, then markers, which fills lint's cache of System's coverage, then conditionals in three runs at once.

The walk takes directories newest first, by each directory's own time, from one queue across every lane, so a walk the deadline stops has read the most recently changed directories, which is where a running build or Close writes. A cut walk is incomplete all the same: a directory's time doesn't change when something deeper does, nor when a file in it is rewritten in place (an index store's `data.mdb`). On a slower file system, such as the coordinator's mounted folder, expect the walk to be cut; the index says how much was read, and `--section activity --only <lane>` reads one lane alone.

### Tests

`test_snapshot.py`, run with lanes.sh's tests above, builds a folder of fixture repositories in one temporary directory: a main clone whose `system-next` has two merges (one with a Linux log, one whose worktree and branch remain), a `STATUS.md`, a CMakeLists.txt missing a file and a stand-in for `lint.sh`; lanes ahead and behind, conflicting, mid-merge, with a stale `index.lock`, adding the same member to `Win32.Error` in two modules, and a gone one; a pitch worktree on `origin/main`; the examples with a lane and a log named for one of its commits; an adopter clone and worktree; a workspace with a report, `logs-*` and `tools-*`; Linux logs and a stand-in for `~/.claude`. Every section is checked against it, and so are the deadline (the stand-in lint sleeps; it's stopped, and the index gives the command), a walk stopped before it starts, the earlier-snapshot diff, the folder moved elsewhere, a stand-in for a git without `--write-tree`, one section alone, and the refusals. One test compares every file under the folder (size, time, mode), the repository's object counts, an empty `TMPDIR` and the tool's directory before and after a run. The readers have text tests: blanking Swift strings and comments, declarations and their scopes, STATUS.md's table, log names, report sections, git's `-z` output and conflict markers.

What the tests can touch: git runs with no global or system configuration; everything is under one temporary directory, which is deleted; the one move is of the fixture folder within it, the one permission change makes its stand-in scripts executable, and the one process stopped is the stand-in lint the snapshot started. Nothing reaches the network.

### Design calls

- **One section per kind of reading, not one file per lane.** The coordinator's questions cut across lanes (what conflicts, what's uncommitted, which logs are new), and which sections get read is what will decide the paring down. *Rejected*: one file per lane (every question reads every file), one file in all (no way to see what's read).
- **`--section` computes, and writes nothing to DIR.** It's the command for a skipped part, and for a quick look. *Rejected*: printing a section from DIR (that's `cat DIR/NAME.md`), and writing the one section into DIR (a snapshot of mixed times, which `since-previous` would then compare as one).
- **lint from a scratch checkout of the head.** lint writes `.build/lint` in its own checkout, and "at the head" means the head commit, not a working tree. *Rejected*: running the main clone's lint.sh (a write in the folder, and the working tree rather than the head); importing lint's modules with a context of our own (bound to lint's internals, and its cmake check reads a working tree).
- **The CMake recipe on the head commit.** The handoff's loop reads a working tree; the snapshot reads `git ls-tree` and `git show` of `system-next`, which is the same where the main clone is clean (`git-state` says whether it is), and right where it isn't.
- **Names: a scope scan, and a key per declaration.** Members are keyed by their type (across extensions, files and modules), top-level names by module, private ones by file; a declaration counts as added if its file at the merge base has no declaration with its key. Each record carries its source line, since a key can't tell an overload by type (10-09: tools-fileio and the examples' `main` both add `withoutTimes(_:)` to `ToolTests`, one over `[UInt8]`, one over `String`). *Rejected*: added lines' names alone (no types, so no members, which was the 10-09 clash), and a compiler's index (no `swift` in the coordinator's shell). A moved file's declarations all count as added.
- **The walk, newest directories first across every lane.** *Rejected*: one lane at a time (a cut walk would have read whole lanes and none of others), and pruning by directory time (a file rewritten in place doesn't change it).
- **Pitch lanes by branch.** A swift-system worktree on a `pitch/` branch is compared with `origin/main`, its base, for commits, changes and trial merges. *Rejected*: by directory name (`pitch-*`), which nothing enforces either.
- **An adopter's base is its clone's `main`**, as lint's conditionals check uses, for changed files and ahead/behind; its commits are `--since` on its branch, as asked.

### Open

- Whether `--deadline 85` leaves enough of the coordinator's 120 s from its shell, whose file system is slower; the index says what a run skipped.
- `since-previous` compares a fixed list of fields; the sections' JSON holds the rest, for a later diff.
- A report's hashes are every 7- to 40-digit hexadecimal word, so a long number shows up as a hash that's in no repository.
