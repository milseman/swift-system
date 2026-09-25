// V16k: a generic helper whose result isn't `~Copyable`, such as
// `func typed<R>(_ body: () throws -> R) rethrows -> R`, given a closure
// that returns an owner, compiles in Swift 6.2 with only warnings: `R`
// becomes `()`, the closure's owner is discarded, and so destroyed, which
// for a file closes it. Platform.typed hit this until it declared
// `R: ~Copyable`.
// Expected: compiles with the warnings "result of call to 'open()' is
// unused" and "constant 'file' inferred to have type '()', which may be
// unexpected", then prints "closed 3" before "got ()". With -D FIXED,
// `R: ~Copyable` makes `file` the owner: "got 3", then "closed 3".
//   swiftc -swift-version 6 V16k_copyable_generic_drops_owner.swift -o /tmp/V16k && /tmp/V16k
//   swiftc -swift-version 6 -D FIXED V16k_copyable_generic_drops_owner.swift -o /tmp/V16k && /tmp/V16k
struct Owner: ~Copyable {
  let raw: Int32
  static func open() throws -> Owner { Owner(raw: 3) }
  deinit { print("closed \(raw)") }
}

#if FIXED
func typed<R: ~Copyable>(_ body: () throws -> R) rethrows -> R { try body() }
#else
func typed<R>(_ body: () throws -> R) rethrows -> R { try body() }
#endif

func main() throws {
  let file = try typed { try Owner.open() }
  #if FIXED
  print("got \(file.raw)")
  #else
  print("got \(file)")
  #endif
}

try main()
