// V9c: a noncopyable struct holding two noncopyable fields, split by consuming each field.
struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}
struct Pair: ~Copyable {
  var readEnd: NC
  var writeEnd: NC
}
func pair() -> Pair { Pair(readEnd: NC(raw: 3), writeEnd: NC(raw: 4)) }
func take(_ x: consuming NC) { print("took \(x.raw)") }

@main struct Main {
  static func main() {
    let p = pair()
    let r = p.readEnd
    let w = p.writeEnd
    take(w)
    print("r", r.raw)
  }
}
