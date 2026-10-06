// V2e: consuming a global (non-static) `let`. Expected to fail: "'unknown' is borrowed and cannot be consumed" in Swift 6.2, and "'globalStandardInput' is borrowed and cannot be consumed" with the snapshot.
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
}
func take(_ x: consuming NC) {}
let globalStandardInput = NC(raw: 0)
func attempt() { take(globalStandardInput) }
