// V16a library: a multi-platform enum as System would vend it: unowned and
// owned (noncopyable) forms, not frozen, with a static let standard input.
// SwiftPM builds SystemPackage without library evolution; the SDK's System
// module is built with it. Build both ways, and a v2 that adds a case:
//   mkdir -p /tmp/V16a/plain /tmp/V16a/evolving
//   swiftc -swift-version 6 -emit-module -module-name Lib -o /tmp/V16a/plain/Lib.swiftmodule Lib.swift
//   swiftc -swift-version 6 -emit-module -enable-library-evolution -module-name Lib -o /tmp/V16a/evolving/Lib.swiftmodule Lib.swift
public struct Owner: ~Copyable, Sendable {
  public let raw: Int32
  public init(raw: Int32) { self.raw = raw }
  public borrowing func read() -> Int32 { raw }
  deinit { print("closed \(raw)") }
}

/// The unowned form: a name, copyable.
public enum Name: Sendable {
  case fd(Int32)
}

/// For contrast: a frozen enum is exhaustive to clients even with library evolution.
@frozen public enum FrozenName: Sendable {
  case fd(Int32)
}

/// The owned form: a noncopyable enum whose case wraps an owner.
public enum File: ~Copyable, Sendable {
  case fd(Owner)
  #if V2
  /// A case that a later version of the library adds.
  case handle(Owner)
  #endif

  public static let standardInput = File.fd(Owner(raw: 0))

  public static func open(_ raw: Int32) -> File {
    #if V2
    if raw.isMultiple(of: 5) { return .handle(Owner(raw: raw)) }
    #endif
    return .fd(Owner(raw: raw))
  }
}
