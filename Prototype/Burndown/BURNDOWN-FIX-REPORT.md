# api-burndown fix: the page's known errors F1 to F3

Lane `burndown-fix` (worktree `../burndown-fix`, branch `burndown-fix`, from system-next `a3dbd4e`), 2026-10-05.

## Resume here

Done; nothing to resume. The fix is `c5d55ee`; the page regenerated with it is `ad8bb0c`; this report and the "fixed" marks in `VERIFY-REPORT.md` section 3 are the commit after. system-next didn't move during the lane, so nothing was merged. What other tools need is in section 6, and nothing is waiting on Michael.

## 1. What

The three errors `verify.sh` found (`VERIFY-REPORT.md`, section 3), each fixed where it arose, in `Utilities/api-burndown` only:

- **F1, hidden operators' kind.** `history.scan_kind` (`scripts/history.py:147`) now gives a scanned declaration the kind the symbol graphs would give it. A function named by an operator (`OPERATOR_NAME_RE`, `:60`) is `swift.func.op`, whether it's a type's static member or global. A `class` member is static, and a static subscript is `swift.type.subscript`. `SCAN_FORMAT` is 3, so cached scans are redone. Four hidden declarations are now Operators rather than Type Methods: `EventPoll.Event.==(lhs:rhs:)`, `IntervalTimer.Schedule.==(lhs:rhs:)`, `Win32.Error.~=(_:_:)`, and a fourth that the verify lane didn't see, `Win32.FileTime.<`. api-delta's scanner names that one `< ()`, and `verify.py`'s `symbol_kind` (`scripts/verify.py:521`) didn't strip the space, so both tools agreed on the wrong kind. It strips the space now.
- **F2, the module's first header.** `Headers.vocab_hit` (`scripts/headers.py:394`) gave a name its vocabulary module's first header (`ar.h`, for `Darwin`) when none of the module's headers named it. Now it first tries `in_included` (`:368`): the headers in no module that the module's headers include. Such a header is in the module of the header that includes it, as for a `#define`. When neither names it, the module is passed over. `in6addr_any`, `in6addr_loopback`, `ipi6_addr` and `ipi6_ifindex` are in `netinet6/in6.h` (`Darwin.POSIX.netinet.in`), "by vocabulary (included header)".
- **F3, another platform's field spelling.** `burndown.locate` (`scripts/burndown.py:389`) now places a field in its struct's header only if that header names the field: `Headers.has_identifier` (`scripts/headers.py:341`) looks for it as an identifier outside comments. So `primary_header` takes the first C name the macOS SDK declares, as design call 13 says. The four `stat` time accessors are grouped by `stat.st_atimespec`, `st_mtimespec`, `st_ctimespec` and `st_birthtimespec`, not by Linux's `st_atim` and its siblings, which their doc sentences name first. `Headers.text` (`:322`) also reads a framework's headers, for a framework struct's fields.
- **verify.py.** The three `KNOWN` rules and the code that matched them are deleted. That includes `classify_kind` and the recount's explained/unexplained split, which only F1 used. Any kind mismatch now fails, like any other unexplained miss.
- **README.md.** Design calls 12 and 13 say how a header in no module and a field are found, with what they rejected; the bullet about a field moved from under *Rejected* to the rules. New design call 20 covers the scan's kinds. The known-error list in "Verify" is empty, and the field limitation names `ipi6_addr`'s header.

On the same inputs, `burndown.json` differs from the unfixed tool's in exactly those 12 declarations (section 2). Totals, days and history units are unchanged.

## 2. The run

`Utilities/api-burndown/regenerate.sh`, run once at the end at `c5d55ee`, with its defaults: 162 seconds.

- **api-delta** ran, since this worktree had no earlier run: main `1b452c2` against system-next `a3dbd4e`.
- **Graph:** `auto` picked the snapshot store's graph of `a3dbd4e`, system-next's head (`../api-graph-snapshots/a3dbd4ec0c9fd2c27c2292b4e8360e7b10a81dbd.json.gz`), so api-graph didn't run and nothing was rebuilt.
- **Checks:** `--check` OK. `verify.sh` (default sample): 0 fail and 1 warn, the stale `origin/main`. None of F1 to F3 appears, and `verify.md` names none of their rules. The details are in `.build/api-burndown/verify.md` in this worktree.
- **Page:** committed in `ad8bb0c`, replacing the one from 2026-10-03 at `d5541b6`.

Before the run, two burn-downs were built with `burndown.py` in a scratch directory under `$TMPDIR`, since deleted. Both used a separate api-delta run for the same commits and the same graph; one used the tool at `a3dbd4e`, the other the fixed tool. `verify.py --sample all` went from 0 fail, 4 warn to 0 fail, 1 warn. The four warns were the stale `origin/main`, F1's three declarations on the two kind lines, and F2's and F3's four each on the headers line; the one left is `origin/main`. The four F2 declarations now pass by the method cause `vocab-parent-module`: the vocabulary has them in `Darwin`, a parent of `Darwin.POSIX.netinet.in`. The fixed tool's `burndown.json` and the regenerate's have the same declarations.

