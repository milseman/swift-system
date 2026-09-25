# A multi-platform enum over each platform's own types

A prototype, not API, of `Next/Vision.md`'s direction 4: an open enum
with a case for each platform's representation of a kind of kernel object.
It hosts the operations the platforms share and needs a `switch` for
anything else. The code is in `Sources/Samples/Platforms`, run as
`system-samples platform <sample>`. The compiler checks are
`Prototype/Verify/V16*`, run with Swift 6.2 (swiftlang-6.2.0.19.9).

**In brief.** The enum is worth having for kinds where one platform has
more than one representation, which here means processes. It isn't worth
having for files, directories, or sockets, where each platform has one.
Swift has no "if this case exists" test: a case exists only in its
platform's build. So every platform-specific switch wraps each arm in
`#if` anyway (V16d, V16e), and the switch is added on top of the `#if`,
not in place of it. It also moves the pressure to escape where the
Vision's constraint warned it would. After a few switches, a Unix user
writes a helper that traps on any other case. A Windows user under the
drafts' noncopyable handle writes one that returns `unsafeRawHandle`,
because nothing else can leave the enum. Windows' owned-only model doesn't
carry over to Unix, where it would cost about 145 members and demote
FileDescriptor to an escape hatch, for more symmetric switch arms. Details
and confidence are under Recommendation.

## Building and running

One source, two configurations:

- **Real**, the default build. Each enum has only this platform's cases. On
  this Mac, every file is `.fd` and every process is `.id`, and each switch
  compiles as a Darwin build would.
- **Simulated**, built with `-Xswiftc -DSIMULATE_PLATFORMS` into a separate
  scratch path. Every platform's cases exist on every platform:
  - Windows' cases wrap stand-ins for the Win32 drafts, simulated over POSIX
    calls.
  - Linux's pidfd case wraps a stand-in `ProcessDescriptor`.
  - `--as windows` or `--as linux` makes a sample's factories produce those
    cases, so the other platforms' arms run too. `--as linux` changes only
    which cases are produced: an `.fd` arm still runs Darwin's code, since
    the build is Darwin's.

How to read the conditions:
- `#if os(Windows) || SIMULATE_PLATFORMS` is what real code would write as
  `#if os(Windows)`.
- Real code would write the Unix side as that condition's `#else`. Here it's
  a separate `#if !os(Windows)`, since the simulated build compiles both.
- Code under `#if SIMULATE_PLATFORMS` alone exists only to simulate.

```sh
swift build && swift run system-samples platform --help
./Prototype/PlatformEnum/check.sh   # both builds, every sample, as every platform
```

