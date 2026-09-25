# Directory streams and walks

System had no public directory iteration. swift-nio (its directory
listings, recursive with fts or not), swift-foundation, and the samples all
need it. This directory records how the prototype's two types were decided:

- `DirectoryStream` (`Sources/System/Directories/DirectoryStream.swift`), an
  owned, noncopyable directory stream: `opendir`, `fdopendir`, `readdir`,
  `rewinddir`, `dirfd`, `closedir`.
- `DirectoryWalk` (`DirectoryWalk.swift`), a recursive walk built on
  `openat`, `fdopendir` and `readdir`, rather than on `fts`.

`run.sh` reproduces every measurement below, building everything under
`$TMPDIR`. `Verify/` holds the compiler checks the design depends on. The
numbers were taken on macOS 26.3 (APFS) with Swift 6.2
(swiftlang-6.2.0.19.9), on an M1 Max.

```sh
swift build -c release --target SystemPackage
Prototype/Directories/run.sh
```

## The API

```swift
var stream = try DirectoryStream.open("/tmp")
while let entry = try stream.next() {      // skips . and ..
  print(entry.name, entry.type as Any, entry.inode)
}
try stream.close()

var walk = try DirectoryWalk("Sources", order: .postorder)
while let entry = try walk.next() {
  let name = FilePath(root: nil, components: entry.name)
  if entry.type == .directory {
    try name.removeDirectory(relativeTo: walk.parentDirectory)
  } else {
    try name.unlink(relativeTo: walk.parentDirectory)
  }
}
```

| | `DirectoryStream` | `DirectoryWalk` |
|---|---|---|
| open | `open(_:)` (`opendir`), `open(_:relativeTo:options:)` (`openat` + `fdopendir`), each for `FilePath` and C strings | `init(_:order:)` from a path; `init(_:path:order:)` from a stream |
| adopt | `init(taking: FileDescriptor)`, `init(_: consuming OwnedFD)` (`fdopendir`) | a consumed `DirectoryStream` |
| read | `mutating next() -> Entry?`, `rewind()` | `mutating next() -> Entry?`, `skipDescendants()` |
| vend | `fileDescriptor` (`dirfd`) | `parentDirectory`: the directory holding the last entry |
| close | `consuming close()`, or deinit | `consuming close()`, or deinit |
| entry | `name`, `type: FileType?`, `inode` | `name`, `path`, `type: FileType?`, `depth`, `error: Errno?` |

Both are `@available(System 199, *)`, and exist on every Unix-like platform
but WASI.

## Ownership

**A `DIR` owns its descriptor.** `fdopendir` hands the descriptor to the C
library, and `closedir` both frees the stream and closes the descriptor.
There's no way to take the descriptor back: POSIX has none, and only FreeBSD
has `fdclosedir`. So `DirectoryStream` can't follow `Prototype/Subtypes`'
shape for owned sub-kinds, a struct that holds an `OwnedFD` and has no deinit
of its own. Its resource is the `DIR`, so it has a deinit that calls
`closedir`.

- **Rejected: holding an `OwnedFD` next to the `DIR`.** Both would close the
  descriptor. The second close gets `EBADF`, or, if the number was reused in
  between, closes someone else's file.
- **Rejected: giving `fdopendir` a duplicate, so an `OwnedFD` stays
  independent.** NIO does this (`makeReaddirSource` in
  `DirectoryEntries.swift`). It costs a descriptor per stream, and the two
  descriptors share one offset, so the stream and the original disturb each
  other's position.
- **Rejected: a stream of its own, over `getdents64` or `getdirentries`,
  holding an `OwnedFD` and a buffer.** That would fit the Subtypes shape, but
  Darwin has no public `getdirentries`: `__getdirentries64` is private, and
  `getattrlistbulk` is a different interface. See `getdents64` below.

Conversions follow the package's patterns:

- `init(taking: FileDescriptor) throws(Errno)` is `fdopendir` as C has it. If
  it succeeds, the stream owns the descriptor; if it throws, the caller still
  does.
