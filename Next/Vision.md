# swift-system: vision and design guidelines for the next major version

Orientation for prototyping work on `system-next`. This came out of a design
conversation, not from the code. Read the package itself for what exists today.
Where this document describes current design, treat it as a starting point to
verify rather than as fact.

Sections are marked by source, because the distinction matters. Some of this is
settled intent, some is open exploration, and some is unconfirmed suggestion.
Do not collapse the three.

Related documents: `Next/Roadmap.md` and `Next/Candidates.md` for the concrete
candidate inventory. This document is the "why", not the "what".


## What swift-system is

A Swift package providing idiomatic interfaces to system calls and low-level
currency types: `FileDescriptor`, `Errno`, and related types. It runs on Darwin,
Linux, and Windows, and a copy ships as the `System` module in Apple's SDKs,
which constrains how freely it can change. It favors thin, faithful wrappers
over platform APIs rather than cross-platform abstraction.

It predates noncopyable types, nonescapable types, typed throws, and `Span`. The
next major version is an opportunity to adopt some of that, though the lifetime
model is still early enough that the design should not depend on it.


## The philosophy

This is the load-bearing part. It should decide the calls that prototyping
forces.

**System removes incidental unsafety and hazards, without being obstructive by
trying, and failing, to remove inherent ones.**

"Unsafety" here means memory safety in Swift's technical sense. "Hazards" means
correctness footguns, such as dropped errors. They are different, and the second
is more of what System deals with.

`FileDescriptor` illustrates both halves. It is a strong type with guarantees,
but it is still the systems-level notion of a file descriptor, warts and all.
Its role is to be an fd. Meanwhile its methods throw `Errno`, so an error must be
caught rather than silently dropped, and they handle EINTR retrying, which nearly
everyone forgets to do. Those are incidental hazards of how C exposes the
concept, and removing them costs nothing.

### The table saw analogy

You want a guard, because you are not insane. But a poor guard encourages people
to remove or bypass it. A guard that blocks a legitimate cut gets taken off and
not put back, so it fails to protect the later cuts too.

### Escape hatches are not free

A common argument says: you can always just use the C interfaces, so let us make
something clean and safe even if it does not cover the concept fully. Reject
this. It produces a world where the unsafe escape hatches are taken routinely
and we hope people put things back together correctly. Most will not.

`FileDescriptor` is not noncopyable, and you can get the `CInt`, because that is
the point of the construct. The goal is enough coverage that nobody wants to
unless they are explicitly interoperating with some other system where they must.
Partial coverage is therefore not a goal, though there will always be a gap.

### The "System inversion"

System differs from most Swift libraries. Most present safe abstractions with
unsafe escape hatches. System is inherently the unsafe system interfaces
presented as sanely as we can manage. That inversion is why a copyable,
full-power currency type is appropriate at this layer.

### Reduced-power types and conditional guarantees

The shape of any new safety work: FD is the full-power type. Anything else is a
reduced-power type for common situations with common and avoidable hazards,
built on top of FD rather than replacing it. Such a type trades operations for
guarantees, and those guarantees hold only if you stay within the subset from
start to finish.

They are also inherently whole-process. If you link a library that spawns a
thread and closes fd 42, it all goes out the crapshoot. That is inherent, and it
is acceptable. System does not need to be airtight. It needs the disciplined
path to be easy and the undisciplined path to be visible.

### Platform divergence

Hiding unnecessary platform divergence in the design is good where possible.
Creating a POSIX emulation layer is not. The current quasi-POSIX UCRT approach
on Windows has to die. The line is roughly: the same concept spelled differently
per platform can share a name, but a concept one platform lacks should not be
faked.

### A hard requirement

Whatever gets designed, stdin has to work. If a design cannot accommodate it,
that is a hard stop, not a tradeoff.


## Directions to explore

These are open explorations. Nothing here is decided.

1. **A lifetime-safety layer for file descriptors.** The `OwnedFD` concept: a
   noncopyable type that guarantees closure. The motivation is the common case of
   opening a file and guaranteeing it gets closed. Prototype it, and write
   samples using both it and `borrowing OwnedFD`. Then determine what value, if
   any, a separate `BorrowedFD` would add.

   There is a live argument that this belongs in a higher-level library instead.
   If the toolchain had a `Files` library with cross-platform interfaces and
   lifetime management, it is unclear we would want to encourage systems-level
   programming for that use case. On the other hand, such a library might itself
   want to use a linear type like this.

