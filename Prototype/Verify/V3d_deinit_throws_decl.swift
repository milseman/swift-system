// V3d: declaring the deinit itself as throwing. Expected to fail to parse: "expected '{' for deinitializer".
struct NC: ~Copyable {
  var raw: Int32
  deinit throws {}
}
