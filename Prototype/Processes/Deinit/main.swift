// Usage: child-deinit-<policy> <scenario name>, or --list.
//
// A scenario that doesn't finish in five seconds is killed by SIGALRM,
// which run.sh reports as a hang. After a scenario, this ends and reaps
// every child the owners left, so that none outlives the harness.

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
  if !Ledger.droppedErrors.isEmpty {
    let names = Ledger.droppedErrors.map { $0 == ECHILD ? "ECHILD" : "\($0)" }
    outcome.append("dropped \(names.joined(separator: ","))")
  }
  print(outcome.isEmpty ? "ok" : outcome.joined(separator: "; "))
  for pid in Ledger.children where peek(pid) != .reaped {
    kill(pid, SIGKILL)
    _ = reap(pid)
  }
} else {
  print("unknown scenario")
}
