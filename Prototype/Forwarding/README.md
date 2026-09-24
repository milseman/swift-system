# Forwarding `FileDescriptor`'s API through `OwnedFD`, or vending it

`OwnedFD` forwarded 15 `FileDescriptor` methods (read, write, seek) and lent
the rest through `withDescriptor(body:)`. This directory measures what it
would cost to reach the full `FileDescriptor` API on `system-next` each way.
`OwnedFD` now keeps the 15 forwards and vends everything else through a
`fileDescriptor` property.

## The surface

`forwarding.py inventory` lists the public members of every
`extension FileDescriptor` in `Sources`, with their availability and `#if`
conditions. For `main`, `system-next`, and the `syscalls-3` lane's pending
commit, the instance members that don't change ownership are the ones a
forward-all `OwnedFD` would need. The other five are `close`, `closeAfter`,
and three `duplicate` overloads.

| tree | instance members | to forward |
|---|---|---|
| `main` (1b452c2) | 14 | 10 |
| `system-next` at c5781b2, when this was measured | 43 | 38 |
| `syscalls-3` then (pending `lock(_:byteRange:)`, `unlock(byteRange:)`) | 47 | 42 |
| `ownership` after merging `syscalls-3` and `demos` (0229e0f) | 63 | 58 |

Other kinds of API forwarding can't reach:

- **Argument position.** 40 public SystemPackage APIs take a `FileDescriptor`
  argument: the 30 `FilePath` `*at` calls, `open(_:relativeTo:)`,
  `duplicate(as:)`, `Stat.init(_:)` and `init(_:relativeTo:)`, and
  `TerminalDescriptor.init`. SystemSockets has 2 more, `SocketDescriptor.init`.
  (Counted from the symbol graph with `swift-symbolgraph-extract`.)
- **Other packages' extensions.** Of FileDescriptor's API, NIO's NIOFS adds
  its own `status()` (fstat), `changeMode` (fchmod), `synchronize`,
  `opendir`, xattrs, `readChunk`, and `open(atPath:)`.
- **C interop.** A survey of swift-subprocess, swift-nio (NIOFS), and SwiftPM
  found `.rawValue` to be the most-used member, with 62 uses. They pass it to
  `fcntl`, `posix_spawn_file_actions_adddup2`/`addclose`, `kevent`,
  `epoll_ctl`, `fstat`, `openat`, the xattr calls, `sendfile`, and `fcopyfile`.
  After `rawValue` and `init(rawValue:)`, the most-used members are
  `read(into:)` (9), `close()` (8), `open` (6), `write` (6), the standard
  streams, `writeAll` (3), and `duplicate` (3). None of the three uses `seek`,
  `pipe()`, `stat`, `setPermissions`, or `open(_:relativeTo:)`.

The full inventory, as `forwarding.py inventory` printed it at c5781b2:

