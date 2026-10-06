// V4c: `discard self` inside @inlinable / @_alwaysEmitIntoClient methods of @frozen and non-frozen public types. Built with library evolution, expected to compile, as a dylib with a module interface that verifies. The snapshot warns at ResilientNC.release(): "'discard' statement cannot be used in an '@inlinable' function inside of type 'ResilientNC', which is not '@frozen'; this will become an error".
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
