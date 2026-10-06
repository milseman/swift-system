// V1c: a computed static returning an owned noncopyable value is a temporary; deinit runs per access. Expected to compile and to print: deinit 0, peek: 0, deinit 0, peek again: 0, end of main. Each access makes a value and destroys it before `print` runs, so a computed standardInput owner would close descriptor 0 at its first use.
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
