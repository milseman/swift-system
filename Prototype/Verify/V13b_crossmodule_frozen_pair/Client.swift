// V13b client: take each pair apart from another module. Expected: `frozen` compiles either way; `resilient` fails. Without library evolution the error is "cannot partially consume 'p' of non-frozen type 'ResilientPair' imported from 'Lib'", and with it, "'p.writeEnd' is borrowed and cannot be consumed". So OwnedFD.Pipe is @frozen.
//   swiftc -emit-sil -o /dev/null -I /tmp/V13b Client.swift
import Lib
func take(_ o: consuming Owned) {}

func frozen() {
  let p = FrozenPair(readEnd: Owned(raw: 3), writeEnd: Owned(raw: 4))
  take(p.writeEnd)
  take(p.readEnd)
}

func resilient() {
  let p = ResilientPair(readEnd: Owned(raw: 3), writeEnd: Owned(raw: 4))
  take(p.writeEnd)
  take(p.readEnd)
}
