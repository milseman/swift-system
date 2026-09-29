# The foundation-gaps lane

What swift-foundation's `no-darwin` branch still needs from System, from its REPORT.md ("No Darwin: what it
takes", "What System needs (for the coverage lane)"), in the order Michael gave: `Errno.notCapable` on Darwin,
DirectoryWalk with a bounded number of descriptors, DirectoryWalk visiting the root and giving each entry's
status, and the number of loaded images. Out of scope: the environment lock (`environ_lock_np`, a private
interface) and swift-foundation itself. Base: system-next at `eee1da2`, after the coverage merge. Built and tested
on Darwin only.

Before any change: XCTest 565 tests (4 skipped), swift-testing 485 tests in 76 suites, all passing. After item 4:
XCTest 565 tests (4 skipped), swift-testing 496 tests in 80 suites, all passing. The ABI-stable build of
SystemPackage fails only in its known files (FileTimes.swift, FilePathOperations.swift, Syscalls.swift); none of
this lane's files has an error there.

**Resume here:** all four items are done (sections 1 to 4); nothing is in progress. What's left is for other lanes
and for Foundation (section 5). This worktree's `.build` and scratch output are deleted.

## 1. `Errno.notCapable` on Darwin: `6ba9b30`

What: `Errno.notCapable` (and its `ENOTCAPABLE` fix-it, and the internal `_ENOTCAPABLE`) is now declared on Darwin
as well as FreeBSD. `capabilityMode` (ECAPMODE) and `integrityCheckFailed` (EINTEGRITY) stay FreeBSD-only: the `#if`
in Errno.swift and Internals/Constants.swift is split in two. It was the one `POSIXError.Code` value that
Foundation's deprecation left without a replacement.

Design calls:
- The condition is `canImport(Darwin, _version: 346) || os(FreeBSD)`, not `SYSTEM_PACKAGE_DARWIN`. The macOS 26.0
  SDK is the first whose `<sys/errno.h>` defines `ENOTCAPABLE` (107, unconditionally, and `ELAST` moved from 106 to
  107); the 15.x SDKs don't, so `SYSTEM_PACKAGE_DARWIN` would break a build with them. This is the gate the package
  already uses for `AT_RESOLVE_BENEATH`, which arrived in the same SDK (Darwin module 347.0.12 in 26.0).
- It stays in Errno's `System 0.0.1` extension with the other platform-gated values, as the FreeBSD values were
  added. It's `@_alwaysEmitIntoClient` and a C constant, so it has no symbol and back-deploys; rejected: a
  `System 199` extension, which would restrict clients for no runtime reason.
- Samples/Beneath.swift still spells `Errno(rawValue: ENOTCAPABLE)`, with a comment that System names it only on
  FreeBSD: that's the demos lane's file, so it's left for them (coverage's Queue row B1 said so too).

Tests: ErrnoTest's `testConstants` checks `ENOTCAPABLE == Errno.notCapable.rawValue` on Darwin (and FreeBSD).
Coverage's Queue row B1 (Prototype/Status/REPORT.md) is marked done.

Next: item 2.

## 2. DirectoryWalk with a bounded number of descriptors: `7c65c04`

