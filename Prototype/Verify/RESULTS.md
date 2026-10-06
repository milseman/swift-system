# Verify: results for V1 to V5 and V7

`Next/Vision.md`'s "Verify with the compiler, not by reasoning" list was
checked with the V1 to V7 snippets, but the results for V1 to V4 and V7 were
never written down. These are those results, run on 2026-10-06 with two
compilers, and V5's again, for the snapshot. Each V1 to V4 and V7 snippet's
first line now states its result, in the V11 to V16 form. `check.sh` reruns
them all.

## Compilers

- **Swift 6.2**: Xcode's (`/usr/bin/swiftc`, from
  `Xcode_internal_latest_wonder.app`), the compiler the V11 to V16 snippets
  were run with. `swiftc --version`: `swift-driver version: 1.127.14.1 Apple
  Swift version 6.2 (swiftlang-6.2.0.19.9 clang-1700.3.19.1)`.
- **Snapshot**: `swift-DEVELOPMENT-SNAPSHOT-2026-09-21-a.xctoolchain` in
  `~/Library/Developer/Toolchains`, which `swift-latest.xctoolchain` links to.
  `swiftc --version`: `Apple Swift version 6.5-dev (LLVM a0a7653f4c0c1a0, Swift
  ac2207a7efaa55c)`, an assertions build.

Both target `arm64-apple-macosx26.0` with Xcode's `MacOSX26.0.sdk`, in the
Swift 6 language mode.

## Results

The snapshot gave the same results as Swift 6.2 except in three snippets:
V2b and V2e name the variable where 6.2 says 'unknown', and V4c adds a
warning. "Same" means the same diagnostics, word for word, or the same output.

