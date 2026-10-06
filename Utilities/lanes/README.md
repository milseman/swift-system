# lanes

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

## What each row says

- **Branch, head**: the checked-out branch, the head commit and its committer time.
- **vs the integration branch**: commits ahead and behind `system-next` for swift-system's worktrees, and `main` for the examples'. An adopter's migration branch records no base, so its row gives the last commit time instead.
- **Uncommitted**: files `git status --porcelain --untracked-files=all` lists.
- **In progress**: a merge (`MERGE_HEAD`), cherry-pick, revert or rebase.
- **Conflicts**: files a trial merge of the integration branch and the lane conflicts in (`git merge-tree --write-tree`), when the lane is both ahead and behind; 0 when one side is an ancestor of the other.
- **Report**: the newest report the lane owns, with its modification time and the first line under "Resume here". Reports are `REPORT*.md`, `*-REPORT.md` (`RECOLLAPSE-*-REPORT.md` among them) and `Prototype/*/REPORT.md`. A lane owns the ones its branch changed since its merge base with the integration branch, plus any uncommitted ones. An adopter or a workspace owns every one in its working tree, since there's no base to diff against.
- **Linux log**: the newest log in `../linux-logs` named for the lane, with its last `Executed N tests` and `Test run with` lines. A log is named for a worktree lane when its name starts with the worktree's directory or branch name and a `-`. It's named for an adopter when its name has `-<package>-` (`recollapse-b-swift-log-musl-….log`). It's named for a workspace when its name starts with its newest report's lane (`RECOLLAPSE-C-REPORT.md` is `recollapse-c`).
- **Session**: the newest `~/.claude/projects/<path>/*.jsonl`, where `<path>` is the lane's path with every character but a letter or a digit replaced by `-`. That's Claude Code's encoding, as this machine's directory names show (`/Users/m/development/base_dir/system-next/tooling-1` is `-Users-m-development-base-dir-system-next-tooling-1`). A session is *active* if its transcript changed in the last 15 minutes. *none* means there's no directory or transcript, and *unknown* means `~/.claude` can't be read, as from the coordinator's shell.
- **Free disk**: `df -h` of the root, once, at the top.

## Read-only, and mounted elsewhere

- Every git call has `--no-optional-locks` (no index refresh is written) and runs with `GIT_NO_LAZY_FETCH=1`, so a partial clone fetches nothing. The trial merges run with `GIT_OBJECT_DIRECTORY` set to a temporary directory, and the repository's objects as alternates. The trees and blobs `merge-tree` writes go there, and the directory is deleted. The tests check that no object reaches the repository.
- A worktree's `.git` file and its main clone's `worktrees/*/gitdir` record absolute paths. When the folder is seen at another path, as in the coordinator's shell, those paths don't exist. A recorded path that's missing is then looked up under the root by its last components, longest suffix first: `/Users/m/…/system-next/adopters-unix/swift-nio` is found at `<root>/adopters-unix/swift-nio`. Git then runs with `--git-dir` (the worktree's directory under the main clone, found the same way) and `--work-tree`. Sessions are looked up at the path the lanes were recorded at, which is where Claude Code ran.
- A worktree whose directory is gone is listed with its recorded path. `git worktree prune` would drop it; this tool doesn't.

## Speed

About a second on this machine for 45 lanes: the lanes are read eight at a time, and the slowest git call is `git status` in the largest adopter clones. A lane past `--timeout` or `--deadline` is skipped, and the table says which, and why.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'
```

They cover the path encoding, the report patterns, the "Resume here" reader and the log matcher, over text fixtures. They also build a folder of fixture repositories in one temporary directory: a main clone with an integration branch and three worktrees (ahead, conflicting with a merge in progress, deleted), an adopter clone and its worktree, a workspace report, Linux logs and a stand-in for `~/.claude`. The tests read it, move it and read it again from the new place. Git runs with no global or system configuration. Nothing outside the temporary directory is written, and it's deleted.

## Design calls

- **Discovered, not configured.** Lanes come from `git worktree list` and the adopter directories. *Rejected*: a list of lanes in a file, which goes stale the day a lane closes. `examples-info` was removed while this tool was written, and its stale worktree entry is the case the "gone" row covers.
- **Owned reports by the branch's diff.** *Rejected*: the newest report anywhere in the worktree. Every worktree has every lane's merged `Prototype/*/REPORT.md`, so the newest by modification time would be whichever the last checkout touched.
- **Workspaces as lanes.** The adopter lanes (recollapse-a to -d, packages-N, uc-adopt) work across many clones from `../adopters` or `../adopters-unix`. Their reports and sessions are the workspace's, so the workspace gets a row.
- **merge-tree into a scratch object directory.** *Rejected*: plain `git merge-tree --write-tree`, which leaves loose objects in the repository (harmless, but a write); and the old trivial-merge mode, which needs no writes but misses renames.

## Next

- A `--since` view: lanes whose head, report or session changed since a time, for a coordinator's catch-up.
- Read the lane's own `STATUS.md` or `MIGRATION.md` totals where a report has none.
- For adopters, the migration branch's base could be recorded (a tag per lane) so that "commits ahead" means something there too.
