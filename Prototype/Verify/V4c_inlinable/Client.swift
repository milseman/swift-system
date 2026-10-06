// V4c client: call inlinable release() methods that contain `discard self`. Expected to compile and to print: 1, 2, 3.
import V4c
@main struct Main {
  static func main() {
    print(FrozenNC(raw: 1).release())
    print(FrozenNC(raw: 2).release2())
    print(ResilientNC(raw: 3).release())
  }
}
