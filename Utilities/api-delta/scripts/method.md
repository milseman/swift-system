### Pipeline

`api-delta-out/regenerate.sh` runs every step. It writes only to `$WORK` (default `/tmp/api-delta-work`) and to `api-delta-out/`, and never touches tracked files.

1. **Export.** `git archive <ref>` exports each commit into `$WORK/{base,head}/src`, and `scripts/patch_manifest.py` patches the *exported* `Package.swift`.
2. **Symbol graphs.** For each export, `swift package dump-symbol-graph --minimum-access-level public --emit-extension-block-symbols` runs twice:
   - once with `--skip-synthesized-members --skip-inherited-docs`, for the diff;
   - once without them, for the docs and for telling inherited doc comments apart.
3. **Diff.** `scripts/symbolgraph_delta.py` diffs the two sets of graphs.
4. **Source scan.** `scripts/scan_sources.py` lexically scans both source trees, and `git diff -U0` gives the line map that separates new declarations from existing ones.
5. **Explicit-availability check.** `swift build -Xswiftc -Xfrontend -Xswiftc -require-explicit-availability=warn` runs on each export (see CLAUDE.md, Commands).
6. **Docs.** `scripts/docs_graphs.py` rewrites availability for DocC, then `xcrun docc convert` builds one archive per module and `xcrun docc merge` combines them.
7. **Cross-check.** `scripts/digester_check.py` dumps each module with `swift-api-digester -dump-sdk`, reconciles its added and removed declarations with the delta by USR, and runs `-diagnose-sdk` for breaking changes.
8. **Report.** `scripts/report.py` writes this file and `api-delta.json`, and includes `scripts/review-notes.md` verbatim.

### Design decisions

Each decision is listed with the alternative it rejected.

1. **Build from `git archive` exports in a scratch directory, not in a checkout.** Tracked files are never edited, even temporarily, so nothing needs reverting. `BASE_REF` and `HEAD_REF` can be any refs.
   *Rejected:* building in this worktree or in `../api-delta-main` with a temporary `Package.swift` edit. That risks leaving tracked changes behind, and it touches a checkout that other sessions may be using. One consequence: uncommitted work isn't included.
2. **Recover `System x.y` availability with a marker domain.** In the default build every `System` macro expands to the same OS versions (macOS 10.10, …), so symbol graphs can't tell `System 199` from `System 0.0.1`. The scratch manifest appends `OpenBSD <x.y>` to each macro's expansion.
   - The compiler then records the macro version in the symbol graph. It merges the version through enclosing extensions and types, taking the maximum, as it does for any availability.
   - OpenBSD isn't a compilation target here, so the macOS build and its diagnostics don't change.
   - Neither tree names OpenBSD in any `@available`.
   - Explicit OS floors show up as OS versions that differ from the macro expansion.

   *Rejected:*
   - The `SYSTEM_ABI_STABLE` mapping. SystemPackage doesn't build under it (CLAUDE.md lists the known failures), and it's lossy: `System 1.7.0` and the explicit `macOS 27.0` floors both become macOS 27, and several macros share OS versions.
   - Reading `@available` text from the sources. That doesn't reproduce how the compiler inherits availability. For example, a member of an unannotated extension of an annotated type has *no* availability in the graph.
3. **Remove the Samples executable and its swift-argument-parser dependency from the scratch manifest.** This avoids a network fetch, and Samples isn't part of either module's API.
   *Rejected:* resolving the dependency over the network, or copying `../swift-system/.build/checkouts`.
4. **Leave synthesized members out of the diff and record conformances instead.** Each new `OptionSet` would otherwise add about 20 `SetAlgebra` default implementations. The docs keep synthesized members, because they help when browsing.
   *Rejected:* one graph variant for both purposes.
5. **Match symbols by USR, then pair the leftovers by (path, kind) and declaration similarity.** A pair counts as *changed*. The comparison covers declaration text (with default arguments and printed attributes such as `@frozen` and `@discardableResult`), effective availability, conformances, generic and extension constraints, and access level. Doc-comment edits and file moves are recorded as notes, not changes.
   *Rejected:* USR-only matching, which reports a signature change such as `throws` → `throws(Errno)` as a removal plus an addition; and name-only matching, which breaks on overloads.
6. **Use the debug configuration.** It's the default, and it's what CLAUDE.md builds. The difference from release is `ENABLE_MOCKING`, and the source scan confirms that no public declaration sits under `ENABLE_MOCKING` or `DEBUG`.
   *Rejected:* a release build, which would have given the same public API at the cost of a second configuration.
