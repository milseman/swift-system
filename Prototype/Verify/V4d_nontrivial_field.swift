// V4d: `discard self` in a type with a non-trivial stored property.
final class Box {}
struct NC: ~Copyable {
  var raw: Int32
  var box: Box
  deinit {}
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
