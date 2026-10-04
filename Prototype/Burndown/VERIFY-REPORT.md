# api-burndown verify: the burn-down page's checks

Lane `verify` (worktree `../verify`, branch `verify`, from system-next `4bf3afd`), 2026-10-04.

## Resume here

Done at `b69b005`. `Utilities/api-burndown/verify.sh` runs the five checks; `regenerate.sh` runs it last and fails if it fails (`--no-verify` skips it). At `b69b005`, after a regenerate against system-next `4bf3afd`, it has no fails (section 2). Its warns are a stale `origin/main` and three known errors in the page, F1 to F3 (section 3), whose fixes belong to whoever owns `burndown.py`, `headers.py` and `history.py`. When one is fixed, its rule in `KNOWN` (`scripts/verify.py`) matches nothing: delete the rule and its name in the README's list. Open choices are in section 4; needs outside this lane in section 6.

The page in this worktree is from the run at `b69b005`, uncommitted, since `Prototype/Burndown/burndown.html` isn't this lane's: commit it to publish it, or `git checkout` it. A rerun takes 7 seconds, since api-delta's run, the graph and the scans are cached in `.build`.

## 1. What

- `Utilities/api-burndown/verify.sh` and `scripts/verify.py`: the checks, with `regenerate.sh`'s variables. They write `.build/api-burndown/verify.md` (each line, every miss, and for a sample of 50 or fewer, everything checked) and exit 1 on a fail. About 2 seconds; 15 with `--sample all`.
- `scripts/test_verify.py`: 30 tests (section 5).
- `regenerate.sh`: `--no-verify`, and verify.sh as step 4, after the check. `--check` is as it was.
- `README.md`, "Verify": what each check does, catches and can't, the known causes, and seven design calls with what they rejected.

## 2. The run

`API_GRAPH_BUILDS= API_BURNDOWN_GRAPH=run Utilities/api-burndown/regenerate.sh` (api-delta, then api-graph with cold adopter builds in scratch directories, then the burn-down: 17 minutes), then `regenerate.sh` and `verify.sh --sample all` at `b69b005`. The details are in `.build/api-burndown/verify.md`.

- Default sample, from `regenerate.sh`: 0 fail, 3 warn, 19 pass.
- `--sample all`: 0 fail, 4 warn, 18 pass. Every site, header and C name from the code was checked, and each miss has a cause:
  - warn, freshness: `main` is 27 commits behind `origin/main`, last fetched 2026-09-25. Everything else is current: the page, api-delta and the graph are at system-next's head, and the 19 migration branches are where the graph read them.
  - warn, recount (kinds, and the page's Kind grouping): F1.
  - warn, C names (headers): F2 and F3. The vocabulary's other disagreements all have a method cause: structs it puts at a forward declaration, macros from a header in no module that it files under `Darwin`, headers in no module, and macros the index didn't record.
  - pass, sites: the 11 lines without the declaration's name are initializers called through a typealias (`CInterop.TimeSpec(…)` for `timespec.init(seconds:nanoseconds:)`; NIO's `IOVector(…)` for `iovec.init(base:length:)`), which are right.
  - pass, C names (code): every C name from the code is a code-only link in the graph and is named in the code the declaration reaches.

## 3. Findings

Real errors in the page, not fixed here. Each is a known error in `KNOWN`, so it warns.

- **F1 `hidden-operator-kind`.** An operator that only the source scan sees has a method's kind. `history.scan_kind` (`Utilities/api-burndown/scripts/history.py:143`) has no rule for operators, so these three are Type Methods on the page, not Operators, as the 23 operators in the symbol graphs are: `EventPoll.Event.==(lhs:rhs:)` (`Sources/System/Events/EventPoll.swift:388`), `IntervalTimer.Schedule.==(lhs:rhs:)` (`Sources/System/Events/IntervalTimer.swift:303`), `Win32.Error.~=(_:_:)` (`Sources/System/Win32/Win32Error.swift:503`). Its comment says api-graph's `build_graph.py` gives scan-only declarations the same kinds, so a fix may belong in both.
- **F2 `module-header-fallback`.** Four declarations are under `ar.h`, the archive format's header, which doesn't name their C names. In `headers.py`, `vocab_hit` (`Utilities/api-burndown/scripts/headers.py:375`) falls back to the module's first header when none of the module's headers name the name. The vocabulary files these under the top module `Darwin`, since `netinet6/in6.h` is in no module. They are `IPv6Address.Host.any` (`in6addr_any`) and `IPv6Address.Host.loopback` (`in6addr_loopback`), in `Sources/SystemSockets/Sockets/SocketAddress+Host.swift:232` and `:238`, and `SocketDescriptor.IPv6PacketInfo.destination` (`ipi6_addr`) and `.interfaceIndex` (`ipi6_ifindex`), in `Sources/SystemSockets/Sockets/SocketMessages+IP.swift:71` and `:76`. All four are declared in `netinet6/in6.h` (`in6addr_any` at line 214, `in6_pktinfo.ipi6_addr` at 547). The last two are also fields the graph didn't name for their struct (the README's limitation for `si_pid`).
- **F3 `field-spelling`.** Four declarations have another platform's field as their primary C name. `stat.accessTime`, `stat.modificationTime`, `stat.statusChangeTime` and `stat.creationTime` (`Sources/System/Internals/CInterop+Accessors.swift:502`, `:511`, `:520`, `:533`) show `stat.st_atim`, `st_mtim`, `st_ctim` and `st_birthtim`. Darwin's `struct stat` has none of them. Each declaration also names Darwin's spelling (`stat.st_atimespec`), as its doc sentence says: "The corresponding C field is `st_atim`, or on Darwin `st_atimespec`." `burndown.py`'s `locate` (`scripts/burndown.py:389`) finds a field by its struct's header and never checks the field, so `primary_header` (`:398`) takes the first name, against design call 13: "the first of its C names the macOS SDK declares". The header is right; the C name the page groups by isn't.

