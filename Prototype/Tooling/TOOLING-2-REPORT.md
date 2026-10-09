# tooling-2: one snapshot of a check-in's readings

Lane `tooling-2`, branch `tooling-2` from system-next `5d0b151` (2026-10-09). The coordinator checks on lanes from a shell that sees only `~/development/base_dir/system-next`, mounted elsewhere, with git 2.34, python3, no `swift`, no `~/.claude`, and 120 s per call. `lanes.sh` gave it an overview, but each check-in still took a dozen more commands. This lane adds `Utilities/lanes/snapshot.sh`: one command that gathers everything a check-in reads, at full fidelity and with no judgment of relevance, into a directory of the caller's, printing only an index. `Utilities/lanes/CHECKS.md` lists every check a check-in makes, its source, and the section that answers it. The tool's options, sections, read-only rules and design calls are in `Utilities/lanes/README.md`. This report gives what isn't there.

## Resume here

- **Done.** Everything is committed on `tooling-2` (section 1), and the 28 tests pass (section 5). system-next hasn't moved from `5d0b151`, so there was nothing to merge.
- The real-folder runs are in section 6: about a minute each on a heavily loaded machine, 3.4 MB written, nothing skipped, and no file in any repository's git directory changed.
- Open: the needs outside this lane's files (section 7) and the open questions (section 8). Nothing was pushed, and nothing outside `Utilities/lanes/` and this report was edited.

## 1. What

| Commit | What |
|---|---|
| `6011f20` | `Utilities/lanes/CHECKS.md`, written first: 59 checks from the handoff's recipes and round notes, the simulated check-in of 10-09, lane-workflow.md, the coordinator's seven additions of 10-09 and the prompt's list, each with the section that answers it or why the coordinator's shell can't. |
| `48c9b04` | `snapshot.sh` and `scripts/snapshot.py`, with `scripts/test_snapshot.py`. `lanes.py` changes: discovery split out of `collect()` for both tools, a pitch kind on `origin/main`, the lists it used to count (conflicting files, uncommitted files, owned reports) kept, a deadline for git calls, and trial merges on a copy of the object store (section 4.1). |
| `eb50ea9` | README: both tools, `snapshot.sh`'s options, sections, read-only rules, speed, tests and design calls. lint's dependence on `xcrun` is shown in the snapshot. Two Markdown caps removed. |
| this commit | This report, README speed figures, CHECKS.md's last edits. |

The snapshot's fifteen sections: `environment`, `lanes`, `branches`, `commits`, `changed-files`, `git-state`, `trial-merges`, `names`, `activity`, `reports`, `linux-logs`, `integration`, `status`, `lint`, and `since-previous` when `--out` held an earlier snapshot. The coordinator's additions map as follows.