2. **Descriptor sub-types and conversions.** Unix fds are messy. FIFOs and
   sockets are not seekable. Kqueues use the same descriptors with none of the
   shared operations. Terminals are fds too. So System should have types like
   `SocketDescriptor` and `TerminalDescriptor` where a subtype needs dedicated
   API. `SocketDescriptor` exists to host socket operations, and having `close`
   on it is fine.

   The direction to try: find simple conversion functions between these
   sub-types and the canonical FD type, checked and unchecked, and formalize that
   pattern. Do not draft protocols for methods.

3. **PIDs and process identity.** The same treatment. A PID wrapper exists. Does
   it need the same split? Should there be an enum where `.pid` is a case, and
   `.fd` is a case on Linux for fd-backed process IDs?

4. **Multi-platform enums.** System is not cross-platform, but it is reasonable
   for people to want similar API on whatever system they are on. Protocols are
   one approach. A more interesting one is an open enum with platform-specific
   cases, for example an fd on Unix and a file handle on Windows. Common-subset
   operations are hosted on the enum. Anything else requires a `switch`, which
   means you are adding explicit cases that clearly communicate what kind of
   platform-specific code you are now writing. Worked examples in the samples
   folder would help sort this out.

5. **Win32 handle types.** `Win32FileHandle`, `Win32OwnedFileHandle`, and so on,
   likely mirroring the fd design somewhat. Separate from the above and probably
   deferred.

6. **Grow the existing API surface**, greatly and in parallel, so long as it
   follows the package's existing API and design conventions.

7. **Adoption PRs**, in parallel, against swift-foundation, swift-nio, SwiftPM,
   and others, migrating all syscalls onto system-next and growing support out as
   gaps appear.

**A tension across these.** The type count multiplies along three axes at once:
ownership mode, descriptor kind, and the cross-platform enum. The assessment so
far is "barely contained type explosion, but at least it fits". Keeping it
contained is itself a design goal, and a prototype that ignores it is not testing
the real problem.


## Concepts developed in the conversation

Useful framings that emerged. Agreed in conversation, not tested against code.

**Three roles.** Each kernel object can have up to three: the **name** (raw,
copyable, no ownership claim), the **responsibility** (owned, an obligation to
close or, for processes, to reap), and **access** (borrowed, a guarantee that the
object stays open for the duration and that the callee will not close it or keep
it). The same three appear to recur for fds, Windows handles, and processes.

**A borrow needs an owner.** A borrowed view over a copyable FD provides nothing,
because any other copy can close the fd at any time. The guarantee comes only
from depending on an owned value, where close is consuming and the compiler can
see the dependency. What a borrowed type actually provides is two promises
running in opposite directions: the caller promises the fd stays open for the
call, and the callee promises not to close it or keep it. Today neither can be
expressed, so passing an fd amounts to handing over permission to close it, with
the real contract living in documentation.

**The enum cannot replace platform owned types.** If the multi-platform enum were
the only owned type, then in single-platform code every platform-specific
operation would need a switch or a consume to reach the payload. The cheapest way
out is grabbing the raw value, which pushes people off owned types entirely,
which is worse than not having the enum. So the enum's owned cases would wrap
platform-specific owned types, making the enum a layer for cross-platform code
only, with single-platform code never touching it.

**Stdin as a static.** `static let standardInput: OwnedFD` was considered a
promising way to give stdin an owned form without needing an "owning but never
actually close it" API, on the reasoning that statics are never deinitialized and
a `let` cannot be consumed. Not confirmed. See the verification list below.


## Open questions

* Can you make an `OwnedFD` from an `FD`, and how unsafe is that? Note that
  "unsafe" is wobbly here. Nothing involved is undefined behavior or
  memory-unsafe, but a double close can close an unrelated fd.
* Can you unsafely destroy an `OwnedFD`?
* What is the role of the raw type, once owned and borrowed types exist?
* Should the Win32 handle be noncopyable and owned with an escape hatch to the
  raw pointer, mirroring the fd design or deviating from it?
* Is there a need for protocols, or a common type to devolve into, to unify raw,
  owned, and borrowed?
