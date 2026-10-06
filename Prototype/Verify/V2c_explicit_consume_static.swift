// V2c: explicit `consume` of a static `let`. Expected to fail: "'consume' can only be applied to a local binding ('let', 'var', or parameter)".
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

enum Holder {
  static let standardInput: NC = NC(raw: 0)
}

func attempt() { _ = consume Holder.standardInput }
