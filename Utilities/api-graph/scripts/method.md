### Pipeline

`Utilities/api-graph/regenerate.sh` runs every step in a scratch directory (`API_GRAPH_WORK`, default `.build/api-graph-work`), and replaces the output directory (`API_GRAPH_OUT`, default `.build/api-graph`) only once every step has succeeded. It never touches tracked files.

1. **API delta.** `Utilities/api-delta/regenerate.sh` runs for the same two commits, into the scratch directory. Its symbol graphs, source scan and delta are this tool's input.
2. **Exports.** `git archive` exports both commits. The head export is built; both are scanned.
3. **Indexed build.** `swift build --build-tests -Xswiftc -index-store-path` builds the head export, tests and Samples included. `--skip-update` resolves swift-argument-parser from SwiftPM's local cache, so nothing is fetched. This runs at the same time as step 1.
4. **Scans.** api-delta's `scan_sources.py` scans both exports, and `scripts/source_index.py` indexes the head export's declarations by extent and top-level block.
5. **References.** `scripts/index_refs.py` reads the index store with the toolchain's libIndexStore.
6. **Declarations.** `scripts/build_graph.py` lists the declarations, their structural and signature edges (with each signature use's role), conformances, blocks, tests, samples and the implementation each one reaches.
7. **C names.** `scripts/cnames.py` runs adopter-coverage's derivation on both exports: the C names each declaration wraps, and their C function families.
8. **Adopters.** `scripts/adopters.py` finds the package clones in `API_GRAPH_ADOPTERS` and `API_GRAPH_ECOSYSTEM`. It builds each migration branch's commit against an export of the head commit, with an index store, in a build directory it keeps for the next build to be incremental, or reuses the references it cached from an earlier build, once it has checked that the System declarations they name haven't changed; matches what the build didn't compile lexically; attaches the diff hunk that introduced each use; and joins the packages' C interfaces, from the coverage tools' results store, with the C names.
9. **Graph.** `scripts/snapshot.py` assembles the snapshot, with the domains (`domains.json`), files it in the store, and diffs it with the store's previous snapshot of the same head ref (`scripts/graphq.py`'s diff); `graphq.py summary` writes `GRAPH.md`.
10. **Pitches.** `scripts/pitches.py` resolves the pitch files against the snapshot and checks them together (`PITCHES.md`), and `scripts/bundles.py` writes a bundle per pitch.
11. **Suggestions.** `scripts/cluster.py` promotes shared types, forms clusters and parts, tags contingencies, and ranks the carve-outs; `scripts/bundles.py` writes a bundle per cluster, ranked part and batch; `scripts/report.py` writes `SUGGESTIONS.md`, `suggestions.json`, the draft pitch files and the DOT graphs, comparing with the previous run's suggestions. `scripts/units.py` is what cluster.py and pitches.py share (open-question tags, metrics, prior text), and `scripts/reach.py` aggregates adopters for any set of declarations.
12. **Index.** `scripts/index.py` writes `API-GRAPH.md`.

### Terms

