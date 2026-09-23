// V12b: the caught error's type in `do`/`catch`, in a function and in a closure annotated `throws(Errno)`. Expected to fail at `inClosure` only: in a function body `error` is Errno, but in a closure it's `any Error` unless the block says `do throws(Errno)`.
enum Errno: Error { case io }
func work() throws(Errno) {}

func inFunction() throws(Errno) {
  do { try work() } catch { throw error }
}

let inClosure = { () throws(Errno) in
  do { try work() } catch { throw error }
}

let inClosureTypedDo = { () throws(Errno) in
  do throws(Errno) { try work() } catch { throw error }
}
