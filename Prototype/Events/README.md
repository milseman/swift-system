# Event notification: kqueue, epoll, eventfd, timerfd, and poll

A prototype of typed event notification APIs, which swift-nio and
swift-subprocess need most of all. The API is in `Sources/System/Events/`;
this directory holds the design record, a sketch of a cross-platform layer,
and the scripts that check what can't be built here.

```sh
swift build && ./Prototype/Events/check.sh        # ReadinessQueue.swift's kqueue half
swift build && ./Prototype/Events/check-linux.sh  # everything Linux, against a model
swift run system-samples events-loop               # an event loop over a pipe and a timer
swift run system-samples events-poll               # poll(2) over three pipes
```

| API | wraps | platforms |
|---|---|---|
| `KernelQueue` | `kqueue`, `kevent` | Darwin, FreeBSD, OpenBSD |
| `KernelEvent`, with `Flags`, `Filter`, `FilterFlags` | `struct kevent`, `EV_*`, `EVFILT_*`, `NOTE_*` | Darwin, FreeBSD, OpenBSD |
| `EventPoll`, `EventPoll.Event`, with `Mask`, `Data` | `epoll_create1`, `epoll_ctl`, `epoll_wait`, `epoll_pwait`, `struct epoll_event`, `EPOLL*` | Linux, Android |
| `EventCounter` | `eventfd`, and `read` and `write` of its counter | Linux, Android |
| `IntervalTimer`, with `Clock` and `Schedule` | `timerfd_create`, `timerfd_settime`, `timerfd_gettime`, `struct itimerspec` | Linux, Android |
| `FileDescriptor.poll(_:timeout:)`, `poll(for:timeout:)`, `PollEntry`, `PollEvents` | `poll`, `struct pollfd`, `POLL*` | every Unix platform but WASI |

## The shape

The four owners (`KernelQueue`, `EventPoll`, `EventCounter`,
`IntervalTimer`) follow `Prototype/Subtypes`' recommendation for kinds that
share none of `FileDescriptor`'s operations. Each is a noncopyable struct
that holds an `OwnedFD` and has no deinit of its own, so it closes its
descriptor exactly as `OwnedFD` does, whatever that policy becomes
(`Prototype/CloseErrors`; today the deinit drops close errors). Each has the
same five ownership members: a factory initializer, `init(taking:)`,
`fileDescriptor`, `close()`, and `relinquish()`. A queue doesn't own what it
watches: registration takes raw `FileDescriptor` names.

Every wait appends to an `inout OutputSpan` and returns how many elements it
appended; registration takes a `Span` or a single value. Timeouts are
`Duration?`: `nil` waits until an event arrives, zero or less doesn't wait,
and a positive timeout rounds up, so that it never becomes zero.

## Where this follows the strawperson, and where it departs

It follows the strawperson (the event notification gist) in most of its
shape: `KernelQueue` as a noncopyable, `Sendable` owner with `init() throws(Errno)`,
consuming `close()`, and `fileDescriptor`; `registerAndPoll(_:into:timeout:)`,
`register(_:)` for a span or one event, and `poll(into:timeout:)`, over `Span`
and `OutputSpan`; the unavailable `kevent(registering:...)` stub that renames
to `registerAndPoll`; `KernelEvent` as `RawRepresentable` over
`CInterop.KEvent`, with `identifier`, `filter`, `flags`, `filterFlags`, `data`,
and `userData`; one `FilterFlags` type whose names carry their filter's
prefix; and, for epoll, `add`, `modify`, `remove`, and `wait(into:timeout:)`,
an event with a mask and a data union, and a `closeOnExec` creation option.

It departs from it here:

