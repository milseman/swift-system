/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Handles signals without a handler function: the signals are blocked in
// every thread, and the main thread takes them one at a time with sigwait,
// where it can run any code, unlike a handler. It ignores SIGPIPE, as NIO
// and SwiftPM do on Linux, so that writing to a closed pipe fails with an
// error rather than ending the process. On SIGINT it ends the way SwiftPM's
// Cancellator does: it restores the signal's default action and raises it,
// so that its parent sees it end by SIGINT.
//
//     $ swift run system-samples process-signals
//     writing to a closed pipe: Broken pipe
//     process 81250 waits for [SIGHUP, SIGINT, SIGTERM, SIGUSR1, SIGUSR2]
//     received SIGUSR1
//     received SIGHUP: reloading
//     received SIGTERM: stopping
//
// With --wait, nothing sends the signals: send them with kill, or type
// Control-C.

#if !os(Windows) && !os(WASI)

import ArgumentParser
import SystemPackage

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

struct ProcessSignals: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-signals",
    abstract: "Take signals with sigwait, ignore SIGPIPE, and end as if by SIGINT"
  )

  @Flag(help: "Wait for signals from elsewhere, rather than sending some")
  var wait = false

  func run() throws {
    // Ignoring SIGPIPE turns a write to a closed pipe into an error.
    try Signal.brokenPipe.setAction(.ignore)
    let pipe = try FileDescriptor.pipe()
    try pipe.readEnd.close()
    do {
      _ = try pipe.writeEnd.writeAll([1])
    } catch {
      print("writing to a closed pipe: \(error)")
    }
    try pipe.writeEnd.close()

    // Block the signals before starting any thread, so that every thread
    // inherits the mask, and the system holds them for sigwait. A signal
    // whose action is to ignore it is discarded even while it's blocked, and
    // a shell starts a background job with SIGINT ignored, so give each its
    // default action first.
    let signals: SignalSet = [.hangup, .interrupt, .terminate, .userDefined1, .userDefined2]
    for signal in signals { try signal.setAction(.default) }
    PThread.blockSignals(signals)
    print("process \(ProcessID.current.rawValue) waits for \(signals)")

    // Signals that a process sends to itself.
    let sender: PThread? = wait ? nil : try PThread {
      for signal: Signal in [.userDefined1, .hangup, .terminate] {
        usleep(50_000)
        try? ProcessID.current.sendSignal(signal)
      }
    }

    // sigwait reports only the signal. A SignalDescriptor on Linux, or a
    // handler function with info, also reports who sent it.
    loop: while true {
      let signal = try PThread.waitForSignal(in: signals)
      switch signal {
      case .hangup:
        print("received \(signal): reloading")
      case .terminate:
        print("received \(signal): stopping")
        break loop
      case .interrupt:
        print("received \(signal): ending as if by SIGINT")
        // The default action ends the process, and the parent sees why.
        try Signal.interrupt.setAction(.default)
        PThread.unblockSignals([.interrupt])
        try Signal.interrupt.raise()
      default:
        print("received \(signal)")
      }
    }
    if let sender { try sender.join() }
  }
}

#else

import ArgumentParser

struct ProcessSignals: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "process-signals",
    abstract: "Unavailable: this platform has no signals"
  )

  func run() throws {
    complain("Error: process-signals needs signals, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI)
