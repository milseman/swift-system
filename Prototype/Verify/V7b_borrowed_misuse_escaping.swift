// V7b: capture a `borrowing` noncopyable parameter in an escaping closure.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  borrowing func read() -> Int32 { raw }
}
func withEscaping(_ body: @escaping () -> Void) {}
func m(_ fd: borrowing Owned) { withEscaping { _ = fd.read() } }
