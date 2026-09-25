// Measures DirectoryStream and DirectoryWalk: the best time of 5 runs, and
// the heap allocations of the last run, per entry.
//
// Usage: DYLD_INSERT_LIBRARIES=mallocs.dylib bench MODE PATH, where MODE is
//   stream-count  read every entry, and look only at its type
//   stream-keep   read every entry, and keep it
//   walk          walk the tree, looking only at types
//   walk-stat     walk the tree, with each entry's status
// Without the interposer, it doesn't count allocations.
import SystemPackage
import Darwin

nonisolated(unsafe) let counter: UnsafeMutablePointer<Int>? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "directory_evidence_mallocs")
  .map { $0.assumingMemoryBound(to: Int.self) }
func mallocs() -> Int { counter?.pointee ?? -1 }
func now() -> Double { var t = timespec(); clock_gettime(CLOCK_MONOTONIC, &t); return Double(t.tv_sec) * 1e3 + Double(t.tv_nsec) / 1e6 }

let mode = CommandLine.arguments[1]
let path = FilePath(CommandLine.arguments[2])
var best = Double.infinity
var entries = 0
var allocations = 0
for _ in 0..<5 {
  entries = 0
  let m0 = mallocs(), t0 = now()
  switch mode {
  case "stream-count":
    var stream = try DirectoryStream.open(path)
    while let entry = try stream.next() { if entry.type != nil { entries += 1 } }
    try stream.close()
  case "stream-keep":
    var stream = try DirectoryStream.open(path)
    var kept: [DirectoryStream.Entry] = []
    kept.reserveCapacity(200_000)
    while let entry = try stream.next() { kept.append(entry) }
    entries = kept.count
    try stream.close()
  case "walk":
    var walk = try DirectoryWalk(path)
    while let entry = try walk.next() { if entry.type != nil { entries += 1 } }
  case "walk-stat":
    var walk = try DirectoryWalk(path)
    var bytes: Int64 = 0
    while let entry = try walk.next() {
      entries += 1
      if let status = try? FilePath(root: nil, components: entry.name)
        .stat(relativeTo: walk.parentDirectory, flags: .symlinkNoFollow) { bytes += status.size }
    }
  default: fatalError("mode")
  }
  let t1 = now(), m1 = mallocs()
  best = min(best, t1 - t0)
  allocations = m1 - m0
}
let perEntry = Double(allocations) / Double(max(entries, 1))
let counted = counter == nil
  ? "allocations not counted"
  : "\(allocations) allocations (\((perEntry * 1000).rounded() / 1000) per entry)"
print("\(mode): \(entries) entries, best of 5: \((best * 10).rounded() / 10) ms, \(counted)")
