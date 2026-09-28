// Claim: a workaround for M4a. A `var` OwnedZone can be destroyed
// after a ZoneBuffer borrowed it, with a spurious warning that the var is
// never mutated. Expected: compiles.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func destroyAfterTheBuffer() throws {
  var arena = try Memory.OwnedZone()
  do {
    var numbers = try Memory.ZoneBuffer<Int>(capacity: 8, in: arena)
    try numbers.append(1)
  }
  arena.destroy()
}
