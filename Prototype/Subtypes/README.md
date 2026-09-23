# Extending ownership to descriptor sub-types and other owners

A sketch, not API. It covers how the owned design (`OwnedFD`: close exactly
once, trap on `EBADF`, vend rather than forward) extends in two directions:
to the descriptor sub-types `SocketDescriptor` and `TerminalDescriptor`, and
to future noncopyable owners such as kqueue, epoll, and pidfd. `check.sh`
typechecks both files as clients of SystemPackage and SystemSockets:

- `Sketch.swift`, the proposed shape, compiles.
- `GenericOwner.swift`, the alternative, compiles, with the workarounds that
  V15a and V15b motivate.

```sh
swift build && ./Prototype/Subtypes/check.sh
```

## The proposed shape (`Sketch.swift`)

Each owned kind is a small noncopyable struct that holds an `OwnedFD` and has
no deinit of its own.

- **Close policy.** It inherits `OwnedFD`'s close semantics, including the
  `EBADF` trap. It can consume its field to implement `close()` and
  `relinquish()`.
- **Vending.** It vends its kind's raw descriptor, and the `FileDescriptor`.
  It forwards nothing (see `Prototype/Forwarding`).
- **Conversions.** It widens to `OwnedFD` without a check, and narrows from
  `OwnedFD` with `init(unchecked:)`. A checked narrowing checks the vended
  descriptor with the existing throwing raw conversion first.
- **Factories.** Operations that create a descriptor (open, accept, pair)
  return it owned.

| kind | raw name | owner | how to lend it | its operations are on |
|---|---|---|---|---|
| file | `FileDescriptor` | `OwnedFD`, `OwnedFD.Pipe` | `borrowing OwnedFD` | `FileDescriptor` (the 15 byte-I/O methods also forwarded) |
| socket | `SocketDescriptor` | `OwnedSocket`, `OwnedSocket.Pair` | `borrowing OwnedSocket` | `SocketDescriptor` |
| terminal | `TerminalDescriptor` | none: an `OwnedFD`, converted with `.fileDescriptor.asTerminal` | `borrowing OwnedFD` | `TerminalDescriptor` |
| kqueue (Darwin, BSD) | none: the vended `FileDescriptor` | `KernelQueue` | `borrowing KernelQueue` | `KernelQueue` |
| epoll (Linux) | none | `EventPoll` | `borrowing EventPoll` | `EventPoll` |
| pidfd (Linux) | none: `ProcessID` plus the vended `FileDescriptor` | `ProcessDescriptor` | `borrowing ProcessDescriptor` | `ProcessDescriptor` |
| Mach port (exists) | `mach_port_name_t` | `Mach.Port` | `withBorrowedName` | `Mach.Port` |

The count, for the six descriptor kinds:
- **Full grid.** Kind × {raw, owned, borrowed} would be 18 types, and 21 with
  the multi-platform enum in each mode.
- **This shape.** 9 types: 3 raw (all existing), 5 owners (`OwnedFD` existing,
  4 new), and 1 owned enum. The two pair types come on top.
- **No borrowed axis.** `borrowing` parameters lend owners
  (`Prototype/BorrowedFD`).
- **No raw twins.** Kinds that share none of `FileDescriptor`'s operations
  (kqueue, epoll, pidfd) get no raw type; the vended `FileDescriptor` names
  them.
- **Forwarding.** None, beyond `OwnedFD`'s 15 byte-I/O methods. Forwarding
  everything instead would put 38 members on `OwnedFD`, 58 on an owned socket
  (its 20 socket members plus the 38), and 49 on an owned terminal: 145 in
  all, from `Prototype/Forwarding/forwarding.py inventory . SocketDescriptor`
  and `... TerminalDescriptor`.

Per owned sub-kind, the API is about ten small members:
- `init(unchecked:)` from `OwnedFD`, and `init(taking:)` from the raw kind
- `OwnedFD.init(_:)` to widen
- `relinquish()`, which returns the raw kind, and `close()`
- two vending properties
- the kind's factories, and a pair type where the kind has pairs

### Sockets

`OwnedSocket` would live in SystemSockets. It can't see SystemPackage's
internals, so it can use only `OwnedFD`'s public API: `init(taking:)`,
`close()`, `relinquish()`, and `fileDescriptor`. `SocketDescriptor` keeps its
own `close()`: the raw type hosts the socket operations, and closing it
through the raw name is fine. The owner adds the guarantee of closing exactly
once. `OwnedSocket.Pair` follows `OwnedFD.Pipe`. Its ends are `first` and
`second`, since a socketpair's ends are interchangeable. In SystemSockets it
would be public and `@frozen`, because only then can clients take it apart
(V13b).

### Terminals

A terminal usually isn't owned. It's standard input, output, or error, which
`OwnedFD`'s static lets represent without ever closing them. And
`TerminalDescriptor`'s operations only need a raw name. So
`OwnedFD.standardOutput.fileDescriptor.asTerminal` reaches the terminal API,
standard input included, which is a hard requirement. An opened `/dev/tty`
converts the same way. An `OwnedTerminal` would be worth adding only
alongside factories that create terminals, such as `posix_openpt`. It would
take the same few members as `OwnedSocket`.