- `init(_: consuming OwnedFD) throws(Errno)` closes the descriptor if it
  throws. This is the consuming, throwing conversion that
  `Prototype/Subtypes` rejected for narrowing a socket. Here it's accepted,
  because `fdopendir` allocates, so it can fail after any check, and a
  conversion that can't fail isn't possible. A caller that wants to keep a
  descriptor that might not be a directory checks first, with
  `Stat(owner.fileDescriptor).type`. That covers the only failure worth
  recovering from, `ENOTDIR`. The documentation shows the check.
- `fileDescriptor` vends the stream's descriptor, as `OwnedFD` vends its
  own. It's valid only while the stream lives, for `*at` calls and `fstat`.
  There's no `relinquish()`: to keep a descriptor past the stream, duplicate
  it.
- `DirectoryWalk(stream)` consumes a stream, and starts from its position.

Two compiler constraints shaped the implementation:

- **No `discard self`.** A stream stores its reusable name storage, an
  Array, and `discard self` requires trivially destroyed stored properties
  (`Verify/D1_discard_nontrivial.swift`, a variant of `Prototype/Verify`'s
  V15a). So `close()` and the conversions clear the optional `DIR` pointer,
  and the deinit, which still runs, finds nothing to close
  (`Verify/D2_consuming_close_clears.swift`).
