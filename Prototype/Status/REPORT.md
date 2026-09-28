# The coverage lane: status and gaps

The `coverage` worktree keeps the project's figures current (`Utilities/adopter-coverage/status.sh`, which
writes `STATUS.md` here) and adds the System API that adopters still mark as missing. Each section records
one step: what was done, the design calls with the alternative each rejected, and the checks. Linux is paused:
everything here is built and tested on Darwin only.

## 1. status.sh and STATUS.md (2026-09-28)

`Utilities/adopter-coverage/status.sh` regenerates `STATUS.md` from commits: api-delta's Summary and *By
area* table (main → HEAD), a row per adopter in `../adopters` on `migrate-darwin` against its merge base with
`main`, and every `SYSTEM-GAP:` marker by interface, ranked and marked missing, covered, or not System's. The
logic is `scripts/status.py`; its METHOD text is also STATUS.md's last section. A run takes about 10 s when
api-delta's last run is current and about 80 s when System's sources changed; a package commit whose
manifest hasn't been seen adds a few seconds.

Design calls:
- **Reuse over new extraction.** API figures are api-delta's own report, copied; `#if` evaluation is
  adopter-coverage's `platforms.py`, comments and strings are blanked by api-delta's scanner, and the SDK
  vocabulary check.sh stored places names in C-library modules. Rejected: check.sh's compiler-backed Darwin
  metric, which needs a build of every package commit and knows only its four audited packages.
- **Package targets from the manifest.** `swift package dump-package` on the manifests at each commit, cached
  by their blob ids, with SwiftPM's default target paths. Swift 6.2 can't type-check swift-foundation's
  manifest in reasonable time, so installed toolchains are tried after the default one (the 2026-09-21
  snapshot evaluates it). Rejected: counting every tracked file (nested packages, Benchmarks, integration
  scaffolding), or only `Sources/` and `Tests/` (kept as the fallback when no toolchain evaluates the manifest).
- **Four import columns, not two.** `import Darwin.POSIX.sys.stat` is neither whole-module nor scoped, and
  NIO's report counts it as not whole-module, so submodule imports get their own column; a file is counted
  once, by its broadest import. Framework-only imports (`#if FOUNDATION_FRAMEWORK`) are counted separately.
