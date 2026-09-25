// V16i: which captures a thread body can make when the parameter is `sending` rather than @Sendable. Expected: B-I compile except H; A fails. `sending` accepts non-Sendable values the caller doesn't use again (G, which @Sendable rejects in H: "capture of 'x' with non-Sendable type 'NotSendable' in a '@Sendable' closure"), and Sendable values shared by several bodies (I). It rejects one pattern that @Sendable accepts (B): two bodies capturing the same local noncopyable value, even a Sendable one (A: "sending value of non-Sendable type '() -> ()' risks causing data races"). Sharing it through a class works (C). PThread's body parameter is `sending`.
// Check each: swiftc -emit-sil -o /dev/null -swift-version 6 -D A V16i_thread_body_captures.swift (and B through I)
struct Lock: ~Copyable, Sendable { let raw: Int; func use() {} }
final class Shared: Sendable { let lock = Lock(raw: 0) }
final class NotSendable { var n = 0 }
final class Counter: @unchecked Sendable { var n = 0 }
func spawnSending(_ body: sending @escaping () -> Void) {}
func spawnSendable(_ body: @escaping @Sendable () -> Void) {}

#if A // sending: two bodies capture one local noncopyable Sendable value
func a() { let lock = Lock(raw: 0); spawnSending { lock.use() }; spawnSending { lock.use() } }
#endif
#if B // @Sendable: the same
func b() { let lock = Lock(raw: 0); spawnSendable { lock.use() }; spawnSendable { lock.use() } }
#endif
#if C // sending: two bodies capture a Sendable class that holds it
func c() { let shared = Shared(); spawnSending { shared.lock.use() }; spawnSending { shared.lock.use() } }
#endif
#if D // sending: one body captures the local, which the caller doesn't use again
func d() { let lock = Lock(raw: 0); spawnSending { lock.use() } }
#endif
#if E // sending: one body captures the local, which the caller uses afterward
func e() { let lock = Lock(raw: 0); spawnSending { lock.use() }; lock.use() }
#endif
#if F // @Sendable: one body captures the local, which the caller uses afterward
func f() { let lock = Lock(raw: 0); spawnSendable { lock.use() }; lock.use() }
#endif
#if G // sending: a non-Sendable value, not used again
func g() { let x = NotSendable(); spawnSending { x.n += 1 } }
#endif
#if H // @Sendable: the same
func h() { let x = NotSendable(); spawnSendable { x.n += 1 } }
#endif
#if I // sending: a Sendable class captured by two bodies
func i() { let c = Counter(); spawnSending { c.n += 1 }; spawnSending { c.n += 1 } }
#endif