- **No `self = try …` in the initializers.** A noncopyable type with a deinit
  and a stored property that isn't trivially destroyed can't be assigned
  from a `try` in its initializer ("conditional initialization or destruction
  of noncopyable types is not supported"). Delegating to a throwing
  initializer works, so the public initializers delegate
  (`Verify/D3_noncopyable_self_assign.swift`).

## Closing, and the undecided close policy

`Prototype/CloseErrors` leaves open whether `OwnedFD`'s deinit should keep
dropping close errors or trap on `EBADF`. `DirectoryStream` and
`DirectoryWalk` follow whatever `OwnedFD` does. Today their deinits drop the
error, and an explicit `close()` reports it. Tests pin the current policy
down (`DirectoryStreamClosingTests.swift`).

Directories narrow the question. `closedir` on a directory opened for
reading can fail only with `EBADF`: there are no delayed writes to report,
unlike a file's close on NFS. Checked on Darwin: after `close(dirfd(d))`,
`closedir(d)` fails with `EBADF`, and so does a `readdir` whose buffer is
empty. So for directory streams, "drop or trap on `EBADF`" is the whole
policy question, and CloseErrors' recommendation would apply unchanged. If
it's adopted, it's the same one-line change in three deinits, `OwnedFD`'s
and these two, plus the places where the walk closes a directory it has
finished.

## Entries, and how long they're valid

`readdir` returns a pointer into the stream's buffer, which the next
`readdir` or the `closedir` overwrites. The prototype removes that hazard
rather than exposing it. Each entry is a copy, a value that stays valid:
`name` is a `FilePath.Component`, with `type` and `inode`, much as
`UserEntry` copies a `passwd`.

Copying the name needn't allocate, though. The stream writes each name
into storage it keeps. When the entry that `next()` returned before is gone,
nothing else shares that storage, so it's overwritten in place. When an
entry is still alive, copy-on-write gives the new name fresh storage. So the
usual loop, `while let entry = try stream.next()`, allocates nothing per
entry, and code that keeps entries pays one allocation each. Measured with a
malloc interposer (`mallocs.c`, `bench.swift`) over a directory of 100,000
files, in a release build:

| | allocations |
|---|---|
| reading every entry, keeping none | 5 in all: none per entry |
| keeping every entry | 1.0 per entry: its name |
| `DirectoryWalk` over the macOS SDK (48,703 entries, 9,531 directories) | 0.81 per entry: about 4 per directory, and none per file. `fdopendir` makes 2, for the `DIR` and its buffer, as it does for the C walker; the other 2 are the level's name and path |

On APFS the copy is small next to `readdir` itself (`entrycost.swift`, per
entry, the best of 7 runs over 100,000 files):

| | ns per entry |
|---|---|
| `readdir`, reading `d_type` and `d_namlen` | 479 |
| … and copying the name into an `Array<CChar>` | 525 |
| … into a `String` | 524 |
| … copying `d_reclen` bytes into a zeroed `dirent` | 506 |
| … copying the whole `dirent`, 1,048 bytes | 496 |

So on Darwin, allocating per entry would cost about 10%. On Linux `readdir`
is likely much cheaper, which would make reuse matter more. That's
unmeasured here.

Rejected:
- **A nonescapable entry view, from `@_lifetime(&self) mutating func
  next()`.** It models `readdir`'s contract exactly: a new entry needs the
  stream exclusively, so the previous view must be dead. But it needs the
  experimental `Lifetimes` feature in any client helper that returns an
  entry, which `Prototype/BorrowedFD` found to be a blocker. And while a view
  is alive, the stream can't be touched at all, not even for
  `stream.fileDescriptor`, which the `*at` calls on the entry need. Copying
  into reused storage gets the same allocation behavior without either cost.
- **A closure, `forEach { (entry: borrowing Entry) in … }`.** A noncopyable
  entry lent to a closure can't escape. But the loop body can't `break`,
  Swift 6.2 infers `throws(any Error)` for the closure rather than
  `throws(Errno)`, and the closure can't read `stream.fileDescriptor` while
  the stream is mutably borrowed.
- **Wrapping a copy of `struct dirent`, as `Stat` wraps `struct stat`.** On
  Darwin a `dirent` is 1,048 bytes, since `d_name` has room for 1,024. And
  copying the whole structure can read past the end of the stream's buffer:
  a record is only `d_reclen` bytes long, often much shorter than
  `sizeof(struct dirent)`. The existing `forEachFile` in
  `FilePathTempPosix.swift` does exactly that (`try body(dirent.pointee)`).
  The prototype reads `d_name` through its offset, and the name's length
  from `d_namlen` (on Darwin) or `strlen` (elsewhere).

The stream skips `.` and `..`, as NIO's listing, Foundation's, and the
temporary-directory helper all do, and as Rust's `read_dir`, Python's
`scandir`, and Go's `ReadDir` do. Recursing into either is the classic way a
walk escapes its tree, and they're never informative: POSIX doesn't even
promise that `readdir` returns them. It also skips an empty name, which a
`FilePath.Component` can't hold. Rejected: returning them, which only
`ls -a` wants, and it can print them itself.

## `d_type`

The field exists on every platform the API covers: Darwin, Glibc, Musl,
Bionic, FreeBSD, and OpenBSD. But some file systems leave it `DT_UNKNOWN`.
So `Entry.type` is a `FileType?`, and `nil`
means that the directory didn't record the type. An `Optional` makes the
unknown case visible, and the documentation shows the `Stat` to call instead.
A walk has to know which entries are directories, so it resolves a `nil` type
itself, with `fstatat(AT_SYMLINK_NOFOLLOW)` relative to the parent. No file
system here produces `DT_UNKNOWN`, so a test calls the resolution directly.
`DT_WHT` becomes `.whiteout` where `FileType` has it (Darwin, FreeBSD);
elsewhere it's `nil`.

WASI is excluded for now. Its `d_type` values aren't the Unix ones, so they
would need `_getConst_DT_*` shims in `CSystemWASI.h` that can't be built here.

## Errors

`readdir` returns `NULL` both at the end and on failure, and sets `errno`
only on failure. `next()` clears `errno` before each call, returns `nil` only
when `errno` is still 0, throws otherwise, and retries `EINTR` if asked.
Retrying is safe because a failed `readdir` hasn't consumed an entry. A real
failure is easy to produce: close the stream's descriptor behind its back,
and `readdir` returns `NULL` with `EBADF` (tested in a child process). For
comparison, NIO's `Libc.readdir` uses the same `errno` sentinel, and
Foundation's `_POSIXDirectoryContentsSequence` treats every `NULL` as the
end, so it silently drops errors.

A walk reports errors the way `fts` does, in two ways.

- **Opening a directory fails.** This is common: `EACCES`, `EMFILE`, or
  `ENOTDIR` for a directory replaced by a link. The directory's entry carries
  the error in `error`, the walk doesn't visit its contents, and it goes on.
  This is `fts`'s `FTS_DNR`. Callers can report the path and continue, as
  `rm -r`, `find`, and `du` do.
- **Reading a directory fails, or finding a type does.** This is rare:
  `EIO`, `ESTALE`. `next()` throws, and the walk leaves that directory, so
  calling `next()` again continues with the rest of the tree. A type that
  `fstatat` can't find is instead reported on the entry, with a `nil` type.

The walk opens a directory before returning the directory's preorder entry.
So the entry can carry the error, and the walk later reads the contents
through that very descriptor, with no second lookup by name.

## `fts`, or a walker of System's own

The walker is System's own. The evidence, from `run.sh` (`walk.c`,
`swap.c`, `deep.c`, `count.c`):

