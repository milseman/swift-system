// V13d: using the remaining end of a partially consumed pair inside a closure. Expected to fail at `autoclosure` and `explicitClosure` with "'p' used after consume": a closure captures the whole pair. Direct use, and capture before the consumption, compile. XCTAssert's arguments are autoclosures, so tests read into a local first.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  consuming func close() { discard self }
  borrowing func read() -> Int32 { raw }
}
struct Pair: ~Copyable { var readEnd: Owned; var writeEnd: Owned }
func check(_ value: @autoclosure () -> Int32) {}
func check2(_ body: () -> Int32) {}

func direct(_ p: consuming Pair) -> Int32 {
  p.writeEnd.close()
  return p.readEnd.read()
}
func autoclosure(_ p: consuming Pair) {
  p.writeEnd.close()
  check(p.readEnd.read())
}
func explicitClosure(_ p: consuming Pair) {
  p.writeEnd.close()
  check2 { p.readEnd.read() }
}
func beforeConsume(_ p: consuming Pair) {
  check(p.readEnd.read())
  p.writeEnd.close()
}
