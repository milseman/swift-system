// V15a: `discard self` in a generic noncopyable owner whose stored property has the generic type. Expected to fail at both `relinquish` methods, even with a BitwiseCopyable constraint: "can only 'discard' type 'Owner<Descriptor>' if it contains trivially-destroyed stored properties at this time". The version that stores a concrete type compiles; Prototype/Subtypes/GenericOwner.swift uses it.
protocol Kind { init(raw: Int32); var raw: Int32 { get } }

struct Owner<Descriptor: Kind>: ~Copyable {
  let descriptor: Descriptor
  deinit {}
  consuming func relinquish() -> Descriptor { let d = descriptor; discard self; return d }
}

struct BitwiseOwner<Descriptor: Kind & BitwiseCopyable>: ~Copyable {
  let descriptor: Descriptor
  deinit {}
  consuming func relinquish() -> Descriptor { let d = descriptor; discard self; return d }
}

struct ConcreteStorageOwner<Descriptor: Kind>: ~Copyable {
  let raw: Int32
  deinit {}
  consuming func relinquish() -> Descriptor { let r = raw; discard self; return Descriptor(raw: r) }
}
