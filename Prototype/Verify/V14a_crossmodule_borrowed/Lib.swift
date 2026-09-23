// V14a library: an owner that vends a lifetime-dependent borrowed view, as a
// BorrowedFD would be vended by OwnedFD. Built with the experimental feature,
// as SystemPackage already is:
//   swiftc -emit-module -enable-experimental-feature Lifetimes -module-name Lib \
//     -o /tmp/V14a/Lib.swiftmodule Lib.swift
public struct Owned: ~Copyable {
  public let raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit {}
  public consuming func close() { discard self }

  public var borrowed: Borrowed {
    @_lifetime(borrow self)
    borrowing get { Borrowed(self) }
  }
}

public struct Borrowed: ~Escapable {
  public let raw: Int32
  @_lifetime(borrow owner)
  public init(_ owner: borrowing Owned) { self.raw = owner.raw }
  public func read() -> Int32 { raw }
}
