# posix-more: milestone reports

One section per cluster, appended as each is committed. The design calls,
with the alternatives they rejected, are in `README.md` beside this file;
these reports summarize them.

**To resume:** read this file's last section for what's next. The lane's
rules: new API is `System 199`; new files only, except the shared ones
(`Sources/System/CMakeLists.txt`, CSystem's headers and `shims.c`,
`Sources/Samples/main.swift`), edited in sorted position; grep every new
name first; after each cluster, `swift build && swift test`, check for
duplicate declarations, commit, and append a report here. Not this lane's:
sockets, processes, signals, statfs, and the syscalls-4 lane's exit/atexit,
openpty, socket options, sendfile, sendmmsg, vsock and Linux-only calls.

## Milestone 1: clusters 1–4 and public errno (reported 2026-09-27, merged into system-next)

| Cluster | Commit | API |
|---|---|---|
| 1. Vectored I/O | `6d65616`, `428384a` | `FileDescriptor.write(vectors:)`, `read(intoVectors:)` and offset forms (`writev`, `readv`, `pwritev`, `preadv`); span forms `write(_:_:)`, `write(_:_:_:)`, `writeAll(_:_:)`, `writeAll(_:_:_:)`, `read(into:_:)`, `read(into:_:_:)` with offset forms; `CInterop.IOVec` |
| 2. Environment | `f93d88c` | `ProcessEnvironment.value(of:)`, `set(_:to:overwrite:)`, `remove(_:)`, `entries()`, `withUnsafeEntries(_:)` |
| 3. Time | `5288455` | `ClockID` and its clocks, `currentTime()`, `resolution()`; `PThread.sleep(for:retryOnInterrupt:)` |
| errno (prototype, item 46 open) | `3ccc4dd` | public `Errno.current { get set }`; `Errno.check(retryOnInterrupt:_:)` for -1 and `nil` results; `Errno.checkOptional(retryOnInterrupt:_:)` |
| 4. System identity | `6cf12cf` | `SystemIdentity` (`uname`), `hostName()`, `loginName()` |

Tests then: 309 XCTests (4 skipped) and 232 swift-testing tests in 30
suites, all passing.

## 5. Paths and files: `07871cd`, and `0de59c4` after the merge

API:
- `FilePath.canonicalized()` (`realpath`) and `remove(retryOnInterrupt:)` (`remove`), with C-string forms.
- `FilePath.makeUniqueFile(options:retryOnInterrupt:) -> (path:, descriptor:)` (`mkostemp`) and `makeUniqueDirectory(retryOnInterrupt:)` (`mkdtemp`), with C-string forms that rewrite the template.
- `FilePath.temporaryDirectory()`: `TMPDIR` unless set-user-ID, then Darwin's per-user directory, then `/data/local/tmp` or `/tmp`.
- `FilePermissions.setCreationMask(_:) -> FilePermissions` (`umask`).
- `FileDescriptor.currentWorkingDirectory` (`AT_FDCWD`).

Design calls:
- **Templates must end in six X's on every platform.** Darwin accepted
  `report-XX`, and made a directory named `scratch` from a template
  without X's; glibc and POSIX reject both. A retry after `EINTR` starts
  from the original template.
- **`mkostemp`, not `mkstemp`**, so `.closeOnExec` is atomic. It goes
  through a CSystem shim on Linux, where glibc declares it only with
  `_GNU_SOURCE` and Bionic only from API level 23.
- **`TMPDIR` is ignored in a set-user-ID program**, through `issetugid` or
  a `getauxval(AT_SECURE)` shim.
- **Since the merge, Darwin's lookup is darwin-more's
  `SystemConfig.string(.userTemporaryDirectory)`.**
- **`setCreationMask` has umask's exact shape, and there's no getter**,
  because C has none. The internal `creationMask` in `FileOperations.swift`
  stays as it was; Foundation still needs a race-free read.

Adopters: NIO's `remove`, `AT_FDCWD` and NIOFS `temporaryDirectory`;
SwiftPM's `mkdtemp`; Foundation's `mkstemp` (still blocked on the umask)
and `NSTemporaryDirectory`.

Unverified off Darwin: the two Linux shims; Linux's `remove` error for a
directory that isn't empty.

Tests after it: 313 XCTests and 238 swift-testing tests in 31 suites.

## 6. Dynamic loading: `88f91a0`

API: `DynamicLibrary: ~Copyable`, with:
- `init(_:options:)` (`dlopen`) and `mainProgram(options:)` (`dlopen(NULL)`);
- `address(of:) -> UnsafeMutableRawPointer?` (`dlsym`);
- `close()`, `deinit`, `relinquish()`, `init(taking:)` and `handle` (`dlclose`);
- `LoaderError` with `dlerror`'s message;
- `OpenOptions`: `.lazy`, `.now`, `.global`, `.local`, `.noLoad`, `.noDelete`, and `.first` on Darwin.

Design calls:
- **`OwnedFD`'s pattern.** The deinit drops `dlclose`'s error, which
  follows `OwnedFD`'s current default without deciding item 54.
- **Errors aren't `Errno`,** since the dynamic linker doesn't set it, and
  so the wrappers have no mock hooks.
