/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

struct SignalIO: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sigio",
    abstract: "Get SIGIO when a socket or a pipe has data, with setSignalOwner and O_ASYNC"
  )

  func run() throws {
    // System has no signal API, so the handler, the signal mask, and taking
    // a pending signal come from C. SIGIO stays blocked, so the handler
    // never runs: it's there because SIGIO is ignored by default, and Darwin
    // discards an ignored signal even while it's blocked.
    let previousHandler = signal(SIGIO, { _ in })
    var sigio = sigset_t()
    sigemptyset(&sigio)
    sigaddset(&sigio, SIGIO)
    var previousMask = sigset_t()
    sigprocmask(SIG_BLOCK, &sigio, &previousMask)
    defer {
      sigprocmask(SIG_SETMASK, &previousMask, nil)
      signal(SIGIO, previousHandler)
    }
    let current = ProcessID.current

    // The owner and O_ASYNC belong to the open file, so they apply to every
    // descriptor for this end of the socket pair.
    let (first, second) = try SocketDescriptor.pair(.local, .stream)
    defer {
      try? first.close()
      try? second.close()
    }
    try watch(second.fileDescriptor, owner: current)
    print("Made this process, \(current.rawValue), the owner of one end of a socket pair, "
      + "and turned on O_ASYNC for it")
    print("  signalOwner() reports \(describe(try second.fileDescriptor.signalOwner()))")
    try send(to: first.fileDescriptor)
    print("Wrote a byte to the other end: "
      + "SIGIO is \(tookSIGIO(&sigio) ? "pending" : "not pending")")
    let flags = try second.fileDescriptor.statusFlags()
    try second.fileDescriptor.setStatusFlags(flags.subtracting(.async))
    try send(to: first.fileDescriptor)
    print("Turned O_ASYNC off, and wrote another byte: "
      + "SIGIO is \(tookSIGIO(&sigio) ? "pending" : "not pending")")

    let pipe = try OwnedFD.pipe()
    try watch(pipe.readEnd.fileDescriptor, owner: current)
    let owner = try pipe.readEnd.fileDescriptor.signalOwner()
    print("Made this process the owner of a pipe's read end, with O_ASYNC")
    print("  signalOwner() reports \(describe(owner))"
      + (owner?.isGroup == true ? ": Darwin reports a pipe's owner with its sign reversed" : ""))
    try send(to: pipe.writeEnd.fileDescriptor)
    print("Wrote a byte to the write end: "
      + "SIGIO is \(tookSIGIO(&sigio) ? "pending" : "not pending")"
      + (owner?.isGroup == true ? ", so the owner is this process after all" : ""))
  }
}

/// Makes a process the owner of an open file's signals,
/// and turns on SIGIO for when input or output becomes possible.
private func watch(_ fd: FileDescriptor, owner: ProcessID) throws {
  try fd.setSignalOwner(owner)
  try fd.setStatusFlags(fd.statusFlags().union(.async))
}

/// Describes the process or process group that receives a file's signals.
private func describe(_ owner: (id: ProcessID, isGroup: Bool)?) -> String {
  guard let owner else { return "no owner" }
  return "\(owner.isGroup ? "process group" : "process") \(owner.id.rawValue)"
}

private func send(to fd: FileDescriptor) throws {
  _ = try [UInt8(1)].withUnsafeBytes { try fd.write($0) }
}

/// Returns whether SIGIO is pending for this process, taking it if so.
/// SIGIO must be blocked, and in `signals`.
private func tookSIGIO(_ signals: inout sigset_t) -> Bool {
  var pending = sigset_t()
  sigpending(&pending)
  guard sigismember(&pending, SIGIO) == 1 else { return false }
  var signal: CInt = 0
  sigwait(&signals, &signal)
  return true
}
