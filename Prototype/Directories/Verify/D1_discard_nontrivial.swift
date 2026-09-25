// Claim: `discard self` is rejected in a noncopyable type with a stored
// property that isn't trivially destroyed, such as the Array behind the
// name storage that DirectoryStream reuses. Expected to fail to compile:
// "can only 'discard' type 'Stream' if it contains trivially-destroyed
// stored properties at this time".
struct Stream: ~Copyable {
  var handle: OpaquePointer
  var names: [CChar] = []
  deinit {}
  consuming func close() -> OpaquePointer {
    let handle = self.handle
    discard self
    return handle
  }
}
