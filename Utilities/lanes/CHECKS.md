# The coordinator's checks, and where the snapshot answers them

Every check the coordinator makes when it checks on the lanes, with where it comes from and the part of `snapshot.sh`'s output that answers it. The coordinator's shell sees only `~/development/base_dir/system-next`, at another path, with git 2.34, python3, no `swift`, no `~/.claude`, and a 120-second limit per call. A row this shell can't answer says so, and why. Section names are `snapshot.sh`'s (`DIR/<section>.md` and `.json`); see README.md for the fields.

Sources:

- **H4**: the handoff's verification recipes (its section 4), as quoted in tooling-2's prompt.
- **HR**: the handoff's per-round notes, as quoted there.
- **S**: the simulated check-in of 2026-10-09, as quoted there.
- **C**: the coordinator's additions of 2026-10-09 (items 1 to 7), from its check-ins of 10-07 to 10-09.
- **LW**: `../Claude outputs/lane-workflow.md`, the coordinator's instructions (its section numbers).
- **P**: tooling-2's prompt's list of what the snapshot holds.
- **T**: added by tooling-2, for a check the others imply.

## Lanes and their git state

| # | Check | Source | Answered by |
|---:|---|---|---|
| 1 | Which lanes exist: swift-system's and the examples' worktrees (the main clones included), pitch worktrees, adopter clones, `adopters-unix` worktrees, adopter workspaces; and worktrees whose directory is gone | LW 13, P | `lanes`: one row per lane, a gone worktree with its recorded path |
| 2 | Paths: worktrees' `.git` files and `worktrees/*/gitdir` name `/Users/milseman/…`, which the coordinator's shell doesn't have; every such path is mapped to the folder as seen, for every repository with worktrees (swift-system, the examples, each adopter clone with an `adopters-unix` worktree), and the index says when a mapping was needed or failed | C1, H4 | index (paths line); `environment` (every mapping and failure); `lanes` (`recordedPath`, `gitDir`, `problem`) |
| 3 | Branch, head commit and its time | H4, P | `lanes` |
| 4 | Every branch a clone has; for adopters, each `migrate-*` head and the worktree it's checked out in | P | `branches` (local branches with head, time, subject and worktree; remote-tracking branches; every worktree with its mapped path) |
| 5 | Ahead of and behind the integration branch (`system-next`; the examples' `main`; `origin/main` for a pitch lane) | LW 8 | `lanes` |
| 6 | The lane merged the integration branch when it moved (standing rule) | LW 6 | `lanes` (behind); `commits` (merge commits are marked) |
| 7 | Each lane's commits: since the integration branch; for a pitch lane since its base on `origin/main`; for an adopter since `--since` | HR, P | `commits` (hash, time, subject, parents) |
| 8 | What changed since the last check | LW 4 ("Changed since last reply"), S, C5 | `since-previous` (a diff with the snapshot `--out` held, which also sets the default `--since`); `commits` and `lanes` mark commits newer than `--since` |
| 9 | Nothing is uncommitted: uncommitted and untracked files, listed | H4 (`git status --porcelain` with `GIT_DIR`/`GIT_COMMON_DIR`/`GIT_WORK_TREE`), HR | `git-state` |
| 10 | A merge in progress (`MERGE_HEAD` in the worktree's git directory); also a cherry-pick, revert or rebase | H4, P | `git-state` (with the commit being merged and its subject); `lanes` |
| 11 | The main clones' state after a Close: `MERGE_HEAD`, a dirty tree, uncommitted conflict markers | C2 | `git-state` for `swift-system` and `swift-system-examples` (unmerged index entries, and conflict-marker lines in every uncommitted file, for every lane) |
| 12 | Stale lock files under any `.git` (`index.lock`, `HEAD.lock`, `*.lock` in refs), with their times | C2 | `git-state` (every `*.lock` in each repository's git directories, worktrees' included, but not in `objects/`'s loose-object directories) |
| 13 | Files changed since the merge base, listed, with a diffstat by top-level directory | P | `changed-files` |
| 14 | Files changed outside the lane's own | HR | In part. `changed-files` lists every file and the diffstat by top-level directory. **Not answerable from this shell**: which files a lane owns is in its prompt, which isn't in the folder. |
| 15 | A trial merge with the integration branch, conflicting files listed | H4 (`git merge-tree`), HR, P | `trial-merges`, and its mode: `write-tree` (git 2.38 and later) or `trivial` (older git, the coordinator's: it misses conflicts through a rename) |
| 16 | Conflicts between the lanes of a round | HR, P | `trial-merges` (every two lanes ahead of the same integration branch) |
| 17 | New names added by more than one lane: public top-level declarations, and members added to the same type across extensions, files and modules (10-09: coverage-9 and winsock-1 both added `static var` error codes to `Win32.Error`; a textual merge shows no conflict) | HR, LW 8, C3 | `names`: each lane's added declarations with their enclosing type, and the keys more than one lane adds, or a lane and its integration branch since their merge base |

## Reports

| # | Check | Source | Answered by |
|---:|---|---|---|
| 18 | Each report's outline and size (43 to 54 KB each on 10-09) | S | `reports` (path, modification time, size, every heading with its line) |
| 19 | Where the lane says to resume | LW 6, LW 7 | `reports` (the whole "Resume here" section) |
| 20 | The commits a report names exist on the lane's branch | LW 8, HR | `reports` (every hash, whether it's a commit in the lane's repository, whether the lane's branch has it, the local branches that do, and the other repositories that have it) |
| 21 | The report's other claims (figures, test counts, what it says it did) | HR, LW 8 | In part. The snapshot holds what a recount reads: file lists (`changed-files`), lint's marker findings (`lint`), Linux test totals (`linux-logs`). **Not answerable from this shell** in general: what to recount is per claim, and a macOS build or test leaves no file to read. |
| 22 | Which reports changed since the last check | LW 4, C5 | `since-previous` (size, time and an outline diff); `reports` (times) |
| 23 | The adopters' `MIGRATION.md` | P | `reports` (each clone's and worktree's, read like a report) |

## Activity

| # | Check | Source | Answered by |
|---:|---|---|---|
| 24 | Recent writes in `.build` | S | `activity` (the newest file in `.build`, and outside it) |
| 25 | The newest file written in the lane's tree (`.build` included, `.git` excluded) | P | `activity` |
| 26 | Writes in the workspaces' `logs-*` and `tools-*` | P | `activity` (each directory of a workspace that isn't a clone, and its files) |
| 27 | The lane's Claude Code session and when its transcript last changed | P | `activity`. **Not answerable from this shell**: `~/.claude` isn't there; sessions say `unknown` and the newest writes stand in. |
| 28 | A lane that looks stuck may never have been launched: the tab table | LW 8 | **Not answerable from this shell**: tabs are Michael's Terminal. The newest writes (`activity`) and commits are the evidence. |

## Linux logs

| # | Check | Source | Answered by |
|---:|---|---|---|
| 29 | A log's totals: `grep -E 'Executed [0-9]+ tests\|Test run with' <log> \| tail -2` | H4 | `linux-logs` (the last of each) |
| 30 | The newest Linux logs | S | `linux-logs` (newest first) |
| 31 | Each log's lane and commit, time, size, `error:` lines (count and first lines), exit-status line | P | `linux-logs` |
| 32 | Whether a lane's head has a log | T | `lanes` (its newest log, and whether that names its head) |

## Integration branches and Closes

| # | Check | Source | Answered by |
|---:|---|---|---|
| 33 | First-parent merges since the last check | S | `integration` (first-parent history since `--since`, which defaults to the earlier snapshot's time, else 7 days) |
| 34 | Whether a Close ran: the merge commit, and the lane's worktree and branch gone (the chain removes them only after its build and tests pass) | H4, LW 9 | `integration` (per merge: the lane, the branch and the worktree present or gone) |
| 35 | A Close's evidence beyond that: the logs a Close block writes for the merge commit (`../linux-logs/system-next-<commit>-*.log`, `examples-<commit>-*.log`). On 10-09 winsock-1's Close stopped silently after the merge; the evidence was a remaining worktree and a missing log | C6, S | `integration` (per merge: those logs, and any other naming the commit) |
| 36 | A Close running or failed (winsock-1, 10-09: merged at 09:00, worktree and branch still there) | S | `integration` (gone or not) with `activity` (writes in the main clone's `.build`) and `git-state` (the main clone's tree). **Not answerable from this shell**: whether the chain's process is still running; processes on the Mac aren't visible. |
| 37 | The merge commit's parents: the merge took what the branch held | LW 9 | `integration` (parents; the branch's head now, if it's still there, and its commits past the merge) |
| 38 | What a merge brought: `--stat`, split into `Sources/` with `Package.swift`, and the rest | P | `integration` |
| 39 | Whether `system-next`'s head has a Linux log; merges touching `Sources/` since the last commit that has one (10-09: none since `0e339dc`, across three such merges) | S | `integration` (the last commit with a `system-next-<commit>` log, and every first-parent commit since, with whether it touches `Sources/` or `Package.swift`); the same for the examples' `examples-<commit>` logs |
| 40 | The CMake list check at the head: `for f in $(git ls-files Sources/System \| grep '\.swift$'); do grep -qF "${f#Sources/System/}" Sources/System/CMakeLists.txt \|\| echo "MISSING $f"; done` | H4 | `integration` (the recipe, read from the head commit rather than a working tree); `lint` (lint's cmake check, which also finds stale entries) |
| 41 | `Utilities/lint/lint.sh` at the head, every check that runs without `swift` | P | `lint`: cmake and pitches at `system-next`'s head, from a scratch checkout of it. **Not answerable from this shell**: the api check, which reads api-delta's output, built with `swift`; it runs only when the main clone has a current `.build/api-delta`. |
| 42 | Adopters: `lint.sh markers` and `lint.sh conditionals` per clone at its newest migration branch | P | `lint` |
| 43 | When `Prototype/Status/STATUS.md` was last regenerated | P | `status` (its last commit on `system-next`) |
| 44 | STATUS.md's content: section 5's gap table as data (each row's gap, the platforms lacking it, *Unblocks*, *Holds*, repositories), per-platform sums of *Unblocks* (the Windows and non-Windows split, computed by hand on 10-07 to choose lanes), and the ledger's per-category site counts | C4 | `status` (the table's rows, sums per platform, for rows lacking only Windows and rows lacking another platform, the per-category counts and each platform's sites left) |

## Environment

| # | Check | Source | Answered by |
|---:|---|---|---|
| 45 | Free disk (the standing rule: wait under 15 GiB) | LW 6 | `environment` (`df -h`) |
| 46 | `../linux-logs`' size | P | `environment` (`du -sh`, if it fits the time) |
| 47 | The git version, and which trial-merge mode ran | P | `environment`, index |
| 48 | Times in one zone: the folder's shell can show UTC while git's dates are local | LW 8 | Every section: times are converted to the zone of the shell that ran the snapshot, and labeled with it |
| 49 | Claims are checked against the current tip, not the lane's base | LW 8 | Every section reads heads as they are when the snapshot runs; `environment` has the time |

## Checks this shell can't run

None of these runs in the coordinator's shell: there's no `swift`, the Windows checks compile with `swiftc`, and the Linux runs need Apple's `container` tool on the Mac. Each is the command Michael runs (from tab 1, the main clone), for a step in a block. The snapshot's `environment` section lists the same commands with the folder's recorded path and the current heads.

| # | Check | Command |
|---:|---|---|
| 50 | System builds on macOS | `cd ~/development/base_dir/system-next/swift-system && swift build` |
| 51 | System's tests pass on macOS | `cd ~/development/base_dir/system-next/swift-system && swift test` |
| 52 | A lane builds and passes its tests on macOS | `cd ~/development/base_dir/system-next/<lane> && swift build && swift test` |
| 53 | The Win32 namespace and its tests compile against the Windows model | `cd ~/development/base_dir/system-next/swift-system && Prototype/Win32/check-windows.sh` |
| 54 | SystemWinSocks and its tests compile against the Winsock model | `cd ~/development/base_dir/system-next/swift-system && Prototype/Win32/check-winsock.sh` |
| 55 | The examples' tests pass on Linux (writes `../linux-logs/examples-<commit>-all.log`) | `cd ~/development/base_dir/system-next/swift-system-examples && Scripts/test-linux.sh` |
| 56 | The examples build and pass their tests on macOS | `cd ~/development/base_dir/system-next/swift-system-examples && swift build && swift test` |
| 57 | System's tests pass on Linux, with the log a Close writes | `cd ~/development/base_dir/system-next/swift-system && Utilities/linux/build.sh --quiet --log "$PWD/../linux-logs/system-next-$(git rev-parse --short HEAD)-test.log" test` |
| 58 | lint's api check (runs api-delta, about 40 s, into `.build/lint`) | `cd ~/development/base_dir/system-next/swift-system && Utilities/lint/lint.sh api` |
| 59 | Whether a lane pushed anything (the standing rules forbid it) | Not a command: a push updates only a configured remote's tracking branch, which `branches` lists; a push to a URL leaves nothing in the folder, and the remote can't be read without the network. |
