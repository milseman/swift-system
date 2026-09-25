// V16e2: `#if` can't wrap catch clauses, and an inactive `#if` block must
// still parse, so this fails on every platform, including those where the
// block is inactive. Platform-specific codes go in a `switch` inside a
// catch-all instead (V16e).
// Expected: "expected expression" at the `#if` and at the `#endif`, then
// "errors thrown from here are not handled because the enclosing catch is
// not exhaustive".
//   swiftc -swift-version 6 -typecheck V16e2_if_config_catch.swift

struct Failure: Error, Equatable {
  var code: Int
  static var exists: Failure { Failure(code: 1) }
  static var sharingViolation: Failure { Failure(code: 2) }
}

func open() throws(Failure) { throw .exists }

func catchClauses() {
  do { try open() }
  catch .exists { print("exists") }
  #if os(Windows)
  catch .sharingViolation { print("retry later") }
  #endif
  catch { print("other") }
}
