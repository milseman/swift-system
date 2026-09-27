# adopter-coverage results

This directory is the results store of swift-system's `Utilities/adopter-coverage`. It lives outside every worktree, so it survives their removal, and every result in it is keyed by the commits that made it:

| Path | What |
|---|---|
| `runs/<run>/` | One `check.sh` run: `run.json` (the System commit, the tool, each package's commit and result), and the combined `COVERAGE.md` and `coverage.json`. A run's id comes from its System commit, tool and package commits, so repeating it lands on the same id. |
| `runs/log.tsv` | Every run, with its date. |
| `results/<package>/<package commit>/<System commit>/<tool>/` | One package against one System commit, by one version of the tool: `COVERAGE.md`, `coverage.json`, `interfaces.json.gz`, `meta.json`, `logs/`. |
| `systems/<System commit>/<tool>/` | System's API scan (`system-api.json`) and what it covers (`derived.json`). |
| `index/<package>/<package commit>/<key>/` | A build's index dump, with the export it was built from (`src.tar.gz`) and the manifest dumps, reused by every run of that commit with the same build settings. `build-failed` marks a commit the compiler at hand couldn't build, which is then extracted lexically. |
| `vocab/`, `sdk-probe/` | The SDK's names, for lexical extraction, and which SDK modules re-export Darwin. |

`<tool>` is a hash of the git trees of `Utilities/adopter-coverage` and api-delta's scanner, so a result names the exact tool that made it; `-dirty-` marks one made with uncommitted changes, which can't be verified.

From a swift-system checkout:

```sh
Utilities/adopter-coverage/results.sh list
Utilities/adopter-coverage/results.sh delta RUN_A RUN_B
Utilities/adopter-coverage/results.sh verify RUN
```

Nothing here is tracked by any repository; deleting a directory costs only the time to rebuild it.
