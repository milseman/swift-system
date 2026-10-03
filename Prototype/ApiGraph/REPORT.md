# api-graph: the API graph, pitch files, and adopters

The `api-graph` lane (worktree `../api-graph`, branch `api-graph`) owns
`Utilities/api-graph`. Since 2026-09-29 its product is a **graph** of the API
system-next adds over main: every new declaration, the base types they build
on, typed links between them, and each declaration's adopter reach, saved as a
snapshot per commit with diffs and a query command. **Pitches** are
hand-curated files that name sets of nodes; the tool checks them together and
bundles each one. The automatic clustering the tool started with stays, as
suggestions only.

This file opens with the two formats (the graph's schema and the pitch
file's), then the status, then the milestones.

## 1. Graph schema

A snapshot is one JSON document (`graph.json.gz`): `schema`
(`api-graph-snapshot/2` since the cnames lane: a `wraps` link has `sources`
and `cKind`, where schema 1 had one `source`), `meta`, `nodes` (by ID),
`links` (a list), and `hunks` (the adopters' diff hunks, by ID, which links
cite). IDs are stable across commits: a declaration's is its USR, which only a
change to its signature or context changes.

### Node kinds

| Kind | ID | What |
|---|---|---|
| `declaration` | USR, or `scan:<module>:<path>` for one only the source scan sees | A Swift declaration. `origin` is `head` (system-next adds it), `base` (a type on main: FileDescriptor, FilePath, Errno, CInterop, UserID, …; kept so links to them aren't cut), or `external` (a C or standard-library type System extends, or a protocol it conforms to). Each head declaration carries its reach (below), `hasDoc` and `ownDoc` (a doc comment, inherited or its own), and `reachesC`: whether its code reaches any C at all, a CSystem shim included (a type: if a member's does); `null` when it doesn't compile on Darwin, whose index this is. |
| `cname` | `cname:<name>` | A C interface a doc comment names or a declaration's code reaches: function, constant, type, macro, field or variable, with the C function family it's in, and whether the base commit already covers it. A field is named for its struct where one can be found, `struct.field` (`cname:stat.st_size`). `cKinds` are what the doc sentences call it, or for a name only code reaches, what its USR says. |
| `internal` | `internal:<USR>`, `internal:c:<name>` | New internal code a declaration's body reaches: `_foo`, `system_foo`, a `_FOO` constant, a CSystem shim. |
| `block` | `block:<file>:<subject>[:<MARK>]#<n>` | A top-level block, a type declaration or one `extension X { … }`, with its `// MARK:` title; `n` counts blocks with the same subject and MARK in the file. |
| `test` | `test:<file>::<scope>.<name>` | A test function, XCTest or swift-testing. |
| `sample` | `sample:<file>` | A sample command's source file. |
| `package` | `package:<key>` | An adopter: a clone in `../adopters` or `../ecosystem` (by origin URL), with its migration branch and where its C interface data comes from. |

Examples:

- `declaration` (head): `s:13SystemPackage7PThreadV5MutexV`, `PThread.Mutex`,
  a struct in `Sources/System/Threads/PThreadMutex.swift:53`.
- `declaration` (head, scan-only): `scan:SystemPackage:SystemConfig.PathName._PC_NAME_MAX`,
  a fix-it stub.
- `declaration` (base): `s:13SystemPackage14FileDescriptorV`, `FileDescriptor`.
- `declaration` (external): `c:@S@timespec`, `timespec`, which System extends
  with `seconds` and `nanoseconds`.
- `cname`: `cname:pthread_mutex_lock`, a function in the family
  `pthread_mutex_lock`, not covered on the base commit.
- `internal`: the internal `system_fchown(_:_:_:)` that
  `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` reaches.
- `block`: the `extension FileDescriptor` in `Sources/System/FileOperations.swift`
  that holds `setOwner`.
- `test`: `test:Tests/SystemTests/FileTimesTest.swift::FileTimesTest.testSetTimes()`.
- `sample`: `sample:Sources/Samples/Touch.swift` (`system-samples touch`).
- `package`: `package:swift-nio`: `migrate-darwin` @ `e1623fbfbe`, interface
  data from the coverage store's extraction of its merge base `feaf4ac57e`.

### Link kinds

Stored links, each kind separate:

| Kind | From → to | What | Example |
|---|---|---|---|
| `memberOf` | declaration → type | A member to its host type. The strongest link: a type's members tend to appear in the same snippets, though they needn't be pitched with it. | `PThread.Mutex.lock()` → `PThread.Mutex` |
| `nestedIn` | type → type | A nested type to the type it's declared in. | `PThread.Mutex.Attributes` → `PThread.Mutex` |
| `extends` | declaration → type | A member an extension adds outside its host's own file: to a base or external type, or to a new type declared elsewhere. (An `extension T` beside `T` is how this repository writes most members, and isn't one.) | `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` → `FileDescriptor`; `timespec.seconds` → `timespec` |
| `conformsTo` | type → protocol | A conformance, to a new, base or external protocol (not the ones every type gets: Copyable, Escapable, BitwiseCopyable, SendableMetatype). | `FileDescriptor.StatusFlags` → `OptionSet` |
| `usesInSignature` | declaration → type | A type its signature names, with its roles: `parameter`, `return`, `throws`, `type` (a property's or case payload's), `aliased` (a typealias's target), `generic` (a constraint). | `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` → `UserID` (parameter), → `Errno` (throws); `FileDescriptor.statusFlags()` → `FileDescriptor.StatusFlags` (return) |
| `wraps` | declaration → cname | A C interface the declaration wraps, with its `sources`: `doc`, its doc comment names it ("The corresponding C function is `x`."), as adopter-coverage's `derive.py` reads it, field and property sentences included; `typealias`, a CInterop typealias stands for it; `code`, its code reaches it, through the internal code it calls (not public API, a type's members, mock hooks or CSystem shims; `scripts/method.md`, decisions 40-41). A doc or typealias link has the sentence's role, `subject`, `alternative` or `argument`, and whether the sentence restricts it to one use; a code-only link is `subject` when the declaration's code reaches that one C name, else `argument`. A doc link and a code link to the same C name are one link with both sources. `cKind` is the link's C kind. Only the stated links (a `doc` or `typealias` source) feed reach, families, domains and pitch rules (`graphq.stated`). | `PThread.Mutex.lock()` → `pthread_mutex_lock` (subject, doc and code); `FileDescriptor.statusFlags()` → `fcntl` (subject, restricted), → `F_GETFL` (argument); `ProcessID.ResourceUsageInfo.pageIns` → `rusage_info_v6.ri_pageins` (subject, field, doc and code); `Signal.SIGTTIN`, a fix-it stub → `SIGTTIN` (subject, code) |
| `reaches` | declaration → internal | New internal code its body reaches, through the index. | `FileDescriptor.setOwner(…)` → `system_fchown(_:_:_:)` |
| `inBlock` | declaration → block | Its top-level block. | `FileDescriptor.setOwner(…)` → the `extension FileDescriptor` block in FileOperations.swift |
| `testedBy` | declaration → test | A test that references it (by USR, from the index; by name for code not compiled here). | `FilePath.setTimes(access:modification:followTargetSymlink:retryOnInterrupt:)` → `FileTimesTest.testSetTimes()` |
| `sampledBy` | declaration → sample | A sample that references it. | the same → `Sources/Samples/Touch.swift` |
| `stubFor` | declaration → declaration | A fix-it stub (`@available(*, unavailable, renamed:)`) to the declaration it renames. | `SystemConfig.PathName._PC_NAME_MAX` → `SystemConfig.PathName.maxFileNameBytes` |
| `usedBy` | declaration → package | Adopter use: the sites on the package's migration branch, each `file:line:column`, `precise` (the compiler's index) or `lexical`, with the hunk of the migration's diff that introduced it. | `PThread.Mutex.lock()` → `swift-log`: `Sources/Logging/Locks.swift:133`, precise, hunk `@@ -114,6 +128,12 @@` |
| `calls` | package → cname | The package calls the C interface: its sites, `file:line`, precise or lexical, at the commit its interface data is from. | `swift-log` → `pthread_mutex_lock`: `Sources/Logging/Locks.swift:99` (1.5.4) |

