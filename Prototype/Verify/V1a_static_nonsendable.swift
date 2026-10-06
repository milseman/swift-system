// V1a: noncopyable type with no Sendable conformance written, in static and global storage, Swift 6 mode. Expected: the `let`s compile, since an internal struct of Sendable fields is implicitly Sendable; the `var`s fail with "static property 'mutableStatic' is not concurrency-safe because it is nonisolated global shared mutable state" and "var 'globalVar' is not concurrency-safe because it is nonisolated global shared mutable state". Compiled without -parse-as-library, the global `var` is a main-actor top-level variable instead, and only the static fails.
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
