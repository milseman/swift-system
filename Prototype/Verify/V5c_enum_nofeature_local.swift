// V5c: nonescapable enum wrapping a stdlib nonescapable type, used locally, no experimental feature.
enum Bytes: ~Escapable {
  case span(Span<UInt8>)
  case empty
}

@available(macOS 26, *)
func count(_ s: Span<UInt8>) -> Int {
  let e = Bytes.span(s)
  switch e {
  case .span(let s): return s.count
  case .empty: return 0
  }
}