## 3. Design calls

1. **The scan's kinds are the symbol graphs', all of them, not only the operator rule F1 needed.** Each rule matches what `swiftc -emit-symbol-graph` (Swift 6.2) gives a small module: operators, static and global, among them a prefix `√`; `class func` and `class var`; a static subscript; a global function. A global `var` is the exception (design call 2).
   *Rejected:* the operator rule alone. That leaves `class` members and static subscripts wrong whenever one appears off Darwin. None does today, so these two rules change nothing on the page yet.
2. **A top-level `var` stays a property.** The symbol graphs would call it a Global Variable (`swift.var`), as `verify.py`'s recount does.
   *Rejected:* `swift.var`. The scanner loses the scope of `IORing`'s members (section 5). That rule would make the three instance properties it puts at the top level global, and no new public `var` is truly global. Open: once the scanner keeps that scope, `swift.var` is right.
3. **An operator is a function whose name doesn't start like an identifier:** not a letter, digit, `_` or backtick (`\s*[^\w\s`(]`). That covers the scanner's `< ()` and Unicode operators.
   *Rejected:* `verify.py`'s rule, every character in ASCII `/=-+!*%<>&|^~?.`. It misses `√`, and the two tools would then agree on the wrong kind. The two rules stay separate, so the recount stays independent.
   *Rejected:* fixing the scanner's `< ()` name, which is api-delta's (section 6).
4. **A header in no module is searched only when the vocabulary's module includes it**, through `included_by`, the breadth-first map the tool already had, and it's reported in the includer's module.
   *Rejected:*
   - Searching every Darwin header for the name, which finds uses as well as declarations.
   - Reporting the vocabulary's module (`Darwin`). That passes verify with no cause, but disagrees with every `#define` the tool finds in the same header, which it puts in `Darwin.POSIX.netinet.in`.
5. **When no header of a vocabulary module names the name, the module is passed over**, and the lookup goes on to the headers' text tables, then "not in the macOS SDK".
   *Rejected:* the old fallback, a header that says nothing about the name.
   *Rejected:* a group of its own ("in the vocabulary, in no header"), a new special header for the page and verify.
   Today only the four F2 names used the fallback: 6 name and kind pairs among the 3,191 C names of the graph's `wraps` links, all now in `netinet6/in6.h`. So nothing lands in "not in the macOS SDK" because of this change. Open: a future name that does would land there unchecked, since check 5 samples only real headers (section 6).
6. **A field is its struct's header's when that header names it as an identifier, outside comments.** It's the same test `verify.py`'s `declares` makes.
   *Rejected:* finding the field inside the struct's braces. Darwin's `struct stat` is `struct stat __DARWIN_STRUCT_STAT64;`, a macro, and the braces of `struct stat {` belong to the 32-bit-inode variant, which has no `st_birthtimespec`.
   *Rejected:* also searching the headers the struct's header includes. No field needed it (section 5), and it would widen what passes.
   *Rejected:* reordering a declaration's C names by platform. The doc sentence's order is design call 13's, and the SDK test already skips the other platform's spelling.
7. **verify.py loses the machinery only F1 used.** `classify_kind`, the `operator` field and the explained/unexplained split are deleted, so a kind mismatch fails.
   *Rejected:* keeping `classify_kind` as a hook that returns `None`. Checks 4 and 5 keep their method causes, so the `KNOWN` mechanism, and its `error` kind, stays for whatever comes next.

## 4. Tests

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'`:

