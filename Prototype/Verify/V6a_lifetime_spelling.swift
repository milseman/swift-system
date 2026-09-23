// V6a: the non-underscored `@lifetime` spelling.
struct Token: ~Escapable {
  let raw: Int32
  @lifetime(immortal)
  init(raw: Int32) { self.raw = raw }
}