- **A missing symbol is `nil`.**
- **The default options are `[.now, .local]` everywhere.** Darwin defaults
  to global and Linux to local.

Adopters: NIO's lookup of `swift_task_enqueueGlobal_hook`; SwiftPM's
`PackagePlugin` `LibraryHandle` and test-bundle loading; Foundation's
`AttributeScope`.

Unverified off Darwin: `RTLD_NOLOAD` and `RTLD_NODELETE` on FreeBSD and
Bionic; OpenBSD's lack of them.

Tests after it: 313 XCTests and 243 swift-testing tests in 32 suites.

## 7. Memory mapping: `c7b5989`

API: `MemoryMapping: ~Copyable`, with:
- `init(byteCount:protection:options:)` (anonymous) and `init(file:offset:byteCount:protection:options:)`;
- `bytes: RawSpan` and `mutableBytes: MutableRawSpan`;
- `setProtection` (`mprotect`), `synchronize` (`msync`), `advise` (`madvise`) and `residentPages()` (`mincore`);
- `unmap()`, `deinit`, `relinquish()`, `init(unsafeTaking:byteCount:)` and `unsafeBuffer`;
- `Protection`, `Options` and `Advice`.

Design calls:
- **Hazards are documented, not typed away:** another process changing a
  shared mapping, `SIGBUS` past a truncated file's end, and writes to
  memory whose protection forbids them.
- **No `MAP_FIXED`.**
- **Adopting a region is `unsafeTaking:`,** since unmapping the wrong
  memory is undefined behavior.
- **Platform differences stay documented:** `.doNotNeed` discards pages on
  Linux and is a hint elsewhere. Linux rejects advice that starts inside a
  page, and Darwin rounds the start down, which a test found.
- **Swift 6.2 limit, found by the sample:** a `let` owner can't be
  consumed after a span has borrowed it, even once the span is gone. The
  `mmap` sample reads its span in a `borrowing` helper.

Adopters: Foundation's mapped `Data`. The `extents` sample, which belongs
to the demos lane, could use it.

Unverified off Darwin: Bionic's non-optional `mmap` result; Linux's
`unsigned char` `mincore` vector.

Tests after it: 315 XCTests and 249 swift-testing tests in 33 suites.

## Merge of system-next: `f620a84`

Brought in the processes, linux-build, coverage, api-graph, darwin-more and
statfs lanes. The conflicts were additions side by side in the shared
files:
- `CSystemLinux.h` and `shims.c`: this lane's Linux shims beside the
  processes lane's;
- `main.swift`: the samples' groups;
- `CMakeLists.txt`: its Internals lines and directory blocks, kept in
  sorted order.

The processes lane now uses this lane's `csystem_environ`. The Threads and
Events copies of `_CLOCK_REALTIME` and `_CLOCK_MONOTONIC`, which collided
on Linux, are gone: linux-build removed the Events ones. The duplicate
check finds only complementary `#if` branches. The ABI-stable and
explicit-availability builds show only the known failures.

Tests after it: 428 XCTests (4 skipped) and 282 swift-testing tests in 37
suites, all passing.

## 8. Network interfaces: `53617e1`

API: the `NetworkInterface` namespace, with:
- `Addresses: ~Copyable`, the owned `getifaddrs` list, with `count` and `forEach(_:)`;
- `Addresses.Entry: ~Escapable`, with `name`, `flags`, `addressFamily` and `unsafeNode`, plus `address`, `netmask`, `broadcastAddress` and `destinationAddress` as `RawSpan?`;
- `Flags` (`IFF_*`);
- `Index`, with `init?(name:) throws(Errno)` (`if_nametoindex`) and `name() throws(Errno)` (`if_indextoname`).

Design calls:
- **Entries can't outlive the list, and neither can their address spans.**
  A compiler check, `Verify/P1_entry_escape.swift`, confirms it.
  Iteration is `forEach`, since a `~Escapable` value can't be an element.
- **Addresses are sockaddr bytes,** because SystemPackage can't name
  `SocketAddress`. The `ifconfig` sample converts them with
  `SocketAddress(_:)`.
- **A sockaddr's length** is `sa_len` on Darwin and the BSDs, and the
  family's size on Linux.
- **A missing interface is `nil`, and other failures throw.** glibc's
  `if_nametoindex` can fail with `EMFILE`.
- **Swift 6.2:** `Optional.map` doesn't take a span, so optional spans are
  unwrapped with `if let`.

Adopters: NIO's `enumerateDevices` and `NIONetworkDevice` (48 lines).

Unverified off Darwin: the Android `getifaddrs` shims (API level 24);
glibc's `IFF_*`, which Swift imports as `Int`; the Linux address lengths.

Tests after it: 430 XCTests (4 skipped) and 285 swift-testing tests in 38
suites, all passing. The duplicate check finds nothing new, and the
availability builds show only the known failures.

## 9. Extended attributes: `e17daad`

