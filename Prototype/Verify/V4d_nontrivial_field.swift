// V4d: `discard self` in a type with a non-trivial stored property. Expected to fail: "can only 'discard' type 'NC' if it contains trivially-destroyed stored properties at this time", with a note "type 'Box' cannot be trivially destroyed".
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