### Checked narrowing

An `Error` must be copyable, so a conversion that consumes an `OwnedFD` and
throws can't give the descriptor back. Destroying it would close it. The
sketch shows two shapes that avoid losing it:

1. **Check, then convert** (preferred, and no new API). Check the vended
   descriptor with the existing checked raw conversion, then convert without
   a check: `_ = try SocketDescriptor(owner.fileDescriptor)`, then
   `OwnedSocket(unchecked: owner)`. Written at the call site, the owner stays
   alive when the check fails. In a helper that consumes its argument, as
   `adoptIfSocket` does, the descriptor is closed on failure.
2. **One step, returning the original on failure**:
   `OwnedSocket.narrowing(_:) -> Narrowing<OwnedSocket, OwnedFD>`, where
   `Narrowing` is a noncopyable enum with cases `.narrowed(OwnedSocket)` and
   `.notNarrowed(OwnedFD, Errno)`. It compiles, including the consuming
   `switch` at the call site. It costs one generic enum, shared by every kind.

### Future owners: kqueue, epoll, pidfd

`KernelQueue` (typechecked on Darwin), and `EventPoll` and
`ProcessDescriptor` (Linux-only, so not typechecked here), have the same
shape.
- **Ownership.** Each holds an `OwnedFD`, vends its `FileDescriptor` for
  `poll(2)` or another queue, and hosts its own operations.
- **Registration.** Descriptors to watch are passed by raw name
  (`watchForReading(_: FileDescriptor)`). A queue never owns what it watches,
  and the kernel drops a registration when its descriptor is closed.
- **pidfd.** Owning a pidfd is an obligation to close the descriptor, not to
  reap the process. Reaping is the separate "responsibility" role for
  processes (`Next/Vision.md`, direction 3). A `ChildProcess` owner can't reap
  in its deinit without blocking, so it would face must-close's tradeoffs
  (`Prototype/CloseErrors`) rather than `OwnedFD`'s.
- **fork.** A kqueue isn't inherited across `fork(2)`. A child that forked
  without `exec` and then destroyed a `KernelQueue` would close a descriptor
  that isn't open, and trap on the `EBADF`.

### The multi-platform enum

The enum's owned cases wrap the per-kind owners, as `Next/Vision.md` says
they must. In the sketch, `OwnedDescriptor` has cases `.file(OwnedFD)` and
`.socket(OwnedSocket)`. It compiles, with a borrowing `switch` for
`fileDescriptor` and a consuming `switch` for `close()`. Single-platform code
never touches it.

## The alternative: one generic owner (`GenericOwner.swift`)

`Owned<Descriptor: OwnableDescriptor>` covers every kind with one type. The
protocol requires only the conversion pair, `fileDescriptor` and
`init(unchecked:)`. `SocketDescriptor` and `TerminalDescriptor` already have
both, and `FileDescriptor` would gain identity versions. Kind-specific API
goes in constrained extensions, and `OwnedFD` would become a typealias. It
compiles, but:

- **`discard`.** The owner can't store the generic `Descriptor`: in 6.2,
  `discard self` requires trivially destroyed stored properties, and a
  generic one doesn't qualify, even with `BitwiseCopyable` (V15a). Without
  `discard`, there's no `relinquish()` and no consuming `close()`. The sketch
  therefore stores a concrete `FileDescriptor`, and rebuilds the kind's
  descriptor on every access.
- **Standard streams.** A static stored property works only in a
  same-type-constrained extension (V15b), so
  `Owned<FileDescriptor>.standardInput` is possible. An unconstrained one
  fails with "static stored properties not supported in generic types".
- **Protocols.** It needs a protocol that every kind conforms to.
  `Next/Vision.md` says not to draft protocols for methods. This one
  captures conversions, but it is still a protocol at the center of the
  design.
- **Raw types.** Kinds without a raw type, such as kqueue, would need one to
  plug in, or else a separate owner, which is the per-kind shape anyway.
- **Readability.** Signatures and diagnostics say
  `Owned<SocketDescriptor>` unless every kind gets a typealias.

The per-kind wrapper costs about ten one-line members per kind and avoids all
of these, so it's the recommendation.

## Decisions

- **Owned sub-kinds.** They wrap `OwnedFD`, with no deinit of their own, and
  vend rather than forward. Rejected: the generic owner (above). Also
  rejected: owners with their own deinit, which would copy the close policy
  into each kind.
- **Terminals.** No owned type until something creates terminals; convert
  the vended descriptor.
- **Checked narrowing.** Check, then convert. `Narrowing` is an option if a
  one-step form is wanted. Rejected: a consuming throwing initializer, which
  would close the descriptor on failure.
- **Future owners.** Owner-only types, with no raw twin. They take watched
  descriptors by raw name.

Confidence: medium-high on the per-kind wrapper and on vending. Medium on
leaving terminals without an owner: that should be revisited when a lane adds
pty or `/dev/tty` factories.
