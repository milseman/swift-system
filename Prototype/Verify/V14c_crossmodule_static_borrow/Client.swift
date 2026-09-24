// V14c client: borrowing a view of another module's static `let`. Expected to fail at `temporary`, `argument`, and `local` with "lifetime-dependent value escapes its scope" (or "lifetime-dependent variable 'b' escapes its scope"), with or without the experimental feature in the client, and with or without library evolution. `throughParameter` and the immortal static compile. The same code within one module compiles (V14d).
//   swiftc -emit-sil -o /dev/null -I /tmp/V14c Client.swift
import Lib
func use(_ b: Borrowed) -> Int32 { b.read() }

func temporary() -> Int32 { Owned.standardInput.borrowed.read() }
func argument() -> Int32 { use(Owned.standardInput.borrowed) }
func local() -> Int32 { let b = Owned.standardInput.borrowed; return b.read() }

func borrowingParameter(_ o: borrowing Owned) -> Int32 { use(o.borrowed) }
func throughParameter() -> Int32 { borrowingParameter(Owned.standardInput) }

func immortal() -> Int32 { use(Borrowed.standardInput) }
