// T13: on Darwin, a joinable thread that finishes keeps some of its resources until it's joined. Expected on macOS 26.3: 500 finished threads that were never joined hold about 15 MiB more virtual memory than before them (about 30 KiB each), and 500 joined ones hold none. This is the cost of the leak policy in Prototype/ThreadDeinit.
// Run: swiftc T13_unjoined_thread_memory.swift -o /tmp/T13 && /tmp/T13 && /tmp/T13 join
import Darwin

func virtualSize() -> UInt64 {
  var info = mach_task_basic_info()
  var count = mach_msg_type_number_t(
    MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
  _ = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
    }
  }
  return info.virtual_size
}

let join = CommandLine.arguments.dropFirst().first == "join"
let before = virtualSize()
for _ in 0..<500 {
  var thread: pthread_t? = nil
  pthread_create(&thread, nil, { _ in nil }, nil)
  if join { pthread_join(thread!, nil) }
}
usleep(200_000)
print(join ? "joined:" : "never joined:",
      (virtualSize() - before) / 1024 / 1024, "MiB more virtual memory after 500 threads")