- **Node**: in the graph, anything with an ID: a declaration (one the head commit adds, `head`; a type on the base commit, `base`; a C or standard-library type or protocol, `external`), a C name, a piece of internal code, a block, a test, a sample, a package. In the suggestions' clustering, a node means a head declaration.
- **Link**: a typed, directed relation between two nodes; the kinds are in `Prototype/ApiGraph/REPORT.md`, section 1. A derived kind (`sameCFamily`, `sameImplementation`, `sameBlock`, `sameMark`, `couldUse`) is computed from stored links at query time.
- **Snapshot**: the graph of one head commit, a JSON document.
- **C function family**: C functions a doc sentence names as spellings of one call, joined with POSIX's variants of the call among the wrapped functions.
- **Reach**: a declaration's packages: those using it on their migration branch, and those calling a C name it newly wraps.
- **Pitch**: a hand-curated file naming a set of head declarations by rules, with a pattern.
- **Domain**: a hand-kept group of C families by task.
- **Atom**: the top-level block holding a declaration, a type declaration or one `extension X { ... }`. A CInterop alias is an atom of its own.
- **Vocabulary**: in the suggestions, a type that declarations use but that isn't clustered: everything on the base commit, anything from another module, and new types promoted to vocabulary.
- **Cluster**: a connected set of atoms once vocabulary is taken out.
- **Part**: a piece of a cluster that could be pitched on its own, after the parts it needs.
- **Batch**: several small clusters that only add members to one existing type in one file.
- **Carve-out** (suggested): a cluster, part or batch, as a candidate pitch.
- **Contingency**: an open design question a carve-out depends on.
- **Adopted site**: a line of a package's migration branch (`migrate-darwin`) that uses a declaration, with the hunk of the migration's diff that introduced it.
- **Would-benefit site**: a line of a package that uses a C interface a declaration newly wraps.

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
19. **The references are cached by what the build depends on besides System, and revalidated when System moves.** The key is the package commit, the path dependencies' commits, the compiler, and the build settings. Each entry records the System commit and tree it was built against, System's manifest, and a fingerprint of every System declaration its references name. A run on the same System tree reuses it. On another tree it's revalidated (decision 37): reused if the manifest and each of those declarations are unchanged in the head commit's symbol graphs, rebuilt if not, and rebuilt whenever its build had failed, since the change may fix it. The log and `GRAPH.md` say which, and why. `API_GRAPH_ADOPTER_BUILDS=reuse` takes any cached index of the commit without checking, and no build starts with less than `API_GRAPH_MIN_FREE_GB` free.
    *Rejected:* keying on System's Sources and manifest trees, as this tool first did: any change under Sources, a comment included, rebuilt every migration, about 20 builds and 23 minutes; rebuilding on every run.
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

26. **The graph is its own stage, and keeps every link.** Base types (FileDescriptor, FilePath, Errno, CInterop) and external ones (the C types System extends, the protocols it conforms to) are nodes, so a link to them is a link, not a cut. Promotion and link cutting are the suggestions' rules, applied after the graph is saved.
    *Rejected:* clustering first and reporting the clusters' edges, which hides every link the promotion cuts (all of ProcessID's dependents).
