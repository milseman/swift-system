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

A snapshot is one JSON document (`graph.json.gz`): `meta`, `nodes` (by ID),
`links` (a list), and `hunks` (the adopters' diff hunks, by ID, which links
cite). IDs are stable across commits: a declaration's is its USR, which only a
change to its signature or context changes.

### Node kinds

| Kind | ID | What |
|---|---|---|
| `declaration` | USR, or `scan:<module>:<path>` for one only the source scan sees | A Swift declaration. `origin` is `head` (system-next adds it), `base` (a type on main: FileDescriptor, FilePath, Errno, CInterop, UserID, …; kept so links to them aren't cut), or `external` (a C or standard-library type System extends, or a protocol it conforms to). Each head declaration carries its reach (below). |
| `cname` | `cname:<name>` | A C interface a doc comment names: function, constant, type, macro, field or variable, with the C function family it's in, and whether the base commit already covers it. |
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
| `extends` | declaration → type | A member declared in an `extension` of its host rather than in the host's own body; the host is often a base or external type. | `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` → `FileDescriptor`; `timespec.seconds` → `timespec` |
| `conformsTo` | type → protocol | A conformance, to a new, base or external protocol. | `FileDescriptor.StatusFlags` → `OptionSet` |
| `usesInSignature` | declaration → type | A type its signature names, with its roles: `parameter`, `return`, `throws`, `type` (a property's or case payload's), `aliased` (a typealias's target), `generic` (a constraint). | `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` → `UserID` (parameter), → `Errno` (throws); `FileDescriptor.statusFlags()` → `FileDescriptor.StatusFlags` (return) |
| `wraps` | declaration → cname | A C interface its doc comment names ("The corresponding C function is `x`."), as adopter-coverage's `derive.py` reads it: role `subject`, `alternative` or `argument`, and whether the sentence restricts it to one use. | `PThread.Mutex.lock()` → `pthread_mutex_lock` (subject); `FileDescriptor.statusFlags()` → `fcntl` (subject, restricted), → `F_GETFL` (argument) |
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
| `sameCFamily` | two declarations that `wrap` C functions of one family (the functions one declaration's sentences name together: `chmod`, or `lchmod` if …) | `FilePath.setTimes(…)` and `FileDescriptor.setTimes(…)` (futimens, utimensat) |
| `sameImplementation` | two declarations that `reach` one internal piece | the fcntl command accessors, through `system_fcntl` |
| `sameBlock`, `sameMark` | two declarations in one block, or in blocks under one MARK title in one file | the members of one `extension FilePath` family |
| `couldUse` (reach) | a declaration, and a package that `calls` a cname it wraps (as subject, alternative or argument, not restricted), unless the base commit covers the cname | `ProcessID.current` → every package that calls `getpid` |

Each head declaration's **reach** is `{usedBy: [packages], couldUse:
[packages]}`, with the sites a query lists.

### Snapshots, diffs and queries

- A run writes the snapshot to its output (`graph.json.gz`) and to the store,
  `<API_GRAPH_SNAPSHOTS>/<head commit>.json.gz` (default
  `../api-graph-snapshots` beside the repository, so it outlives worktrees),
  and diffs it with the previous snapshot of the same head ref: nodes and
  links added, removed and changed.
- `scripts/graphq.py` queries a snapshot: a node's neighborhood by link kind,
  a type with or without its members, everything reaching a C family, a C
  name's callers, a package's reach, and the diff of two snapshots.

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

Build order (from the 2026-09-29 direction): graph, adopter reach, pitch files
and checks, bundles, suggestions, domains.

| Step | State | Where |
|---|---|---|
| Graph | done: snapshot, store, diff, queries | `scripts/snapshot.py`, `scripts/graphq.py`; build_graph.py records signature roles, conformances and blocks; `scripts/cnames.py` the C names and families (`3a31998`, `188cd6c`) |
| Adopter reach | done: `usedBy` and `calls` links, each declaration's reach | `scripts/adopters.py` (milestone 1), folded into the snapshot |
| Pitch files and checks | done: format, resolver, checks, five examples | `scripts/pitches.py`, `Prototype/Pitches/` (`9791564`) |
| Bundles | next: per-pitch bundles with adopter examples | bundles.py, generalized to any set of nodes |
| Suggestions | to do: today's clustering as a report proposing pitches | cluster.py, report.py |
| Domains | to do: C families by domain | a hand-kept data file |

On system-next `7b0875f`: 9835 nodes, 37892 links; 58 packages (the
ecosystem gained 21 clones during the session, picked up with no change).

To resume: read this section, then run `Utilities/api-graph/regenerate.sh`
(about 5 minutes when every adopter index is cached) and read the output's
`GRAPH.md` and `PITCHES.md`; `scripts/graphq.py --help` for queries.

## 4. Milestone 1: adopters for every carve-out (done)

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
  `adopters.md`); in `API-GRAPH.md`, Adopters columns and an Adopter reach
  section; `scripts/reach.py` ranks and filters by reach. A clone in
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

## 5. For the coverage lane

Nothing needed. Noted: `derive.py` reads `nil` in "with `UTIME_OMIT` for a
`nil` time" and `value` in "the 8 bytes of `value`" as argument C names;
harmless for the coverage checks, and filtered here.