1. **Names.** `EventPoll`, not `EPoll`: the E is "event", and spelling it
   out, as `KernelQueue` does, removes the asymmetry the strawperson asks
   about. Its event is `EventPoll.Event` rather than `EPollEvent`, and the
   kqueue filter is `KernelEvent.Filter` rather than a top-level
   `KernelEventFilter`, next to `Flags` and `FilterFlags`. `oneShot` in both
   (the strawperson has `oneshot` for kqueue), `readable` and `writable`
   rather than epoll's `in` and `out`, which is what the bits mean and what
   `PollEvents` also says, `exceptional` rather than `except`, and prefixes
   and names in words: `processExit` (`procExit`), `vnodeAttributes`
   (`vnodeAttrib`), `vnodeUnlock` (`vnodeFunlock`), `userNoOperation`
   (`userNop`). `EventPoll.Options`, not `CreateFlags`, as `OpenOptions` and
   `PipeOptions` are.
2. **Waits return a count.** They return the number of events appended,
   discardably, as `read(into: inout OutputRawSpan)` does, rather than
   nothing: the span may have held events before the call.
3. **The identifier question.** The strawperson asks whether `identifier`
   should be a `FileDescriptor` or have an overload. An overload, and a
   `fileDescriptor` view: the identifier is also a process ID, a signal
   number, or a number you choose, so it stays `UInt`.
4. **Errors in the event list.** `registrationError` reads the errno that a
   failed change, or an `EV_RECEIPT` receipt, carries in `data`. A call that
   returns successfully can carry failures as events, which a caller that
   only checks the return value misses; NIO checks each event for `EV_ERROR`.
5. **EINTR.** The strawperson says only that the wrappers handle `EINTR`.
   kevent applies every change before it waits, so a call that a signal
   interrupts has applied them all. A retry that resends the changes would
   apply them twice, and an `EV_DELETE` would then fail with `ENOENT`. So
   `registerAndPoll` retries without the changes, and `register`, which
   never waits, treats `EINTR` as success, as NIO does.
6. **Timeouts.** Clamped to 100,000,000 seconds (about three years) for
   kevent: Darwin's kevent rejects a `tv_sec` over 2^31 - 1 with `EINVAL`,
   checked here, and NIO clamps to this value for older kernels. Negative
   timeouts, which kevent also rejects, don't wait.
7. **epoll_pwait, not epoll_pwait2.** The `signalMask:` overload wraps
   `epoll_pwait`, whose timeout is in milliseconds. `epoll_pwait2` takes a
   `timespec`, but needs Linux 5.11 and glibc 2.35, so it would need a
   CSystem shim, and an `ENOSYS` fallback. The mask is a `sigset_t` value
   rather than a pointer.
8. **epoll's data.** `EventPoll.Event.Data` holds the union's 64 bits as its
   raw value, with `fileDescriptor(_:)` and `pointer(_:)` factories and views.
   It drops `u32`, which the raw value covers. The views convert through the
   C union, so a descriptor lands where C code expects it on big-endian
   machines too, where `fd` is the high half of `u64`.
9. **More kinds.** eventfd (`EventCounter`), timerfd (`IntervalTimer`), and
   `poll(2)`, which the strawperson doesn't cover.
10. **Availability.** Members that take a `Span` or `MutableSpan` carry
    macOS 10.14.4, and members that take a `Duration` carry macOS 13, next to
    `System 199`, as `FileLock`'s timed lock does.
11. **The examples.** The strawperson's examples call
    `Array(capacity:initializingWith:)`, which Swift 6.2's standard library
    doesn't have. The documentation uses
    `Array(unsafeUninitializedCapacity:)` with
    `OutputSpan(buffer:initializedCount:)` and `finalize(for:)` instead, and
    the samples reuse one buffer across waits, as an event loop would.

## Decisions

Each with the alternative it rejects.

1. **Owners hold an `OwnedFD`, with no deinit of their own.** They share
   `OwnedFD`'s close policy, which is still open, rather than copy it.
   Rejected: a deinit per owner.
