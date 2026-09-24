# `BorrowedFD`: still blocked with Swift 6.2

A `BorrowedFD` would be a nonescapable view whose lifetime depends on a
borrow of an `OwnedFD`. The claims checked here: it needs the experimental
`Lifetimes` feature in Swift 6.2, and it blocks consuming a local `let` owner
after borrowing it. The installed toolchain is Swift 6.2
(swiftlang-6.2.0.19.9), the same compiler the V6 snippets were first run
with. Every claim still holds. The new V14 snippets add a finding: a client
can't take a lifetime-dependent borrow of another module's static `let`. So
`OwnedFD.standardInput.borrowed` wouldn't compile in client code.

`BorrowedFD` isn't adopted. `borrowing OwnedFD` parameters remain the way to
lend an owner.

## The V5 and V6 snippets, rerun

With and without `-enable-experimental-feature Lifetimes`:

| snippet | with `Lifetimes` | without |
|---|---|---|
| V5a nonescapable enum | compiles | "an initializer cannot return a ~Escapable result" |
| V5b enum, no annotations | compiles | "an implicit initializer cannot return a ~Escapable result" |
| V5c enum over `Span`, local | compiles | compiles |
| V6a `@lifetime` spelling | "'@lifetime' attribute is only valid when experimental feature LifetimeDependence is enabled"; with that feature, a warning: "Unsupported use of @lifetime, use @_lifetime" | same |
| V6b valid uses | fails at `o.close()`: "noncopyable 'o' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type" | "a method cannot return a ~Escapable result" |
| V6c misuse | use after close and escape past the owner's scope: rejected. Returning the view from a `borrowing` function compiles, with the dependence inferred | as above |
| V6d escape to storage | class property and escaping closure: rejected, "lifetime-dependent variable ... escapes its scope". A `nil` global declaration compiles; V6g rejects storing into it | as above |
| V6e consume after last use | A (a consuming parameter, with the borrow in a local `let`): "'o' used after consume" and "overlapping accesses to 'o', but deinitialization requires exclusive access". B and C (a temporary, or an inner scope): compile. D (a local `let` owner): the V6b error | as above |
| V6f local owners | E (`var` owner) and G (`borrowing` helper): compile. F (`let` owner, borrow in an inner scope): the V6b error | as above |
| V6g global nonescapable | "lifetime-dependent value escapes its scope" | as above |
| V6h inferred dependence | the V6e-A errors | as above |
| V6i two candidates | "a function with a ~Escapable result requires '@_lifetime(...)'" | as above |

Without the feature, no declaration may return a `~Escapable` value: no
initializer, method, getter, or function. With it, the underscored
`@_lifetime` is the only spelling that works.

## New snippets

- `Prototype/Verify/V14a_crossmodule_borrowed/`: a library built with the
  feature, as SystemPackage is, vends a borrowed view. `main` enables
  `Lifetimes` too, so the package already requires it.
  - `ClientUse.swift` compiles *without* the feature: temporaries, locals,
    arguments, and a `var` owner. Code that only uses a vended `BorrowedFD`
    wouldn't need the feature.
  - `ClientReturn.swift`, a helper that returns the view, fails without the
    feature with "a function cannot return a ~Escapable result". It compiles
    with the feature. So any client wrapper or helper that produces a
    `BorrowedFD` needs the experimental feature.
  - `ClientConsumeLet.swift`: consuming a local `let` owner after a borrow
    that is only a temporary fails, with or without the feature. The same code
    through a `borrowing` helper compiles.
- `V14b_borrowedfd_owned_cat.swift`: a `BorrowedFD` over SystemPackage's real
  `OwnedFD`, used as the OwnedCat sample uses `borrowing OwnedFD`:
  - `cat` opens a file, copies it, and then calls `try file.close()`, OwnedCat's
    own pattern. It fails at the close.
  - `catVar` makes `file` a `var`, which compiles. But it warns "variable
    'file' was never mutated; consider changing to 'let' constant", and
    following the fix-it produces the error.
  - Every borrow of `OwnedFD.standardInput` or `standardOutput` fails with
    "lifetime-dependent value escapes its scope".
- `V14c_crossmodule_static_borrow/` and `V14d_samemodule_static_borrow.swift`
  narrow down that last failure:
  - Borrowing a view of another module's static `let` fails, even as a
    temporary (`Owned.standardInput.borrowed.read()`). It fails with or
    without the feature in the client, and with or without library evolution.
  - The same code within one module compiles (V14d).
  - Passing the static to a `borrowing` parameter first compiles.
  - So does an immortal static view, `Borrowed.standardInput`, declared
    `@_lifetime(immortal)` in the library. Standard input would need that
    form: an "owning but never closing" API that the static `let` had avoided
    for `OwnedFD`.

## What a `BorrowedFD` would add, and cost

`borrowing OwnedFD` parameters already make both of the promises
`Next/Vision.md` asks of a borrow. The caller keeps the descriptor open for
the call, and the callee can't close it or keep it. A `BorrowedFD` adds what a
parameter can't do:
- a borrow stored in a nonescapable struct or enum, such as the
  multi-platform enum's borrowed case (V5a, V6b)
- a borrow returned from a function
- a borrow of something that has no `OwnedFD`, such as an immortal standard
  input

Against that:
- **Experimental feature.** Every declaration that produces a `BorrowedFD`
  needs `@_lifetime`, in SystemPackage and in any client helper.
- **Owners that are local lets.** After any borrow, even one that has ended,
  the owner can't be consumed. That rules out closing explicitly to see the
  error (V14b), which `Prototype/CloseErrors` concluded is how close errors
  get reported. The `var` workaround draws a warning that undoes it.
- **Standard streams.** `OwnedFD.standardInput.borrowed` doesn't compile
  outside SystemPackage (V14c).
- **Forwarding.** A `BorrowedFD` that vended its `FileDescriptor` would let
  the copy escape, and so provide nothing ("a borrow needs an owner"). To be
  worth having, it would have to forward every operation itself: the
  38-member cost that `Prototype/Forwarding` rejects for `OwnedFD`, paid for
  a second type.

## Decision

Don't adopt `BorrowedFD` now. It needs the experimental feature, and in
Swift 6.2 it breaks two patterns that `OwnedFD` relies on: explicit `close()`
of a local owner, and the standard-stream statics. Revisit when three things
land:
- `@lifetime` is a supported feature
- the move checker lets an owner be consumed after the last use of a borrow
- cross-module borrows of a static `let` work

When it's revisited, its API should be settled together with the forwarding
question, since a useful `BorrowedFD` has to carry the operations itself.

Confidence: high.