## 4. Design calls

The README's "Verify" section has seven, each with what it rejected. Its alternatives, which stay open:

- Hook: `--sample all` in the hook would check every site and header (15 seconds, not 2), deterministically, where the default 25 finds a known error only when the sample happens to include it.
- Seed: a fixed seed would check the same sample until the data shifts; the default is a seed from the digest.
- Thresholds: `--max-misses K` would let up to K unexplained misses warn.
- Known errors: they could fail until fixed, rather than warn.

Beyond those:

- **Every known cause is checked, not assumed.** `init-through-alias` needs the `typealias` in the adopter's branch or in System; `vocab-forward-declaration` needs the struct's definition in the page's header; `macro-not-indexed` needs its `#define` there; `branch-moved` needs the name on the line at the commit the graph read.
  *Rejected:* a list of the sites known to miss, which a new error at another site would never match.
- **Check 5 checks the code, not only the graph.** That the graph has a code-only link for each C name the page marks "code" checks only that `burndown.py` read the graph right. So the check also walks the code itself, lexically; the walk was tuned on this run's data. Following every internal name passed 47% of wrong pairings (a C name another declaration's code reaches). Only the graph's recorded code passed 1 in 2,984, but missed 68 of the 2,281 right ones. System's internal spellings (`_x`, `system_x`, non-public types' initializers), four levels deep, passed 31 in 2,984 (1.0%) and found all 2,281.
- **Checks 3 to 5 read `burndown.json`, and check 2 reads the page's data.** The digest ties the two.
  *Rejected:* reading every check from the page, whose rows have no USRs or C name sources.
- **The recount pairs declarations, not just counts.** Each of api-delta's declarations is paired by origin, module, path, file and line, so a renamed or swapped declaration fails, even when every count still agrees.
- **`api-delta.json` is the one `burndown.json` records** (`.build/api-burndown/api-delta/`): the api-delta run the burn-down used. `API_BURNDOWN_DELTA` takes another.
  *Rejected:* `.build/api-delta`, where a separate run of api-delta writes by default, which may be of other commits.

## 5. Tests

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'`:

- Before (`4bf3afd`): 15 tests, OK (`test_burndown.py`).
- After (`b69b005`): 45 tests, OK: `test_burndown.py`'s 15 and `test_verify.py`'s 30.

`test_verify.py` has a small fixture per check. Checks 1, 4 and 5 use scratch git repositories, and checks 2 and 3 use `page.py`'s own encoding of the page. Each check passes on its fixture, and checks 2 to 5 fail on a planted miss:

1. Freshness: current refs pass. A head ref, an adopter branch and `origin/main` that moved, a fetch over seven days old, and an upstream that moved after the page flagged it each warn.
2. Sums: an off-by-one total, a row in no platform, a row with no state, another run's page, and a `burndown.json` edited after it was written each fail.
3. Recount: a wrong kind, a missing declaration, and a renamed one with every count intact each fail; a hidden operator typed as a method warns.
4. Sites: a line without the name fails. An initializer through a typealias, and a site that moved with its branch, are explained.
5. C names: a header that doesn't name its C name, or names it only in a comment, fails, and so does a module the vocabulary disagrees with. A forward declaration and an unindexed macro are explained, and the module's-header fallback warns. A C name only a mock hook reaches fails, and so does a "code" mark the graph disagrees with.

There are also unit tests of `split_name`, the seeded sample, `symbol_kind` and the mock-line filter, and one of the command, whose planted fail exits 1 and is written to the report.

## 6. Needs outside this lane

- F1 to F3: fixes in `history.py` (perhaps also api-graph's `build_graph.py`), `headers.py` and `burndown.py`.
- `Utilities/api-burndown/README.md`, outside "Verify": "Running it" and "What it writes" could name `verify.sh`, `--no-verify` and `verify.md`.
- `origin/main` hasn't been fetched since 2026-09-25, and `main` is 27 commits behind it. This lane fetches nothing.
