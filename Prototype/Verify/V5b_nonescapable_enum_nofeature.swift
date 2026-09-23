// V5b: nonescapable enum declaration only, no lifetime annotations, no experimental feature.
struct Token: ~Escapable {
  let raw: Int32
}

enum Either: ~Escapable {
  case token(Token)
  case none
}

func inspect(_ e: borrowing Either) -> Int32 {
  switch e {
  case .token(let t): return t.raw
  case .none: return -1
  }
}
