// V4e: `discard self` in a noncopyable type without a deinit.
struct NC: ~Copyable {
  var raw: Int32
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
