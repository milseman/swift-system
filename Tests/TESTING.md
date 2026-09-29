# What a test may depend on

Every test in this package must pass on a busy laptop and on CI, every run, whatever
else is running. These rules keep it that way. `Prototype/TestHygiene/REPORT.md` has
the failures behind them.

## Time

- Wait for the event, not for time. Block on whatever shows that it happened: a
  latch, a pipe or socket becoming readable (`poll`), a kqueue event, a child's exit,
  a signal handler having run. Don't sleep and then check.
- A timeout only guards against a hang. Wait for something that should happen at
  once for up to `hangGuardSeconds` (`HangGuard.swift`, 300 s). A busy machine can
  delay any step for seconds, so no test may fail because a wait took that long.
- Bound elapsed time only from below (a 20 ms timeout takes at least 15 ms). An upper
  bound is at most the hang guard, and the call that mustn't wait gets a longer
  timeout than that.
- A value that falls as time passes, such as a timer's time left, may have fallen by
  the hang guard. Rounding it is checked against bounds from clock readings made
  around the calls.
- Compare two clocks by bracketing: start the outer interval first and end it last.
- A child that must still be running comes from `spawnWaitingChild()`, which runs
  until it's signaled. Not `sleep 10`.
- A short sleep may give a wrong result the chance to show, such as a suspended
  child that mustn't exit, as long as the right result doesn't depend on it.

## Scheduling

- Don't depend on when a thread runs. A thread at background QoS can wait many
  seconds for a processor: while the test needs it, keep it at the default class with
  a QoS override, which it can't see.

## Values that anything can change

- Don't compare two samples of a value that anything else can change: free disk
  space, the process table, a group list. Check one sample's values against each
  other and against fixed ones, or check only what the test controls, such as its own
  child in both process lists.
- Don't count a malloc zone's blocks: about one new zone in 250 is a ProbGuard zone,
  whose statistics are all zero. Ask which zone holds a block.
- A full disk, a nice value, or no controlling terminal is the machine's state. A
  test allows for it, or skips with the reason when it can't run at all.

## Parallelism

swift-testing runs its tests in parallel, on threads of one process. XCTest runs one
test at a time in another process, and with `--parallel` each test in a process of
its own, beside the others.

- A swift-testing test changes nothing that the whole process shares: the working
  directory, the umask, the environment, signal actions, timers, resource limits,
  the terminal, or the name, QoS or signal mask of a thread it didn't create. Such a
  test is an XCTest test that restores the state in a `defer`, or an exit test
  (`#expect(processExitsWith:)`), whose body runs in a process of its own.
- A swift-testing test doesn't use a memory address, a descriptor's number, or a zone
  after freeing, closing or destroying it: another test's thread can be given it at
  once. For a descriptor that's never open, use -1. A test that must use one does it
  in an exit test.
- A swift-testing test doesn't spawn children itself: a child inherits the pipes that
  other tests have open, and holds them open. (An exit test's process starts without
  them.) Children are for XCTest tests, each of which reaps every child it starts, so
  that `waitForAnyChild` finds only the test's own.
- `.serialized` runs a suite's tests one at a time, but beside other suites. The
  malloc zone tests share one serialized suite, and reading every zone's statistics
  (`statisticsForAllZones`), which crashes if another thread destroys a zone, happens
  only in an exit test.

## Other processes

- Other checkouts' test runs can be running too. Make files with
  `withTemporaryFilePath` or `mkstemp`, put the process ID in IPC names, and bind
  sockets to port 0.
- Leave nothing changed: restore process-wide state in a `defer`, and end and reap
  every child.

## Checking a new test

`Prototype/TestHygiene/stress.sh` builds, then runs `swift test` and
`swift test --parallel` repeatedly under CPU load that it creates, and lists each
run's failures. Run it after adding a test that waits, spawns, or shares state.
