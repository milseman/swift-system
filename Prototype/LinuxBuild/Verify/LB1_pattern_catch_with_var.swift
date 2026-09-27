// Swift 6.3.3 crashes (signal 11, in StackNesting::fixNesting during
// MandatoryAllocBoxToStack) compiling a pattern catch, such as
// `catch Errno.fileExists`, in a function that has a local var, even one
// the catch doesn't use. A string interpolation anywhere in the function
// counts, since it makes a mutable temporary. Swift 6.2 compiles it, and so
// does 6.3.3 without the var, with the do/catch in a function of its own,
// or with a catch-all that tests the error, as in `guard error == .a else
// { throw error }`. Found in Sources/Samples/Rename.swift, MkdirP.swift, and
// Touch.swift, on swift:6.3-noble.
//
//   swiftc -c -o /dev/null -swift-version 6 LB1_pattern_catch_with_var.swift

struct E: Error, Equatable { var code: Int32 }
extension E { static var a: E { E(code: 1) } }
func make() throws(E) {}

func f() throws -> Int {
  var n = 0
  n += 1
  do { try make() } catch E.a {}
  return n
}
