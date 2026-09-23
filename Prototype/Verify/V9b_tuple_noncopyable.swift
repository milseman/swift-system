// V9b: returning and destructuring a tuple of noncopyable values.
struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}
func pair() -> (readEnd: NC, writeEnd: NC) { (NC(raw: 3), NC(raw: 4)) }

@main struct Main {
  static func main() {
    let (r, w) = pair()
    print("r", r.raw, "w", w.raw)
    let p = pair()
    print("p.readEnd", p.readEnd.raw)
  }
}
