### Pipeline

`Utilities/api-graph/regenerate.sh` runs every step in a scratch directory (`API_GRAPH_WORK`, default `.build/api-graph-work`), and replaces the output directory (`API_GRAPH_OUT`, default `.build/api-graph`) only once every step has succeeded. It never touches tracked files.

1. **API delta.** `Utilities/api-delta/regenerate.sh` runs for the same two commits, into the scratch directory. Its symbol graphs, source scan and delta are this tool's input.
2. **Exports.** `git archive` exports both commits. The head export is built; both are scanned.
3. **Indexed build.** `swift build --build-tests -Xswiftc -index-store-path` builds the head export, tests and Samples included. `--skip-update` resolves swift-argument-parser from SwiftPM's local cache, so nothing is fetched. This runs at the same time as step 1.
4. **Scans.** api-delta's `scan_sources.py` scans both exports, and `scripts/source_index.py` indexes the head export's declarations by extent and top-level block.
5. **References.** `scripts/index_refs.py` reads the index store with the toolchain's libIndexStore.
6. **Graph.** `scripts/build_graph.py` builds the nodes, edges and atoms, and attaches tests, samples and the implementation each declaration needs.
   - **Adopters.** `scripts/adopters.py` finds the package clones in `API_GRAPH_ADOPTERS` and `API_GRAPH_ECOSYSTEM`. It builds each migration branch's commit against an export of the head commit, with an index store, or reuses the references it cached from an earlier build; matches what the build didn't compile lexically; attaches the diff hunk that introduced each use; and joins the packages' C interfaces, from the coverage tools' results store, with the C names in the declarations' doc comments.
7. **Clusters.** `scripts/cluster.py` promotes shared types, forms clusters and parts, tags contingencies, and ranks the carve-outs.
8. **Bundles.** `scripts/bundles.py` writes one bundle per cluster, ranked part and batch, with its Adopters section and `adopters.md`.
9. **Report.** `scripts/report.py` writes this file, `api-graph.json`, and the DOT graphs. It compares with the previous run's `api-graph.json` when there is one. `scripts/reach.py` aggregates the adopters by carve-out for both, and ranks or filters a run's carve-outs by reach.

### Terms

- **Node**: a declaration the head commit adds or changes.
- **Atom**: the top-level block holding a node, a type declaration or one `extension X { ... }`. A CInterop alias is an atom of its own.
- **Vocabulary**: a type that nodes use but that isn't a node. That covers everything on the base commit, anything from another module, and new types promoted to vocabulary.
- **Cluster**: a connected set of atoms once vocabulary is taken out.
- **Part**: a piece of a cluster that could be pitched on its own, after the parts it needs.
- **Batch**: several small clusters that only add members to one existing type in one file.
- **Carve-out**: a cluster, part or batch, as a candidate pitch.
- **Contingency**: an open design question a carve-out depends on.
- **Adopted site**: a line of a package's migration branch (`migrate-darwin`) that uses a node, with the hunk of the migration's diff that introduced it.
- **Would-benefit site**: a line of a package that uses a C interface a node newly wraps.
- **Reach**: the number of packages with either kind of site in a carve-out.

### Design decisions

Each decision is listed with the alternative it rejected.

1. **Build on api-delta by running it, and by importing its code.** Its symbol graphs, source scan and delta are the input, and `scan_sources.py` (the lexer, the declaration pattern, `#if` evaluation) and `report.py`'s diff parser are imported, not copied.
   *Rejected:* forking its scripts, which would drift; and reusing an existing `.build/api-delta` whenever its commits match, which would read output from an older version of api-delta without saying so. (`API_GRAPH_DELTA` reuses one on request.)
2. **Nodes are the whole delta: symbol-graph symbols plus the declarations only the source scan sees.** On system-next that adds 186 declarations compiled only off Darwin and 135 fix-it stubs. A scan-only declaration that's another platform's variant of a graph symbol, such as a CInterop alias spelled per C library, merges into it.
   *Rejected:* the macOS graphs alone, which would drop EventPoll, IntervalTimer, EventCounter and PThread.CPUSet.
