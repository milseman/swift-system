// V1a3: @frozen public noncopyable type in static storage, Swift 6 mode, library evolution.
@frozen public struct NC: ~Copyable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

public enum Holder {
  public static let standardInput: NC = NC(raw: 0)
}
