// V1a4: public non-Sendable noncopyable type in static storage with nonisolated(unsafe).
public struct NC: ~Copyable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

public enum Holder {
  nonisolated(unsafe) public static let standardInput: NC = NC(raw: 0)
}