Derived kinds, which queries and checks compute from the stored ones, so a
snapshot and its diffs hold each fact once:

| Kind | From | Example |
|---|---|---|
| `sameCFamily` | two declarations whose stated links `wrap` C functions of one family: functions a sentence names as spellings of one call (`chmod`, or `lchmod` if …), joined with POSIX's variants of the call (`x`, `xat`, `fx`, `lx`, `fxat`) | `FilePath.setTimes(…)` and `FileDescriptor.setTimes(…)` (the utimensat family: futimens, utimensat) |
| `sameImplementation` | two declarations that `reach` one internal piece, unless more than 20 do (a shared helper, like the mock hooks) | the fcntl command accessors, through `system_fcntl` |
| `sameBlock`, `sameMark` | two declarations in one block, or in blocks under one MARK title in one file | the members of one `extension FilePath` family |
| `couldUse` (reach) | a declaration, and a package that `calls` a cname a stated link says it wraps (as subject, alternative or argument, not restricted, not a field), unless the base commit covers the cname (`graphq.could_use`) | `ProcessID.current` → every package that calls `getpid` |

Each head declaration's **reach** is `{usedBy: [packages], couldUse:
[packages]}`, with the sites a query lists, and its **domains** (from
`Utilities/api-graph/domains.json`, section 2's companion: C families by
task, after *Advanced Programming in the UNIX Environment*; a type is in its
members' domains).

### Snapshots, diffs and queries

- A run writes the snapshot to its output (`graph.json.gz`) and to the store,
  `<API_GRAPH_SNAPSHOTS>/<head commit>.json.gz` (default
  `../api-graph-snapshots` beside the repository, so it outlives worktrees),
  and diffs it with the previous snapshot of the same head ref: nodes and
  links added, removed and changed.
- `scripts/graphq.py` queries a snapshot: a node's neighborhood by link kind,
  a type with or without its members, everything reaching a C family, a C
  name's callers, a package's reach, and the diff of two snapshots. `show`
  and `cname` print each `wraps` link's sources (`from doc+code`), and
  `type --members` marks a code-only C name `(code)`.
- The first snapshot of schema 2 diffed with one of schema 1 shows every
  `wraps` link changed (it gained `sources` and `cKind`) and the code and
  field links added: a one-time jump, not a change to System.

## 2. Pitch file format

A pitch is a hand-curated JSON file, `Prototype/Pitches/<id>.json`, that a
pitch-writing chat edits. The tool never writes these files; it resolves them
against a snapshot, checks them together, and bundles each.

```json
{
  "id": "descriptor-types",
  "title": "Descriptor types: sockets, terminals and kernel queues",
  "pattern": "types-without-members",
  "status": "draft",
  "include": [
    {"types": ["SocketDescriptor", "TerminalDescriptor"], "members": false}
  ],
  "exclude": [],
  "notes": "The types and their conversions from FileDescriptor; their operations are pitched with each type's members."
}
```

| Field | | |
|---|---|---|
| `id` | required | The file's name without `.json`. |
| `title` | required | |
| `pattern` | required | The pitch's shape (below). |
| `status` | | `draft` (default), `ready`, `pitched`, `accepted`. |
| `include` | required | Rules; the pitch's declarations are every rule's matches, less `exclude`'s. |
| `exclude` | | Rules. |
| `requires` | | Pitch IDs this one knowingly builds on; the check reports prerequisites not listed. |
| `notes` | | Free text for the pitch chat. |

Rules, each an object; any rule can narrow itself with `file` (a path prefix)
or `mark` (a MARK title):

| Rule | Matches |
|---|---|
| `{"ids": [...]}` | Declarations by ID. |
| `{"paths": [...]}` | Declarations by path, as queries print them (`FileDescriptor.setOwner(user:group:retryOnInterrupt:)`). |
| `{"types": [...], "members": false}` | The types; with `"members": true`, their members too, and with `"nested": true`, their nested types with their members. |
| `{"membersOf": "TYPE"}` | The type's members, not the type (`"nested": true` adds its nested types). The type can be a base type: `{"membersOf": "FileDescriptor", "file": "Sources/System/FileOperations.swift", "mark": "Owner"}`. |
| `{"cFamily": "futimens"}` | Declarations that wrap a function of that C family, as subject or alternative. |
| `{"cNames": ["F_SETOWN"]}` | Declarations that wrap these C names, in any role. |
| `{"match": "REGEX"}` | Declarations whose path matches. |

Fix-it stubs go with the declaration they rename unless a rule excludes them.
Base and external declarations are never a pitch's: a rule can name them only
to reach their new members.

Patterns:

| `pattern` | Shape | Example file |
|---|---|---|
| `types-without-members` | A family of types, without their members: names, conformances, conversions. | `descriptor-types.json`: SocketDescriptor, TerminalDescriptor |
| `members-of-pitched-type` | The members of a type another pitch owns. | `terminal-attributes-members.json`: TerminalAttributes' members, after `terminal-types.json` |
| `self-contained-type` | A type with its members and nested types. | `kernel-queue.json`: KernelQueue |
| `function-family` | The wrappers of one C function family, on existing types. | `file-times.json`: futimens and utimensat |
| `vocabulary-type` | A type many pitches name, with only the members they all need. | `process-id.json`: ProcessID, `current`, `parent`, its raw value |
| `constants` | New constants, options or cases on an existing type. | `open-options-sync.json`: O_SYNC and O_DSYNC |

The check, over every pitch file at once:

- declarations no pitch covers yet, and declarations two pitches cover;
- prerequisites: a pitch whose signatures (or memberships, nestings,
  extensions, conformances) name a type another pitch owns needs that pitch,
  and one that names a new type no pitch owns needs one; cycles are flagged;
- rule problems: a rule that matches nothing, an ID or path not in the graph,
  a pattern its rules don't fit (a `members-of-pitched-type` pitch whose type
  no other pitch owns);
- what changed since the last snapshot: declarations a pitch's rules match
  now and didn't, ones they no longer match, and changed declarations it
  includes.

## 3. Status and where to resume

Every step of the 2026-09-29 direction is built, in its order: graph,
adopter reach, pitch files and checks, bundles, suggestions, domains
(commits `3a31998`..`a51afc5`). Local system-next is `7b0875f`, merged.

| Step | Where |
|---|---|
| Graph | `scripts/build_graph.py` (signature roles, conformances, blocks), `scripts/cnames.py` (C names and families), `scripts/snapshot.py` (the snapshot, store and diff), `scripts/graphq.py` (queries); `GRAPH.md`, `graph.json.gz`, `DIFF.md` |
| Adopter reach | `scripts/adopters.py` (milestone 1), folded into the snapshot as `usedBy` and `calls` links and each declaration's reach |
| Pitch files and checks | `scripts/pitches.py`; `Prototype/Pitches/` (seven examples, one per pattern); `PITCHES.md` |
| Bundles | `scripts/pitches.py --units-out`, `scripts/bundles.py --units`, `scripts/units.py` (shared with the clustering); `pitches/<id>/` |
| Suggestions | `scripts/cluster.py`, `scripts/report.py` (pitch coverage, draft pitch files); `SUGGESTIONS.md`, `suggestions/` |
| Domains | `Utilities/api-graph/domains.json`; `graphq.py domain`; the pitch bundles' Related API |

On system-next `7b0875f` the snapshot has 9835 nodes (3741 new
declarations, 21 base and 130 external types, 1872 C names in 500
families, 2308 pieces of internal code, 621 blocks, 982 tests, 102
samples, 58 packages) and 38065 links. 689 new declarations are used on a
migration branch, and 914 wrap a C interface some package calls. The seven
example pitches cover 170 of the 3507 declarations (fix-it stubs follow
what they rename). The adopters grew during the session, and each new
clone was picked up with no change: the ecosystem gained 21 packages, and
swift-build and swift-llbuild gained migrations (16 migrated now).

To resume: run `Utilities/api-graph/regenerate.sh` (4 minutes with the
adopter cache warm), open `.build/api-graph/API-GRAPH.md`, and use
`scripts/graphq.py`. A pitch chat edits `Prototype/Pitches/<id>.json`,
reruns, and reads `PITCHES.md` and `pitches/<id>/bundle.md`. Open items are
in section 4's known misses.

## 4. Milestone 2: the graph, pitch files, suggestions, domains (done)

### What

- **The graph** (section 1), built before any clustering and keeping every
  link: base and external types are nodes, and promotion and link cutting
  apply only to the suggestions. A snapshot per head commit goes to the store
  beside the repository (`../api-graph-snapshots`), with an index, and each
  run diffs it with the store's previous snapshot of the same head ref.
  `graphq.py` answers: a node and its links (`show`), a neighborhood by link
  kind and depth (`neighbors`), a type with or without its members and their
  reach and sites (`type`), a C family or a C name with its wrappers and
  callers (`family`, `cname`; `cname getpid` lists every package calling
  getpid, which `ProcessID.current` wraps), a package's reach (`package`), a
  domain (`domain`), and `diff`.
- **Pitch files** (section 2): seven examples, one per pattern, checked
  together into `PITCHES.md`: coverage, overlaps, prerequisites (found:
  terminal-attributes-members needs terminal-types, listed in `requires`),
  new types no pitch owns (`CInterop.KEvent`, `CInterop.TimeSpec`,
  `FilePath.ResolutionFlags`, `BaudRate`, …), pattern fit, and changes since
  the previous snapshot.
- **Pitch bundles**: the suggestions' bundle format (source, tests, samples,
  commit messages, open-question tags, prior text), plus the pitch file's
  rules and what each matched, adopter examples whose hunks say what else they
  use and which pitch owns it ("also uses `TerminalDescriptor` (pitch
  descriptor-types); `openPseudoterminal` (no pitch yet)"), and related API by
  domain. A type pitched without its members shows only its declaration's
  head.
- **Suggestions**: the clustering's report, now `SUGGESTIONS.md`, with a
  Pitched column (how much of each suggestion pitch files cover) and draft
  pitch files for every suggestion none covers (246 of 260), the first 15
  listed as candidate pitches.
- **Domains**: 21, from the APUE chapters plus time, memory, randomness,
  dynamic loading, C strings, C math and Darwin's own; every C family but one
  derivation artifact (`progress`) falls in one.

### Design calls

`scripts/method.md`, decisions 26-36, has each with the alternative it
rejected: the graph as its own stage keeping every link (26); many-to-many
relations as hubs derived at query time (27); USRs as IDs (28); `extends` as
extension outside the host's file (29); C families from the sentences' `or`
and POSIX's naming, not every co-mention (30); a store that outlives
worktrees (31); pitch files as data the tool never writes, with rules rather
than ID lists (32); prerequisites through signature-level links only (33);
pitch bundles quoting only what the pitch holds (34); suggestions that
propose and draft but never override (35); hand-kept domains by task, not by
file (36).

### Verification

- `units.py` took the open-question tags, evidence, prior text and metrics
  out of cluster.py; cluster.py's output was compared byte for byte with the
  old one's under a fixed hash seed: identical. (The old output varied from
  run to run in the order of tied prior-text names; now sorted.)
- The pitch change report was checked against a doctored previous snapshot
  (one declaration removed, one signature changed): it reported "now also
  matches `timespec.fileTimeNow`" and "`FileDescriptor.setTimes(…)`
  changed (decl)".
- The snapshot diff reported the 2406 `extends` links the narrower
  definition removed, and nothing else, between two snapshots of one commit.
- Queries were run by hand on PThread.Mutex, ProcessID, KernelQueue, the chmod
  family, getpid and swift-log, and their answers checked against the sources.

### Runtime

`regenerate.sh` in 3 minutes 57 seconds with the adopter cache warm (M1 Max,
Swift 6.2, other lanes building): the adopters step 98 seconds (58 packages),
cnames 4, the snapshot 5, the pitches and their bundles about 10, the
suggestions about 30. A snapshot is 1 MB compressed.

### Known misses

- C function families follow the doc sentences and POSIX's naming: a family a
  sentence calls two calls stays two, and a derivation artifact can be a
  one-name family (`progress`).
- `extends` misses a member added by an extension in the host's own file after
  the fact; the repository's style makes that the common case, so it isn't
  flagged.
- A pitch's prerequisites come from links; a need only a doc comment or a
  sample shows isn't one. Implementation-only needs are listed apart.
- The related API a domain suggests is broad (a domain is a chapter), so a
  pitch bundle shows the largest families first and stops at 40.
- The snapshot diff compares facts, not lines: a declaration that moved in its
  file isn't changed, and a doc comment's change counts only through its
  summary.
- Pitch files are read from the working tree (chats edit them between
  commits), unlike everything else.
- The store keeps one snapshot per head commit; a rerun of the same commit
  replaces it, so a tool change is diffed against the previous commit's
  snapshot, not the same commit's earlier one.

## 5. Milestone 1: adopters for every carve-out (done)

The brief before the new direction: say, for each automatic carve-out
(cluster, part, batch), which adopters use its declarations and where, and
which would benefit. That work is the adopter reach the graph now carries.

### What

- **Adopted**: the 14 packages migrated on `migrate-darwin` in `../adopters`
  (indexstore-db, swift-argument-parser, swift-async-algorithms,
  swift-certificates, swift-driver, swift-foundation, swift-log, swift-nio,
  swift-package-manager, swift-subprocess, swift-syntax,
  swift-tools-protocols, swift-tools-support-core, WasmKit; swift-build has
  the branch with no commits yet). Each branch's commit is exported, pointed
  at an export of the head commit, and built with an index store as the
  coverage tools' package file says; the store's references to a
  declaration's USR are its precise sites. Tests, `#if` branches Darwin
  doesn't take and failed builds are matched lexically. Each site carries the
  hunk of the migration's diff that introduced it.