API:
- On `FilePath` (with `followTargetSymlink:`), on `FileDescriptor`, and as `FilePath` statics over C strings: `extendedAttributeNames()`, `extendedAttribute(_:) -> [UInt8]?`, `setExtendedAttribute(_:to:options:)` and `removeExtendedAttribute(_:)`.
- `ExtendedAttributeOptions` (`.create`, `.replace`).
- `Errno.attributeNotFound`, now also on Linux and Android, as `ENODATA`.

Design calls:
- **One set of signatures over two.** Darwin's `position` is always 0, and
  `XATTR_NOFOLLOW` versus Linux's `l` calls is `followTargetSymlink:`, as
  `stat` names it.
- **A missing attribute reads as `nil`,** where Darwin reports `ENOATTR`
  and Linux `ENODATA`.
- **`Errno.attributeNotFound` works on both** for the calls that throw it:
  on Linux it's `ENODATA`, which libattr also names `ENOATTR`.
- **Values are read in two calls,** the size and then the value, and again
  after an `ERANGE`. Setting takes any `Sequence<UInt8>`.
- **`CSystemLinux.h` includes `<sys/xattr.h>`,** which Glibc's module
  lacks. It declares no types.
- **FreeBSD's and OpenBSD's `extattr_*` calls aren't wrapped.**

Adopters: NIOFS's `FileHandle` attribute methods (22 lines); Foundation's
`FileManager` extended attributes.

Unverified off Darwin: every Linux branch, and user attributes on CI's file
systems (the tests skip on `ENOTSUP`).

Tests after it: 433 XCTests (4 skipped) and 290 swift-testing tests in 39
suites, all passing. The duplicate check finds only `_XATTR_CREATE` and
`_XATTR_REPLACE`, which are complementary Darwin and Linux branches. The
availability builds show only the known failures.

## 10. Random bytes: `5fb9a17`, and `8d60190`, the ifaddrs probe

API: `Entropy.fill(_:)`, over an `UnsafeMutableRawBufferPointer` or an
`inout MutableRawSpan`, and `Entropy.bytes(count:) -> [UInt8]`, which wrap
`getentropy`.

Design calls:
- **Any size, in 256-byte calls,** the most one `getentropy` call fills.
- **`getentropy`, not `getrandom` or `arc4random_buf`:** Darwin lacks
  `getrandom`, and `arc4random_buf` can't report a failure.
- **It throws,** where `SystemRandomNumberGenerator` traps.
- **`CSystemDarwin.h` includes `<sys/random.h>`,** which the Darwin module
  doesn't export.
- **Bionic below API level 28** gets `ENOSYS` from a shim.

Adopters: none; NIO and Foundation use `SystemRandomNumberGenerator`.

Unverified off Darwin: the Linux, BSD and Android declarations.

Tests after it: 434 XCTests (4 skipped) and 293 swift-testing tests in 40
suites, all passing. The duplicate check finds nothing new, and the
availability builds show only the known failures. A MemberImportVisibility
probe now covers `struct ifaddrs`, which `Entry.unsafeNode` vends.

## The lane is done

All ten clusters and the errno prototype are committed, on `posix-more`
after the merge of system-next at `f620a84`. system-next hadn't moved
since, at the last check.

Still open, for you to decide:
- **Public errno, item 46.** The prototype is `3ccc4dd`; its alternatives
  are in README.md.
- **Deinits that drop errors.** `DynamicLibrary` and `MemoryMapping`
  follow `OwnedFD`'s current default, so item 54's answer should cover
  them too.
- **The umask.** A race-free read is still missing. Foundation needs it;
  the options are making `FileOperations.swift`'s internal `creationMask`
  public, or reading Linux's `/proc/self/status`.
- **Span floors.** All of this lane's Span API carries the existing macOS 15
  floor, so a `SystemWithSpan` macro should replace them all at once.

For other lanes:
- **Coverage lane:** `mapping.ini` entries can now cite this lane's API
  for writev, getenv/setenv/unsetenv, the environment block, clock_gettime,
  usleep, gettimeofday, uname and gethostname, errno, remove, AT_FDCWD, the
  temporary directory, mkdtemp, dlopen/dlsym, getifaddrs, if_nametoindex,
  and the extended attributes.
- **Demos lane:** the `extents` sample's `mmap` and `mincore` could use
  `MemoryMapping`.
- **SystemSockets fold-in:** delete SystemSockets' `CInterop.IOVec`, and
  give `NetworkInterface.Addresses.Entry` `SocketAddress` properties.
- **Upstream Swift:** two 6.2 limits are recorded in Verify/P2 and in
  README.md. A `let` owner can't be consumed after a span has borrowed it,
  and `Optional.map` doesn't take a span.

Unverified off Darwin, in general: nothing here compiles for Linux,
Android, the BSDs, WASI or Windows. The riskiest pieces:
- the Android API-level shims (`preadv`/`pwritev` 24, `getifaddrs` 24,
  `mkostemp` 23, `getentropy` 28);
- the Linux `mkostemp` and `AT_SECURE` shims;
- the glibc-only spellings: `<sys/xattr.h>` through CSystem,
  `ifa_ifu.ifu_dstaddr`, and `IFF_*` imported as `Int`;
- the Linux clock and `XATTR_*` values, which are hard-coded kernel values;
- the `environ` shim.