**Safety.** `swap.c` replaces a directory with a link to a directory
outside the tree while each walk is between two calls, as another process
could, and removes what the walk visits, as `rm -r` would:

| walk | outcome |
|---|---|
| `fts`, `FTS_PHYSICAL \| FTS_NOCHDIR`, as NIO uses it | follows the link: **removed `outside/precious`** |
| `fts`, `FTS_PHYSICAL`, which changes directory | safe: it checks each directory's device and inode after `chdir`. But it changes the working directory of the whole process, which no multithreaded library can do |
| `openat(parent, name, O_DIRECTORY \| O_NOFOLLOW)` | safe: "Not a directory"; nothing outside touched |

`FTS_NOCHDIR` is the only mode a library can use, and it resolves each path
in full from the root, links included. `DirectoryWalk` opens each directory
relative to its parent's descriptor, with `O_NOFOLLOW`. A test does the same
swap between `readdir` and `open`, as a live race would, and the entry
reports the error (`ENOTDIR` on Darwin) instead of the walk following the
link.

**Paths longer than `PATH_MAX`.** In a chain of 60 directories with 1,332-byte
paths, `fts` with `FTS_NOCHDIR` stops at level 47 ("File name too long"). The
native walker visits all 62 entries, since it never resolves a whole path.

**Speed.** Walking the macOS SDK (48,704 entries, 9,531 directories, 21
deep), warm, the fastest of 5 runs, in ms. The C numbers in the first column
are from a quiet machine. The second column is one `run.sh` run on a loaded
one (load average about 86).

| walk | quiet | loaded |
|---|---|---|
| C `openat` walker, types from `d_type` | 279 | 310 |
| `DirectoryWalk` (Swift, release) | | 298 |
| `fts`, `FTS_NOSTAT` | 332 | 351 |
| `fts`, with stat | 341 | 357 |
| `fts`, changing directory | 703 | 744 |
| C `openat` walker, with `fstatat` per entry | 476 | 497 |
| `DirectoryWalk`, with `Stat` per entry | | 564 |

For types alone, the native walker is 12 to 16% faster than `fts`, and the
Swift prototype is as fast as the C one. With every entry's status, `fts` is
faster, by 1.4 times over the C walker and 1.6 over the prototype. `count.c` shows why: Darwin's `fts` never calls
`readdir`. It reads each directory with `getattrlistbulk`, two calls per
directory, and gets attributes in bulk whether or not `FTS_NOSTAT` is set:

| walk of the SDK | `getattrlistbulk` | `fstatat` | `openat` | `readdir` |
|---|---|---|---|---|
| `fts`, `FTS_NOSTAT` | 19,099 | 9,531 | 0 | 0 |
| native | 0 | 0 | 9,531 | 77,296 |
| native, with `fstatat` per entry | 0 | 48,703 | 9,531 | 77,296 |

