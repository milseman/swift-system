# windows

`first-run.ps1` builds and tests `system-next` on Windows and writes one log, for the first Windows run. Nothing on
`system-next` has run on Windows before: the Windows code was written from Microsoft's documentation and compiled on
macOS against a model of the SDK (`Prototype/Win32/check-windows.sh` and `check-winsock.sh`). This page says how to
run the script, what it touches, and what to look at in its log afterward.

## Running it

From a clone of swift-system on the `system-next` branch, in a terminal where `swift --version` works:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Utilities\windows\first-run.ps1            # everything
powershell -NoProfile -ExecutionPolicy Bypass -File Utilities\windows\first-run.ps1 -ListOnly  # the steps, run nothing
powershell -NoProfile -ExecutionPolicy Bypass -File Utilities\windows\first-run.ps1 -SkipSuites
```

`-ExecutionPolicy Bypass` applies to that one process, so the script runs without changing the machine's execution
policy. It runs under Windows PowerShell 5.1, which Windows includes, and under PowerShell 7 (`pwsh`).

| Parameter | Default | |
|---|---|---|
| `-BuildTimeoutMinutes` | 60 | Each build step. |
| `-TestTimeoutMinutes` | 60 | The run of every test. |
| `-SuiteTimeoutMinutes` | 15 | Each Windows-only suite's run. |
| `-SkipSuites` | off | Leaves out the per-suite runs. |
| `-ListOnly` | off | Prints the steps and the Windows-only suites it found, and exits. |

The steps, each run as `swift <arguments>` in the clone through `cmd.exe`:

1. `swift package describe`: the package as a Windows host's manifest declares it.
2. `swift build`: the libraries.
3. `swift build --build-tests`: the tests too. If this fails, nothing can run (SwiftPM links every test target into
   one test executable), so the script builds each test target alone (`swift build --target SystemTests`,
   `SystemWinSocksTests`, `MemberImportVisibility`) to show which don't compile, and stops there.
4. `swift test --skip-build`: every test, XCTest and swift-testing.
5. `swift test --skip-build --filter <suite>`, for each Windows-only suite, one at a time, so that a crash in one
   doesn't hide the others' results. The suites are the XCTest classes and swift-testing suites of the files in
   `Tests/SystemTests` and `Tests/SystemWinSocksTests` whose first condition is `#if os(Windows)`: the `Win32*Tests`,
   `FileOperationsTestWindows`, and all of SystemWinSocksTests' (57 at `system-next`'s first run). A suite whose filter
   selects no test is reported as such, not as a pass.

The output shows as it comes. A step that outlives its time-out is stopped, with `taskkill /T /F` on the step's own
`cmd.exe` and the processes under it, and counted as timed out. At the end the script prints a summary: each step's
status, time and test counts (XCTest's tests, skips and failures, and swift-testing's tests and issues, from each
run's last summary line), and the names of the tests that failed. It exits with 0 when every step passed, 1 otherwise.

## What it touches

- **The log**: `.build\windows-first-run-<date>-<time>.log` in the clone, with the machine's details first (Windows
  version and build, architecture, PowerShell, whether the session is elevated, Developer Mode, long paths, the
  commit, local changes, `swift --version`), then each step's output. Each step's output passes through a file beside
  the log, deleted after the step.
- **Builds**: SwiftPM's `.build` in the clone. SwiftPM's caches and configuration go there too
  (`--manifest-cache local`, and `--cache-path`, `--config-path` and `--security-path` under
  `.build\windows-first-run-swiftpm`), so that nothing is written under the user's profile.
- **The network**: none. On a Windows host the manifest declares no package dependencies (it leaves out the samples
  and their swift-argument-parser), so SwiftPM fetches nothing.
- **Rights**: none beyond the user's. The script reads a few registry values under `HKLM` for the log, which needs no
  elevation, and changes no setting, environment variable or file outside the clone.
