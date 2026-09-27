// Swift 6.3.3 crashes (signal 11, in StackNesting::fixNesting during
// ClosureLifetimeFixup) compiling a catch whose where clause uses ||, which
// makes its right-hand side an autoclosure. Swift 6.2 compiles it, and so
// does 6.3.3 with the || in the catch's body, or with a switch. Found in
// Sources/Samples/RmR.swift, on swift:6.3-noble.
//
//   swiftc -c -o /dev/null -swift-version 6 LB2_catch_where_or.swift

struct E: Error, Equatable { var code: Int32 }
extension E { static var a: E { E(code: 1) }; static var b: E { E(code: 2) } }
func open() throws(E) -> Int32 { 3 }

func f() throws -> Int32? {
  do { return try open() }
  catch let e where e == .a || e == .b { return nil }
}
