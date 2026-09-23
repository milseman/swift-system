// V7c: follow the fix-it: explicit `consume` of a borrowing parameter to store it.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
nonisolated(unsafe) var globalSlot: Owned? = nil
func m4(_ fd: borrowing Owned) { globalSlot = consume fd }