2. **No raw twin.** A kqueue or an epoll shares none of `FileDescriptor`'s
   operations, so the owner hosts them, and the vended `FileDescriptor` names
   it. Rejected: a copyable `KQueueDescriptor`, as in the 2021 okay_cue
   branch.
3. **Spelled-out names** (`KernelQueue`, `EventPoll`). Rejected: `KQueue`
   and `EPoll`, which follow `IORing`'s precedent of keeping the C name in
   Swift case, and the strawperson's mix of the two.
4. **Spans only.** Rejected: `UnsafeMutableBufferPointer` overloads, which
   NIO's storage fits today. The roadmap demotes pointer-based I/O (C6-C7),
   and `OutputSpan(buffer:initializedCount:)` and `finalize(for:)` bridge any
   existing storage in two lines. Pointer overloads can be added later
   without breaking anything.
5. **One `FilterFlags` type, prefixed by filter.** Rejected: an option set
   per filter, which would multiply types over a field that's one `UInt32`
   in C, and okay_cue's unprefixed names (`deleted`, `written`), which hide
   that `NOTE_DELETE` and `NOTE_SECONDS` share a value.
6. **Platform-specific members are gated and say so.** FreeBSD's
   `processDescriptor` filter and `timerMilliseconds`, Darwin's
   `userDataSpecific` and `timerMachTime`, and so on. The same concept under
   different names shares one: Darwin's `NOTE_ABSOLUTE` and FreeBSD's
   `NOTE_ABSTIME` are both `timerAbsolute`. Rejected: a Darwin-only
   `KernelEvent`.
7. **Linux constants by value.** glibc declares the epoll events as an enum
   (`EPOLLIN.rawValue`), musl and Bionic as macros, and Bionic's `EPOLLET`
   doesn't import at all. Their values are the kernel's and the same on every
   architecture, and the flags that aren't are defined as `O_CLOEXEC` and
   `O_NONBLOCK`, which System already imports. Rejected: the C names, which
   would need three spellings, none compilable here.
8. **`init()` calls `kqueue()` and takes no options.** Darwin's kqueue is
   already close-on-exec (checked), and no kqueue is inherited across `fork`.
   Rejected: `kqueue1` and `kqueuex` options, which only FreeBSD and OpenBSD
   have.
9. **`EventPoll(options:)` defaults to no options**, as `epoll_create1(0)`
   does, and as System's `open` and `pipe` default to C's behavior.
   Rejected: close-on-exec by default, which would be safer for a process
   that spawns children, but unlike the rest of System.
10. **`poll(2)` is a static method over a `MutableSpan<PollEntry>`**, plus
    `poll(for:timeout:)` for the common case of one descriptor. Rejected: an
    `inout [PollEntry]` parameter, the easiest to call but not span-first.
    WASI's `poll` is left out: wasi-libc's constants aren't checked here.
11. **eventfd and timerfd are `EventCounter` and `IntervalTimer`.**
    Rejected: `EventFD` and `TimerFD` (the C spellings), `EventDescriptor`
    and `TimerDescriptor` ("Descriptor" names System's copyable raw types),
    and `Timer`, which collides with `Foundation.Timer`.
12. **Their reads and writes go through System's `read` and `write`,** which
    retry `EINTR` and are mocked. Rejected: glibc's `eventfd_read` and
    `eventfd_write`, which do neither.
13. **The cross-platform layer stays a sketch** (below). Rejected: shipping
    it in System.

## The cross-platform sketch

`ReadinessQueue.swift` is a multi-platform enum, as `Next/Vision.md`'s
fourth direction suggests: one case per platform, wrapping that platform's
owner, with the operations that both kqueue and epoll can implement hosted
on the enum, and cross-platform code (`echoOnce`) that never names either.
It compiles on both, through SIL: `check.sh` for the kqueue half and
`check-linux.sh` for the epoll half. What it shows:

- **A Linux case needs two owners.** kqueue wakes a waiting thread with a
  user event, but epoll needs an eventfd it watches, so the epoll case holds
  an `EventPoll` and an `EventCounter`. A case with two noncopyable payloads
  fails a borrowing `switch` in Swift 6.2 with "copy of noncopyable typed
  value. This is a compiler bug" (`Verify/two_owner_case.swift` reproduces
  it), so they're one struct, which also has to close both.
