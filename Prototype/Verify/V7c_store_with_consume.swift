// V7c: follow the fix-it: explicit `consume` of a borrowing parameter to store it. Expected to fail: "'fd' is borrowed and cannot be consumed". So V7g's fix-it leads to a second error.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
nonisolated(unsafe) var globalSlot: Owned? = nil
func m4(_ fd: borrowing Owned) { globalSlot = consume fd }