- **Markers are read for the interfaces they name.** A marker's head (before its first sentence end, or a
  colon not followed by a list) is split into items; an item names itself, the list after a phrase (`libm
  (sin, cos)`), `X members` for MemberImportVisibility struct gaps, and so on (METHOD has the rules). A marker
  that names nothing is counted under its phrase, and the scoped imports under it decide its status; with
  none, it's *unread* (one now). Rejected: an SDK vocabulary alone (the explanations are English, and `time`,
  `free`, `sleep`, `remove` are C functions), and the imports alone (`import struct Darwin.msghdr` is there
  for msghdr's fields, which CInterop's alias doesn't give).
- **Covered is what System documents.** A doc comment's *The corresponding C … is* names, public typealias
  targets, and `extension CInterop.<alias>` for struct members, at HEAD and at `system-next` (the table says
  when only this branch has an interface). A short table of replacements (usleep and sleep by nanosleep,
  localtime by localtime_r, mkstemp by mkostemp, time by clock_gettime) counts the obsolescent forms as covered.
  Rejected: mapping.ini's entries, which group symbols by concept but don't say usleep is nanosleep's.
- **Not System's**, fixed in `status.py` with reasons: libm, C stdio, locale and xlocale, string.h and ctype.h
  (memcpy, memmove, memset are the standard library's copyMemory and initializeMemory; memcmp and memchr are
  System's Memory, as the malloc lane decided), numeric conversion, and the Darwin overlay's POSIXErrorCode.
- **Copies are verbatim and few.** Only the test totals (the start and latest lines, with a table's header)
  and the re-export counts are copied from MIGRATION.md or REPORT.md, quoted with line numbers; a report whose
  lines don't match the patterns shows —.

First run, at `ebc1231` with 10 adopters: 142 markers in 96 files, 175 interfaces: 85 covered (the markers
predate the lanes that merged since), 23 not System's, 66 missing, 1 unread. The missing ones by family,
largest first: compile-time limits (5 files), fts (3), XATTR_MAXNAMELEN, UTIME_OMIT, posix_spawn's raw
attributes and file actions, tzfile.h (2 each), then one-file gaps (malloc_type_*, time_t, dlerror,
mkstemps, nfds_t, O_SEARCH, removefile, timeval, EX_USAGE, mktemp, AF_VSOCK).

Limits: name matching can't see an API whose doc comments don't name the C interface (System's `nil` file
time is UTIME_OMIT, undocumented), and counts a partial wrapper as covered (`linger` is named by
`SocketDescriptor.linger()`, but NIO's public API needs the C type).

## 2. CInterop.TimeVal and CInterop.Linger: `0e1defa`

NIO's SocketOptionProvider takes and returns C `timeval` and `linger` values in its public API, so it keeps
Darwin imports until System names them and makes them usable without the C library.

- `CInterop.TimeVal` (SystemPackage, next to TimeSpec) copies TimeSpec's shape: `init(seconds:microseconds:)`
  with zero defaults (the zero value too), `seconds`, `microseconds`, and from macOS 13 `init(duration:)` and
  `duration`, normalized and rounded down to a microsecond. Rejected: rounding up, as the socket timeouts and
  ProcessTimer do internally so that a positive time never becomes C's "none"; the general conversion
  matches TimeSpec's, and its doc points out the zero case.
- `CInterop.Linger` (SystemSockets) has `init(isEnabled:time:)`, `isEnabled` and `time`. Rejected names:
  `seconds` (Darwin's `SO_LINGER` counts clock ticks; only `SO_LINGER_SEC` is seconds) and `timeout` (reads
  as a Duration, and as a failure). SocketDescriptor's `linger()` now uses the alias; the internal `_CLinger`
  it replaced is gone.

Tests: accessors against the C fields, the duration conversions, a `CInterop.Linger` through
`setOption`/`getOption` on a TCP socket agreeing with `linger()`, and both in the MemberImportVisibility
probe. XCTest 471 (4 skipped), swift-testing 437 in 65 suites, all passing.

## 3. Compile-time limits and O_SEARCH: `040169c`

Foundation's gaps with the most files (5): NAME_MAX, PATH_MAX and MAXSYMLINKS as compile-time constants, for
buffers sized before there's a path to ask `pathconf` about; and O_SEARCH for directory descriptors.

- `SystemConfig.maxFileNameBytes`, `maxPathBytes`, and on Darwin `maxSymbolicLinks`, as `Int`s. They reuse the
  names of the `pathconf` names in `SystemConfig.PathName`, so `value(.maxFileNameBytes, for: dir)` is the
  directory's limit and `SystemConfig.maxFileNameBytes` the headers'. Rejected: `FilePath` members (a path
  can be longer; calls fail with ENAMETOOLONG) and a new namespace. `maxSymbolicLinks` is Darwin-only:
  glibc's MAXSYMLINKS (20) isn't the Linux kernel's limit (40).
- `FileDescriptor.AccessMode.search` and `.execute`, Darwin-only, with the renamed `O_SEARCH`/`O_EXEC` stubs.
  Darwin's O_EXEC is outside O_ACCMODE's bits and F_GETFL reports it for both modes, so Darwin's internal
  access-mode mask now includes it: `accessMode()` returns `.execute` for either (it said `.readOnly`), and
  `statusFlags()` drops the stray bit. Rejected: leaving the mask alone, which misreports every such
  descriptor; a separate `.search` from `accessMode()`, which F_GETFL can't tell apart.

Found on macOS 26.3: O_SEARCH opens only directories (ENOTDIR); its descriptor reads fail (EBADF) but
`openat`, `fchdir` and `fstat` work; O_EXEC needs execute permission (EACCES); a path resolves through 32
links and fails on the 33rd, counting links in the path itself (the temporary directory's `/var`), so the test
opens its chains relative to a directory descriptor.

Tests: CompileTimeLimitsTest, SearchAccessModeTest. XCTest 478 (4 skipped), swift-testing 437, all passing.