| path | what | compiled in |
|---|---|---|
| `Simulation.swift` | the two configurations and `--as` | both |
| `Enums/` | `Platform.File`, `.Directory`, `.Socket`, `.Process`, `.Error`; `Variants.swift` | both; foreign cases simulated only |
| `Unix/` | `OwnedSocket` (the Sketch's) and `Unix.FileHandle` (variant C): hypothetical Unix API | both |
| `StandIns/Win32.swift`, `Win32FileHandle.swift`, `Win32Bridges.swift` | the drafts, SYS-0010 to SYS-0016 | simulated |
| `StandIns/Win32Hypothetical.swift` | in no draft: standard handles, `ProcessHandle`, `Socket`, `CreatePipe` | simulated |
| `StandIns/Win32Copyable.swift` | the drafts' rejected copyable handle (variant B) | simulated |
| `StandIns/Win32CFunctions.swift` | C functions that no draft wraps | simulated |
| `StandIns/LinuxProcessDescriptor.swift` | the Sketch's pidfd owner, over a kqueue | simulated |
| `StandIns/Win32Simulation.swift` | the machinery (list below) | simulated |
| `Samples/` | the samples | both; `windows-only` simulated only |

The simulation reproduces the Windows behavior the samples depend on:
- share modes and sharing violations
- mandatory byte-range locks, within this process
- positional I/O that moves the file pointer
- seeks on pipes that succeed
- no SIGPIPE, and ERROR_NO_DATA from a write to a closed pipe
- process waits that don't reap: a kqueue with `NOTE_EXITSTATUS` watches
  the process, and the exit code stays readable

Everything else is Darwin's.

## The design, and what was rejected

- **One enum per kind, one case per representation.** The four enums are
  File, Directory, Socket, and Process, and each case wraps the platform's
  owner.
  - Rejected: one enum across kinds, like the Sketch's `OwnedDescriptor` with
    `.file` and `.socket`. It mixes kind with platform.
  - Rejected: one enum for files and directories. Windows gives directories a
    separate type to remove a runtime failure, and a merged enum would bring
    the failure back.
- **Cases under `#if`,** so each build has only its platform's cases.
  - Rejected: every platform's cases everywhere, with the foreign payloads
    uninhabited. A switch could then omit foreign cases (V16d), but an arm
    that uses a foreign payload still needs `#if`, and every foreign type
    would have to be declared everywhere.
- **No `.fd` case on Windows.** A C runtime descriptor goes through SYS-0011's
  bridges, so the enum's Windows code never goes through UCRT, the approach
  the Vision wants gone. Rejected: `.fd` on Windows, which would make every
  Windows switch handle two representations of a file.
- **Owned only.** There's one enum per kind, lent with `borrowing` parameters.
  - An unowned enum has no Windows case under the drafts' noncopyable handle.
    Its payload must be copyable, and the drafts' only copyable form is a
    bare `HANDLE`. So it's Unix-only on real platforms (variant B has one,
    over the rejected copyable handle).
  - A borrowed, nonescapable enum can't be produced without `Lifetimes`. With
    it, a `let` owner can't be closed after a borrow (V16g). It would also
    need a `BorrowedFD` and a borrowed handle view, which aren't adopted
    (`Prototype/BorrowedFD`) or are blocked (SYS-0011).
- **The common subset.** File has 14 members, Directory 3, Socket 6, and
  Process 5, plus five vocabulary types where the platforms' own don't
  match: `Access`, `Disposition`, `SeekOrigin`, `SocketPair`, and
  `ExitStatus`. Choices the subset had to make:
  - Opening is never inheritable, which is Unix's non-default.
  - Share modes are read, write, and delete.
  - Dispositions are Windows' five.
  - `flush()` means durable: `F_FULLFSYNC` on Darwin, whose `fsync` leaves
    data in the drive's cache, `fsync` on Linux, and FlushFileBuffers on
    Windows. Rejected: `fsync` everywhere.
  - `terminate()` has to choose the exit code Windows reports, 1.
  - Kept out: locking and inheritance (sample 2), permissions and security,
    and stat.
- **`Platform.Error` is the platform's own type:** Errno on Unix, Win32.Error
  on Windows (E4, below). The simulated build, with every platform's cases,
  uses `any Error`.
- **Standard streams are optional statics.** A Windows process can lack them,
  and each is a second immortal owner, because `OwnedFD.standardInput` can't
  be consumed into an enum.
  - Rejected: trapping at first use.
  - Rejected: treating a missing handle as `/dev/null`, as Rust does, which
    fakes a stream.
- **Names.** `Platform.File` and the rest, nested in a namespace like `Mach`
  and `Win32`. Rejected: `AnyFile` (sounds like type erasure), `NativeFile`
  (the payload is the native type; the name went to variant D), and
  `PortableFile` (sounds like emulation).

## The samples, and how they read

**1. `copy`: the common subset only.** No switch, no `#if`. It reads well:

```swift
var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
let read = try source.read(fromAbsoluteOffset: offset, into: &buffer)
try destination.write(buffer.bytes, toAbsoluteOffset: offset)
```

The "same" operations differ, and the file's comments mark each place:
- open: inheritance and share modes
- stdin: can be absent on Windows
- resize: a hole on Unix, zeros on Windows
- read: Ctrl+C on a Windows console throws
- write to a closed pipe: SIGPIPE on Unix, `noData` on Windows
- flush and close: see the list above
- positional I/O: the output shows this one. After the positional copy,
  both positions are 0 as `.fd` and 100000 as `.handle`, since Windows moves
  the file pointer. OwnedCopy's `copyRange` documents the Unix behavior as
  if it held everywhere.

