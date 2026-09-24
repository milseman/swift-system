// V13b library: a frozen and a non-frozen public pair of noncopyable owners.
// Build it without and with library evolution:
//   swiftc -emit-module -module-name Lib -o /tmp/V13b/Lib.swiftmodule Lib.swift
//   swiftc -emit-module -enable-library-evolution -module-name Lib -o /tmp/V13b/Lib.swiftmodule Lib.swift
public struct Owned: ~Copyable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit {}
}

@frozen public struct FrozenPair: ~Copyable {
  public var readEnd: Owned
  public var writeEnd: Owned
  @inlinable public init(readEnd: consuming Owned, writeEnd: consuming Owned) {
    self.readEnd = readEnd
    self.writeEnd = writeEnd
  }
}

public struct ResilientPair: ~Copyable {
  public var readEnd: Owned
  public var writeEnd: Owned
  public init(readEnd: consuming Owned, writeEnd: consuming Owned) {
    self.readEnd = readEnd
    self.writeEnd = writeEnd
  }
}
