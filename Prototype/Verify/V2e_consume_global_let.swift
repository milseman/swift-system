// V2e: consuming a global (non-static) `let`.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
}
func take(_ x: consuming NC) {}
let globalStandardInput = NC(raw: 0)
func attempt() { take(globalStandardInput) }
