// V14c library: an owner with a static `let`, as OwnedFD.standardInput is,
// and a borrowed view with an immortal static for standard input.
//   swiftc -emit-module -parse-as-library -enable-experimental-feature Lifetimes \
//     -module-name Lib -o /tmp/V14c/Lib.swiftmodule Lib.swift
public struct Owned: ~Copyable, Sendable {
  public let raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit {}
  public var borrowed: Borrowed {
    @_lifetime(borrow self)
    borrowing get { Borrowed(self) }
  }
  public static let standardInput = Owned(raw: 0)
}

public struct Borrowed: ~Escapable {
  public let raw: Int32
  @_lifetime(borrow owner)
  public init(_ owner: borrowing Owned) { raw = owner.raw }
  @_lifetime(immortal)
  internal init(immortal raw: Int32) { self.raw = raw }
  public func read() -> Int32 { raw }

  /// Standard input, which no owner closes, so the borrow never ends.
  public static var standardInput: Borrowed {
    @_lifetime(immortal)
    get { Borrowed(immortal: 0) }
  }
}