- **Interest bookkeeping.** kqueue registers each filter separately, and
  epoll one mask per descriptor, so changing a registration needs the old
  interest, as NIO's selector passes it.
- **Translation.** The platforms' events have different types, so a
  portable wait can't write into a caller's `OutputSpan<Readiness>`: it
  waits into a buffer of its own and translates, and kqueue reports a
  descriptor that's readable and writable as two events.
- **Precision.** kevent's timeout is a `timespec`, and `epoll_wait`'s is in
  milliseconds, which is why NIO arms a timerfd on Linux.
- **Mapping.** End of file and errors are `EV_EOF` and a socket error in
  `fflags` on one, and `EPOLLRDHUP`, `EPOLLHUP`, and `EPOLLERR` on the other.

Each of these is a policy that an event loop library chooses, and NIO and
swift-subprocess have already chosen differently. So System should ship the
per-platform primitives, which is what both need from it, and leave the
selector to them.

## Windows: what I/O completion ports would need

Out of scope, but the sketch has no Windows case for a reason: IOCP reports
completed I/O, not readiness. A caller starts an overlapped read or write
(`ReadFile`, `WSARecv`) and later dequeues its completion
(`GetQueuedCompletionStatusEx`), so nothing on Windows implements "wait until
this descriptor is readable" except `WSAPoll`, which NIO's Windows selector
uses and which scales poorly, and the undocumented `\Device\Afd` polling that
libuv, mio, and wepoll use. An `IOCompletionPort` would need:

- an owned `HANDLE` for the port (`CreateIoCompletionPort`), from the Win32
  handle types of `Next/Vision.md`'s fifth direction, and a way to associate
  other handles with it, each with a completion key;
- an owned `OVERLAPPED` per operation that can't be destroyed or moved while
  the operation is in flight, since the kernel writes to it after the call
  returns: a noncopyable pending-operation type, with `CancelIoEx`;
- buffers that stay alive until the completion, which `Span`'s scoped
  lifetimes can't express: owned buffers that the operation holds;
- `GetQueuedCompletionStatusEx` into an `OutputSpan` of `OVERLAPPED_ENTRY`,
  `PostQueuedCompletionStatus` for wake-ups, and
  `SetFileCompletionNotificationModes`;
- Win32 error codes (`GetLastError`, `WSAGetLastError`), not `Errno`.

## swift-nio's coverage

NIO's coverage mapping (then `Utilities/nio-coverage/mapping.ini`, now
`Utilities/adopter-coverage/mapping.ini`) listed each of NIO's event
interfaces as missing. This API would cover them as follows; nothing in
`Utilities/` changes here.

| entry | would be | by |
|---|---|---|
| `[kqueue]` | covered on Darwin; OpenBSD unverified | `KernelQueue` (`init`, `register`, `poll`, `registerAndPoll`), `KernelEvent`, and the `add`, `clear`, `delete`, `enable`, `endOfFile`, `error` flags, the `exceptional`, `read`, `user`, and `write` filters, and `userNoOperation`, `lowWatermark`, and `userTrigger` |
| `[epoll]` | covered, unverified | `EventPoll` (`init(options:)`, `add`, `modify`, `remove`, `wait`), `EventPoll.Event`, its `Mask` and `Data` |
| `[eventfd]` | covered, unverified | `EventCounter` (`init(initialValue:options:)`, `increment(by:)`, `read()`) |
| `[timerfd]` | covered, unverified | `IntervalTimer` (`init(clock:options:)`, `setSchedule(_:options:)`, `readExpirations()`), `Schedule` |
| `[poll]` | partial: Unix covered, `WSAPoll` missing | `FileDescriptor.poll(_:timeout:)`, `poll(for:timeout:)`, `PollEntry`, `PollEvents` |
| `[timespec]` | partial, as before, less kevent's timeout | kevent's timeout becomes a `Duration` |
| `[monotonic clock]` | still missing, less timerfd's clock | `IntervalTimer.Clock.monotonic` |

