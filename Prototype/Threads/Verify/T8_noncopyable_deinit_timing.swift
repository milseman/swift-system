// T8: a noncopyable local's deinit runs at the end of its scope, in reverse order of declaration, not after its last use, including when an error ends the scope. Expected to print the same order at -Onone and -O: "deinit b" and "deinit a" after "end of scope", and "deinit c" after "about to throw". So a PThread whose deinit joins is joined at the end of the scope that created it.
// Run: swiftc -swift-version 6 -O T8_noncopyable_deinit_timing.swift -o /tmp/T8 && /tmp/T8
final class Log: @unchecked Sendable { var lines: [String] = [] }
let log = Log()

struct Owner: ~Copyable {
  let name: String
  deinit { log.lines.append("deinit \(name)") }
  borrowing func use() { log.lines.append("use \(name)") }
}

@inline(never) func work(_ s: String) { log.lines.append(s) }

func f() {
  let a = Owner(name: "a")
  a.use()
  work("after last use of a")
  let b = Owner(name: "b")
  work("b never used")
  _ = b
  work("end of scope")
}

func g() throws {
  let c = Owner(name: "c")
  c.use()
  struct E: Error {}
  work("about to throw")
  throw E()
}

f()
try? g()
print(log.lines.joined(separator: "\n"))
