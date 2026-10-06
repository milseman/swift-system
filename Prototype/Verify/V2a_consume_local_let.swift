// V2a: a local `let` of a noncopyable type can be consumed. Expected to compile and to print: took 1, deinit 1, finish 2, deinit 2, deinit 3, end of main. A consuming parameter, a consuming method, and `_ = consume` each destroy the value before main ends.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  consuming func finish() { print("finish \(raw)") }
}

func take(_ x: consuming NC) { print("took \(x.raw)") }

@main struct Main {
  static func main() {
    let a = NC(raw: 1)
    take(a)
    let b = NC(raw: 2)
    b.finish()
    let c = NC(raw: 3)
    _ = consume c
    print("end of main")
  }
}
