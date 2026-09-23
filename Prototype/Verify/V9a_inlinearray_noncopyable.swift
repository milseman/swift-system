// V9a: InlineArray of a noncopyable element type, as an fd table.
struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

@available(macOS 26, *)
func table() {
  var t: InlineArray<3, NC> = InlineArray { i in NC(raw: Int32(i)) }
  for i in t.indices { print("slot", t[i].raw) }
  t[1] = NC(raw: 10)          // replaces slot 1; old value destroyed
  print("end of table()")
}

@main struct Main {
  static func main() {
    if #available(macOS 26, *) { table() }
  }
}
