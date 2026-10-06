// V7e: owned local misuse: use after close, close in a loop, optional binding. Expected to fail at u1, "'fd' used after consume", with "consumed here" and "used here" notes; at u2, "'fd' consumed in a loop"; and at u4, "'maybe' is borrowed and cannot be consumed", whose "consumed here" note points at the `if`. u3, binding a consuming Optional, compiles.
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  consuming func close() throws(CloseError) { discard self }
  borrowing func read() -> Int32 { raw }
}
func make() -> Owned { Owned(raw: 3) }

func u1() throws(CloseError) -> Int32 {
  let fd = make()
  try fd.close()
  return fd.read()          // use after close
}
func u2() {
  let fd = make()
  for _ in 0..<2 { try? fd.close() }   // close in a loop
}
func u3(_ maybe: consuming Owned?) -> Int32 {
  if let fd = maybe { return fd.read() }   // optional binding consumes
  return -1
}
func u4(_ maybe: borrowing Owned?) -> Int32 {
  if let fd = maybe { return fd.read() }   // optional binding of a borrowed optional
  return -1
}
