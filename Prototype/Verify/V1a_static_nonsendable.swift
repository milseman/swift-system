// V1a: noncopyable type (not Sendable) in static and global storage, Swift 6 mode.
struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

enum Holder {
  static let standardInput: NC = NC(raw: 0)
  static var mutableStatic: NC = NC(raw: 1)
}

let globalLet: NC = NC(raw: 2)
var globalVar: NC = NC(raw: 3)
