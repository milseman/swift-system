// V3d: declaring the deinit itself as throwing.
struct NC: ~Copyable {
  var raw: Int32
  deinit throws {}
}
