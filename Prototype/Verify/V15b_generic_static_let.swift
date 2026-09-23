// V15b: a static stored property of a generic noncopyable owner, as a generic owner's standard input would need. Expected: the same-type-constrained extension compiles; the unconstrained one fails with "static stored properties not supported in generic types".
struct FD: Sendable { var raw: Int32 }

struct Owned<Descriptor: Sendable>: ~Copyable, Sendable {
  let descriptor: Descriptor
  deinit {}
}

extension Owned where Descriptor == FD {
  static let standardInput = Owned(descriptor: FD(raw: 0))
}

extension Owned {
  static let unconstrained: Int = 0
}
