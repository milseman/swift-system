# Close errors in `OwnedFD`'s deinit

`deinit` can't throw, so an error from the implicit close has to be dropped,
turned into a trap, or avoided by requiring an explicit `close()`. This
directory compares the policies in use. `OwnedFD` now drops I/O errors and
traps on `EBADF`.

## Policies

| policy | deinit on a close error | precedent |
|---|---|---|
| drop | ignores it | `OwnedFD` before this change; `IORing`'s deinit ignores `close`'s result |
| trap | traps on any error | `Mach.Port`'s deinit (`_machPrecondition`) |
| must-close | traps whenever deinit runs, as a debug-build check | swift-subprocess's `IODescriptor` (`Configuration.swift:1110`), NIO's `SystemFileHandle` (`SystemFileHandle.swift:127`) |
| EBADF trap (chosen) | ignores I/O errors, traps on `EBADF` | Rust's `OwnedFd` (debug builds only); swift-subprocess's `_safelyClose` (`Configuration.swift:1022`, all builds) |

## The harness

`run.sh` builds `Kernel.swift`, `OwnedFD.swift`, `Scenarios.swift`, and
`main.swift` once per policy (`-D POLICY_...`) and runs each scenario in its own
process, so a trap ends only that scenario. `Kernel` is a stand-in descriptor
table that can make `close` or `write` fail. As on Linux and Darwin, a failed
close still releases the descriptor, and `open` reuses the lowest free number.
Each scenario follows a sample or test in the package. The `must-close:` rows
are the same code rewritten to satisfy the must-close policy.

```sh
./Prototype/CloseErrors/run.sh
```

Output with Swift 6.2 (swiftlang-6.2.0.19.9). "dropped" means a close error
that no code saw.

| scenario | modeled on | drop | trap | must-close | EBADF trap |
|---|---|---|---|---|---|
| explicit-close | OwnedCat, OwnedRedirect | ok | ok | ok | ok |
| explicit-close-fails | close() on NFS: EIO | threw ioError | threw ioError | threw ioError | threw ioError |
| scope-exit | OwnedCopy's input file | ok | ok | TRAP | ok |
| scope-exit-close-fails | a forgotten close() on NFS | ok; dropped ioError | TRAP | TRAP | ok; dropped ioError |
| body-throws | any throwing call before close() | threw noSpace | threw noSpace | TRAP | threw noSpace |
| body-throws-close-fails | testThrowingScopeDropsCloseError | threw noSpace; dropped ioError | TRAP | TRAP | threw noSpace; dropped ioError |
| closed-through-hatch | V10a, testClosingThroughWithDescriptorLeavesOwnerStale | ok; dropped badFileDescriptor | TRAP | TRAP | TRAP |
| closed-through-hatch-reused | V10a, with the number reused | threw badFileDescriptor; dropped badFileDescriptor | TRAP | TRAP | TRAP |
| adopted-twice | V10a adoptTwice | ok; dropped badFileDescriptor | TRAP | TRAP | TRAP |
| reassign | testReassignmentClosesPreviousDescriptor | ok | ok | TRAP | ok |
| optional-set-to-nil | testOptionalSetToNilCloses | ok | ok | TRAP | ok |
| consuming-parameter | testConsumingParameterClosesInCallee | ok | ok | TRAP | ok |
| loop-continue | OwnedCat's loop, skipping one file | ok | ok | TRAP | ok |
| inline-array-table | OwnedPoll | ok | ok | TRAP | ok |
| relinquish | OwnedLines (fdopen) | ok | ok | ok | ok |
| must-close: scope-exit | scope-exit | ok | ok | ok | ok |
| must-close: body-throws | body-throws-close-fails | threw noSpace | threw noSpace | threw noSpace | threw noSpace |
| must-close: reassign | reassign | ok | ok | ok | ok |
| must-close: optional-set-to-nil | optional-set-to-nil | ok | ok | ok | ok |
| must-close: inline-array-table | inline-array-table | ok | ok | ok | ok |

## The same policies on the package

`run-package.sh` patches each policy into a copy of
`Sources/System/OwnedFD.swift`, then runs the OwnedFD tests
(`OwnedFDTests`, `OwnedFDOwnershipTests`, and `WriteAllInterruptTests`, 26
methods) and the Owned samples, each in its own process:

| policy | tests (26) | samples |
|---|---|---|
| drop | 26 pass | all run |
| trap | 25 pass; `testThrowingScopeDropsCloseError` traps | all run |
| must-close | 16 pass; 10 trap (listed below) | `owned-copy` traps (its input is closed by scope exit); `owned-poll` traps (InlineArray table) |
| EBADF trap | 26 pass | all run |

The 10 tests that trap under must-close: `testDeinitClosesOnce`,
`testBorrowingUseDoesNotClose`, `testThrowingScopeDropsCloseError`,
`testDeinitClosesRealDescriptor`, `testWithDescriptorCanReturnOwnedFD`,
`testConsumingParameterClosesInCallee`,
`testReassignmentClosesPreviousDescriptor`, `testOptionalSetToNilCloses`,
`testRelinquishedDescriptorStaysOpen`, and
`testClosingThroughWithDescriptorLeavesOwnerStale`.