Judgment: good, as long as the documentation of each operation does the
work the types can't.

**2. `lock`: one platform-specific operation.** Two kinds of switch:

```swift
switch file {
#if !os(Windows)
case .fd(let owner):
  try owner.fileDescriptor.setDescriptorFlags(.closeOnExec)
#endif
#if os(Windows) || SIMULATE_PLATFORMS
case .handle(let handle):
  try handle.setInheritable(false)
#endif
}
```

- **One concept, two spellings.** The switch costs 7 lines of scaffolding
  for 2 of code, against 3 for a bare `#if`/`#else`. The concept is shared,
  so it could join the common subset.
- **One concept, two shapes.** The lock, sketched:

  ```swift
  // Unix: two calls, and the unlock on every path is the caller's job.
  try owner.fileDescriptor.lock(.write, wait: true)
  do { ... } catch { try? owner.fileDescriptor.unlock(); throw error }
  try owner.fileDescriptor.unlock()
  // Windows: scoped.
  try handle.withLock { try handle.append(bytes) }
  ```

  `appendRecord` writes the critical section twice, once per platform's API.
  `withExclusiveLock(on:_:)` factors it into a closure, and Windows' shape
  wins, since a closure can't become two calls.
- **Different meanings.** With `--contend`, a second open writes during the
  lock. The same code succeeds as `.fd` (advisory) and fails with
  `ERROR_LOCK_VIOLATION` as `.handle` (mandatory).

Judgment: the switch is honest about the shapes, but the body that's
correct under one platform's lock can fail under the other's.

**3. `darwin-only` and `windows-only`: single-platform code.** Neither
mentions `Platform`.
- `darwin-only` uses OwnedFD and FileDescriptor, with `F_NOCACHE`,
  `F_FULLFSYNC`, and `F_GETPATH`.
- `windows-only` uses the drafts' FileHandle: an exclusive share mode and
  the sharing violation it causes, `openOrCreate`'s `existed`, a scoped
  mandatory lock, and volume information.

Judgment: the constraint holds; the enum costs single-platform code
nothing.

**4. `library`: an enum from a library, and a platform-only need.** A mock
library, `TinyJournal`, vends `Platform.File`. The app's first switch sets
`F_NOCACHE`. Even the Unix arm needs an `#if`, since Linux has no
`F_NOCACHE`. The Windows arm can't change the library's handle at all:
Windows chooses caching when a handle is opened, so it has to reopen a
second one. Then come the helpers users write after the second switch:

```swift
extension Platform.File {
  var descriptor: FileDescriptor {        // Unix: a one-case match
    switch self {
    case .fd(let owner): return owner.fileDescriptor
    #if SIMULATE_PLATFORMS
    case .handle: fatalError("\(summary) isn't a file descriptor")
    #endif
    }
  }
  var rawHandle: HANDLE {                 // Windows: the only copyable way out
    switch self {
    case .handle(let handle): return handle.unsafeRawHandle
    ...
```

- The noncopyable handle can't be returned from a property. The correct
  helper takes a closure (`withHandle`). A `_read` accessor works, but it's
  underscored, and SE-0474's `yielding borrow` doesn't parse in 6.2 (V16j).
  The helper that returns a value, like Unix's does, returns
  `unsafeRawHandle`.
- The helpers use their escapes for:
  - `.rawValue`, for a kqueue `EVFILT_VNODE` watch
  - the raw HANDLE, for GetFileInformationByHandle, which no draft wraps
- A consuming switch hands the journal to C's `fdopen`: `relinquish()` on
  Unix, `FileDescriptor(adopting:)` on Windows.

Judgment: this is where the enum hurts. A switch per operation is enough
friction that a user writes a trapping one-case accessor. That's an
unchecked downcast, and against a library-evolution System it also needs
`@unknown default: fatalError()` (V16a). Unix's escape lands on a typed
name; Windows' lands on C's.

