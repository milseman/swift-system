// V5a: a nonescapable enum: declare, construct from a parameter, switch over it.
struct Token: ~Escapable {
  let raw: Int32
  @_lifetime(immortal)
  init(raw: Int32) { self.raw = raw }
}

enum Either: ~Escapable {
  case token(Token)
  case none
}

@_lifetime(copy t)
func wrap(_ t: consuming Token) -> Either { .token(t) }

func inspect(_ e: borrowing Either) -> Int32 {
  switch e {
  case .token(let t): return t.raw
  case .none: return -1
  }
}
