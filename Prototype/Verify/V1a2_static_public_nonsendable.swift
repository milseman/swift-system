// V1a2: public noncopyable type (no implicit Sendable) in static storage, Swift 6 mode. Expected to fail at both declarations: "static property 'standardInput' is not concurrency-safe because non-'Sendable' type 'NC' may have shared mutable state" and "let 'globalLet' is not concurrency-safe because non-'Sendable' type 'NC' may have shared mutable state", with fix-its to make NC Sendable, add @MainActor, or add nonisolated(unsafe).
public struct NC: ~Copyable {
  public var raw: Int32
  public init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
}

public enum Holder {
  public static let standardInput: NC = NC(raw: 0)
}

public let globalLet: NC = NC(raw: 2)
