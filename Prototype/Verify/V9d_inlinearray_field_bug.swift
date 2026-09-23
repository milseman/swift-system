// V9d: calling a borrowing method on a noncopyable field of a noncopyable InlineArray element.
struct NC: ~Copyable {
  var raw: Int32
  deinit {}
  borrowing func peek() -> Int32 { raw }
}
struct Pair: ~Copyable {
  var a: NC
  var b: NC
}
func take(_ p: borrowing Pair) -> Int32 { p.a.peek() }

@available(macOS 26, *)
func direct(_ t: borrowing InlineArray<2, Pair>) -> Int32 {
  t[0].a.peek()                // method on a field of the element
}

@available(macOS 26, *)
func viaBorrowingParam(_ t: borrowing InlineArray<2, Pair>) -> Int32 {
  take(t[0])                   // element passed to a borrowing parameter
}

@available(macOS 26, *)
func elementMethod(_ t: borrowing InlineArray<2, NC>) -> Int32 {
  t[0].peek()                  // method on the element itself
}