A walk that needs every entry's status on Darwin could close the gap with a
`getattrlistbulk` path of its own later. NIO's recursive listing uses only
path and type, so it would be faster on the native walker.

**Descriptors.** The native walker holds one descriptor per level. Under
`ulimit -n 256`, the usual soft limit on macOS, it stops at depth 253,
while `fts` finishes a 300-deep tree. `fts` reads each directory whole and
closes it. `DirectoryWalk` reports this as `EMFILE` on the directory it
couldn't open, and a test checks that in a child process with a lowered
limit. Trees that deep are rare, and the limit can be raised. Rejected for
now: reopening ancestors through `..`, checking each one's device and inode,
as `fts`' `chdir` mode does. That's the way to bound the descriptors if it
comes to matter.

**Portability.** `fts` isn't in Glibc's Swift module, so it would need
`<fts.h>` in a CSystem header. That's the MemberImportVisibility hazard
CLAUDE.md describes, if an `FTSENT` were ever vended. NIO includes it in
`CNIOLinux.h`, and wraps `fts_open` because Android's nullability annotations
are wrong. Foundation checks `__has_include(<fts.h>)`. Musl doesn't provide
`fts` (unverified here), and neither does WASI. The native walker uses only
calls System wraps on every Unix-like platform.

**Removing while reading.** A postorder walk removes the entries of the
directory it's reading. Some file systems have skipped entries when that
happens: old coreutils carried a workaround for HFS+ (from memory, not
checked here). On APFS, `rm-r` removed a directory of 100,000 files and
another of 20,000 in one pass, with nothing left behind: the final `rmdir`
succeeded. In a release build that took 10.9 s, against 13.6 s for
`/bin/rm -r`, under load.

**Stack.** The walk is iterative. It keeps an array of open levels, and
doesn't recurse.

Decision: **a walker of System's own.** Rejected: `fts` with `FTS_NOCHDIR`,
for the link and `PATH_MAX` results and its portability. Rejected: `fts`
changing directory, since it changes the working directory of the whole
process.

The walk's shape:
- **The root isn't visited.** Only what's under it is, as a stream returns a
  directory's contents but not the directory itself. Otherwise every caller
  special-cases it: `rm -r` would have to remove the root relative to a
  parent it doesn't have. Rejected: `fts`'s level-0 entry.
- **Each entry once, before or after its contents**, chosen by `order:`,
  like `nftw`'s `FTW_DEPTH` and Rust walkdir's `contents_first`. Rejected:
  `fts`'s pair of visits per directory (`FTS_D`, then `FTS_DP`), which every
  consumer has to filter. NIO's comment is "Don't visit directories twice".
- **`skipDescendants()`** skips the contents of the directory just returned
  in preorder. A skipped directory gets no second visit, because in preorder
  there is none. It does nothing after a file, or in a postorder walk.
- **`parentDirectory` is on the walk, not on the entry.** It's the
  descriptor for the directory that holds the last entry, valid until the
  walk moves on. Entries are values that code collects. A descriptor stored
  in one would go stale, and closed descriptor numbers are reused, so an
  `fstatat` through a stale one could silently reach another file.
- **Paths are built only when asked for.** An entry holds its parent's path,
  shared with the walk, and `entry.path` appends the name on demand.