## Compiler checks

- `Prototype/Verify/V11a_defer_consume_let.swift`: `defer { try? fd.close() }` on
  a `let` owner fails with "noncopyable 'fd' cannot be consumed when captured
  by an escaping closure or borrowed by a non-Escapable type".
- `V11b_defer_consume_var.swift`: the same with a `var` fails with "missing
  reinitialization of closure capture 'fd' after consume".
- `V11c_defer_take_optional.swift`: an `Optional` owner emptied with `take()`
  in `defer` compiles, but it can only drop the close error.
- `V11d_close_on_both_paths.swift`: `do`/`catch` with a close on each path
  compiles. In a closure, this needs `do throws(Errno)`, or the caught error
  is `any Error`.
- `V11e_inlinable_deinit.swift`: `@inlinable` and `@_alwaysEmitIntoClient` are
  accepted on a deinit, and its body goes into the module interface. At run
  time the check still follows the library's configuration: with a library
  built `-O` and a client built `-Onone`, neither variant's `assert` fired.
  With both built `-Onone`, both fired.

## Decision

Drop I/O errors, as before, and trap on `EBADF` in every build.

- **Must-close is rejected: it is the guard that blocks legitimate cuts.**
  - It traps in 9 of the harness's 12 plain scenarios that use the owner
    correctly (and in the 3 that misuse it), in 10 of the 26 tests, and in 2
    of the 5 samples. These are the ways a noncopyable owner is meant
    to be used: scope exit, error unwinding, reassignment, `Optional`,
    consuming parameters, `continue`, and fixed-size tables.
  - The compiler can't find a missing close, so the policy works as a
    runtime lint, and only on the paths a program happens to run. Error
    paths are the least-run of those.
  - Satisfying it costs extra code: a `do`/`catch` for each throwing scope,
    because `defer` can't consume (V11a, V11b). An `InlineArray` table needs
    `Optional` slots emptied with `take()`, and each multi-descriptor type
    needs a close that aggregates errors. The `must-close: body-throws`
    rewrite still ends in `try? fd.close()`, which is what drop does without
    any extra code.
  - swift-subprocess and NIO use must-close for their own handle types, whose
    close is asynchronous or tied to kqueue/epoll registration. Those types
    could hold an `OwnedFD` and keep their own deinit check: a stricter policy
    can sit on top of a lenient owner, but a strict owner can't be made
    lenient.
- **Trap on every error is rejected.** Close errors like `EIO` and `ENOSPC`
  are real I/O errors. NFS reports delayed write failures at close. If the
  owner is destroyed while another error propagates, trapping replaces that
  error with a crash (`body-throws-close-fails`,
  `testThrowingScopeDropsCloseError`). `Mach.Port` can trap because a failed
  deallocation there is always a programming error. A failed close isn't.
- **`EBADF` is the one close error that is always a programming error.** It
  can't come from the file, only from the descriptor table. Something closed
  the descriptor behind its owner's back: `withDescriptor { $0.close() }`, two
  owners of one descriptor, or C code that took ownership. If the number had
  been reused first, the owner would have closed an unrelated file, with no
  error to report (`closed-through-hatch-reused`). No policy catches that
  case. Trapping on `EBADF` makes the detectable half visible.
- **Why every build, not only debug builds.** A debug-only check follows the
  build configuration of the module that compiles the deinit, and V11e shows
  that `@_alwaysEmitIntoClient` doesn't change this. In a release build of
  the library, such as System in the SDK, it would never fire. Mach.Port's
  deinit and swift-subprocess's `_safelyClose` also trap in every build. The
  check costs nothing, since it reads the result `close` already returns.
  Rust checks only in debug builds, because it checks with an extra
  `fcntl(F_GETFD)` before closing, and because a FUSE server can return
  `EBADF` from the flush that close performs. That FUSE case is the risk
  this choice accepts.
- **Relation to `closeAfter`.** Dropping in deinit gives `OwnedFD` the error
  semantics of `closeAfter(_:)` without the closure. When the body throws, its
  error propagates and the close error is dropped. On success, an explicit
  `try fd.close()` reports the close error. `OwnedFD` also rules out the
  double close that `closeAfter` permits (`testCloseAfterPermitsDoubleClose`),
  and its errors stay typed. So `closeAfter` needs no typed-throws redesign
  for owned descriptors.

Confidence: high that must-close and trap-on-every-error are wrong for a
general owner. Medium on trapping `EBADF` in release builds rather than only
in debug builds. Changing that is a one-line switch to `assertionFailure`,
which V11e shows would then check only debug builds of SystemPackage.

Tests: `Tests/SystemTests/OwnedFDDeinitTests.swift` checks the trap with
swift-testing exit tests: closing through `withDescriptor`, and adopting one
descriptor twice. Controls check that destroying an owner normally exits
cleanly, and that `close()` throws `EBADF` rather than trapping. Against the
drop policy, the two trap tests fail as expected.
