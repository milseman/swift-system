// V4b file 2: `discard self` in an extension in a different file of the same module. Expected to compile, with Type.swift, as one module (-wmo, with -emit-sil).
extension NC {
  consuming func release() -> Int32 {
    let r = raw
    discard self
    return r
  }
}
