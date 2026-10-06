// V4e: `discard self` in a noncopyable type without a deinit. Expected to fail: "'discard' has no effect for type 'NC' unless it has a deinitializer", with a fix-it that removes it.
struct NC: ~Copyable {
  var raw: Int32
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