**5. `owned`: conversions and switches.**
- The case constructors are the conversions, so `.fd(owner)` and
  `.handle(handle)` need no initializers.
- Borrowing parameters switch freely.
- Standard input needs a switch at both levels, because `if let` and
  `if case` consume a static (V16c).
- Getting a payload out:
  - A failable accessor, `nativeOwner() -> NativeOwner?`, can only return
    the case it matched, so it destroys, and closes, any other. The
    simulated Windows run shows the handle closing on the way to `nil`.
  - A `Narrowing` result, the Sketch's pattern, hands the original back.
- Windows has two owners for one file: the handle, and a C runtime
  descriptor over it. `FileDescriptor(adopting:)` consumes the handle, and
  `withWin32HandleIfAvailable` only lends one back. So owning a handle
  again takes a `duplicate()`, which shares the file pointer, plus closing
  the descriptor.

Judgment: workable, and every step spells out its ownership. But the safe
extraction takes a generic type the enum has to ship.

**6. `process`: two representations per platform.** Linux has `.id` and
`.descriptor`, Windows `.id` and `.handle`. This is the one kind where a
platform's own switch has two arms in a real build.
- The common subset diverges visibly:
  - A second wait fails with ECHILD on Unix, because the first reaped the
    child. On Windows it reports the same code again.
  - `terminate()` gives `.signaled(9)` against `.exited(1)`.
- The platform-specific graceful stop:

  ```swift
  case .id(let id):
    #if os(Windows)
    try Win32.ProcessHandle.open(id, access: .terminate).terminate(exitCode: 3)
    #else
    guard kill(id.rawValue, SIGTERM) == 0 else { throw Errno(rawValue: errno) }  // C
    #endif
  case .descriptor(let descriptor): try descriptor.sendSignal(SIGTERM)  // pidfd_send_signal
  case .handle(let handle): try handle.terminate(exitCode: 3)  // no SIGTERM on Windows
  ```

- `.id`, the case every platform has, still needs `#if` inside its arm,
  because Windows has no `kill`.

Judgment: the best case for the enum. The representation is a runtime
fact on one platform, and the switch makes code handle each one.

**`socket` and `save` (sockets and directories).**
- `socket`'s SIGPIPE suppression has three shapes: a socket option on
  Darwin, a per-call flag on Linux, and nothing on Windows. So the switch
  has an arm with nothing in it but its reason, which documents more than
  an `#if` would.
- `save` makes a rename durable:
  - Unix syncs the directory's descriptor.
  - Windows uses MoveFileExW's `MOVEFILE_WRITE_THROUGH` and ignores the
    directory's handle.

  An operation that needs a directory on one platform and not the other
  doesn't fit an enum of directories. That's why `Platform.Directory`'s
  common subset is only open and close.

**`variants` and `errors`** are covered under Counts and Errors.

## Escape hatches reached for

| escape hatch | where | why |
|---|---|---|
| `owner.fileDescriptor`, OwnedFD's vended name | samples 2, 3, 4; variant A | OwnedFD forwards only byte I/O, so descriptor flags, locks, `stat`, `F_NOCACHE`, and `F_FULLFSYNC` are on the FileDescriptor. It's the full-power type, so this is the design working, not an escape |
| a one-case accessor that traps, `var descriptor` | sample 4 | the user's answer to writing the same switch three times |
| `.rawValue` | sample 4 | C: kqueue registration, `fdopen` |
| `unsafeRawHandle`, and a helper returning it | sample 4; every `summary` | C: an unwrapped Win32 function; and the noncopyable handle can't be returned any other way |
| `relinquish()` | samples 4, 5 | handing ownership to C's stdio, or to a C runtime descriptor |
| `FileDescriptor(adopting:)`, `withWin32HandleIfAvailable` + `duplicate()` | samples 4, 5 | moving between Windows' two owners |
| `reopen(flags: .noBuffering)` | sample 4 | an open-time option lost because a library did the open |
| C calls: `posix_spawn`, `kill`, `waitpid`, `kqueue`, `fdopen`, MoveFileExW, GetFileInformationByHandle | samples 4, 6, `save` | System has no process API, and the drafts don't wrap these |
| `Platform.typed { }` | the enums | FileDescriptor's `resize(to:)` and SocketDescriptor's operations still throw untyped errors |

