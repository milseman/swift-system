// Usage: thread-deinit-<policy> <scenario name>, or --list.
//
// A scenario that doesn't finish in five seconds is killed by SIGALRM,
// which run.sh reports as a hang.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

setvbuf(stdout, nil, _IONBF, 0)
let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "--list" {
  for scenario in allScenarios() { print("\(scenario.name)\t\(scenario.modeledOn)") }
} else if let name = arguments.first,
  let scenario = allScenarios().first(where: { $0.name == name })
{
  alarm(5)
  var outcome: [String]
  do {
    outcome = try scenario.run()
  } catch {
    outcome = ["threw \(error)"]
  }
  // Let detached threads finish, so that they don't count as unreleased.
  usleep(100_000)
  let unreleased = Ledger.unreleased
  if unreleased > 0 { outcome.append("leaked \(unreleased)") }
  if !Ledger.droppedErrors.isEmpty {
    let names = Ledger.droppedErrors.map { $0 == ESRCH ? "ESRCH" : $0 == EINVAL ? "EINVAL" : "\($0)" }
    outcome.append("dropped \(names.joined(separator: ","))")
  }
  print(outcome.isEmpty ? "ok" : outcome.joined(separator: "; "))
} else {
  print("unknown scenario")
}
