// V2d: `_ = static let` at runtime, and reassigning a `static var` (runs deinit on the old value). Expected to compile and to print: after `_ = Holder.standardInput`, deinit 100, after reassigning static var, end of main. `_ =` destroys nothing, and the replacement is never destroyed.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

enum Holder {
  static let standardInput: NC = NC(raw: 0)
  nonisolated(unsafe) static var mutableStandardInput: NC = NC(raw: 100)
}

@main struct Main {
  static func main() {
    _ = Holder.standardInput
    print("after `_ = Holder.standardInput`")
    _ = Holder.mutableStandardInput.raw
    Holder.mutableStandardInput = NC(raw: 101)
    print("after reassigning static var")
    print("end of main")
  }
}
