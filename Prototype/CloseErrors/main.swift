// Usage: close-errors-<policy> <scenario name>, or --list.

let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "--list" {
  for scenario in allScenarios() { print("\(scenario.name)\t\(scenario.modeledOn)") }
} else if let name = arguments.first,
  let scenario = allScenarios().first(where: { $0.name == name })
{
  var outcome: [String] = []
  do {
    try scenario.run()
    outcome.append("ok")
  } catch {
    outcome.append("threw \(error)")
  }
  if !Kernel.droppedCloseErrors.isEmpty {
    outcome.append("dropped \(Kernel.droppedCloseErrors.map { "\($0)" }.joined(separator: ","))")
  }
  if !Kernel.open.isEmpty { outcome.append("leaked \(Kernel.open.count)") }
  print(outcome.joined(separator: "; "))
} else {
  print("unknown scenario")
}
