// Claim: the workaround for M4a and M4c that needs no var. Buffers made in
// a function that borrows the zone end with the call, and the caller can
// then destroy the zone. Expected: compiles.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func fill(_ arena: borrowing Memory.OwnedZone, _ flag: Bool) throws -> Bool {
  var numbers = try Memory.ZoneBuffer<Int>(capacity: 8, in: arena)
  try numbers.append(1)
  return flag && numbers.span[0] == 1
}

@available(System 199, *)
func destroyAfterTheCall() throws -> Bool {
  let arena = try Memory.OwnedZone()
  let filled = try fill(arena, true)
  arena.destroy()
  return filled
}
