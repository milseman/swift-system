// V4c: `discard self` inside @inlinable / @_alwaysEmitIntoClient methods of @frozen and non-frozen public types.
@frozen public struct FrozenNC: ~Copyable {
  @usableFromInline internal var raw: Int32
  @inlinable public init(raw: Int32) { self.raw = raw }
  @inlinable deinit {}
  @inlinable public consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
  @_alwaysEmitIntoClient public consuming func release2() -> Int32 {
    let r = raw
    discard self
    return r
  }
}

public struct ResilientNC: ~Copyable {
  @usableFromInline internal var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit {}
  @inlinable public consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
