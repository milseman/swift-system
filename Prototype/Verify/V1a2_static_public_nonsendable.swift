// V1a2: public noncopyable type (no implicit Sendable) in static storage, Swift 6 mode.
public struct NC: ~Copyable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

public enum Holder {
  public static let standardInput: NC = NC(raw: 0)
}

public let globalLet: NC = NC(raw: 2)