| id | probes | Swift 6.2 | snapshot |
|---|---|---|---|
| V1a | a noncopyable type with no Sendable written, in a static and a global `let` and `var` | The `let`s compile: an internal struct of Sendable fields is implicitly Sendable. The `var`s fail: "static property 'mutableStatic' is not concurrency-safe because it is nonisolated global shared mutable state", and the same for "var 'globalVar'". | same |
| V1a2 | a public non-frozen type in a static and a global `let` | Fails at both: "static property 'standardInput' is not concurrency-safe because non-'Sendable' type 'NC' may have shared mutable state", and the same for "let 'globalLet'". | same |
| V1a3 | a `@frozen` public type in a static `let`, library evolution | Compiles: `@frozen` makes it implicitly Sendable. It compiles without library evolution too. | same |
| V1a4 | a public non-Sendable type in a `nonisolated(unsafe) static let` | Compiles, with no warning. | same |
| V1b | borrowing a Sendable static, a global, and a local; deinits at exit | Compiles. Prints peek: 0, borrowing param: 0, global let: 2, local: 9, end of main, deinit 9. | same |
| V1c | a computed static that returns an owner | Compiles. Prints deinit 0, peek: 0, deinit 0, peek again: 0, end of main: a value is made and destroyed on every access. | same |
| V1d Lib | the library: a public type with a static `let`, library evolution | Compiles, and its module interface verifies. | same |
| V1d Client | borrowing the static from another module | Compiles. Prints peek: 0, borrowing param: 0, take local: 7, end of main. | same |
| V1d ClientConsume | consuming the static from another module | Fails at both attempts: "'unknown' is borrowed and cannot be consumed". | same |
| V1d ClientDiscard | `discard self` in a client module's extension | Fails: "can only 'discard' from the same module defining type 'NC'". | same |
| V1e | whether FileDescriptor is Sendable, and a Sendable owner that stores one | Compiles. | same |
| V1f | the control: the probe rejects a class; the SDK's FileDescriptor | Fails at `control` only: "type 'NotSendable' does not conform to the 'Sendable' protocol". `sdk` compiles. | same |
| V2a | consuming local `let`s: by a consuming parameter, by a consuming method, and by `_ = consume` | Compiles. Prints took 1, deinit 1, finish 2, deinit 2, deinit 3, end of main. | same |
| V2b | consuming a static `let` in four ways | Fails at attempt1 to attempt3: "'unknown' is borrowed and cannot be consumed". attempt4, `_ =`, compiles. | Fails at the same three: "'standardInput' is borrowed and cannot be consumed". |
| V2c | `consume` of a static `let` | Fails: "'consume' can only be applied to a local binding ('let', 'var', or parameter)". | same |
| V2d | `_ =` of a static `let`; reassigning a static `var` | Compiles. Prints after `_ = Holder.standardInput`, deinit 100, after reassigning static var, end of main. | same |
| V2e | consuming a global `let` | Fails: "'unknown' is borrowed and cannot be consumed". | Fails: "'globalStandardInput' is borrowed and cannot be consumed". |
| V3a | a throwing consuming `close()` that runs `discard self` first, alongside a deinit | Compiles. Prints closed 3, error -1, end of main: the deinit runs on neither path. | same |
| V3b | throwing before `discard self` | Fails: "must consume 'self' before exiting method that discards self". | same |
| V3c | a throwing call in a deinit | Fails: "errors thrown from here are not handled". | same |
| V3d | `deinit throws` | Fails to parse: "expected '{' for deinitializer". | same |
| V3e | a consuming `close()` without `discard self` | Compiles with no diagnostic. Prints rawClose(3), deinit, rawClose(3): a second close. | same |
| V3f | consuming `self` on the throw path instead | Compiles. Prints rawClose(-1), deinit, rawClose(-1): the deinit closes again. | same |
| V4a | `release()` through `discard self` | Compiles. Prints released 5, end of main, deinit 6. | same |
| V4b | `discard self` in an extension in another file of the module | Compiles. | same |
| V4c Frozen | `discard self` in `@inlinable` and `@_alwaysEmitIntoClient` methods of a frozen and a non-frozen type, library evolution | Compiles, and its module interface verifies. | Compiles, with a warning at `ResilientNC.release()`: "'discard' statement cannot be used in an '@inlinable' function inside of type 'ResilientNC', which is not '@frozen'; this will become an error". |
| V4c Client | calling those methods from another module | Compiles. Prints 1, 2, 3. | same |
| V4d | `discard self` in a type with a class field | Fails: "can only 'discard' type 'NC' if it contains trivially-destroyed stored properties at this time". | same |
| V4e | `discard self` in a type with no deinit | Fails: "'discard' has no effect for type 'NC' unless it has a deinitializer". | same |
| V4f | `discard self` in a borrowing method | Fails: "'discard' statement can only appear in consuming instance method". | same |
| V7a | consuming a `borrowing` parameter in six ways, and one valid read | Fails at m1, m2, m3, and m9: "'fd' is borrowed and cannot be consumed". Fails at m6 (a non-escaping closure) and m8 (`defer`): "noncopyable 'fd' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type". m7 compiles. | same |
| V7b | capturing a `borrowing` parameter in an escaping closure | Fails: "'fd' cannot be captured by an escaping closure since it is a borrowed parameter". | same |
| V7c | `consume` of a `borrowing` parameter, to store it | Fails: "'fd' is borrowed and cannot be consumed". | same |
| V7d | type-checker misuse: no ownership modifier, a Copyable generic, an Array, a Dictionary | Fails at all four: "parameter of noncopyable type 'Owned' must specify ownership", "global function 'generic' requires that 'Owned' conform to 'Copyable'", and "type 'Owned' does not conform to protocol 'Copyable'" twice. | same |
| V7e | owned-local misuse: use after close, close in a loop, `if let` | Fails at u1: "'fd' used after consume". At u2: "'fd' consumed in a loop". At u4: "'maybe' is borrowed and cannot be consumed". u3 compiles. | same |
| V7f | a borrowing `switch` over a borrowed Optional | Compiles. | same |
| V7g | storing a `borrowing` parameter into an Optional | Fails at both: "implicit conversion to 'Owned?' is consuming", with a fix-it to add `consume`. | same |

### V5, rerun for question 5

