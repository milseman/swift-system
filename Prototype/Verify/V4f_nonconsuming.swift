// V4f: `discard self` in a borrowing method.
struct NC: ~Copyable {
  var raw: Int32
  deinit {}
  borrowing func release() -> Int32 {
    discard self
    return raw
  }
}
