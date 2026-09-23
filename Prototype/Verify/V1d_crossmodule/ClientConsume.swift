// V1d client: try to consume the library's static let from another module.
import Lib
func take(_ x: consuming NC) {}
func attempt1() { take(NC.standardInput) }
func attempt2() { _ = NC.standardInput.take() }
