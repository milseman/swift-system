// V1b: noncopyable + Sendable in static storage; borrow it; check deinit at exit.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  borrowing func peek() -> Int32 { raw }
}

enum Holder {
  static let standardInput: NC = NC(raw: 0)
}

let globalLet: NC = NC(raw: 2)

func use(_ x: borrowing NC) -> Int32 { x.peek() }

@main struct Main {
  static func main() {
    print("peek:", Holder.standardInput.peek())
    print("borrowing param:", use(Holder.standardInput))
    print("global let:", use(globalLet))
    let local = NC(raw: 9)
    print("local:", use(local))
    print("end of main")
  }
}