## Counts

Variant A, the design above: Unix unchanged, Windows as drafted.
- Parenthesized types are shared, or C types with no Swift type.
- Starred types are hypothetical: in neither System nor the drafts.
- No mode has a borrowed type: `borrowing` parameters lend every owner and
  every enum.

| kind | Unix name | Unix owner | Windows name | Windows owner | enum (owned) |
|---|---|---|---|---|---|
| file | FileDescriptor | OwnedFD | (HANDLE) | Win32.FileHandle | Platform.File |
| directory | (FileDescriptor) | (OwnedFD) | (HANDLE) | Win32.DirectoryHandle | Platform.Directory |
| socket | SocketDescriptor | OwnedSocket* | (SOCKET) | Win32.Socket* | Platform.Socket |
| process | ProcessID | ProcessDescriptor* (Linux) | (ProcessID)* | Win32.ProcessHandle* | Platform.Process |

Totals for the four kinds, on both platforms:
- The platform types don't count the value types (option sets, errors)
  that every variant shares.
- Conversions are declared members that convert between types. The enums'
  9 case constructors come free.

| variant | platform types | enums | vocabulary types | conversions | members beyond A |
|---|---|---|---|---|---|
| A: Unix unchanged, Windows noncopyable (drafts) | 10: 3 names, 7 owners | 4 | 5 | 26 | none |
| B: Unix unchanged, Windows copyable | 14: 7 names, 7 owners | 8: 4 owned, 4 unowned | 5 | 42 | Windows' names repeat their owners' operations, which SYS-0011 counts as doubling the surface |
| C: Unix owned-first, Windows noncopyable | 10 | 4 | 5 | 26, with Unix's vends now `@unsafe` | about 145 hosted on Unix owners (Forwarding's count), against 15 forwarded today |
| D: no enum, typealiases (processes still need one) | 10 | 1 | 4 | 26 | the file, directory, and socket subset (23 members) written once per platform, with nothing checking they match |
| `Prototype/Subtypes`, Unix only, six kinds | 8: 3 names, 5 owners | 1 | 0 | about 10 per owned kind | none |

What the counts show:
- The enum layer isn't the Sketch's single enum. It's one per kind, 4 here,
  plus the vocabulary its common subset needs, 5 here. That's 9 types over
  the 10 the platforms already need.
- The full grid, kinds × {name, owner, borrowed} × {Unix, Windows, enum},
  is 36 cells. A needs 14 types for it, and B needs 22. No variant
  has a borrowed type.
- Per platform-specific operation, the enum costs a switch with each arm
  under its platform's `#if`, while D costs a bare `#if`. In the samples,
  a two-platform switch is 7 lines of scaffolding for 2 lines of code.
- Where the enum hosts the subset, the switches are in System:
  `PlatformFile.swift` has 16 switches and 23 platform `#if`s for its 14
  members.

## Errors compared

`platform errors` runs one open refused by another open, and one write to
a pipe whose reader closed, under each design:

| design | use site | busy vs. denied (simulated Windows) | write to a closed pipe (simulated Windows) |
|---|---|---|---|
| E1: untyped, native errors | `case Errno.x`, and under `#if`, `case Win32.Error.x` | told apart | ERROR_NO_DATA, matched |
| E2: `throws(Errno)`, `Errno(approximating:)` | one set of `Errno` patterns, no `#if` | EACCES for both | EINVAL: ERROR_NO_DATA isn't in the C runtime's table |
| E3: an error enum with platform cases | `case .win32(Win32.Error.x)` under `#if`, and a wrap in every arm that calls platform API | told apart | matched |
| E4: the platform's own type, typed | E1's patterns, typed; no conversion in any arm | told apart | matched |

