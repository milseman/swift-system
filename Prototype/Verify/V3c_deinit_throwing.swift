// V3c: calling a throwing close from deinit without handling the error.
struct CloseError: Error {}
func throwingClose(_ fd: Int32) throws(CloseError) {}

struct NC: ~Copyable {
  var raw: Int32
  deinit { try throwingClose(raw) }
}
