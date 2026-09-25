// What each way of copying a directory entry costs, over and above readdir
// itself, in nanoseconds per entry. Usage: entrycost DIRECTORY
import Darwin

@inline(never) func sink<T>(_ x: T) { withExtendedLifetime(x) {} }

func run(_ label: String, _ path: String, _ body: (UnsafeMutablePointer<dirent>) -> Void) {
  var best = Double.infinity
  var count = 0
  for _ in 0..<7 {
    guard let dir = opendir(path) else { perror("opendir"); exit(1) }
    var t0 = timespec(), t1 = timespec()
    clock_gettime(CLOCK_MONOTONIC, &t0)
    count = 0
    while let entry = readdir(dir) {
      body(entry)
      count += 1
    }
    clock_gettime(CLOCK_MONOTONIC, &t1)
    closedir(dir)
    let ns = Double(t1.tv_sec - t0.tv_sec) * 1e9 + Double(t1.tv_nsec - t0.tv_nsec)
    best = min(best, ns / Double(count))
  }
  print("\(label): \(count) entries, best of 7: \((best * 10).rounded() / 10) ns per entry")
}

let path = CommandLine.arguments[1]
run("readdir, read d_type and d_namlen", path) { e in sink((e.pointee.d_type, e.pointee.d_namlen)) }
run("+ copy the name into an Array<CChar>", path) { e in
  let length = Int(e.pointee.d_namlen)
  let name = withUnsafeBytes(of: &e.pointee.d_name) { raw in
    Array(raw.bindMemory(to: CChar.self).prefix(length + 1))
  }
  sink(name)
}
run("+ copy the name into a String", path) { e in
  let name = withUnsafeBytes(of: &e.pointee.d_name) { raw in
    String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
  }
  sink(name)
}
run("+ copy d_reclen bytes into a zeroed dirent", path) { e in
  var copy = dirent()
  memcpy(&copy, e, Int(e.pointee.d_reclen))
  sink(copy)
}
run("+ copy the whole dirent (sizeof \(MemoryLayout<dirent>.size))", path) { e in sink(e.pointee) }