What: `DirectoryWalk.Options`, a new `options:` parameter of both initializers (default `[]`), with
`.boundedDescriptors`. Such a walk reads each directory's entries whole the first time it reads the directory, as
fts does, and closes the directory when it goes into one of its subdirectories; only the root stays open. When it
comes back to a directory (for the rest of its entries, or a subdirectory's postorder visit), it reopens it by the
names from the root down, each `openat` relative to the one before with `O_DIRECTORY | O_NOFOLLOW`, then `fstat`s
it and checks the device and inode it recorded when it first opened it. It holds at most three descriptors: the
root, the directory whose entries it visits, and a subdirectory it has opened (`.whenRead`'s pending one) or the
one in the middle of a reopen. Without the option, nothing changes. Removes the EMFILE break for Foundation's copy,
link and `subpathsOfDirectory` (its SYSTEM-GAP markers at `_LinkOrCopyWalk` and `_subpathsOfDirectory`) once it
passes the option.

The guarantees that `a1c544c` documents, and what the option gives up (the option's doc says both):
- Kept: every open is relative to the directory that contains it, and none follows a symbolic link, going down or
  coming back, so replacing a directory with a link still can't lead the walk out of the tree.
- Kept: `parentDirectory` is always the directory whose entries the walk visits (the identity check).
- Given up: "a directory the walk has opened stays open even if it's moved elsewhere, and the walk reads it where it
  is". Between a directory and its subdirectories the walk follows names, not directories: if the directory has
  moved or been replaced when the walk comes back, `next()` throws the reopen's error, or ENOENT if another
  directory has the name (as fts's `fts_safe_changedir` does), and the walk leaves that directory, as after a read
  error (its remaining entries and its postorder visit, and the finished subdirectory's postorder visit, are
  dropped). A directory's entries are the ones it had when first read, and the walk keeps in memory the entries of
  every directory between the root and the entry it visits.
- Cost: a return to a directory at depth d is d `openat`s and an `fstat`, plus one `fstat` per directory opened.
  A preorder walk reopens a directory only if it has entries left after a subdirectory; a walk with postorder
  visits reopens the parent for each directory's postorder visit, so a chain n deep costs about n²/2 `openat`s
  (fts's `FTS_NOCHDIR` resolves each directory's whole path, which is the same number of lookups, in the kernel).
  Not measured.

Design calls, with the alternatives rejected:
- The way back to a closed directory:
  - Taken: its names from the root, one `openat` per level with `O_NOFOLLOW`, and the identity check.
  - fts's own: the directory's whole path from the root's path. Gives up `O_NOFOLLOW` for every component but the
    last (the Directories README's `swap.c` result: a link swapped in above leads out of the tree), fails at
    `PATH_MAX`, and needs the root's path, which a walk made from a stream may not have.
  - `..` from the subdirectory, checked by device and inode (fts's `chdir` mode, and the README's "rejected for
    now"): one `openat` per return instead of d. But when the check fails the walk needs another way back anyway,
    so it's an optimization on top of the names, not a replacement.
  - One `openat` of the whole relative path that refuses any link: Darwin's `O_NOFOLLOW_ANY`, Linux's `openat2`
    with `RESOLVE_NO_SYMLINKS | RESOLVE_BENEATH`; one call per return, falling back to the chain past `PATH_MAX`.
    The optimization to take first if the cost matters (the identity check stays).
  - A window of the deepest N levels kept open, reopening only beyond it: fewer reopens in ordinary trees, but a
    limit to choose.
  - Reopening lazily, only when `parentDirectory` or an entry needs the descriptor: saves the reopen for a
    postorder visit that uses only the path, but `parentDirectory` would become a `mutating get` that can't report
    a failure.
  - No identity check: `parentDirectory` could then be a directory renamed over the one read, and a call relative
    to it (such as `rm -r`'s `unlinkat`) would act on another directory's files of the same names.
- The API: an `Options` option set, `options:`, which item 3's options join. Rejected: another enum parameter per
  feature, like `opening:` (they're on or off, and three more parameters); a Bool (rejected for `opening:` too); a
  `DirectoryOpening` case (when a directory is opened and how many stay open are independent: the option works
  with both openings and all three orders).
- A read error part way through a directory is kept and thrown after the entries read before it, where a walk
  without the option would have thrown it: the same visits and the same throw.

Tests (DirectoryWalkBoundedTests.swift, swift-testing): `visitsTheSame` (every order, both openings, with and
without skipping: the same visits in the same order as a walk without the option, and every entry in its
`parentDirectory`), `anUnreadableDirectory` (the same, with a directory that can't be opened), `aDirectoryMovedAwayIsLeft`
(a directory moved and replaced while the walk is in its subdirectory: ENOENT once, no postorder visits for it or the
subdirectory, the rest of the tree visited; without the option, no error), `aDirectoryReplacedByALinkIsNotFollowedBack`
(ENOTDIR or ELOOP, nothing outside visited), and the exit test `aWalkWithBoundedDescriptorsGoesDeeperThanTheLimit`
(macOS: with exactly five descriptors free, the walk goes 100 deep without an error, and without the option one
directory fails and it stops).

Findings: Prototype/Directories/README.md's "Descriptors" paragraph ("Rejected for now: reopening ancestors through
`..`") predates the option; it's not this lane's file, so it's left as it is.

Next: item 3. For Foundation: pass `options: .boundedDescriptors` in `_LinkOrCopyWalk` and `_subpathsOfDirectory`,
and drop the EMFILE notes.

## 3. DirectoryWalk visiting the root, and giving each entry's status: `ae2bc09`

What: two more `DirectoryWalk.Options`.
- `.includesRoot`: the walk visits the root itself where its order puts any directory's visits: first, last, or
  both (fts's level-0 `FTS_D` and `FTS_DP`). The root's entry has depth 0, the name `.`, the root's path as its
  `path` (empty for a walk made from a stream without one), and type `.directory`. During its visits
  `parentDirectory` is the root itself. `skipDescendants()` after its first visit ends the walk, skipping its
  second visit too, as for any directory.
- `.includesStatus`: each entry gets `Entry.status: Stat?`, the `fstatat(parent, name, AT_SYMLINK_NOFOLLOW)` taken
  when the walk reads the entry, or `Entry.statusError: Errno?` when that fails (fts's `FTS_NS`), and the entry's
  type comes from the status. A directory's postorder visit has the status from its first (as fts's `FTS_DP` has),
  and the root's is its descriptor's `fstat`. The one `fstatat` replaces the one a walk makes for an entry whose
  directory records no type. With the two, Foundation's `_LinkOrCopyWalk` no longer needs its own root visits or its
  `fstatat` per entry (its third SYSTEM-GAP marker); it still `lstat`s the root first for a root that isn't a
  directory, or is a link, which fts visited as the only item.

Design calls, with the alternatives rejected:
- The root's name is `.`, with `parentDirectory` the root, so a call relative to `parentDirectory` with the entry's
  name reaches the root (`fstatat` gives its status, and removing it fails with EINVAL). Rejected: the root's last
  path component, which with the root as `parentDirectory` would name a file inside the root (walking `x`, where
  `x/x` exists, an `unlinkat(parentDirectory, name)` would remove `x/x`), and which `/` and an empty path don't have;
  an optional `name`, which changes every caller; the root's parent as `parentDirectory`, which the walk doesn't
  have, and which `..` gets wrong when the root's path is a link.
- The root's entry is the directory the walk opened, which is the link's target if the root's path is a symbolic
  link; fts with `FTS_PHYSICAL` visits the link itself. Documented on the option; rejected: an `lstat` of the root's
  path, which a walk made from a stream doesn't have.
- The status is two properties, `status` and `statusError`, like `error`. Rejected: `Result<Stat, Errno>?`, which no
  public property in System uses; reusing `error`, which for a directory already holds the error from opening it
  (a directory in a directory that can be read but not searched fails both).
- When the status fails, `type` is the directory's `d_type`, and `error` is set only if that's unknown too, so the
  documented rule stays: the type is `nil` only if it couldn't be found, and then `error` says why.
- Both options are members of section 2's `Options`; the root's visits are a small state machine (`_RootVisits`) in
  front of either way of reading, and the root stays open for its last visit, which the next call closes.

Tests (DirectoryWalkRootAndStatusTests.swift, swift-testing): `theRootIsVisitedInEachOrder` (every order, both
openings, with and without `.boundedDescriptors`: the root's visits around the same visits as without the option,
its entry's fields, and `.` through `parentDirectory` reaching the root), `skippingTheRootsContentsEndsTheWalk`,
`eachEntrysStatus` (every order and opening, with and without `.boundedDescriptors`: each status is the entry's own
`lstat`, the type agrees, a link's is the link's, a directory's two visits share one, and none without the option),
and `entriesWhoseStatusCantBeRead` (a directory with only read permission: its entries have `statusError`
EACCES and the type their directory records, and its subdirectory also fails to open).

Next: item 4. For Foundation: `_LinkOrCopyWalk` can take `options: [.boundedDescriptors, .includesRoot,
.includesStatus]` with `opening: .whenEntered`, keeping its `lstat` of the root, its `PATH_MAX` check and its "._"
filter.

## 4. The number of loaded images

What: `DynamicLibrary.loadedImageCount`, Darwin only: the number of images the dynamic loader has loaded (the
program, and every library and bundle, asked for or depended on), as `_dyld_image_count` returns it. It's for
AttributeScope's cache in Foundation's framework build: a count different from the last one means images have loaded
or unloaded since, so a scope it didn't find may be there now (its SYSTEM-GAP marker). The doc says the converse
doesn't hold (a load and an unload leave the count the same) and that another thread can change it at any time.

Design calls, with the alternatives rejected:
- A static property of `DynamicLibrary`, beside the loader-wide `mainProgram(options:)`, `takePendingError()` and
  `symbolInfo(containing:)`, returning `Int`. Rejected: a new top-level type for the loaded images (a collection
  with each image's name, header and slide, `_dyld_get_image_name`, `_dyld_get_image_header`,
  `_dyld_get_image_vmaddr_slide`): more than was asked, and those calls race with other threads by index, which
  `dladdr` (already `symbolInfo(containing:)`) doesn't; a `UInt32` result, the C type.
- Not added, as asked: a callback for each image that loads (`_dyld_register_func_for_add_image`). It's the exact
  answer to "was a scope loaded since", but a registration can't be undone, dyld calls it at once for every image
  already loaded and then for each new one while holding its lock, and it takes a C function pointer with no
  context, so a Swift wrapper needs a global registry of closures. `_dyld_register_func_for_remove_image` is the
  same.
- No mock hook: `_dyld_image_count` can't fail, like `_NSGetExecutablePath`'s wrapper in
  `Syscalls+Executable.swift`, whose pattern the new `Internals/Syscalls+LoadedImages.swift` follows
  (`import MachO.dyld`, Darwin only). The API is in the new `DynamicLoading/LoadedImages.swift`; both are in
  Sources/System/CMakeLists.txt, as a block of their own after DynamicLoading's (an insert only). No throws and no
  `retryOnInterrupt`: it neither fails nor blocks.

Tests (LoadedImagesTests.swift, swift-testing, Darwin): `theProgramAndItsLibraries` (at least two), and the exit
test `loadingALibraryAddsToTheCount` (in a process of its own, where nothing else loads or unloads: loading the first
of three system libraries that `.noLoad` shows isn't loaded yet raises the count).

## 5. For others

- swift-foundation (`no-darwin`): `_LinkOrCopyWalk` can take `opening: .whenEntered` and `options:
  [.boundedDescriptors, .includesRoot, .includesStatus]`, keeping its `lstat` of the root, its `PATH_MAX` check and
  its "._" filter, and `_subpathsOfDirectory` `.boundedDescriptors`; that removes their SYSTEM-GAP markers for the
  descriptor limit, the root's visits and the per-entry `fstatat`. AttributeScope's can use
  `DynamicLibrary.loadedImageCount`, once System ships in the SDK with it. `Errno.notCapable` closes the SYSTEM-GAP
  at `POSIXError.Code`.
- The demos lane: Samples/Beneath.swift can drop its `Errno(rawValue: ENOTCAPABLE)` for `.notCapable`.
- The Directories README (Prototype/Directories/README.md): its "Descriptors" paragraph and "The root isn't
  visited" decision predate `.boundedDescriptors` and `.includesRoot`.
- Not done, noted: the one-call reopen (`O_NOFOLLOW_ANY`, `openat2`) and a measurement of the option's cost
  (section 2); `_dyld_register_func_for_add_image` (section 4). Linux is unbuilt here: the walk's new code uses only
  calls it already made on every Unix-like platform (`openat`, `fdopendir`, `readdir`, `fstat`, `fstatat`, `close`),
  and the loaded-image count is Darwin only.