What else the use sites show:
- **Catch sites need `#if`.** Any platform-specific code needs it, and
  `#if` can't wrap catch clauses, even inactive ones (V16e2). So they match
  in a `switch` inside a catch-all.
- **Implicit members are ambiguous on Windows.** SYS-0010's
  `Win32.Error.~=(_, any Error)` and Errno's shipped `~=(_, Error)` make
  every implicit-member pattern ambiguous where both types have the member,
  in a switch as well as a catch.
  - Disfavoring only one operator makes the other type's typed catches
    compile and silently never match. Both need `@_disfavoredOverload`
    (V16f).
  - The shared names are `fileExists`, `fileTooLarge`, `notSupported`,
    `brokenPipe`, and `noData`: 5 of Errno's 222 names and the drafts' 34.
- **Two of the shared names are false friends.** Errno's `brokenPipe`
  (EPIPE) is a write with no reader. Win32's (ERROR_BROKEN_PIPE) is a pipe
  whose writer went away, and Windows reports the write as `noData`. So
  `catch Platform.Error.brokenPipe` compiles on both platforms and, as the
  sample shows, misses on Windows.
- **E1's hazard.** Errno exists on Windows too, so an Errno pattern
  compiles there and never matches.

**Recommendation: E4**, with confidence medium-high.
- It's lossless, unlike E2, which fails both scenarios.
- It needs no wrapping in switch arms, unlike E3, so platform-specific code
  composes with the enum's operations at no cost.
- It's typed, unlike E1. The catch sites are otherwise E1's, with
  explicitly typed patterns under `#if`.

Conditions:
- **One error type per platform.** Every case on a platform must report the
  same error type. That holds for everything here. It would break for a
  Darwin case over a Mach task port, whose errors are `kern_return_t`, and
  E3 is the fallback there.
- **Operator fixes.** Both `~=` operators need `@_disfavoredOverload`.
- **Shared names.** Don't write cross-platform catches by shared name.

## Verify results

