// V16l: in top-level code, a noncopyable `let` is a global, and a global can't be consumed, so `try t.join()` on a PThread declared at top level fails: "cannot consume noncopyable stored property 't' that is global". The same applies to OwnedFD's close(). Expected to fail as written, and to compile with -D IN_FUNCTION. Samples and tests create owners in functions.
// Check: swiftc -emit-sil -o /dev/null -swift-version 6 [-D IN_FUNCTION] V16l_toplevel_owner_consume.swift
struct Owner: ~Copyable {
  consuming func join() { discard self }
  deinit {}
}

#if IN_FUNCTION
func run() {
  let t = Owner()
  t.join()
}
run()
#else
let t = Owner()
t.join()
#endif
