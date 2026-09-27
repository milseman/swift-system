# posix-more compiler checks

Each snippet checks one claim, stated in its opening comment, with Swift 6.2.
They import SystemPackage, so run `swift build` first. Use `-emit-sil`: the
move and lifetime checkers run in SIL, so `-typecheck` misses their errors.

```sh
swiftc -emit-sil -o /dev/null -swift-version 6 -enable-experimental-feature Lifetimes \
  -I .build/debug/Modules -Xcc -fmodule-map-file=Sources/CSystem/include/module.modulemap \
  Prototype/PosixMore/Verify/P1_entry_escape.swift
```

| Check | Claim | Result |
|---|---|---|
| `P1_entry_escape.swift` | A `NetworkInterface.Addresses.Entry`, or a span of its address, can't outlive the list | fails as expected: "lifetime-dependent variable 'entry' escapes its scope" |
| `P2_let_owner_span.swift` | A `let` noncopyable owner can't be consumed after a span borrowed it; `var` or a borrowing helper avoids it | fails only in `letOwner()`; `varOwner()` warns "never mutated" |