| snippet | claim | result |
|---|---|---|
| V16a_open_enum | "open" needs library evolution | As a client of an evolving library, Swift 6 errors without `@unknown default` ("switch covers known cases, but 'File' may have additional unknown values"); Swift 5 warns. Against a non-evolving library (SystemPackage's build) `@unknown default` is accepted silently, so writing it is the only spelling that builds against both. A binary built against v1 and run against v2 sees the new case as unknown, and its consuming `@unknown default` closes the owner. A borrowing switch over another module's static let compiles |
| V16b | the switches a noncopyable enum needs | all compile without experimental features: borrowing over a parameter, `self`, and a static let; consuming; extraction. `default: return nil` destroys the other cases' owners; Narrowing doesn't |
| V16c | `if case` and `guard case` | consume the enum, even with no binding: "'file' is borrowed and cannot be consumed", and for a static let, "'unknown' is borrowed and cannot be consumed" |
| V16d | uninhabited foreign cases | a switch may omit them; an arm that uses one still needs its API |
| V16e, V16e2 | `#if` in cases, switches, catches | enum and switch cases: yes; catch clauses: "expected expression", even in an inactive block |
| V16f | pattern resolution with both error types | as under Errors: ambiguous; silently wrong with one operator disfavored; right with both, or with the type spelled out |
| V16g | a borrowed, nonescapable enum | declarable; nothing returns one without `Lifetimes` ("an implicit initializer cannot return a ~Escapable result", "a method cannot return a ~Escapable result"); with it, a `let` owner can't be closed after the borrow (the V6b error) |
| V16h | containers | an owned enum can't be an Array or Dictionary element; `InlineArray` of optionals works |
| V16i | an IRGen crash | a pattern catch (`catch Win32.Error.sharingViolation`, or `catch let e as E where ...`), then in the same function a `try` inside string interpolation on a noncopyable local, or an owner-returning call on an owner with a deinit, crashes in `FixedTypeInfo::deallocateStack`. Work around it by moving the catch into a helper, or hoisting the `try` |
| V16j, V16j2 | handing out a noncopyable payload | a closure and `_read` work, a getter can't; `yielding borrow` doesn't parse in 6.2, and can be staged only behind `#if compiler(>=...)`, since an inactive `#if hasFeature` block must parse |
| V16k | a Copyable-generic helper | given a closure returning an owner, it infers `()` and destroys the owner, with only warnings |

Also relied on: V1 (static lets of noncopyable types, for the standard
streams), V13d (a partly consumed pair can't be captured, which the pipe in
`errors` works around), and V9a (InlineArray).

Found along the way, with no snippet of their own:
- `Array.span` needs macOS 26, while System's span I/O needs 15, so the
  samples build a RawSpan with `RawSpan(_unsafeBytes:)`, as System's tests
  do.
- `try x ?? f()` loses a typed error, since `??` rethrows.
- FileDescriptor's `open`, `close`, `seek`, and `resize` still throw
  untyped errors, so typed code goes through OwnedFD or recasts.

## Draft details the prototype depends on

The stand-ins follow these drafts, so a change to any of them should be
traced to the listed samples.

- **SYS-0010: Win32.Error**
  - A struct over DWORD, not an enum, with named codes. The samples use
    `sharingViolation`, `lockViolation`, `accessDenied`, `fileExists`,
    `noData`, `brokenPipe`, `invalidParameter`, `fileNotFound`,
    `notADirectory`, `invalidHandle`, and `negativeSeek`.
  - `debugDescription` is `ERROR_X (n, 0xN)`.
  - `~=(Win32.Error, Swift.Error)` isn't `@_disfavoredOverload`, which V16f
    and the `errors` sample rely on.
  - `Errno(approximating:)` follows `_dosmaperr`: codes 19 to 36 become
    EACCES, ERROR_NO_DATA becomes EINVAL, and unknown codes become EINVAL.
- **SYS-0011: file handles.** All samples depend on these.
  - FileHandle and DirectoryHandle are `~Copyable` and `Sendable`, with a
    consuming `close() throws(Win32.Error)`, a deinit that drops the error,
    and `@unsafe` `init?(unsafelyAdopting:)`, `unsafeRawHandle`, and
    `relinquish()`.
  - `open`'s defaults: share read, write, and delete; `.openExisting`; not
    inheritable.
  - `openOrCreate`'s `existed`; `DirectoryHandle.open` throws
    `notADirectory`.
  - `duplicate`, which shares the file pointer, `reopen`, `isInheritable`,
    and `setInheritable`.
  - The bridges: `withWin32HandleIfAvailable` lends through a borrowing
    closure, and is nil for a socket. `init(adopting:)` throws Errno and
    closes the handle on failure.
  - No copyable RawFileHandle (variant B's stand-in is the rejected
    alternative) and no borrowed view.
- **SYS-0012.** `fileType()`'s disk, character, pipe, and unknown, with a
  socket reporting `.pipe`. Used by `owned` and `windows-only`.
- **SYS-0013: I/O**
  - A positional read or write moves the file pointer (`copy`, `owned`).
  - `write` always loops, and there's no single-call write, so the common
    subset's write means "all of it".
  - `append` is a single WriteFile.
  - A seek on a pipe succeeds.
  - `flush` is FlushFileBuffers, which commits the device's cache and blocks
    on a pipe.
  - `resize(to:)` leaves the pointer alone.
  - Spans only.
- **SYS-0014: locks** (`lock`, `windows-only`)
  - Mandatory and scoped, with typed and untyped overloads.
  - A shared lock denies the holder's own writes.
- **SYS-0015 and SYS-0016.** `volumeInformation()` and `finalPath()`
  (`windows-only`, `library`).
- **Future directions the stand-ins fill in, hypothetically**
  - GetStdHandle, as the standard streams.
  - CreatePipe (`errors`).
  - Querying file information (`library`, through `unsafeRawHandle`).
  - Processes and sockets, which no draft covers.
  - `ProcessID` on Windows over a DWORD, sharing the name, as the Vision's
    rule allows.

Where the stand-ins differ from the drafts:
- They're internal, so nothing is `@frozen` or `public`.
- The MutableRawSpan and typed-span read overloads are left out, as are
  `write(draining:)` and `append(draining:)`.
- Everything else in the drafts' signatures compiles on Swift 6.2,
  including `@safe` and `@unsafe`, a `borrowing Win32.FileHandle? = nil`
  parameter, and the withLock overload pair. The drafts were tested with
  6.4 and 6.5-dev.

## Recommendation

**Whether the enum layer is worth it: no, as a general pattern; yes for
processes.** Confidence medium-high.

Where it hurts:
- **It adds to `#if`.** Each case exists only on its platform, so each
  platform-specific switch wraps each arm in `#if`. The switch adds
  exhaustiveness, but only for the platform being compiled: a switch
  written on a Mac compiles with only its `.fd` arm, and the missing
  `.handle` arm is an error only in a Windows build. That's the same as
  `#if`, which is what the simulated configuration had to exist to check.
- **Escape pressure is real, and asymmetric** (sample 4). The trapping
  one-case accessor is what users write, and on Windows the easy one
  returns `unsafeRawHandle`. Library evolution adds `@unknown default` to
  every switch, and a consuming one closes whatever it doesn't know.
- **Owned enums are awkward in 6.2.**
  - `if case` consumes.
  - Statics need nested switches.
  - Standard streams are optional.
  - Owners can't go in collections, so tables fall back to raw names.
  - Idiomatic code hits an IRGen crash (V16i).
- **The common subset can't make semantics the same.** Positional I/O,
  locks, flush, waits, and exit codes all differ. The subset can document
  them, and code correct on one platform can still be wrong on the other
  (`lock --contend`).
- **The counts.** The enum layer adds 4 enums and 5 vocabulary types for 4
  kinds, over the 10 platform types they wrap (variant A). Variant B would
  add 4 more enums and 4 more types.

Where it helps:
- **Signatures.** A cross-platform library can use one type in its
  signatures with no `#if` (`TinyJournal`).
- **Common-subset code** reads cleanly (`copy`).
- **Processes.** Linux and Windows each have two representations, so the
  switch does work that `#if` can't. That's the one kind worth prototyping
  in System, alongside the process work of direction 3.

For files, directories, and sockets, variant D, a per-platform typealias
with the common subset as same-named members, gets the signatures without
the switch or the escape. Its costs:
- Nothing checks that the members agree across platforms, short of a
  protocol, which the Vision says not to draft for methods.
- It can't represent a second representation on one platform.

That's less explored than the enum here: confidence medium.

**What the Windows model implies for Unix: keep Unix unchanged.**
Confidence high.
- The drafts make Windows' handle owned-only for a reason specific to
  Windows. A reused handle value can name an overlapped handle, on which
  synchronous I/O isn't memory-safe, so a copyable handle's operations would
  have to be `@unsafe` (SYS-0011).
- A stale Unix descriptor names some other file: a correctness hazard, not
  a memory-safety one.
- Mirroring Windows (variant C) buys symmetric switch arms and costs the
  Vision's full-power copyable FileDescriptor. The type count doesn't
  change; the members hosted on owners grow from 15 to about 145.
- The asymmetry does cost the enum layer. It can have no unowned form, and
  its Windows escapes go to C's HANDLE. That argues against the enum, not
  for changing Unix.
- If a cross-platform unowned layer is ever needed, for fd tables and poll
  loops, the choice is between B's copyable handle, whose operations would
  be `@unsafe`, and raw values. The drafts' own reasoning says raw values.

**If System does ship enums, for processes or more:**
- owned only, lent with `borrowing`
- the platform's own error type (E4), with both `~=` operators
  disfavored
- `@unknown default` documented as required, and written in System's own
  samples
- a Narrowing-style extraction rather than failable accessors
- no borrowed form until lifetimes are supported (V16g)
