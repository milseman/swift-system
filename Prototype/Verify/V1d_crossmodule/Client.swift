// V1d client: borrow the library's static let from another module.
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
