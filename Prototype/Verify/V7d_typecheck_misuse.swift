// V7d: type-checker diagnostics around noncopyable owners. Expected to fail at all four: "parameter of noncopyable type 'Owned' must specify ownership", with fix-its for `borrowing`, `inout`, and `consuming`; "global function 'generic' requires that 'Owned' conform to 'Copyable'", with a note "'where T: Copyable' is implicit here"; and "type 'Owned' does not conform to protocol 'Copyable'" for the Array and the Dictionary.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
func noModifier(_ fd: Owned) {}                 // parameter without ownership modifier
func generic<T>(_ x: borrowing T) {}
func g1(_ fd: borrowing Owned) { generic(fd) }  // generic parameter without ~Copyable
func g2() { let table: [Owned] = []; _ = table } // Array element
func g3() { let d: [Int32: Owned] = [:]; _ = d } // Dictionary value