- Before (`a3dbd4e`): 45 tests, OK.
- After (`c5d55ee`): 51 tests, OK: `test_burndown.py` 20, `test_verify.py` 31.
- The new test files against the unfixed scripts (`a3dbd4e`'s, in scratch): 11 of the 51 fail. Nine are the new or changed tests; the other two are recount tests whose fixture now names `< ()`.

New and changed tests, each on text fixtures:

- `ScanKindTests` (`test_burndown.py:322`), for F1. A Swift text fixture is scanned with api-delta's own `scan_file`. `test_kinds_are_the_symbol_graphs` checks each declaration's kind against what Swift 6.2's symbol graphs give the same source. `test_a_hidden_operator_is_an_operator_on_the_page` passes the scanned `< ()` and `==` through `delta_units` as hidden declarations and checks that the page's kind name is Operator. `test_names` covers the name rule: `..<`, `√`, a backticked name, and a top-level `var` that stays a property.
- `ModuleMapTests` gains `ar.h`, `netinet/in.h` including `netinet6/in6.h` (in no module), a Darwin-like `struct stat` with `st_atim` only in a comment, and a framework, `CoreFoo`, in its fake SDK. Its `struct kevent` fixture gains the `ident` field that `test_primary_header` names; without it, the F3 check rightly rejects `kevent.ident`.
  - `test_a_header_in_no_module_that_a_module_includes`: for F2, three names are in `netinet6/in6.h`, and a name no header names gets no header, not `ar.h`.
  - `test_a_field_is_in_its_structs_header_only_if_the_header_names_it`: for F3, Linux's spelling is skipped, and so is a field that only a comment names. A macro spelling (`st_atime`) counts, a declaration with only another platform's spelling is "not in the macOS SDK", and a framework struct's field is in the framework's header.
- In `test_verify.py`, the old known-error tests now expect fails: `test_a_hidden_operator_typed_as_a_method_fails` (for both `==` and `< ()`), `test_a_modules_first_header_fails`, and the new `test_another_platforms_field_spelling_fails`. `test_symbol_kinds_of_hidden_declarations` adds `< ()`.

**Where they write.** I checked each test before running it. The new ones write only under their own `tempfile.mkdtemp` directory (`api-burndown-sdk-…`, `api-burndown-scan-…`) and delete it in `tearDown`. `Headers` gets no cache directory, so no index is written, and `scan_file` only reads. The `test_verify.py` changes are in memory, or read the existing fixture's temporary SDK. After a full run, `$TMPDIR` had no directories with the tests' prefixes, `git status` was clean, and there was no `__pycache__`.

## 5. Findings

- **F1 had four cases, not three.** Both the page and verify's recount typed `Win32.FileTime.<` as a Type Method, because api-delta's scanner names `static func < (lhs:rhs:)` `< ()`. Its function-name pattern (`Utilities/api-delta/scripts/scan_sources.py:341`, `[A-Za-z_]\w*|[^\s(<]+`) excludes `<`, so the fallback name keeps a space and loses the labels. The page's path for it is `Win32.FileTime.< ()`. The scan has seven `< ()` operators in all; only the Win32 one is hidden.
- **api-graph's graph has the same four wrong.** In the store's graph of `a3dbd4e`, the four scan nodes have `symbolKind` `swift.type.method` (section 6).
- **api-delta's scanner loses `IORing`'s scope.** In `Sources/System/IORing/IORing.swift`, every member of `public struct IORing: ~Copyable {` (line 354), and every type nested in it, is scanned with no scopes. Examples are `init(queueDepth:flags:)` at 424, `registeredFileSlots` at 738, `supportedFeatures` at 915, and `SetupFlags` at 400 as a top-level type. No other file has an initializer, subscript or property without a scope. None of these declarations is on the page, since main has all of `IORing.swift`. It's why design call 2 keeps a top-level `var` a property.
- **F3's check, over every field in the graph:** of its 349 `struct.field` C names, 15 aren't named by their struct's Darwin header.
  - The four `stat` time fields are F3.
  - `statfs.f_flag` is `StatFS.mountFlags`'s alternative, so the declaration stays under its subject, `statfs.f_flags`.
  - Ten Windows console fields, such as `dwSize.X`, are on no Darwin declaration.
- **`origin/main`** is 27 commits ahead of `main` and was last fetched on 2026-09-25, as before. This lane fetches nothing.

## 6. Next, and needs outside this lane

- **api-graph** (the ledger lane owns `Utilities/api-graph/`). `scripts/build_graph.py:407-411` gives scan-only declarations the old kinds. It needs the same rules as `history.scan_kind`. In place of those five lines:

  ```python
          kind = SCAN_KIND.get(x["kw"], "swift." + x["kw"])
          if x["kw"] == "func" and not x["scopes"]:
              kind = "swift.func"
          if x["kw"] in ("var", "let", "func", "subscript") and {"static", "class"} & set(x["modifiers"]):
              kind = {"swift.method": "swift.type.method", "swift.property": "swift.type.property",
                      "swift.subscript": "swift.type.subscript"}.get(kind, kind)
          # An operator, static or global; the scanner names `static func <` `< ()`.
          if x["kw"] == "func" and re.match(r"\s*[^\w\s`(]", x["name"]):
              kind = "swift.func.op"
  ```

  - The four nodes in section 5 become `swift.func.op`, and `pitches.py`'s kind counts follow. `CALLABLE_KINDS` already has `swift.func.op`.
  - The burn-down doesn't read these kinds: it takes a hidden declaration's kind from its own scan.
  - An alternative to two copies: api-graph moves the rule into a small function the burn-down imports, as it already imports `pitches.py`.
  - The `SCAN_KIND` comment in `history.py` names `build_graph.py` as the table's source, which stays true either way.
- **api-delta** (`Utilities/api-delta/scripts/scan_sources.py`):
  - name `<` operators with their labels (`<(lhs:rhs:)`), as it does `==`;
  - keep `IORing`'s scope (section 5).

  Both reach api-delta's own `hiddenFromGraphs` and api-graph's scan nodes. The burn-down's scan cache is keyed by the scanner's contents, so after either change it rescans every day's commit by itself, and each day gets the new paths at once.
- **verify.py, possible:** check 5 doesn't sample declarations under "(not in the macOS SDK)". A check that the vocabulary has none of their C names in a Darwin module would catch a name that design call 5 now sends there.
- **From `VERIFY-REPORT.md` section 6, still open:** "Running it" and "What it writes" in the README could name `verify.sh`, `--no-verify` and `verify.md`. It's in this lane's files, but outside its task, so left as it was.
