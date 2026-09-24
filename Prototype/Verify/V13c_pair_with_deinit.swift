// V13c: a pair type with its own deinit can't be taken apart. Expected to fail: "cannot partially consume 'p' when it has a deinitializer". So OwnedFD.Pipe has no deinit, and destroying it destroys each end.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
struct Pair: ~Copyable {
  var readEnd: Owned
  var writeEnd: Owned
  deinit {}
}
func take(_ o: consuming Owned) {}
func split(_ p: consuming Pair) {
  take(p.writeEnd)
}