V5's first lines are unchanged. Its 6.2 results were already in
`Prototype/BorrowedFD/README.md`, and match these.

| id | probes | Swift 6.2 | snapshot |
|---|---|---|---|
| V5a | a `~Escapable` enum over a `~Escapable` struct, built with `@_lifetime` | Without `Lifetimes`, fails: "an initializer cannot return a ~Escapable result", "a function cannot return a ~Escapable result", and "'@_lifetime' attribute is only valid when experimental feature Lifetimes is enabled". With it, compiles. | same |
| V5b | the same declarations, with no annotations | Without `Lifetimes`, fails at the struct: "an implicit initializer cannot return a ~Escapable result". With it, compiles. | same |
| V5c | an enum over `Span`, made and switched over locally | Compiles, with or without `Lifetimes`. | same |

## The vision doc's questions

1. **Noncopyable statics.** SE-0390's restriction is gone in both
   compilers: a noncopyable `static let` or global `let` compiles, is
   borrowed in its own module and from others, and is never destroyed (V1b,
   V1d), so `static let standardInput: OwnedFD` works. Swift 6 adds that the
   type must be Sendable, as internal and `@frozen` public types are
   implicitly (V1a, V1a3) and non-frozen public ones aren't (V1a2), or the
   declaration must say `nonisolated(unsafe)`, as a `static var` must anyway
   (V1a4, V1a, V2d); a computed static instead makes and closes an owner on
   every access (V1c).
2. **Consuming a `let`.** A local `let` can be consumed (V2a), but no use of
   a static or global `let` can consume it, in either compiler, from the
   same module or another (V2b, V2c, V2e, V1d ClientConsume). `_ =
   Holder.standardInput` compiles and destroys nothing (V2b, V2d), so the
   stdin trick holds.
3. **`consuming close() throws` with a `deinit`.** It compiles cleanly when
   `close()` runs `discard self` before the call that can fail: the deinit
   then runs on neither path and the error reaches the caller (V3a), while
   throwing first is rejected (V3b), and consuming `self` on the throw path
   (V3f) or leaving out `discard self` (V3e) compiles but closes twice. A
   deinit can neither throw nor let an error out (V3c, V3d), so only an
   explicit `close()` can report a close error; the implicit one can only
   drop it or trap.
4. **`discard self` to release.** Yes: `release()` returns the raw value
   without running the deinit (V4a), from any file of the type's module (V4b)
   and from `@inlinable` or `@_alwaysEmitIntoClient` methods of a `@frozen`
   type called from another module (V4c), which is how `OwnedFD.relinquish()`
   is declared. It's allowed only in a consuming method (V4f) of a type with a
   deinit (V4e) and only trivially destroyed stored properties (V4d), in the
   type's own module (V1d ClientDiscard), and the snapshot warns that in an
   `@inlinable` method of a non-frozen type it "will become an error" (V4c).
5. **Nonescapable enums.** They exist: with no experimental feature, a
   `~Escapable` enum can be declared, made from a view at hand such as a
   `Span` parameter, and switched over (V5c). But in both compilers no
   initializer or function can return a `~Escapable` value without
   `-enable-experimental-feature Lifetimes`, so a payload type of one's own,
   such as a borrowed descriptor, can't be made without it (V5a, V5b); V16g,
   run with 6.2 only, adds that with the feature, a `let` owner can't be
   closed after it has been borrowed.
6. **Diagnostics for borrowed misuse.** The common mistakes get a precise
   error with a "consumed here" note in both compilers: closing, passing,
   rebinding, returning, or escaping a borrowed parameter (V7a, V7b, V7c),
   using an owner after closing it or in a loop (V7e), and the type checker's
   missing-ownership and Copyable errors (V7d). The weak spots: consuming in a
   non-escaping closure or `defer` blames "an escaping closure or ... a
   non-Escapable type" (V7a m6, m8), storing into an Optional offers an "add
   `consume`" fix-it that leads to a second error (V7g, V7c), `if let` on a
   borrowed Optional points at the `if` when `switch` is the fix (V7e u4,
   V7f), and 6.2 calls a static or global 'unknown', which the snapshot fixes
   except across modules (V2b, V2e, V1d ClientConsume).

