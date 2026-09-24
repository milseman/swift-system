// V14a client without the experimental feature: the uses that don't declare
// anything returning a Borrowed. Expected to compile.
//   swiftc -emit-sil -o /dev/null -I /tmp/V14a ClientUse.swift
import Lib

func use(_ b: Borrowed) -> Int32 { b.read() }

func temporary(_ o: borrowing Owned) -> Int32 { o.borrowed.read() }
func local(_ o: borrowing Owned) -> Int32 {
  let b = o.borrowed
  return use(b)
}
func varOwner() -> Int32 {
  var o = Owned(raw: 1)
  o = Owned(raw: 2)
  let r = use(o.borrowed)
  o.close()
  return r
}
