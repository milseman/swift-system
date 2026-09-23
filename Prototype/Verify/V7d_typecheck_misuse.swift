// V7d: type-checker diagnostics around noncopyable owners.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
func noModifier(_ fd: Owned) {}                 // parameter without ownership modifier
func generic<T>(_ x: borrowing T) {}
func g1(_ fd: borrowing Owned) { generic(fd) }  // generic parameter without ~Copyable
func g2() { let table: [Owned] = []; _ = table } // Array element
func g3() { let d: [Int32: Owned] = [:]; _ = d } // Dictionary value