- **Would benefit**: 37 packages' C interfaces (the coverage store's
  extraction, or a lexical scan when it has none) joined with the C names the
  coverage tools' derivation reads from the doc comments, less what the base
  commit covers.
- Output: per bundle, an Adopters section (`bundle.md`, `bundle.json`,
  `adopters.md`); in the report (then `API-GRAPH.md`, now `SUGGESTIONS.md`),
  Adopters columns and an Adopter reach section; `scripts/reach.py` ranks and filters by reach. A clone in
  `../ecosystem` or `../adopters` is picked up by the next run.

### Design calls

`Utilities/api-graph/scripts/method.md`, decisions 18-25, has each with the
alternative it rejected. In short:

1. Precise sites from an indexed build of each migration against the head
   commit (USRs tell overloads apart and see uses the text doesn't spell).
   *Rejected:* diff name matching alone; the adopters' own `.build` stores
   (working trees); the coverage store's dumps (main commits only).
2. Build settings from the coverage tools' package files, read-only;
   swift-foundation builds with the swift.org snapshot (Swift 6.5-dev), whose
   store Xcode 6.2's libIndexStore reads. *Rejected:* a settings file of our
   own.
3. Path dependencies point at commits (swift-system at the head export,
   swift-driver's swift-tools-support-core at its branch), and the export's
   directory is named as the clone is (a root package's identity is its
   directory's name). *Rejected:* `pathdeps.py rewrite` as is, which points
   other clones at their working trees.
4. Cache the references, not the builds. *Rejected:* keeping builds (6 GB for
   SwiftPM); rebuilding every run.
5. Narrow lexical matching: added lines only, qualified paths, distinctive
   names, one host type per member, parameters the call's labels supply.
   *Rejected:* building tests; broad matching.
6. Would benefit joins the coverage derivation, less base-covered names,
   restricted subjects and derivation artifacts; C code's uses of C types
   don't count. *Rejected:* build_graph's backtick scan; joining everything.
7. Interfaces from the best-matching commit: a migration's merge base, else
   the ecosystem clone; a lexical scan when the store has neither.
   *Rejected:* running the coverage tools from here.
8. Reach is a view, not a score term. *Rejected:* weighting the ranking.

### Runtime

M1 Max, Swift 6.2, other lanes building:

- Every adopter index cached: the full `regenerate.sh` in 3 minutes 46
  seconds; the adopters step 40-50 seconds (it was 129 seconds before one `git
  cat-file --batch` per commit replaced a `git show` per file).
- Nothing cached (system-next moved to `7b0875f`, which changes System's
  Sources tree and so every key): 25 minutes 34 seconds; the builds take 20
  seconds to 5 minutes each, swift-foundation's (with the snapshot compiler)
  and SwiftPM's the longest.

### Spot-check

Twelve sites across swift-nio, swift-foundation and swift-subprocess, drawn at
random (seed 20260929) from the run on system-next `7b0875f`, checked by hand
against the commits and System's sources:

| # | Site | Attributed to | Verdict |
|---:|---|---|---|
| 1 | swift-nio `Sources/NIOPosix/GetaddrinfoResolver.swift:250`, `result.address.withUnsafeBytes { … }` | `SocketAddress.withUnsafeBytes(_:)`, precise | Right: `result` is a `SystemSockets.SocketAddress.ResolvedAddress`; the hunk `@@ -206,9 +238,45 @@` added the line. |
| 2 | swift-nio `Sources/NIOPosix/System.swift:682`, `SocketDescriptor.IPOption.packetInfo.rawValue` | `SocketDescriptor.IPOption.rawValue`, precise | Right. |
| 3 | swift-nio `Sources/_NIOFileSystem/Internal/SystemFileHandle.swift:843`, `options: materialization.exclusive ? [.exclusive] : []` | `FilePath.RenameOptions.exclusive`, precise, line not added | Right, and rightly marked: the migration replaced NIO's own `RenameOptions` with `typealias RenameOptions = FilePath.RenameOptions` (Syscall.swift:137), so the unchanged line now means System's. |
| 4 | swift-nio `Tests/NIOPosixTests/ControlMessageTests.swift:23`, `import struct SystemSockets.SocketDescriptor` | `SocketDescriptor`, lexical | Right: a scoped import; the index records the same reference in compiled files. |
| 5 | swift-foundation `…/FileManager+DarwinSearchPaths.swift:51`, `SearchPaths.Domains(rawValue: …)` | `SearchPaths.Domains`, precise | Right (the snapshot compiler's index). |
| 6 | swift-foundation `…/FileOperations+Enumeration.swift:484`, `try? stream.close()` | `DirectoryStream.close()`, precise | Right: `stream` is `DirectoryStream.open(…)`'s; hunk `@@ -336,8 +354,158 @@`. |
| 7 | swift-foundation `Tests/…/FileManagerTests.swift:701`, `SystemConfig.maxFileNameBytes - 3` | `SystemConfig.maxFileNameBytes`, lexical | Right: the compile-time `Int` (Limits/CompileTimeLimits.swift:29), not `SystemConfig.PathName.maxFileNameBytes`. |
| 8 | swift-subprocess `Sources/Subprocess/Platforms/Subprocess+Unix.swift:59`, `SystemPackage.Signal.terminate.rawValue` | `Signal.rawValue`, precise | Right. |
| 9 | swift-subprocess `Tests/SubprocessTests/IntegrationTests.swift:2498`, `var sleepPidToKill: CInterop.ProcessID = 0` | `CInterop.ProcessID`, lexical | Right. |
| 10 | swift-nio would benefit, `Sources/NIOCore/SocketAddresses.swift:785` (merge base), `self.sin_addr` | `sockaddr_in` → `CInterop.SockAddrIn`, precise | Right but coarse: a field use joins through its struct's typealias, not the Swift-named accessors. |
| 11 | swift-foundation would benefit, `…/ErrorCodes+POSIX.swift:327`, `POSIXErrorCode` | `CInterop.POSIXErrorCode`, lexical | Right, weak: the provisional typealias. |
| 12 | swift-subprocess would benefit, `Sources/_SubprocessCShims/process_shims.c:464`, `int _pidfd_open(pid_t pid)` | `pid_t` → `CInterop.ProcessID` | **Wrong**: C code can't adopt a Swift type. Fixed in `4c8ef6c`: a C, C++ or header site of an interface that's only a type is dropped (357 sites). |

11 of 12 right before the fix, 12 of 12 after. Found and fixed while building
it, before the sample: paths with a space end in a tab in `git diff`'s headers
(NIO's `System Calls/`), which had marked 90 NIO sites "not added"; `.union` and
`.unspecified` matched lexically to new declarations; `makeFIFO(permissions:)`
matched the `relativeTo:` overload; the derivation's `nil` and `value` read as
C names (511 `nil` sites in swift-toolchain-sarif); an export directory named
`src` broke swift-argument-parser's build (package identity); the snapshot
toolchain's `swiftc` resolved to `swift-driver`.

### Top 15 carve-outs by adopter reach

System-next `7b0875f`, from `reach.py --limit 15`. Reach counts packages
using the carve-out on `migrate-darwin` or calling C interfaces it newly
wraps; the pitch rank is the automatic order's.

| # | Carve-out | Kind | Pitch rank | Reach | Using | Would benefit | Sites |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | `pthread` | cluster (361 declarations) | 249 | 21 | 13 | 21 | 1235 |
| 2 | `memory` | cluster (118) | 176 | 17 | 2 | 17 | 622 |
| 3 | `processid-exit-exit-atexit` | cluster (3) | 41 | 16 | 8 | 14 | 73 |
| 4 | `pthread--signal` | part (37) | 72 | 15 | 6 | 14 | 219 |
| 5 | `processid-exitcode` | cluster (24) | 61 | 15 | 3 | 15 | 107 |
| 6 | `memory--memory` | part | 52 | 15 | 2 | 15 | 510 |
| 7 | `pthread--pthread-mutex` | part | 242 | 14 | 7 | 13 | 241 |
| 8 | `filestream` | cluster | 68 | 14 | 3 | 14 | 221 |
| 9 | `pthread--signal-action` | part | 79 | 13 | 5 | 11 | 91 |
| 10 | `errno-current` | cluster | 111 | 13 | 3 | 13 | 408 |
| 11 | `processid` | cluster | 36 | 12 | 6 | 10 | 133 |
| 12 | `cstring` | cluster | 34 | 12 | 0 | 12 | 208 |
| 13 | `memory--memory-memcmp-memchr-memset-s` | part | 138 | 11 | 1 | 11 | 96 |
| 14 | `pthread--pthread` | part | 193 | 10 | 7 | 8 | 180 |
| 15 | `dynamiclibrary` | cluster | 189 | 10 | 6 | 10 | 330 |

Reading it: the thread primitives (mutexes, signals) and process exit are what
the most packages already adopted; `ProcessID.exit` alone is used by 8 of the
14 migrations. Memory, C strings and errno are what the most would benefit
from without anyone having adopted them yet (the C-library wrappers the
coverage lane added as provisional). Big clusters lead because they hold more
declarations; `reach.py --kind part` ranks parts alone.

### Known misses

- Adopted sites are precise only where the macOS build compiles: tests and
  other platforms' branches are lexical, and the narrow rules miss common
  member names there (`try mutex.lock()`).
- The `#if` reading that sends lines to the lexical matcher can't decide a
  package's own flags; such a line is left to the index, and missed if the
  build didn't compile it.
- Migration branches move while other lanes work (swift-subprocess, SwiftPM
  and swift-foundation moved during the session); each run records the
  commit it read.
- Would-benefit sites are at the extraction's commit; for a package whose
  extraction is the ecosystem clone's (an older tag, for swift-log), a diff
  says only whether the line survives on the branch.
- A C name reaches every declaration that names it (`pthread_mutex_lock` counts
  for `lock()` and `withLock(_:)`), and a field use reaches its struct's
  typealias, not the field's Swift accessor.
- The lexical interface scan (packages the coverage store hasn't audited) reads
  library Swift sources only.

## 6. For the coverage lane

Nothing needed. Noted: `derive.py` reads `nil` in "with `UTIME_OMIT` for a
`nil` time" and `value` in "the 8 bytes of `value`" as argument C names;
harmless for the coverage checks, and filtered here.
