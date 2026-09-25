// Claim: in a noncopyable type that has a deinit and a stored property that
// isn't trivially destroyed, as DirectoryStream has, a throwing initializer
// can't assign `self` from a `try`, whether from a throwing call or from
// `Result.get()`: "conditional initialization or destruction of noncopyable
// types is not supported; this variable must be consistently in an
// initialized or uninitialized state through every code path". Delegating
// to a throwing initializer works, so DirectoryStream's public initializers
// delegate to `init(_fdopendir:closingOnFailure:)`.
// Expected to fail to compile in `init(assigning:)` and `init(result:)` only.
// Without the deinit, or without `names`, both compile.
struct E: Error {}
struct Stream: ~Copyable {
  var handle: Int
  var names: [CChar] = []
  init(handle: Int) { self.handle = handle }
  deinit {}
  static func make(_ handle: Int) throws(E) -> Stream { Stream(handle: handle) }
  static func result(_ handle: Int) -> Result<Stream, E> { .success(Stream(handle: handle)) }

  init(assigning handle: Int) throws(E) {
    self = try Stream.make(handle)
  }

  init(result handle: Int) throws(E) {
    self = try Stream.result(handle).get()
  }

  init(delegating handle: Int) throws(E) {
    try self.init(checking: handle)
  }
  init(checking handle: Int) throws(E) {
    guard handle >= 0 else { throw E() }
    self.init(handle: handle)
  }
}