Not included: following links (`FTS_LOGICAL`, `FTS_COMFOLLOW`) and the
cycle detection that needs; staying on one file system (`FTS_XDEV`); and
sorting (`fts`'s `compar`). A physical walk can't cycle, except through a
bind mount, and then it stops at the descriptor limit.

## `getdents64`

Not added. Glibc's `readdir` already buffers `getdents64`, 32 KB at a time.
A direct wrapper would save the `DIR`'s allocation, a copy of each entry, and
let the caller supply the buffer. But it's Linux-only, can't be built or
measured here, and neither NIO nor Foundation uses it. If it's added, it's the
natural backing for a stream that does fit the Subtypes shape: an `OwnedFD`
and a buffer, with no `DIR` and no deinit.

## Found along the way

These are in files this lane doesn't own, so they're reported here, not
fixed.

- **`withTemporaryFilePath` removed the wrong files, leaked trees, and could
  crash.** This lane found it, and `40d0ea4` on `system-next` (refine-3) fixed
  it independently, the same day. `recursiveRemove` in
  `FilePathTempPosix.swift` recursed, and unlinked, relative to the top
  directory's descriptor, not the subdirectory's. For a file `sub/x`, it
  unlinked the top directory's `x`, or got `ENOENT`, which the helper's `try?`
  dropped, so every subdirectory that wasn't empty leaked. A chain of
  same-named directories, as short as `d/d`, recursed until it crashed:
  SIGSEGV on the main thread, SIGBUS on a 512 KB thread. After the fix, one
  limit remains. The removal still recurses, with large frames, so in a debug
  build it overflows the stack of the thread that runs a swift-testing test.
  A 40-deep chain is removed; a 60-deep one crashes the test process with
  SIGBUS. On XCTest's main thread, 500 deep is fine. The directory tests
  therefore empty their scratch directories with a postorder `DirectoryWalk`
  first (`DirectoryFixture.withTemporaryDirectory`), because the
  descriptor-limit test makes a tree 100 deep. A walk-based
  `_recursiveRemove` would lift the limit.
- **`forEachFile` copies the whole `dirent`** (`try body(dirent.pointee)`),
  which can read past the end of `readdir`'s buffer (see Entries).
- **`FilePath.Component.withPlatformString` always copies.** That's the FIXME
  at `SystemString.swift:237`. A directory entry's name ends where its
  storage does, so fixing it would make `*at` calls with entry names free of
  copies. The walk uses an internal version that doesn't copy.

## Unverified off Darwin

Everything here was built and run only on macOS. These parts have never
been compiled or run:
- the Linux, Android, FreeBSD, and OpenBSD branches: `strlen` for the name's
  length, `d_fileno`, and `DT_WHT`;
- whether `O_DIRECTORY | O_NOFOLLOW` on a link fails there with `ELOOP` or
  `ENOTDIR` (the code and tests accept either);
- Glibc's and Musl's `fdopendir` and `closedir` behavior;
- the per-entry costs on Linux file systems.

The descriptor-limit test runs on macOS only, because `RLIMIT_NOFILE`'s type
differs between the C libraries.

## Decisions

- **Ownership.** `DirectoryStream` owns a `DIR` and has a deinit of its own.
  It adopts a raw descriptor, or an `OwnedFD` (closing it if that fails),
  vends its descriptor, and can't give the descriptor back. Rejected: an
  `OwnedFD` beside the `DIR`, and a duplicate for `fdopendir`.
- **Close policy.** It follows `OwnedFD`: the deinit drops the error, and
  `close()` reports it. For directories the only error is `EBADF`, so
  whatever CloseErrors decides applies unchanged.
- **Entries.** They're copies. Name storage is reused while nothing shares it,
  so a loop allocates nothing per entry. Rejected: a lifetime-dependent view,
  a closure-scoped borrow, and a `dirent` wrapper.
- **`d_type`.** `FileType?`, with `nil` for unknown. The walk resolves it with
  `fstatat`.
- **Errors.** `nil` means the end, and anything else throws. A walk puts
  open errors on the entry, and throws read errors, after which it can
  continue.
- **Walk.** It's System's own, on `openat`, `O_NOFOLLOW`, and `fdopendir`,
  iterative, with one visit per entry in preorder or postorder. Rejected:
  `fts`.
- **`getdents64`.** Not added; noted as the backing for a future stream that
  holds an `OwnedFD`.

Confidence: high on the walk's safety and the error model. It's also high on
copying into reused storage: the measurements back it, and the alternatives
fail on 6.2's lifetime and closure support. Medium on the descriptor-per-level
limit. Medium on excluding WASI: it should be cheap to add with shims.