- **The tests themselves** make and remove their own temporary files and directories under `%TEMP%`, start child
  processes of their own, and use sockets on loopback only (127.0.0.1, `::1`, and Unix domain socket files in
  `%TEMP%`); the address-resolution tests use numeric names, so no resolver is asked (winsock-1's report, section 4,
  and coverage-9's "Tests added or changed"). A run as administrator can change what the permission tests see; run it
  as a normal user.

## What to look at in the log

The tests check most of what Windows must confirm, so the first thing to read is the summary: a failed test's
expectation and the value Windows gave are in its output above. Win32 and Winsock codes print with their names
(`WSAEWOULDBLOCK (10035, 0x2733)`), so a failure's code reads directly. What the tests leave to a reader:

**The manifest and the build** (winsock-2):
- The `manifest` step lists `SystemSockets` with the path `Sources\SystemSockets\WindowsHost` and the one source
  `WindowsHost.swift`, `SystemWinSocks` and `SystemWinSocksTests`, no SystemSocketsTests, no samples, and no package
  dependencies; and nothing in the log fetches or resolves a package.
- The build's warnings in `Sources\SystemWinSocks` and `Sources\System\Win32`: the model can't catch a macro that
  doesn't import on Windows, a type the importer gives differently (`BOOL`, `DWORD`, the `LPFN_` typedefs), or a
  layout difference.
- `RtlSecureZeroMemory`, which `winnt.h` defines inline, imports and links (coverage-9, section 4): `Memory.secureZero`
  builds, and `Win32MemoryTests` passes.

**Winsock** (winsock-1's report, section 4), with the suite that shows each:
- `inet_pton` and `inet_ntop` work before `WSAStartup`: the exit test in `SocketAddressTests`.
- The codes the failure tests expect: `WSAEAFNOSUPPORT` for an unknown family and `WSAENOTSOCK` for closing a
  non-socket (`SocketDescriptorTests`), `WSAENOTCONN` for shutting down an unconnected socket, `WSAEINVAL` for an
  unbound socket's name, `WSAECONNREFUSED`, `WSAEADDRINUSE` and `WSAEMSGSIZE` (`SocketOperationsTests`),
  `WSAEMSGSIZE` from `WSARecvMsg` (`SocketMessagesTests`), `WSAETIMEDOUT` for a receive time-out
  (`SocketOptionsTests`), and `ERROR_INVALID_PARAMETER` from `inet_ntop` (`SocketAddressTests`).
- Winsock's option types: `DWORD` milliseconds for the time-outs, `DWORD`s for `IP_MULTICAST_TTL` and
  `IP_MULTICAST_LOOP`, `u_short` linger fields, the TCP keepalive times settable before connecting, and `IPV6_V6ONLY`'s
  `true` default (`SocketOptionsTests`); multicast on the loopback interface, which that suite's multicast test needs.
- Which message type Winsock sends a received type of service as: the log line `SocketMessagesTests.typeOfService:
  the type of service came as message type [...]` (`IP_TOS` is 3, `IP_RECVTOS` 40); and `IN_PKTINFO`'s 8-byte layout
  (`SocketMessagesTests`' packet-information tests).
- The extension functions are found through a UDP and a TCP socket, with the right GUIDs (`SocketMessagesTests`,
  `SocketStreamExtensionsTests`), and a canceled operation's completion packet carries `ERROR_OPERATION_ABORTED`
  (`SocketOverlappedIOTests`).
- Unix domain sockets: a stream round trip, no datagrams, a non-ASCII path's UTF-8 (`UnixSocketTests`; Windows 10
  version 1803 or later).
- Every constant against the SDK (`WinsockConstantsTests`, and each suite's own), especially those Rust's bindings
  lack and the model couldn't check: the IP and IPv6 options other than multicast's, the TCP keepalive options,
  `INET_ADDRSTRLEN`.
- Not tested, for a reader with a debugger or a scratch program: whether `accept`'s socket is inheritable until
  System's `SetHandleInformation` (the test checks only the result).
- Whether Winsock's last error is the thread's last error, which decides whether `Win32.Error.current` serves a
  caller's own Winsock calls (mapping.ini's `[Winsock errors]`): `WinsockErrorTests.winsockErrorIsTheThreadsLastError`.

**Win32** (coverage-9's report), with the suite that shows each:
- Each `Win32.Error` code against the SDK, `current` against `GetLastError` and `SetLastError` and after a failing
  `GetHandleInformation`, `init(hResult:)`, and `NTStatus`' severities and ntdll's message for `0xC0000005`:
  `Win32ErrorTests`, `Win32HResultTests`, `Win32NTStatusTests` (section 1).
- `FilePath.remove()`: files, empty directories and a directory link removed, a full directory, a missing path, a
  read-only file and one open without delete sharing refused: `Win32FilePathRemoveTests` (section 3).
- The signals: the numbers against ucrt's macros, a number that isn't a signal, and `SIGINT` raised with a handler the
  test installs and restores: `Win32SignalTests` (section 5).
- The known folders: the GUIDs and options against the SDK, the system and Windows directories against their own
  functions, a `LocalAlloc` block freed: `Win32KnownFoldersTests` (section 7).

**Skips**: the console tests skip without a console, the symbolic-link tests without Developer Mode or elevation, the
mount-manager test where it can't be opened, and the account tests outside an account domain. The log's header says
whether Developer Mode and long paths are on; a skip is a test that didn't run, not a pass.

## Afterward

Send back the log. Each fix it leads to goes in the code with the Windows behavior it found, and what the model
missed goes into `Prototype/Win32/WindowsModel`, so that `check-windows.sh` and `check-winsock.sh` catch it next time.
