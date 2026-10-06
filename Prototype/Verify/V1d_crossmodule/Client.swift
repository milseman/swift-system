// V1d client: borrow the library's static let from another module. Expected to compile and to print: peek: 0, borrowing param: 0, take local: 7, end of main. No deinit runs: take() discards self, and the static is never destroyed.
import Lib

func use(_ x: borrowing NC) -> Int32 { x.peek() }

@main struct Main {
  static func main() {
    print("peek:", NC.standardInput.peek())
    print("borrowing param:", use(NC.standardInput))
    let local = NC(raw: 7)
    print("take local:", local.take())
    print("end of main")
  }
}
