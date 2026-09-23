// V14a client: consuming a local `let` owner after borrowing it, even though
// the borrow is a temporary that ends first. Expected to fail, with or without
// the feature: "noncopyable 'o' cannot be consumed when captured by an
// escaping closure or borrowed by a non-Escapable type". The `var` owner in
// ClientUse.swift and the borrowing helper here (`viaHelper`) compile.
import Lib

func afterTemporary() -> Int32 {
  let o = Owned(raw: 1)
  let r = o.borrowed.read()
  o.close()
  return r
}

func read(_ o: borrowing Owned) -> Int32 { o.raw }
func viaHelper() -> Int32 {
  let o = Owned(raw: 1)
  let r = read(o)
  o.close()
  return r
}