7. **Use a lexical source scan for what the graphs omit, evaluating each declaration's `#if` stack per platform.** The platforms are Darwin, Linux (Glibc), Musl, Android, FreeBSD, OpenBSD, WASI and Windows.
   - The scan follows CLAUDE.md: FreeBSD and OpenBSD import the overlay named `Glibc`, `canImport(Darwin, _version:)` is assumed true for a current SDK, and IORing is Linux-only.
   - A module whose files reach `#error` on a platform is treated as not building there.
   - The scan is checked against the graphs. Every graph symbol maps to a scanned declaration, except enum cases (which have no `public` keyword) and synthesized `Codable` initializers. Every scanned public declaration missing from the graph is explained: unavailable stub, underscored, not compiled on Darwin, or member of a non-public type.

   *Rejected:*
   - Cross-building for Linux: no Linux SDK is installed, since `swift sdk list` is empty.
   - Diffing `.swiftinterface` files: that needs `-enable-library-evolution`, changes the build, and is still macOS-only.
8. **Decide whether a hidden declaration is new from `git diff -U0` line numbers.** A declaration is new if the line with its keyword was added.
   *Rejected:* matching names across trees, which is fragile with overloads and with per-platform duplicates such as `OutputFlags.expandTabs`.
9. **Build docs with `xcrun docc convert` from the same symbol graphs as the diff, then `xcrun docc merge`.** The docs can't disagree with the delta, and the manifest needs no plugin dependency and no network fetch. SystemSockets is converted with `--dependency` on the SystemPackage archive, so links from sockets docs to SystemPackage symbols resolve where DocC supports it.
   *Rejected:* swift-docc-plugin. It needs a `Package.swift` dependency edit and a network fetch, and it extracts its own graphs, which wouldn't carry the availability marker.
10. **Show availability in DocC as spelled in the source.** `scripts/docs_graphs.py` renames the marker domain to a `System x.y` platform, and drops OS entries that only repeat the macro expansion while keeping explicit floors. `--platform name=System,version=199.0.0,beta=true` then marks everything in `System 199` as **Beta**.
    *Rejected:* the ABI-stable OS mapping, where `System 199` becomes macOS 9999. It's lossy, as described under decision 2.
11. **Ship `main`'s SystemPackage archive as is.** `main` has one module, and in this toolchain `docc merge` of a single archive fails ("The file “tutorials” couldn't be opened").
12. **Cross-check with `swift-api-digester`, not with a second symbol-graph run.** The digester is the compiler's own API-breakage tool and applies different inclusion rules: it keeps implicit and underscored declarations. Agreement between the two is therefore meaningful, and the report lists every declaration the digester has that the graphs don't.
    *Rejected:* diffing `.swiftinterface` files, which needs library evolution (see decision 7).
13. **Keep hand review separate.** The naming and design notes in section 5 are hand-written in `scripts/review-notes.md` and included verbatim, stamped with the commit they were written against. Everything else is recomputed.

### Limitations

- The graphs come from macOS only. API that exists only on Linux, Windows or WASI comes from the lexical scan, which the compiler hasn't checked. Its platform sets rest on the assumptions in decision 7.
- Symbol graphs don't record `@_alwaysEmitIntoClient` or `@inlinable`, so ABI-only changes to existing API wouldn't be reported. Section 4 counts ABI surface in new code only.
- DocC diagnostics count as new when their summary text doesn't occur on `main`. Line numbers shift, so they can't be compared.

### Outputs

| Path | What |
|---|---|
| `API-DELTA.md` | This report. |
| `api-delta.json` | The same data in machine-readable form: every added, removed and changed entry with its declaration, availability, platforms, doc status and location, the declarations the graphs can't see, and the oddity lists. |
| `docs/<head>.doccarchive` | DocC for `system-next`: SystemPackage and SystemSockets merged, with a landing page. |
| `docs/<base>.doccarchive` | DocC for `main` (SystemPackage only). |
| `symbolgraphs/<ref>/` | The symbol graphs the diff read. Their availability includes the `OpenBSD` marker domain; read it as `System x.y`. |
| `logs/` | Build logs for `dump-symbol-graph` and the explicit-availability build, DocC logs and diagnostics, the source diff, run metadata (`meta.json`), and the `swift-api-digester` results (`digester.json`, `digester-SystemPackage.txt`). |
| `scripts/` | The pipeline, `review-notes.md` and this `method.md`. |
| `regenerate.sh` | Reruns everything. |

### Browsing the docs

DocC archives have to be served; they don't work from `file://`. Either open one in Xcode:

```sh
open api-delta-out/docs/system-next.doccarchive
open api-delta-out/docs/main.doccarchive
```

or serve it with any static web server:

```sh
python3 -m http.server 8000 --directory api-delta-out/docs/system-next.doccarchive
# then browse http://localhost:8000/documentation/
# (main: http://localhost:8000/documentation/systempackage/)
```

In the `system-next` docs, API marked `System 199` shows a **Beta** badge. Explicit OS floors appear as ordinary platform badges.

### Regenerating

```sh
api-delta-out/regenerate.sh      # main vs system-next; scratch in /tmp/api-delta-work
BASE_REF=main HEAD_REF=HEAD WORK=/tmp/api-delta-work api-delta-out/regenerate.sh
```

A full run takes a few minutes, most of it the four builds. It needs Xcode's toolchain (`swift`, `xcrun docc`) and `python3`, and no network.
