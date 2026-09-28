// Claim (a Swift 6.2 limit, not a design goal): a `let` OwnedZone can't be
// destroyed after a ZoneBuffer borrowed it, even once the buffer is gone.
// Expected: fails to compile, though it's sound. M4b and M4d are workarounds.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func destroyAfterTheBuffer() throws {
  let arena = try Memory.OwnedZone()
  do {
    var numbers = try Memory.ZoneBuffer<Int>(capacity: 8, in: arena)
    try numbers.append(1)
  }
  arena.destroy()
}