* What is the checked and unchecked conversion story between descriptor kinds?
* Does the process side get the same split?
* How does a borrowed type fit alongside the multi-platform enum?
* `BorrowedFD`: defer it, ship a limited form, or embrace it fully before
  lifetimes are sorted out? There is reluctance to hang the design on a feature
  still early in its design phase.
* Naming. `FileDescriptor` is fixed, but names for owned, borrowed, handle, and
  kind types are open.


## Verify with the compiler, not by reasoning

These came up as assertions in conversation. None are confirmed. Roughly in order
of how load-bearing they are.

* **Noncopyable types in global or static storage.** SE-0390 originally
  prohibited this. If that restriction still stands, `static let standardInput:
  OwnedFD` does not compile and stdin needs a different answer. Check this first,
  since stdin is a hard requirement.
* Whether a `let` binding of a noncopyable type can be consumed, which is the
  other half of that trick.
* Whether `consuming func close() throws` alongside a `deinit` compiles cleanly.
  This matters because close can fail, with EIO on NFS and EINTR whose retry
  semantics diverge by platform, while `deinit` cannot throw. Dropping that error
  silently is exactly the kind of hazard System exists to remove, so the design
  needs an answer. Note that `Next/Roadmap.md` already flags `closeAfter` as
  needing a typed-errors design for the double-failure case; these are the same
  problem.
* Whether `discard self` provides a clean release-without-closing path returning
  the raw FD. That is what handing ownership to C or to `posix_spawn` requires.
* Whether nonescapable enums exist. A borrowed multi-platform enum would depend
  on them.
* Current status of lifetime dependence generally.
* What the diagnostics look like when someone misuses a borrowed noncopyable
  value. Bad diagnostics are their own form of obstruction, and this philosophy
  cares about obstruction.

### Already answered by the existing handoff notes

Drawn from `Claude outputs/system-next-handoff.md`, not from the design
conversation. Confirm against the code.

* `SocketDescriptor` already exists, from the Sockets 2026 work merged in from
  `staging`. It is `Sendable` while `FileDescriptor` is not, which is an open
  question of its own (PR #112).
* `FileDescriptor.closeAfter(_:)` already exists and already provides scoped
  closure. This affects how much `OwnedFD` actually adds, and the prototype
  should say what the delta is.
* `Mach.Port` and `IORing` are already `~Copyable`, so there is prior art in the
  package for the ownership question. Look at what those types do about escape
  hatches and about failure during teardown before designing `OwnedFD` from
  scratch.
* The Span-based I/O already uses `throws(Errno)`.

### One correction to carry

A Win32 `HANDLE` is `void *`, not `DWORD *`. It is an opaque name that is never
dereferenced, which makes it structurally much like a file descriptor.


## Suggestions from the assistant, unconfirmed

Entropy pool, not direction. None of this was agreed.

* Settle early whether `OwnedFD` forwards FD's methods or simply vends an FD.
  Direction 6 grows the FD surface, so if the answer is forwarding, the cost
  scales with that surface and gets paid retroactively. The same applies to
  operations hosted on the multi-platform enum.
* The adoption PRs may be stronger evidence than samples, since that code already
  exists and has no stake in this design. If NIO's fd handling wants `OwnedFD`,
  that is real. If the migration is fine with plain FD, that is also real.
* Samples that test the escape-hatch prediction rather than showing the design at
  its best: a poll loop with an fd table, `posix_spawn` file actions, passing an
  fd over SCM_RIGHTS, a `dup2` redirect. Then look at where the raw value shows
  up.
* Enumerating the actual grid (fd, socket, terminal, handle, process, across raw,
  owned, borrowed) and counting types, conversions, and forwarding boilerplate
  would turn "barely contained" from a guess into a number.
* The enum may be hard to evaluate without at least a sketch of the Windows side,
  since its cases are the platform types. That pulls against deferring Win32
  entirely.
* PIDs might be a better first testbed than fds. Forgetting to reap is a bug
  people actually hit, whereas use-after-close through a copied FD has so far
  been theoretical.
* Rust's I/O safety work (`RawFd`, `BorrowedFd`, `OwnedFd`, and RFC 3128) reached
  similar conclusions, including treating I/O safety as a whole-program property.
  Worth reading, not worth copying.