3. **Edges come from the symbol graph's declaration fragments, by USR.** A member typealias named through its parent, `CInterop.PThreadMutex`, comes as `CInterop` with a USR, then `.`, then `PThreadMutex` without one, so the qualified name is rebuilt and looked up. Scan-only declarations get their edges from the type names in their source text, resolved in their enclosing scopes.
   *Rejected:* parsing signatures as text for every declaration, which can't tell overloads or generic parameters from types.
4. **Everything on the base commit is vocabulary, not just FileDescriptor, FilePath, Errno and CInterop.** UserID, GroupID, Stat and FilePermissions shipped too. As nodes, they'd join unrelated features: `setOwner(user:group:)` and UserEntry would be one cluster through UserID.
   *Rejected:* a hand-kept list of vocabulary types, which would go stale as main moves.
5. **Atoms are top-level blocks.** This repository writes one extension per C function family, often under a `// MARK: -` naming it, so a block is the smallest unit an author treated as one thing. A CInterop alias is an atom of its own, because one CInterop block holds many features' aliases.
   *Rejected:* declarations as atoms, which leaves 89 singletons and splits overloads; and files as atoms, because FilePathOperations.swift holds 14 C families and FileOperations.swift 20.
6. **A new type that code in two or more places outside its home depends on is promoted to vocabulary.** A place is a directory under the module, or a file in its root. Edges into a promoted type from outside its home are cut, and become prerequisites of the clusters they came from. On system-next that promotes ProcessID alone, which terminal job control, `F_SETOWN`, `FileLock.processID` and libproc's task and resource-usage info all use. The threshold and the promote and demote lists are in `config.json`.
   *Rejected:*
   - No promotion: one 450-declaration component, joined through ProcessID and the fcntl overloads.
   - Promoting every type with two dependents, or every articulation point: that splits Terminal into seven clusters, and FilePath's families from ResolutionFlags, although those do belong together.
7. **CInterop aliases join a cluster that uses them.** First choice is the cluster whose signatures name them most. Failing that, it's the cluster whose bodies use them (`CInterop.IOVec` appears only inside `sendMessage`), then the cluster owning the aliases declared beside them. Otherwise the file's unused aliases form one cluster.
8. **A cluster that nothing's signature connects to anything else, and whose types only one other cluster's implementation uses, joins that cluster if the two share a file.** This is how AddressResolutionError, which only the resolution functions throw, joins sockets.
   *Rejected:* implementation references as edges in general, which would pull standalone features such as SystemConfig into whatever happens to call them.
9. **Parts: atoms merge when:**
   - they're mutually dependent;
   - one extends or nests into a type the other declares in the same file;
   - they extend the same new type in one file;
   - a part is used by exactly one other part and is either a helper (copyable, wrapping no C function of its own) or in the same file;
   - they're unmarked leaves in one file that need the same parts.

   So flags and ControlCharacters fold into TerminalAttributes, and KernelEvent into KernelQueue. OwnedFD, DirectoryStream and DirectoryWalk stay separate owners, as do FilePath's C families.
   *Rejected:* one part per atom, which gives many one- and two-declaration parts; and folding any type used by one other part into it, which folds OwnedFD into DirectoryStream.
