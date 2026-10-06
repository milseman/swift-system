// V1d client, for V4: `discard self` on a library type, from an extension in a client module. Expected to fail: "can only 'discard' from the same module defining type 'NC'".
import Lib
extension NC {
  consuming func clientRelease() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
