// V1d client: try to consume the library's static let from another module. Expected to fail at both attempts: "'unknown' is borrowed and cannot be consumed", in the snapshot too, though it names a static of the same module (V2b).
import Lib
func take(_ x: consuming NC) {}
func attempt1() { take(NC.standardInput) }
func attempt2() { _ = NC.standardInput.take() }