| kind | member | availability | platforms (#if) | declared at | ownership |
|---|---|---|---|---|---|
| method | accessMode() | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:1268 |  |
| method | advise(_:offset:length:) | System 199, * | (os(Linux) \|\| os(Android) \|\| os(FreeBSD) \|\| os(WASI)) | Sources/System/FileOperations.swift:1418 |  |
| method | allocateSpace(offset:length:retryOnInterrupt:) | System 199, * | (os(Linux) \|\| os(Android) \|\| os(FreeBSD) \|\| os(WASI)) | Sources/System/FileOperations.swift:1380 |  |
| method | close() | System 0.0.1, * | all | Sources/System/FileOperations.swift:160 | OwnedFD.close() consumes the owner |
| method | closeAfter(_:) | System 0.0.1, * | all | Sources/System/FileHelpers.swift:23 | an owner closes itself |
| method | descriptorFlags() | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:1170 |  |
| method | duplicate(as:options:retryOnInterrupt:) | Windows, unavailable macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, * | (!os(WASI)) | Sources/System/FileOperations.swift:689 | returns a new descriptor, which should come back owned |
| method | duplicate(as:retryOnInterrupt:) | System 0.0.2, * | (!os(WASI)) | Sources/System/FileOperations.swift:647 | returns a new descriptor, which should come back owned |
| method | duplicate(atLeast:closeOnExec:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:772 | returns a new descriptor, which should come back owned |
| method | lock(shared:nonBlocking:retryOnInterrupt:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:822 |  |
| method | read(filling:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileHelpers.swift:215 |  |
| method | read(fromAbsoluteOffset:filling:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileHelpers.swift:248 |  |
| method | read(fromAbsoluteOffset:into:retryOnInterrupt:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:258 |  |
| method | read(fromAbsoluteOffset:into:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileOperations.swift:494 |  |
| method | read(into:retryOnInterrupt:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:222 |  |
| method | read(into:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileOperations.swift:468 |  |
| method | resize(to:retryOnInterrupt:) | System 1.2.0, * | all | Sources/System/FileOperations.swift:954 |  |
| method | seek(offset:from:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:178 |  |
| method | setDescriptorFlags(_:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:1193 |  |
| method | setFileFlags(_:retryOnInterrupt:) | System 199, * | (SYSTEM_PACKAGE_DARWIN \|\| os(FreeBSD) \|\| os(OpenBSD)) | Sources/System/FileOperations.swift:1141 |  |
| method | setOwner(user:group:retryOnInterrupt:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:1095 |  |
| method | setPermissions(_:retryOnInterrupt:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:1055 |  |
| method | setStatusFlags(_:) | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:1250 |  |
| method | setTimes(access:modification:retryOnInterrupt:) | macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, * | (!os(Windows)) | Sources/System/FileSystem/FileTimes.swift:62 |  |
| method | setTimesToNow(access:modification:retryOnInterrupt:) | macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, * | (!os(Windows)) | Sources/System/FileSystem/FileTimes.swift:90 |  |
| method | stat(retryOnInterrupt:) | System 1.7.0, * | (!os(Windows)) | Sources/System/FileSystem/Stat.swift:625 |  |
| method | statusFlags() | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:1222 |  |
| method | synchronize(retryOnInterrupt:) | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:995 |  |
| method | synchronizeData(retryOnInterrupt:) | System 199, * | (!os(Windows) && !SYSTEM_PACKAGE_DARWIN) | Sources/System/FileOperations.swift:1028 |  |
| method | synchronizeFully(retryOnInterrupt:) | System 199, * | (SYSTEM_PACKAGE_DARWIN) | Sources/System/FileOperations.swift:1308 |  |
| method | synchronizeWithBarrier(retryOnInterrupt:) | System 199, * | (SYSTEM_PACKAGE_DARWIN) | Sources/System/FileOperations.swift:1338 |  |
| method | unlock(retryOnInterrupt:) | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/FileOperations.swift:842 |  |
| method | write(_:retryOnInterrupt:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:311 |  |
| method | write(_:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileOperations.swift:395 |  |
| method | write(toAbsoluteOffset:_:retryOnInterrupt:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:344 |  |
| method | write(toAbsoluteOffset:_:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileOperations.swift:421 |  |
| method | writeAll(_:) | System 0.0.1, * | all | Sources/System/FileHelpers.swift:54 |  |
| method | writeAll(_:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileHelpers.swift:157 |  |
| method | writeAll(toAbsoluteOffset:_:) | System 0.0.1, * | all | Sources/System/FileHelpers.swift:104 |  |
| method | writeAll(toAbsoluteOffset:_:retryOnInterrupt:) | macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, * | all | Sources/System/FileHelpers.swift:184 |  |
| property | asTerminal | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/Terminal/TerminalDescriptor.swift:108 |  |
| property | isTerminal | System 199, * | (!os(Windows) && !os(WASI)) | Sources/System/Terminal/TerminalDescriptor.swift:96 |  |
| property | rawValue | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:21 |  |
| static | open(_:_:options:permissions:retryOnInterrupt:) | System 0.0.1, * | all | Sources/System/FileOperations.swift:29 |  |
| static | open(_:_:options:permissions:retryOnInterrupt:) | System 0.0.1, * | (!os(Windows)) | Sources/System/FileOperations.swift:70 |  |
| static | open(_:_:options:permissions:retryOnInterrupt:) | System 0.0.1, * | (!(!os(Windows))) | Sources/System/FileOperations.swift:121 |  |
| static | open(_:relativeTo:_:options:permissions:retryOnInterrupt:) | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:540 |  |
| static | open(_:relativeTo:_:options:permissions:retryOnInterrupt:) | System 199, * | (!os(Windows)) | Sources/System/FileOperations.swift:577 |  |
| static | pipe() | System 1.1.0, * | (!os(WASI)) | Sources/System/FileOperations.swift:866 |  |
| static | pipe(options:) | macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, * | (!os(WASI)) | Sources/System/FileOperations.swift:887 |  |
| static | standardError | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:41 |  |
| static | standardInput | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:33 |  |
| static | standardOutput | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:37 |  |
| type | AccessMode | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:49 |  |
| type | Advice | System 199, * | (os(Linux) \|\| os(Android) \|\| os(FreeBSD) \|\| os(WASI)) | Sources/System/FileDescriptor.swift:634 |  |
| type | DescriptorFlags | System 199, * | (!os(Windows)) | Sources/System/FileDescriptor.swift:541 |  |
| type | DuplicateOptions | Windows, unavailable macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, * | all | Sources/System/FileDescriptor.swift:403 |  |
| type | OpenOptions | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:92 |  |
| type | PipeOptions | macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, * | all | Sources/System/FileDescriptor.swift:332 |  |
| type | SeekOrigin | System 0.0.1, * | all | Sources/System/FileDescriptor.swift:456 |  |
| type | StatusFlags | System 199, * | (!os(Windows)) | Sources/System/FileDescriptor.swift:578 |  |

Totals: 40 method, 3 property, 10 static, 8 type; 38 instance members to forward

## The options

| option | declarations to cover the API | who maintains it | reaches argument-position APIs? |
|---|---|---|---|
| hand-written forwards | 38 (23 more), about 13 lines each: +300 lines, +52 for the pending lane commit | every lane that adds `FileDescriptor` API, in its own `#if` and `@available` | no |
| generated forwards | 38, as 414 generated lines, plus the 312-line `forwarding.py` | a generator, plus a CI check that its output is current | no |
| `withDescriptor(body:)` closure (before) | 1 | nobody | yes |
| borrowing accessor (chosen) | 1 | nobody | yes |
| `@dynamicMemberLookup` over key paths | 1 | nobody | properties only (V12d) |
| a protocol that owners conform to | one extension method per operation (V12e) | as for forwarding | no |

A macro can't generate forwards, since a macro sees only the syntax it's
attached to, not `FileDescriptor`'s members.

### Generated forwarding works, with four fixes

`build-generated.sh` replaces `OwnedFD`'s hand-written forwards in a copy of
the package with `forwarding.py generate`'s output, and builds it. It took
four fixes to compile:

1. `@available(Windows, unavailable)` had been read as `*, unavailable`,
   which dropped the `dup3` overload of `duplicate(as:options:)`.
2. Nested type names like `AccessMode` resolve inside
   `extension FileDescriptor` but not inside `extension OwnedFD`, so the
   generator qualifies them.
3. `setTimes` uses the C `timespec`, so the output needs `FileTimes.swift`'s
   platform imports.
4. 11 of the 43 members still throw untyped errors (`read`, `write`, `seek`,
   `writeAll`, `resize`, `duplicate(as:)`, `close`, `closeAfter`). Faithful
   forwards broke every Owned sample, which call them from `throws(Errno)`
   functions. The generator now reads each body and forwards to its internal
   `_foo(...).get()` call, as the hand-written forwards do. That couples it
   to the internal layering.

With those fixes, the copy builds and its 26 OwnedFD tests pass. After the
merge of `syscalls-3` and `demos`, the generator needed no further fixes for
the 20 new members: 661 lines for 58 members, and the copy still builds. The
generated forwards carry no documentation, only "Forwards to
`FileDescriptor.x`". They add 23,708 bytes (1.6%) to the debug
`SystemPackage.swiftmodule`. They add no code: the same operations compile
to 166 instructions forwarded, 166 through the accessor, and 167 through a
closure, at `-O`.

### Call sites

`Ports/` holds the same code written against each option. It comes from the
AtomicWrite, PIDFile, and SetAttributes samples, which use the new file
operations and an owned directory, and from the four Owned samples that
used `withDescriptor`. `Closure.swift` and `Accessor.swift` typecheck against
this branch. `ForwardAll.swift` typechecks against the copy from
`build-generated.sh`.

| port | uses of the escape hatch | `throws(Errno) in` annotations | code lines |
|---|---|---|---|
| `Closure.swift`: I/O forwards + `withDescriptor` (before) | 15 | 11 | 79 |
| `ForwardAll.swift`: generated forwards + `withDescriptor` | 6, all APIs that take a descriptor argument | 3 | 71 |
| `Accessor.swift`: I/O forwards + `fileDescriptor` (chosen) | 19 | 0 | 62 |

With the closure, a typed error is lost at each use. Swift 6.2 infers
`throws(any Error)` for a closure that contains `try`, even when the closure
is passed as a `throws(E)` parameter. So `try fd.withDescriptor { try
$0.stat() }` fails to compile in a `throws(Errno)` function, with "thrown
expression type 'any Error' cannot be converted to error type 'Errno'"
(V12a). Inside such a closure, a `do`/`catch` block catches `any Error` unless
it is spelled `do throws(Errno)` (V12b). `-enable-upcoming-feature
FullTypedThrows` changes neither, and the experimental feature is refused by
the production compiler. Two owners need nested closures, as in `redirect`.

## Compiler checks

- `V12a_closure_thrown_type.swift`: expected to fail as described above; the
  annotated form compiles.
- `V12b_closure_do_catch_type.swift`: expected to fail only in the closure
  without `do throws(Errno)`.
- `V12c_accessor_on_temporary.swift`: vending from a temporary owner, such as
  `try OwnedFD.open(...).fileDescriptor`, compiles without a diagnostic
  through the accessor and through a closure. Either way, the result names a
  closed descriptor.
- `V12d_dynamic_member_keypath.swift`: `owner.rawValue` and
  `owner.isTerminal` work; `owner.stat()` fails with "dynamic key path member
  lookup cannot refer to instance method 'stat(retryOnInterrupt:)'".
- `V12e_protocol_operations.swift`: noncopyable owners can share operations
  through a `~Copyable` protocol's extension. This compiles. It is still one
  declaration per operation, and `Next/Vision.md` rules out protocols for
  methods.

## Decision

Keep forwarding reading, writing, and seeking. Vend everything else through
`public var fileDescriptor: FileDescriptor`. Remove `withDescriptor(body:)`.
Don't extend forwarding.

- **Forwarding can't be the whole answer.** Even with every member forwarded,
  the ports need 6 escape-hatch uses, all for APIs that take a descriptor
  argument, and C interop and other packages' extensions need the raw
  descriptor too. Some form of vending has to exist, and once it does,
  forwarding more is convenience rather than coverage.
- **Forwarding's cost grows with the API, in every lane.** The count went from
  10 to 38 by c5781b2, and to 58 once the `syscalls-3` lane merged. Each lane that adds
  a `FileDescriptor` method would have to add a matching `OwnedFD` forward
  with the same `#if` and `@available`. Only the ABI-stable build catches a
  mismatch, and that build doesn't pass today. Owned socket, terminal, and
  kqueue types would multiply this (see `Prototype/Subtypes`).
- **Generated forwards are workable but fragile.** The generator needed four
  fixes on its first real run, and it depends on the internal `_foo` layering
  to keep errors typed. It would need a CI check, it duplicates the API in
  documentation, and it still leaves the argument-position APIs.
- **The accessor replaces the closure.** It reaches everything with one
  declaration: receivers, arguments, other packages' extensions, and
  `rawValue`. It needs no annotations, and typed errors pass through. It
  follows the pattern `SocketDescriptor` and `TerminalDescriptor` use to vend
  the canonical descriptor. The closure only looked safer: `withDescriptor {
  $0 }` escapes a copy as easily (V10a, V12c), and it cost 11 annotations and
  nested closures in the ports.
- **Why keep the 15 forwards.** Read, write, and seek are what code that
  borrows an owner does most. In the survey, `read(into:)` and `write` are
  the most-used operations after `rawValue` and `init(rawValue:)`. These
  forwards also throw `Errno` where `FileDescriptor` still throws untyped
  errors. The rule is short: `OwnedFD` forwards the byte I/O, and nothing
  else. New `FileDescriptor` API needs no `OwnedFD` change.

The remaining hazard is the same with the closure and with forwarding: a
vended descriptor can outlive its owner (V12c), or be closed. Closing it
leaves the owner to close the same number again. Its deinit drops the
`EBADF`, or closes an unrelated file if the number was reused; whether that
should trap is open (see `Prototype/CloseErrors`). Keeping it is
caught only by review, or in the future by a lifetime-dependent borrowed type
(see `Prototype/Verify/V14*`). Such a type would itself need
the whole forwarded surface to be worth having.

Confidence: high that forwarding shouldn't grow with `FileDescriptor`'s API.
Medium on the accessor rather than the closure: it trades the closure's scope
cue for ergonomics. `forwarding.py` stays here, ready to use, if full
coverage turns out to matter more than its upkeep.
