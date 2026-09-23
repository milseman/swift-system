// V4b file 2: `discard self` in an extension in a different file of the same module.
extension NC {
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
