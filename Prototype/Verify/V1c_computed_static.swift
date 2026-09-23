// V1c: a computed static returning an owned noncopyable value is a temporary; deinit runs per access.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  borrowing func peek() -> Int32 { raw }
}

enum Holder {
  static var computedStandardInput: NC { NC(raw: 0) }
}

@main struct Main {
  static func main() {
    print("peek:", Holder.computedStandardInput.peek())
    print("peek again:", Holder.computedStandardInput.peek())
    print("end of main")
  }
}
