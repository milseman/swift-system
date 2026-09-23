// V7f: read through a borrowed Optional of a noncopyable type via `switch`.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  borrowing func read() -> Int32 { raw }
}
func u5(_ maybe: borrowing Owned?) -> Int32 {
  switch maybe {
  case .some(let fd): return fd.read()
  case .none: return -1
  }
}