The vision doc's other item, the status of lifetime dependence generally, is
V6 and V14, in `Prototype/BorrowedFD/README.md`. It wasn't rerun here.

## Lane notes

**How the snippets were compiled.** `check.sh [name [swiftc [SystemPackage
scratch path]]]` compiles every snippet listed above with one compiler, and
runs the ones that print. Its header has the commands for both compilers.
- Every compile uses `-swift-version 6 -parse-as-library`. None of these
  snippets has top-level code, the `@main` ones need the flag, and it makes
  the globals real globals, as in a library. The V11 to V16 recipes use it for
  their `@main` snippets.
  - In script mode, V1a's global `var` is a main-actor top-level variable and
    compiles. Its static `var` fails either way. `check.sh` shows both.
- Snippets that only need to compile are compiled with `-emit-sil -o
  /dev/null`, as in the V11 to V16 recipes, since the move checker runs in
  SIL. V4b's two files are compiled as one module, with `-wmo`.
- Snippets that print are built into executables and run.
- Each cross-module library (V1d, V4c) is built with
  `-enable-library-evolution`, as its comment says, as a dylib with its
  module and a module interface (`-verify-emitted-module-interface`). Its
  clients link against it, with an rpath.
- V1e compiles against SystemPackage, built by the same compiler into
  `.build/verify/spm-<name>`. The snapshot's SwiftPM needs `--build-system
  native`: its default build system stops with "platform 'linux' with name
  'linux' already registered", for Xcode's Linux platform.
- `-sdk` is passed explicitly, since the snapshot's driver picks no SDK by
  itself here.
- Diagnostics are in the `llvm` style, one line per diagnostic. The quotes
  above and on the first lines are word for word.
- The binaries ran against the OS's Swift runtime. The snapshot's printed the
  same against the toolchain's runtime (`DYLD_LIBRARY_PATH`).
- Build products went in `.build/verify/`, and were deleted at the end.

**Surprises.**
- FileDescriptor is Sendable (V1e, V1f). `Next/Vision.md`'s "Already
  answered" section says SocketDescriptor "is `Sendable` while
  `FileDescriptor` is not". In fact the SDK's System interface declares
  `extension System.FileDescriptor : Swift.Sendable {}`, a `@frozen` public
  struct of a CInt gets the conformance implicitly (V1a3), and SystemPackage
  has declared it explicitly since `b631444`.
- `_ = x` doesn't consume a noncopyable local: V4a's `y` lives to the end of
  `main`. `_ = consume x` does (V2a). On a static `let`, `_ =` is a no-op
  (V2b, V2d).
- A computed static's temporary is destroyed before the `print` that uses it
  runs: V1c prints "deinit 0" before "peek: 0".
- The snapshot's new `discard` warning (V4c) doesn't reach `OwnedFD`. That
  type is `@frozen`, and its `close()` and `relinquish()` are
  `@_alwaysEmitIntoClient`, like V4c's `FrozenNC.release2()`, which draws no
  warning.
- V1a's description said its type was "(not Sendable)", but it's implicitly
  Sendable, so its first line now says "with no Sendable conformance
  written". `V1d_crossmodule/ClientDiscard.swift` called itself "V4", and now
  says "V1d client, for V4". The other descriptions are unchanged, and their
  predictions held.

**Needs outside this lane's files.**
- `Next/Vision.md`: the sentence that FileDescriptor isn't Sendable (see
  Surprises). It's another session's file.
- V5, V6, V9, V10b, and V10c still have only a description on their first
  line, and the V10d files have none. V5's and V6's results are in
  `Prototype/BorrowedFD/README.md`.
- In passing, and not checked here: V14b's first line says
  `catStandardStreams` "borrows the static lets, and compiles", while
  `369561e` and `Prototype/BorrowedFD/README.md` say every borrow of
  `OwnedFD.standardInput` or `standardOutput` fails.
