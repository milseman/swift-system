// Claim (a Swift 6.2 limit): with a `var` OwnedZone, a ZoneBuffer's span
// used in an autoclosure, such as the right side of `&&`, is reported as
// escaping its scope; with `let arena` the same code compiles.
// Expected: fails to compile. M4d is the workaround.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func useInAnAutoclosure(_ flag: Bool) throws -> Bool {
  var arena = try Memory.OwnedZone()
  let points = try Memory.ZoneBuffer<Int32>(repeating: 0, count: 50, in: arena)
  let ok = flag && points.span[49] == 0
  _ = consume points
  arena.destroy()
  return ok
}
