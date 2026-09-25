// V16g: the standard library's Synchronization.Mutex isn't a pthread mutex. Expected to print that Mutex<Void> is 4 bytes, the size of os_unfair_lock, against 64 for pthread_mutex_t, so pthread_cond_wait can't take it and it has no attributes. Its interface (Synchronization.swiftinterface) wraps _MutexHandle, a _Cell<os_unfair_lock> on Darwin, and vends only withLock, withLockIfAvailable, and _MutexHandle's unsafeLock/unsafeTryLock/unsafeUnlock. With -D VAR it fails: "variable of type 'Mutex<Int>' must be declared with a 'let'" (@_staticExclusiveOnly).
// Run: swiftc -swift-version 6 V16g_synchronization_mutex.swift -o /tmp/V16g && /tmp/V16g
import Darwin
import Synchronization

@available(macOS 15, *)
func sizes() {
  print("Mutex<Void>:", MemoryLayout<Mutex<Void>>.size, "bytes")
  print("os_unfair_lock:", MemoryLayout<os_unfair_lock>.size, "bytes")
  print("pthread_mutex_t:", MemoryLayout<pthread_mutex_t>.size, "bytes")
  print("pthread_cond_t:", MemoryLayout<pthread_cond_t>.size, "bytes")
}

#if VAR
@available(macOS 15, *)
func declareVar() { var m = Mutex(0); _ = m }
#endif

if #available(macOS 15, *) { sizes() }