10. **Contingencies are data (`contingencies.json`), each with concrete rules.** A rule matches on noncopyable types, deinits, lifetimes, declaration or path patterns, the module, the platform, throwing closures, C names, or implementation pieces. Every tag records its evidence. The decisions document isn't in this repository, so each entry says in its own words what the tool takes the question to be.
    - *Typed throws*: plain `throws(Errno)` wrappers are precedent on main (Stat, FileOperations, IORing), so only API that has to combine a closure's error with an Errno counts (withRawMode, withLock, closeAfter), along with changes to an existing throws clause and non-Errno typed errors. *Rejected:* tagging every `throws(Errno)`, which would tag nearly everything and single out nothing.
    - *Win32 (75)*: compiling on Windows extends the UCRT layer that Vision.md says has to die. A concept a Win32 draft covers (byte-range locks, a descriptor's path, volume information) is a weaker, 0.4-weight naming tag.
11. **Contingencies pass along prerequisites, marked by route.** A contingency can arrive through signatures, through the implementation only (KernelQueue keeps an OwnedFD), or through nesting only (PThread.Mutex needs the name PThread, not the answer to PThread's deinit). A platform fact such as compiling on Windows doesn't pass on.
    *Rejected:* one kind of inheritance. That would make every PThread-nested type wait on item 80 as fully as PThread does, and make kqueue, which never compiles on Windows, wait on Win32.
12. **The ranking is a penalty score, never ahead of a prerequisite.** The score adds up size, types, undocumented and untested declarations, code not compiled on Darwin, unverified platform claims, platform variants, availability oddities, open questions (direct, inherited, implementation-only, nesting-only) and prerequisites, with a small credit for prior proposal text. The weights are in `config.json`. Among carve-outs whose prerequisites are placed, the lowest score goes next.
    - *Rejected:* the score alone, which put `F_SETOWN` before ProcessID; and a strict order by contingency, then size, which hides documentation and test gaps.
    - Batches take their members' place: FileOperations.swift's nine one- and two-declaration clusters would otherwise fill the top of the list.
13. **Tests and samples come from the index store, by USR.** Overloads are told apart: which tests call the Span `read(into:)` and which the buffer-pointer one. So are samples that only name a scratch file with `ProcessID.current`, which the bundle ranks last.
    *Rejected:* matching names, which can't separate overloads. It's kept only for declarations not compiled here, whose tests aren't either.
14. **A carve-out's implementation is the new internal code its bodies reach, through the index: `_foo`, `system_foo`, `_FOO` constants, CSystem shims.** Code that's already on the base commit is left out, since it doesn't have to land. A piece that another carve-out also reaches is marked shared.
15. **"Checked off Darwin" needs evidence (`evidence.json`), not an `#if`.** Today that's the events harness, `Prototype/Events/check-linux.sh`, which typechecks the Linux event code against a model header.
    *Rejected:* reading commit messages, which mostly say "Not run on Linux", and whose positive statements are ambiguous ("Run the termios tests on a pseudoterminal, on Linux too" enables them; it doesn't report a run).
16. **Bundles are self-contained.** They quote the source ranges, tests, samples, and the full messages of the commits that wrote most of the lines, found with `git blame` on the head commit. Commit bodies in this repository discuss shape, naming, precedent and platforms, which is pitch material.
    *Rejected:* links only, which would send a session searching; and whole files, which are mostly other carve-outs' code.
17. **Output and scratch directories follow api-delta's rules.** The script refuses a directory that git tracks or doesn't ignore, and deletes only directories it created.

18. **Adopted sites come from the compiler's index of each migration, built against the head commit.** A migration branch's commit is exported and built as the coverage tools build that package (its file in `Utilities/adopter-coverage/packages/`: targets, flags, environment, and a newer compiler where it names one), with its path dependency on swift-system pointed at an export of the head commit, and one on another migrated clone at that clone's branch. The store's references to a node's USR are its sites. USRs tell overloads apart (`makeFIFO(permissions:)` from `makeFIFO(_:relativeTo:permissions:)`), and see uses the text doesn't spell: `ev.data` once the migration makes `ev` a `KernelEvent`, and `sockaddr_storage()` now resolving to System's `init(family:)`, whose parameter has a default. A type named only to qualify the next reference (`PThread` in `PThread.Mutex`) is kept as a qualifier, which reach doesn't count, and implicit references (the accessors a property use calls) are dropped.
    *Rejected:*
    - Matching names in the migration's diff alone: it can't tell overloads or receivers apart (`.lock()` is every lock's).
    - The adopters' own `.build` index stores: they record their working trees, not commits, and other lanes are rebuilding them.
    - The coverage tools' index dumps: they exist only for the commits those tools audit, the packages' main branches.
19. **The references are cached by what the build depends on, and the build is deleted as soon as it's read.** The key is the package commit, System's Sources and manifest trees, the path dependencies' commits, the compiler, and the build settings. A first run builds 14 packages in about 15 minutes; later runs reuse the cache until a package or System's sources move. `API_GRAPH_ADOPTER_BUILDS=reuse` takes any cached index of the commit when System has moved, and no build starts with less than `API_GRAPH_MIN_FREE_GB` free.
    *Rejected:* keeping the builds, which are several GB each (SwiftPM's); rebuilding on every run.
20. **Lexical matching covers what the build doesn't compile: test files, added lines in `#if` branches the Darwin build doesn't take, and packages that don't build.** Only the lines the migration added are matched. A qualified type path counts (`PThread.Mutex.Kind.errorChecking`, `SystemPackage.FileDescriptor.Command.setStatusFlags`). An unqualified name counts only when it's distinctive: no declaration on the base commit, in the package, or in the Swift libraries (their symbol graphs) has it. A member is attributed only when every declaration it fits is of one type, an implicit member (`.errorChecking`) only when exactly one fits, and a call only to declarations whose parameters its labels supply, less defaulted ones.
    *Rejected:* building every package's tests, which would add tens of minutes and gigabytes (NIO's and SwiftPM's test targets) for the code an adoption PR cares least about; matching every name, which attributed `.union(...)` to `SignalSet` and `.unspecified` to `PThread.QoSClass`.
21. **A site's hunk is the one in the migration's diff, against the branch's merge base with the package's main, whose new lines hold the site.** A precise site on a line the migration didn't add is kept and marked: the migration changed a type elsewhere, or an overload the head commit adds now wins.
22. **Would-benefit sites join the coverage tools' extraction with the coverage tools' own derivation of the C names.** The C names are adopter-coverage's `derive.py`, run on the head export, so the join agrees with what the coverage reports call covered. Left out:
    - names the base commit's derivation already covers, since a package using them needs nothing new;
    - restricted subjects (`fcntl` for an `F_GETFL` accessor), since every fcntl call would match every command's accessor; the command constant still joins;
    - the Swift words and parameter names the derivation reads as C names (`nil` in "with `UTIME_OMIT` for a `nil` time", `value` in "the 8 bytes of `value`").

    A shim's interface stands for what it wraps (`CNIOLinux_pthread_setname_np` for `pthread_setname_np`), as in the coverage tools.
    *Rejected:* `build_graph.py`'s own C names, which take every backticked name in the sentence; joining the names the base commit covers, which made every `read` and `stat` call a reason for the Span and Stat carve-outs.
23. **The extraction is the coverage store's, of the commit that matches best: a migration's merge base, else the ecosystem's clone, else a clone in `../adopters` without a migration.** The newest extraction of the commit is used. A package the store has none for is scanned lexically: functions called, constants and types spelled as C spells them, in its library Swift sources. So a new clone counts at once, and the coverage tools' own run of it replaces the scan. For a package with a migration, each site says whether its line is unchanged on the branch.
    *Rejected:* running the coverage tools from here, which needs a package file under `Utilities/adopter-coverage` (another lane's); a lexical scan of every package, which the coverage tools already do better.
24. **A package is a git clone, identified by its origin URL.** Clones of one repository in both directories (swift-nio in `../adopters` and `../ecosystem`) are one package. swift-system itself is skipped, and so is a clone with no `Package.swift` at its HEAD. A clone with the branch but no commits past its merge base hasn't been migrated yet.
25. **Reach is a view beside the ranking, not part of its score.** The pitch order stays by effort and open questions. Reach, the number of packages that use a carve-out or would benefit from it, is a column beside it, a ranking of its own, and `reach.py`'s filters.
    *Rejected:* adding reach to the score, which would move big clusters (more declarations, so more uses) ahead of the small, question-free carve-outs the order is for.

### Where it's wrong

- **Promotion depends on file layout.** A type used across features within one directory isn't promoted, which is why Terminal is one cluster with seven parts rather than seven clusters. A type used by a single root file isn't either, so FileLock and the fcntl layer share a cluster. `config.json`'s `promote` and `demote` lists override it.
- **The part rules are heuristics.** `FileDescriptor.isTerminal` and `asTerminal` are a two-declaration part apart from TerminalDescriptor. SocketAddress's integration blocks join IPv4Address and the other address types because they share their files, not because of anything in the graph.
- **The contingency rules approximate the questions.** They match lexically. The Win32 overlaps are name patterns. A closure that throws through a generic `Body` type isn't recognized as one.
- **Declarations only the scan sees aren't checked by any compiler here.** Their edges come from type names in their text, and their tests from name matches. Their internal code isn't in the index, so their bundles list no implementation.
- **The implementation lists only new code.** An edit to existing internal code, such as a new case in an existing switch, isn't cited.
- **Commit attribution is by the last change to each line.** A later sweep, such as the `@available` pass, can outrank the commit that introduced the code; the bundle lists every commit with its line count.
- **Prior-text matches are by name.** They can match prose that only mentions a function in passing, so multiplexers like `fcntl` and `ioctl` are ignored.
- **Names and ids come from heuristics.** An id changes when a cluster's name does, so the comparison with the previous run matches clusters by shared declarations as well as by id.
- **The weights are judgment calls.** Their only guarantees are that any open question outweighs size, and that nothing comes before a prerequisite.
- **Adopted sites are precise only where the Darwin build compiles.** Tests and other platforms' branches are matched lexically, and the rules that keep that precise lose recall: a member with a common name (`try mutex.lock()`), or one several new types share, isn't attributed there.
- **The `#if` reading that sends lines to the lexical matcher is lexical too.** A condition it can't decide (a package's own flag) leaves the line to the index, so an uncompiled line in such a branch is missed.
- **The migration branches move while other lanes work.** Each run records the commit it read; a branch that moves between runs is rebuilt.
- **Would-benefit sites are at the extraction's commit.** When that's the ecosystem's clone rather than the migration's merge base, line numbers differ from the branch's; the diff says whether a line survives on the branch, not whether Darwin still compiles it (a migration that adds a Darwin branch leaves the old line to the other platforms).
- **A C name reaches every declaration that names it.** `pthread_mutex_lock` counts for `PThread.Mutex.lock()` and `withLock(_:)` alike, so a carve-out holding either gets the site.
- **The lexical interface scan is coarse**: library Swift sources only (no C), and no scope analysis beyond the package's own declarations.

### Outputs

| Path | What |
|---|---|
| `API-GRAPH.md` | This report. |
| `api-graph.json` | Clusters, parts, batches, promoted types, contingencies, the ranked carve-outs, and the run's metadata. |
| `graph.json` | Every node (with its tests, samples, implementation and C calls), edge, atom, test and sample. |
| `clusters.dot`, `atoms.dot` | The cluster map and the atom graph, for Graphviz (`dot -Tsvg`). |
| `bundles/<id>/` | One per carve-out: `bundle.md`, `bundle.json`, `sources.md`, `tests.md`, `samples.md`. `bundles/index.json` lists them in rank order. |
| `adopters.json` | The packages, their builds, every adopted and would-benefit site, the hunks, and each node's C names. |
| `bundles/<id>/adopters.md` | Every adopted and would-benefit site of the carve-out, and every hunk in full. |
| `api-delta/` | The api-delta report and JSON this run used. |
| `logs/` | Build and tool logs, and `meta.json`. |
