// V13a: a noncopyable pair of owners, as OwnedFD.Pipe is, taken apart by consuming each field, with `let` and with `var` fields, and with a `var` field replaced. Expected to compile and to print: took 4, close 4, read 3, close 3, took 6, close 6, read 5, close 5, close 8, replaced, close 7, close 9.
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("close \(raw)") }
}
struct LetPair: ~Copyable { let readEnd: Owned; let writeEnd: Owned }
struct VarPair: ~Copyable { var readEnd: Owned; var writeEnd: Owned }
func take(_ o: consuming Owned) { print("took \(o.raw)") }

func letSplit() {
  let p = LetPair(readEnd: Owned(raw: 3), writeEnd: Owned(raw: 4))
  take(p.writeEnd)
  print("read", p.readEnd.raw)
}
func varSplit() {
  let p = VarPair(readEnd: Owned(raw: 5), writeEnd: Owned(raw: 6))
  take(p.writeEnd)
  print("read", p.readEnd.raw)
}
func varReplace() {
  var p = VarPair(readEnd: Owned(raw: 7), writeEnd: Owned(raw: 8))
  p.writeEnd = Owned(raw: 9)   // closes 8
  print("replaced")
}

@main struct Main { static func main() { letSplit(); varSplit(); varReplace() } }
