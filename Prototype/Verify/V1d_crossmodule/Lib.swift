// V1d library: public noncopyable type with a static let, built with library evolution. Expected to compile, as a dylib with a module interface that verifies (check.sh builds it and links Client.swift against it).
public struct NC: ~Copyable, Sendable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  public borrowing func peek() -> Int32 { raw }
  public consuming func take() -> Int32 { let r = raw; discard self; return r }
}

extension NC {
  public static let standardInput: NC = NC(raw: 0)
}