| Coordinator's item (10-09) | Where |
|---|---|
| 1. Paths recorded as `/Users/milseman/…` | Every worktree path and git directory mapped by its last components, for swift-system, the examples and each adopter clone with a worktree (branches' worktree paths too). The index has a line on how many mappings were needed and which failed; `environment` lists each. Tested by moving the fixture folder. |
| 2. The main clones as lanes; stale locks | The main clones are lanes. `git-state` has unmerged entries, conflict-marker lines in every uncommitted file, operations in progress, and every `*.lock` under each repository's git directory with its time. |
| 3. Members added to one type by two lanes | `names`: a scope scan of each changed Swift file at both ends. Members are keyed by their type across extensions, files and modules, and each record carries its source line. Clashes with what the integration branch added since the lane's merge base are found too (section 4.3). |
| 4. STATUS.md's content | `status`: section 5's gap table as rows, sums of *Unblocks* and *Holds* per platform lacking, for rows lacking only Windows (59 rows, 141 sites on 10-09) and rows lacking another platform (38, 76), each platform's sites left, and the ledger's categories. |
| 5. Changes since the previous snapshot | `since-previous`, with `--since` defaulting to the earlier snapshot's time. |
| 6. Close evidence per merge | `integration`: each merge's `system-next-<commit>-*.log` or `examples-<commit>-*.log`, other logs naming the commit, the branch and worktree present or gone, and the branch's commits past the merge. |
| 7. Checks the shell can't run | CHECKS.md rows 50 to 59 with Michael's commands; `environment` lists them with the recorded root. |

## 2. Design calls, with the alternatives rejected

The README's list covers: sections by kind of reading, `--section` computing without writing, lint from a scratch checkout, the CMake recipe on the head commit, the scope scan for names, the walk's order, pitch lanes by branch, and adopters' base. Besides those:

- **Trial merges on a copy of the object store, mode read from usage.** See section 4.1. *Rejected*: the repository's objects as an alternate, which tooling-1 used (git freshens them); hard or symbolic links (they share the file whose time git sets); the trivial merge only (writes nothing, but misses renames, and the prompt asked for lanes.sh's way). The copy costs about 20 MB per run, for swift-system and the examples, which are the only repositories with trial merges. With the coordinator's git it isn't made at all, since its merges are trivial.
- **Deadline, then grace.** At 85 s every part stops. Git calls stop by timeout, lint by stopping its process group, the walk between directories (or within one, every 500 entries). Parts then get up to 5 s to hand in what they have, which leaves about 8 s of the coordinator's 100. A skipped part is listed with `snapshot.sh --out DIR --section NAME [--only LANE]`, the command that gets it alone. *Rejected*: a fixed budget per part, which can't know the coordinator's file system in advance.
- **The walk is one queue across every lane, newest directories first.** A cut walk has read whatever changed most recently anywhere. *Rejected*: per-lane walks, and splitting each tree at `.build` into parallel pieces (tried; a 345,000-entry piece was still a 48 s long pole). Threads don't speed it up here (16 to 21 s for the main clone with 1, 4 or 8 threads), but they don't hurt.
- **A lane's Linux logs by name and by commit.** The examples' logs are `examples-<commit>-…` whichever lane ran them, so a lane also gets every log naming one of its commits (marked `matched: commit`). *Rejected*: names only (an examples lane would never have a log).
- **DIR is refused** inside the folder read, or when it holds files but no snapshot, so the tool never overwrites anything but its own files. *Rejected*: writing anywhere asked (a snapshot inside the folder would show up as the newest write in its lane).
- **Times in the running shell's zone.** JSON has ISO 8601 with offsets; Markdown states the zone once and marks any time whose offset differs. *Rejected*: Michael's zone hard-coded (wrong for anyone else); UTC (the handoff's confusion was a zone left unlabeled, not a zone).
- **`since-previous` diffs a fixed list of fields**, mechanically. *Rejected*: a generic JSON diff (session ages and timings change on every run, and would drown the rest).

## 3. CHECKS.md's rows not answerable from the coordinator's shell, and why

| Row | Check | Why |
|---:|---|---|
| 14 | Files changed outside the lane's own | Which files a lane owns is in its prompt, not in the folder. The snapshot lists every changed file, with a diffstat by top-level directory. |
| 21 | The report's other claims | What to recount depends on the claim, and a macOS build or test leaves no file. The snapshot holds what a recount reads. |
| 27 | Session transcripts | `~/.claude` isn't there. The newest writes stand in. |
| 28 | The tab table | Michael's Terminal. |
| 36 | Whether a Close's chain is still running | Processes on the Mac aren't visible. Recent writes in the main clone's `.build` and its tree's state are the evidence. |
| 41 | lint's api check | It reads api-delta's output, which `swift` builds. It runs only if the main clone has a current `.build/api-delta` (on 10-09, it didn't). |
| 50 to 58 | Builds, tests, `check-windows.sh`, `check-winsock.sh`, the examples' `Scripts/test-linux.sh`, System's Linux tests, lint's api check | No `swift`, and the Linux runs need Apple's `container` tool on the Mac. Each row gives the exact command. |
| 59 | Whether a lane pushed | A push to a configured remote moves a remote-tracking branch, which `branches` lists; a push to a URL leaves nothing in the folder, and the remote can't be read without the network. |

## 4. Findings

### 4.1 lanes.sh's trial merges could touch a repository's objects

When git writes an object it already has, it "freshens" the existing file, setting its time, even in an alternate. tooling-1's trial merges ran with the repository's objects as an alternate, so a merge whose result tree or blob already existed changed a repository file's time. The tests compared only object counts, so they didn't see it. The snapshot's first mode probe, a merge of HEAD with itself, did exactly this, and the new test caught it. Trial merges now run on a copy of the object store. The mode comes from `git merge-tree --write-tree` with no commits, whose usage names `[--write-tree]` only when git has it, and which writes nothing. Both tools' tests now compare every file's size, time and mode under the fixture folder. On the real folder, a snapshot left all 6,641 files in the repositories' git directories unchanged.

### 4.2 lint's conditionals check depends on xcrun

`ledger.swift_declared_names` reads the macOS SDK's Swift interfaces through `xcrun --sdk macosx --show-sdk-path`, so that `String` or `UInt` in an adopter isn't read as a C name. Without `xcrun`, as in the coordinator's shell, the names are missing and the check finds more: 168 `conditionals/mixed` rather than 160 on 10-09, with a stand-in `xcrun` that fails. The snapshot says when `xcrun` is missing. The fix is lint's (section 7).

### 4.3 What the names scan found on 10-09

No declaration added by two lanes of the same round. One key was added by a lane and by its integration branch: tools-fileio's `withoutTimes(_:)` in `Tests/ToolTests/DdTests.swift:35`, which the examples' `main` also added since tools-fileio's merge base, in `TimeTests.swift:38`. One takes `[UInt8]` and the other `String`, so it's a legal overload. The source lines in the record show that. A key can't tell overloads apart by type.

### 4.4 Other readings worth a look

- The examples' last commit with a log, `56b44c4`, has only `examples-56b44c4-filter-SandboxTests.log`, a filtered run, not the whole suite.
- A lint run in the main clone at 10:52:57 wrote its scratch to `swift-system/.build/lint` (`scan.json`, `derived.json`, `mapping-5d0b151e426f.ini`). It wasn't this lane: the snapshot runs lint from a scratch checkout, and the tests use a stand-in. `activity` shows writes like it.
- During the lane, the machine's load average was 60 to 150, and free disk fell from 45 to 24 GiB (another lane's scratch under `linux-logs` grew from 2.3G to 16G), then came back to 31 GiB. Run times vary with that.

## 5. Tests

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'`

- Before: lanes.sh's 11 tests passed, and lint's 15 (untouched).
- After: 28 pass in about 30 s: lanes.sh's 11, with the read-only test now comparing every file's time; and `test_snapshot.py`'s 17.
- `test_snapshot.py` has 8 text tests. They cover blanking Swift strings and comments; declarations and scopes (extension members, nested types, locals left out, initializer and subscript labels, operators, case lists, private keys by file); STATUS.md's table and sums; log names; "Resume here" sections and outlines; hashes; git's `-z` output; conflict markers.
- Its 9 tests over a fixture folder cover:
  - every section, and nothing written outside `--out`: every file under the folder, the object counts, an empty `TMPDIR`, the tool's directory;
  - the deadline, where the stand-in lint sleeps, is stopped, and the index gives the command;
  - a walk stopped before it starts, and the earlier-snapshot diff;
  - the folder moved elsewhere, and a git without `--write-tree`;
  - one section alone, and the refusals.
- Vigilance (Michael, 10-05):
  - The tests delete only their own temporary directory; the tool deletes only its own scratch in `--out`.
  - The only move is the fixture folder, within that directory.
  - Files are written only there, and the only permission change makes the stand-in scripts executable.
  - The only process signaled is the stand-in lint the snapshot itself started.
  - Git runs with no global or system configuration, and nothing reaches the network.

## 6. The real-folder run

`Utilities/lanes/snapshot.sh --out /tmp/claude-final`, 2026-10-09 11:11, on Michael's Mac (git 2.50.1, load average about 90): **58.1 s** of an 85 s deadline (59.4 s wall), **3.4 MB** written, nothing skipped. The index it printed:

| Section | Markdown | JSON | What it holds |
|---|---|---|---|
| environment | 7.9 KB | 8.3 KB | git version 2.50.1 (Apple Git-155), trial merges write-tree; 32.1 GiB free; linux-logs 8.0G; 0 path mappings, 0 failed; checks not run here, with commands |
| lanes | 13.3 KB | 51.3 KB | 50 lanes (3 system, 1 pitch, 4 examples, 30 adopter, 2 workspace, 10 adopter worktree): branch, head, base, ahead/behind, uncommitted, in progress, conflicts, newest write, report, Linux log, session |
| branches | 192.9 KB | 336.1 KB | 32 repositories: 89 local branches with worktrees, 1302 remote-tracking |
| commits | 23.0 KB | 49.7 KB | 148 commits across 48 lanes since their bases (148 since --since) |
| changed-files | 75.2 KB | 156.4 KB | 1080 files changed since the merge bases, by lane, with a diffstat by top-level directory |
| git-state | 2.8 KB | 12.3 KB | 28 uncommitted or untracked files, 0 lanes mid-operation, 0 files with conflict markers, 0 lock files |
| trial-merges | 1.8 KB | 2.9 KB | 8 lanes against their bases (2 conflict); 4 lane pairs (3 conflict) |
| names | 121.4 KB | 270.7 KB | 0 declarations added by two lanes, 0 public names, 1 also added by the integration branch, over 6 lanes |
| activity | 10.9 KB | 36.1 KB | newest writes in 50 trees (.build and outside), workspaces' directories, sessions |
| reports | 117.5 KB | 333.3 KB | 62 reports: outline, Resume here, 880 commit hashes checked |
| linux-logs | 423.1 KB | 526.7 KB | 407 logs, newest winsock-2-f03620b-test.log: lane, commit, totals, error lines, exit status |
| integration | 55.2 KB | 134.8 KB | system-next 5d0b151: 16 merges since --since, last logged 5d0b151, 0 commits since; main 56b44c4: 9 merges since --since, last logged 56b44c4, 0 commits since; CMake list: 0 missing |
| status | 16.1 KB | 32.2 KB | STATUS.md at fc8aaa4: 97 gap rows (217 sites unblocked), sums by platform, ledger categories |
| lint | 130.7 KB | 349.2 KB | System 12 findings (api didn't run); adopters 547 findings over 30 clones |

The other runs:

- The same command two minutes later, into the same directory: 70.1 s (load about 110). `--since` defaulted to the first run's time, and `since-previous` (2.1 KB) listed 11 lane fields changed. These were other lanes' writes, sessions and uncommitted counts.
- With a stand-in git that lacks `--write-tree`, as the coordinator's 2.34 does, and no `~/.claude`: 58.6 s. Trial merges were trivial, with the same conflicting files as write-tree for every lane and pair.
- With stand-ins for `swift`, `swiftc`, `xcrun` and `xcodebuild` that record calls: only `xcrun` was called, by lint (section 4.2).
- Single sections:
  - `--section activity --only swift-system`: 23 s.
  - `--section lint --only adopters/swift-nio`: 15 s.
  - `--section status --json`: 0.3 s.
- An 8 s deadline: done in 8.3 s, with 109 parts skipped, each listed with its command.

The coordinator's shell hasn't run it. Its file system is slower, so expect the walk, and perhaps lint, to be cut at 85 s. The index lists what was skipped.

## 7. Needs outside this lane's files

- **`Utilities/README.md`**: a row for `snapshot.sh` next to `lanes.sh`. The index belongs to the utilities lane, or the coordinator.
- **`CLAUDE.md`'s Commands**: `Utilities/lanes/snapshot.sh --out DIR`, with a pointer to CHECKS.md.
- **lint (`Utilities/adopter-coverage/scripts/ledger.py`)**: store the SDK's Swift-declared names with the coverage tools' vocabulary (`coverage-results/vocab`), or under `Utilities`, so that lint's conditionals check gives the same findings without `xcrun` (section 4.2).
- **The handoff**: section 4's recipes can become "run `snapshot.sh --out <scratch>`, read the index, then the sections it points to". The CMake recipe, the trial merge and the log grep are all in it.
- **The coordinator's shell**: none of the lanes is a partial clone, but `GIT_NO_LAZY_FETCH` needs git 2.44. If the shell's user doesn't own the folder's files, git 2.34.2 and later refuse with "dubious ownership" unless `safe.directory` allows them; lanes.sh already works there, so presumably they do.

## 8. Open, and next

- **What to pare.** The coordinator's reading decides it: which sections and fields it opens over a few check-ins. A next step could log, in the coordinator's own notes, which files it reads.
- **The deadline in the coordinator's shell.** 85 s plus at most 5 s of grace was chosen for 120 s calls. Its first run will show what's skipped there, most likely parts of the walk.
- **The names scan's limits.** It sees no types: a key can't tell an overload by type from a clash. A moved file's declarations count as added. Module qualifiers on extended types (`extension SystemPackage.Errno`) aren't stripped. Declarations under `#if` count on every platform.
- **Report hashes** are every 7- to 40-digit hexadecimal word. A long number shows up as a hash that's in no repository, which the record says.
- **`since-previous`'s fields** are a fixed list. The JSON of both snapshots allows a fuller diff later; the earlier snapshot is replaced, so a later diff would need DIR copied first.
