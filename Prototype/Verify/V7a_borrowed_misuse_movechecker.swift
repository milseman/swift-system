// V7a: misuse of a `borrowing` noncopyable parameter (move-checker diagnostics). Expected to fail at m1, m2, m3, and m9 with "'fd' is borrowed and cannot be consumed", and at m6 (a non-escaping closure) and m8 (`defer`) with "noncopyable 'fd' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type", each with a "consumed here" note. m7 compiles.
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  consuming func close() throws(CloseError) { discard self }
  borrowing func read() -> Int32 { raw }
}
func take(_ o: consuming Owned) {}
func withBody(_ body: () -> Void) { body() }
func withEscaping(_ body: @escaping () -> Void) {}
nonisolated(unsafe) var globalSlot: Owned? = nil
final class Keeper { var kept: Owned? = nil }

func m1(_ fd: borrowing Owned) { try? fd.close() }            // close a borrowed value
func m2(_ fd: borrowing Owned) { take(fd) }                   // pass to consuming parameter
func m3(_ fd: borrowing Owned) { let copy = fd; _ = copy }    // bind to a new owner
func m6(_ fd: borrowing Owned) { withBody { try? fd.close() } } // consume in non-escaping closure
func m7(_ fd: borrowing Owned) { withBody { _ = fd.read() } }   // read in non-escaping closure (valid)
func m8(_ fd: borrowing Owned) { defer { try? fd.close() }; _ = fd.read() } // close in defer
func m9(_ fd: borrowing Owned) -> Owned { return fd }         // return it
