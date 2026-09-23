// V4a: `consuming func release() -> Int32` via `discard self`: returns the raw value, deinit does not run.
struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}

@main struct Main {
  static func main() {
    let x = NC(raw: 5)
    let raw = x.release()
    print("released \(raw)")
    let y = NC(raw: 6)
    _ = y
    print("end of main")
  }
}
