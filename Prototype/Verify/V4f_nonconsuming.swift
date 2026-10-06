// V4f: `discard self` in a borrowing method. Expected to fail: "'discard' statement can only appear in consuming instance method".
struct NC: ~Copyable {
  var raw: Int32
  deinit {}
  borrowing func release() -> Int32 {
    discard self
    return raw
  }
}
