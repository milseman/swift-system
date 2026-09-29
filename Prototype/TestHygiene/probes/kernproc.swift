import Darwin

// Times KERN_PROC_ALL the way SystemControl._bytes reads it, counting the
// ENOMEM retries and the time each step takes.
let clock = ContinuousClock()
for attempt in 0..<6 {
  let start = clock.now
  var mib: [CInt] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
  var retries = 0
  var sizeTime = Duration.zero, fetchTime = Duration.zero
  while true {
    var length = 0
    var t = clock.now
    guard sysctl(&mib, 3, nil, &length, nil, 0) == 0 else { print("size failed \(errno)"); break }
    sizeTime += clock.now - t
    var bytes = [UInt8](repeating: 0, count: max(length, 1))
    length = bytes.count
    t = clock.now
    let result = bytes.withUnsafeMutableBytes { sysctl(&mib, 3, $0.baseAddress, &length, nil, 0) }
    fetchTime += clock.now - t
    if result != 0 {
      if errno == ENOMEM { retries += 1; continue }
      print("fetch failed \(errno)"); break
    }
    break
  }
  print("attempt \(attempt): \(clock.now - start) total, \(retries) retries, sizes \(sizeTime), fetches \(fetchTime)")
}
