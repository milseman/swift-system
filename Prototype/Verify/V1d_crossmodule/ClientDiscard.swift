// V4: `discard self` on a library type, from an extension in a client module.
import Lib
extension NC {
  consuming func clientRelease() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
