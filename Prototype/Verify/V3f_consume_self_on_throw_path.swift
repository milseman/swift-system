// V3f: in a method that discards self, the throw path explicitly consumes self instead (deinit runs there). Expected to compile and to print: rawClose(-1), deinit, rawClose(-1). It satisfies V3b's rule, but the deinit closes again after the failed close.
struct CloseError: Error {}
func rawClose(_ fd: Int32) -> Int32 { print("rawClose(\(fd))"); return fd < 0 ? -1 : 0 }

struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit"); _ = rawClose(raw) }
  consuming func close() throws(CloseError) {
    if rawClose(raw) != 0 {
      _ = consume self
      throw CloseError()
    }
    discard self
  }
}

@main struct Main {
  static func main() {
    let x = NC(raw: -1)
    try? x.close()
  }
}
