// V7g: storing a `borrowing` noncopyable parameter into an Optional global or class property.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
nonisolated(unsafe) var globalSlot: Owned? = nil
final class Keeper { var kept: Owned? = nil }
func m4(_ fd: borrowing Owned) { globalSlot = fd }
func m5(_ fd: borrowing Owned, _ k: Keeper) { k.kept = fd }