What NIO's selectors would still need, or have to write:

- **Changelists from stack storage.** NIO builds up to three kevents in a
  tuple (`KeventTriple`). `InlineArray.span` needs macOS 26, so on older
  systems NIO would pass `Span(_unsafeElements:)` over its tuple, or make
  one `register` call per change.
- **Its event buffer.** NIO's growable `UnsafeMutablePointer<kevent>`
  storage becomes `KernelEvent` storage, wrapped in an `OutputSpan` for each
  wait: three lines, unsafe.
- **Closing under a lock.** A class can't consume its stored property, so
  NIO's `Selector` would hold `KernelQueue?` and `take()` it in `close0`,
  while `wakeup0` on another thread borrows it under the lock it already
  takes.
- **Its conventions.** NIO turns `Errno` into `IOError`, and traps on
  `EBADF` and `EFAULT`, where System throws.
- **io_uring.** The opt-in io_uring selector issues only polls
  (`[io_uring polls]`), which `IORing` doesn't have.
- **Windows.** The `WSAPoll` selector.

swift-subprocess needs the same kqueue and epoll surface, with
`EVFILT_PROC`, `NOTE_EXIT`, and `EV_ONESHOT` (covered, and tested on a child
process here), FreeBSD's `EVFILT_PROCDESC` (`processDescriptor`,
unverified), and `epoll_pwait` with an empty mask (`wait(into:timeout:signalMask:)`).
It also needs pidfds and signalfd, which are outside this prototype.

## What's unverified

Nothing here builds for anything but macOS, so:

- **Linux and Android** (`EventPoll`, `EventCounter`, `IntervalTimer`, the
  Linux constants, `PollEvents.readHangUp`, their tests, and the Linux
  half of `events-loop`) have never run. `check-linux.sh` typechecks them,
  and compiles the clients through SIL, against `LinuxModel/LinuxModel.h`,
  once with glibc's declarations and once with Bionic's nullability. It
  catches Swift errors, not the model's differences from a real C library:
  the packed `epoll_event` on x86_64, the constants' values, and each C
  library's feature macros are checked only by reading their headers.
- **MemberImportVisibility on Linux.** glibc's module doesn't include
  `<sys/epoll.h>`, so on glibc only CSystem's header declares `epoll_event`,
  and a client that enables MemberImportVisibility can't see its C members.
  `EventPoll.Event`'s properties cover them. The new probe checks
  `epoll_event` and `itimerspec` on musl and Bionic only.
- **FreeBSD and OpenBSD kqueue.** The members gated to them, FreeBSD's
  `kevent` with its `ext` field and 64-bit `data`, and OpenBSD's 64-bit
  `time_t`, come from their headers and from NIO's and swift-subprocess's
  code. OpenBSD's `EVFILT_USER` flags are inferred from NIO's use of
  `EVFILT_USER`, `NOTE_TRIGGER`, and `NOTE_FFNOP` there.
- **The CMake build** of the new files, which only CI runs on Linux.

## Files

| file | |
|---|---|
| `README.md` | This design record. |
| `ReadinessQueue.swift` | The cross-platform sketch. |
| `check.sh` | Compiles the sketch's kqueue half through SIL, against the built package. |
| `check-linux.sh` | Compiles everything Linux against the model, twice. |
| `LinuxModel/` | The model: a header of the C declarations that the Linux code calls, and its module map. |
| `Verify/two_owner_case.swift` | The Swift 6.2 move-checker bug that the sketch works around. Expected to fail. |
