// V2b: attempts to consume a static `let` of a noncopyable type (move checker). Expected to fail at attempt1, attempt2, and attempt3: "'unknown' is borrowed and cannot be consumed" in Swift 6.2, and "'standardInput' is borrowed and cannot be consumed" with the snapshot. attempt4, `_ =`, compiles and destroys nothing (V2d).
struct NC: ~Copyable, Sendable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  consuming func finish() { print("finish \(raw)") }
}

enum Holder {
  static let standardInput: NC = NC(raw: 0)
}

func take(_ x: consuming NC) {}

func attempt1() { take(Holder.standardInput) }        // pass to consuming parameter
func attempt2() { Holder.standardInput.finish() }     // call consuming method
func attempt3() { let y = Holder.standardInput; _ = y } // bind to a new owner
func attempt4() { _ = Holder.standardInput }           // discard via `_ =`
