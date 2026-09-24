// V11e: `@inlinable` and `@_alwaysEmitIntoClient` on the deinit of a @frozen noncopyable struct, built with library evolution. Expected to compile, with the deinit's body in the module interface. A debug-only check in the deinit follows the configuration of whichever module compiles that body, so in the release-built System in the SDK it would fire only where a client emitted the deinit itself.
// Build: swiftc -emit-module -enable-library-evolution -module-name V11e -emit-module-interface-path /tmp/V11e.swiftinterface -o /tmp/V11e.swiftmodule V11e_inlinable_deinit.swift
@frozen public struct InlinableDeinit: ~Copyable {
  @usableFromInline var raw: Int32
  @inlinable public init(raw: Int32) { self.raw = raw }
  @inlinable deinit { assert(raw >= 0, "negative descriptor") }
}

@frozen public struct AlwaysEmittedDeinit: ~Copyable {
  @usableFromInline var raw: Int32
  @inlinable public init(raw: Int32) { self.raw = raw }
  @_alwaysEmitIntoClient deinit { assert(raw >= 0, "negative descriptor") }
}
