// V14a client without the experimental feature: a helper that returns the
// borrowed view. Expected to fail: "a function cannot return a ~Escapable
// result". With -enable-experimental-feature Lifetimes it compiles, with the
// dependence inferred from the one borrowing parameter.
import Lib

func view(_ o: borrowing Owned) -> Borrowed { o.borrowed }