27. **Relations that hold between many declarations at once are hubs, not pairs.** Two declarations are in one C family when they `wrap` C names of one family, reach the same internal code when they `reach` one piece, share a block when they're `inBlock` one block; those are derived at query time. A snapshot then holds each fact once, and a diff shows the fact that changed.
    *Rejected:* storing the pairwise links, which multiplies them (the fcntl commands' accessors are ten declarations and forty-five pairs) and fills diffs with pairs that follow from one change.
28. **Node IDs are USRs**, which change only when a declaration's signature or context does, and `scan:<module>:<path>` for a declaration no symbol graph has. Blocks are named by file, subject, MARK and ordinal, C names by name, packages by origin URL.
    *Rejected:* graph-local numbers, which change whenever anything is added, so no diff or pitch file could name a node.
29. **`extends` is a member added by an extension outside its host's own file**, or to a base or external type. This repository writes most members in `extension T` blocks beside `T`, which says nothing a pitch needs.
    *Rejected:* every member declared in an extension (3270 of 3434 memberships on system-next, nearly all of them `memberOf` again).
30. **A C function family comes from the doc sentences, joined by POSIX's naming.** Functions a sentence names with `or` are spellings of one call (`chmod`, or `lchmod` if …); `and` names another call it makes (`openat` and `fdopendir`), which doesn't join them. Among the wrapped functions, `x`, `xat`, `fx`, `lx` and `fxat` are one call's variants (mkdir and mkdirat; stat, fstat, lstat, fstatat; futimens and utimensat), except the C library's streams (`fread` isn't `read`'s).
    *Rejected:* every name one sentence mentions, which joined open with fdopendir and readdir; the sentences alone, which split mkdir from mkdirat.
31. **Snapshots go to a store beside the repository, one per head commit, and each run diffs with the store's previous snapshot of the same head ref.** A pitch chat's checks need the last snapshot, whatever worktree ran it.
    *Rejected:* the output directory, which each run replaces; `.build`, which goes with the worktree.
32. **Pitch files are hand-curated data the tool reads and never writes.** Rules name what a chat means (types without their members, the members of a type, a C family) rather than lists of IDs, so a pitch follows the code as it grows, and the check says what its rules match now and didn't before. Fix-it stubs go with the declaration they rename, and base types can only lead to their new members.
    *Rejected:* computed pitches (the clustering), which can't express a judgment such as "these types without their members"; ID lists alone, which go stale silently.
33. **A pitch needs another when its declarations name a type the other owns**, through a signature, a membership, a nesting, an extension or a conformance; implementation-only uses are reported apart.
    *Rejected:* counting any link, which would make every pitch that tests with a pseudoterminal need the terminal pitch.
34. **A pitch bundle quotes what the pitch holds.** A type pitched without its members shows its declaration's head, not its body; a member shows its extension's head too. Each adopter hunk says what else it uses, and which pitch owns it.
    *Rejected:* whole blocks, as the suggestions' bundles quote them, which show another pitch's members.
35. **The clustering stays, as suggestions**: a report that ranks carve-outs, says how much of each the pitch files cover, and drafts a pitch file for the leading uncovered ones, into the output.
    *Rejected:* dropping it, which loses the candidates it finds; letting it write `Prototype/Pitches`, which would override the chats' judgment.
36. **Domains are a hand-kept file of C families by task**, after the chapters of *Advanced Programming in the UNIX Environment*, matched by glob; a type is in its members' domains. They suggest related API the links don't connect, and nothing else depends on them.
    *Rejected:* domains inferred from files or directories, which follow this repository's layout rather than the task (`FileOperations.swift` holds twenty families).
37. **Revalidation checks the System declarations a cached index names, not what the migration's names might newly resolve to.** The declarations are the head commit's symbol graphs from api-delta, the whole public API (the graph holds only the delta). A declaration's fingerprint covers what decides how a use of it compiles: its declaration fragments (signature, default arguments, attributes), availability, SPI, access, generic signature, extension constraints and, for a type, its conformances; not doc comments or locations. A property's accessors stand for the property. An adopter's own members in extensions of System types, and its declarations whose signatures only mention a System type, aren't System's and aren't checked. A migration whose build compiles another migration (swift-build's of swift-driver) is revalidated only if that one is too. What this can't see:
    - a use in the migration that newly resolves to a System declaration: a new overload that wins over the one the index recorded, a new member that collides with the adopter's own extension member of that name, a new type or function that shadows another module's name or makes it ambiguous (a `Mutex` beside Synchronization's);
    - a new conformance of a System type that changes which generic overload a call picks, and implicit declarations the symbol graphs don't list;
    - System declarations under `#if compiler(...)` that a package built with a newer toolchain sees (swift-foundation's), since the symbol graphs come from Xcode's;
    - a dependency fetched by URL, not a migrated clone, that itself uses System.

    `API_GRAPH_ADOPTER_VALIDATE=interface` rebuilds whenever any public declaration changes or is added, and `tree` whenever System's sources change.
    *Rejected:*
    - the whole public interface as the default: it sees new overloads, but lanes add API with nearly every merge, so every migration would rebuild almost every time;
    - also comparing each named declaration's overload set, its siblings of the same base name in the same type: it sees the first case above but not the others, and is a possible next step;
    - matching the migration's identifiers against the names System adds: broad (`init`, `read`), and blind to uses that inference resolves;
    - trusting a cached index across System changes unchecked, which `API_GRAPH_ADOPTER_BUILDS=reuse` does on request.

38. **Each migration's build directory is kept, and what it builds is updated in place, so a rebuild is incremental.** They're in `API_GRAPH_BUILDS`, one per package: the export of the migration's commit (named as the clone is), exports of the clones its path dependencies name, SwiftPM's scratch directory, the last build's log, and `state.json`, what it was built from. System's export at the head commit, `system/swift-system`, is shared: every build's manifest points at it. A package is re-exported only when its commit or a path dependency's moved, and System when the head commit did. The commit is exported beside the old export and its manifests rewritten there, and only the files that differ are moved in, dated now: the others keep their modification times, which are what SwiftPM goes by, so it recompiles only what the changed files reach. What the commit doesn't have is removed, except a `Package.resolved` SwiftPM wrote. A build directory is started over when the compiler, the build settings or the package's manifest changed, because the index store would keep the units of targets no longer built; the units of files since deleted are skipped when the store is read. A tools version is lowered only when it's newer than the toolchain's, and the export remembers that it was. One run at a time uses a builds directory (a lock). The log and `GRAPH.md` give each build's start (cold or incremental) and the directories' sizes. `API_GRAPH_BUILDS=` (empty) builds each migration in the scratch directory and deletes it once read, as before.
    *Rejected:*
    - the build directories under the cache directory: the cache is a few MB, and deleting it is how a reindex is forced, while a build directory is several GB;
    - a fresh export into a kept build directory: `git archive` dates every file at its commit, so every file would look changed to SwiftPM and every build would be cold;
    - `git worktree` checkouts of the clones, which `git checkout` would update with only the changed files: they'd write into the clones' repositories, which other lanes own, and couldn't hold the rewritten manifests without showing as changes;
    - one export of each dependency clone for all the packages that build it (swift-driver's, for swift-build and SwiftPM): the exports are small, and sharing them would let one package's re-export change another's build while it runs.

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
- **A build that fails partway can keep old index units.** A file whose recompile failed keeps the unit of its last successful build, so a `partial` index can have sites from an older version of that file.
- **A revalidated index can miss what a rebuild would find**: a use that now resolves to a declaration System added since the build (decision 37). `API_GRAPH_ADOPTER_VALIDATE=interface` or `tree` trades that for rebuilds.
- **Would-benefit sites are at the extraction's commit.** When that's the ecosystem's clone rather than the migration's merge base, line numbers differ from the branch's; the diff says whether a line survives on the branch, not whether Darwin still compiles it (a migration that adds a Darwin branch leaves the old line to the other platforms).
- **A C name reaches every declaration that names it.** `pthread_mutex_lock` counts for `PThread.Mutex.lock()` and `withLock(_:)` alike, so a carve-out holding either gets the site.
- **The lexical interface scan is coarse**: library Swift sources only (no C), and no scope analysis beyond the package's own declarations.
- **C function families are what the doc sentences and POSIX's naming say.** A family a sentence calls two calls stays two (`posix_spawn` and the credential calls it makes); a derivation artifact can be a one-name family (`progress`).
- **A pitch's prerequisites come from its declarations' links**, so a need only a doc comment or a sample shows isn't one.
- **The related API a domain suggests is broad**: a domain is a whole chapter (files and directories is 297 declarations), so a pitch's list shows the largest families first and stops at 40.
- **The snapshot diff compares facts, not lines**: a declaration that moved within its file isn't changed; a changed doc comment isn't either, unless its summary did.

### Outputs

| Path | What |
|---|---|
| `API-GRAPH.md` | The index of the reports. |
| `GRAPH.md`, `graph.json.gz` | The graph: its summary, and the snapshot. |
| `DIFF.md`, `diff.json` | The snapshot against the store's previous one. |
| `PITCHES.md`, `pitches.json`, `pitches/<id>/` | The pitch files' checks, and a bundle per pitch. |
| `SUGGESTIONS.md` | This report. |
| `suggestions.json`, `suggestions/<id>/`, `suggestions/drafts/` | The suggestions' data, bundles, and draft pitch files. |
| `clusters.dot`, `atoms.dot` | The cluster map and the atom graph, for Graphviz (`dot -Tsvg`). |
| `adopters.json` | The packages, their builds, every adopted and would-benefit site, the hunks, and each node's C names. |
| `pitches/<id>/adopters.md`, `suggestions/<id>/adopters.md` | Every adopted and would-benefit site of a pitch or suggestion, and every hunk in full. |
| `api-delta/` | The api-delta report and JSON this run used. |
| `logs/` | Build and tool logs, and `meta.json`. |
