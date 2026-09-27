/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: Signal and SignalSet as values. These change no process state,
// so they're swift-testing tests; SignalActionTests.swift has the ones that
// do.

#if !os(Windows) && !os(WASI)

import Testing

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

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Signal")
private struct SignalTests {
  @available(System 199, *)
  @Test func constantsAreTheCValues() {
    #expect(Signal.hangup.rawValue == SIGHUP)
    #expect(Signal.interrupt.rawValue == SIGINT)
    #expect(Signal.kill.rawValue == SIGKILL)
    #expect(Signal.brokenPipe.rawValue == SIGPIPE)
    #expect(Signal.terminate.rawValue == SIGTERM)
    #expect(Signal.stop.rawValue == SIGSTOP)
    #expect(Signal.continue.rawValue == SIGCONT)
    #expect(Signal.childStatusChange.rawValue == SIGCHLD)
    #expect(Signal.userDefined1.rawValue == SIGUSR1)
    #expect(Signal.userDefined2.rawValue == SIGUSR2)
    #expect(Signal.windowSizeChange.rawValue == SIGWINCH)
  }

  @available(System 199, *)
  @Test func namedSignalsAreDistinct() {
    let signals = Signal._names.map(\.0)
    #expect(Set(signals).count == signals.count)
    #expect(signals.allSatisfy { $0.rawValue > 0 && $0.rawValue < _NSIG })
  }

  @available(System 199, *)
  @Test func descriptionIsTheCName() {
    #expect(Signal.interrupt.description == "SIGINT")
    #expect(Signal.segmentationViolation.description == "SIGSEGV")
    #expect(Signal.continue.debugDescription == "SIGCONT")
    #expect(Signal(rawValue: 1000).description == "Signal(rawValue: 1000)")
  }
}

@Suite("SignalSet")
private struct SignalSetTests {
  @available(System 199, *)
  @Test func emptySet() {
    let set = SignalSet()
    #expect(set.isEmpty)
    #expect(!set.contains(.interrupt))
    #expect(Array(set) == [])
    #expect(set.description == "[]")
  }

  @available(System 199, *)
  @Test func insertAndRemove() {
    var set = SignalSet()
    #expect(set.insert(.interrupt) == (true, .interrupt))
    #expect(set.insert(.interrupt) == (false, .interrupt))
    #expect(set.contains(.interrupt))
    #expect(!set.contains(.terminate))
    #expect(set.update(with: .terminate) == nil)
    #expect(set.update(with: .terminate) == .terminate)
    #expect(set.remove(.interrupt) == .interrupt)
    #expect(set.remove(.interrupt) == nil)
    #expect(set == [.terminate])
  }

  @available(System 199, *)
  @Test func membersAreInIncreasingOrder() {
    let set: SignalSet = [.terminate, .hangup, .interrupt]
    #expect(Array(set) == [.hangup, .interrupt, .terminate])
    #expect(set.description == "[SIGHUP, SIGINT, SIGTERM]")
  }

  @available(System 199, *)
  @Test func algebra() {
    let a: SignalSet = [.hangup, .interrupt, .quit]
    let b: SignalSet = [.quit, .terminate]
    #expect(a.union(b) == [.hangup, .interrupt, .quit, .terminate])
    #expect(a.intersection(b) == [.quit])
    #expect(a.symmetricDifference(b) == [.hangup, .interrupt, .terminate])
    #expect(a.subtracting(b) == [.hangup, .interrupt])
    #expect(a.isDisjoint(with: [.terminate]))
    #expect(SignalSet([.quit]).isSubset(of: a))
    var c = a
    c.formIntersection(b)
    #expect(c == [.quit])
  }

  @available(System 199, *)
  @Test func equalityAndHashingIgnoreHowTheSetWasBuilt() {
    var built = SignalSet()
    built.insert(.userDefined2)
    built.insert(.userDefined1)
    built.insert(.alarm)
    built.remove(.alarm)
    let literal: SignalSet = [.userDefined1, .userDefined2]
    #expect(built == literal)
    #expect(built.hashValue == literal.hashValue)
    #expect(Set([built, literal]).count == 1)
  }

  @available(System 199, *)
  @Test func allHoldsTheSignals() {
    let all = SignalSet.all
    #expect(all.contains(.interrupt))
    #expect(all.contains(.terminate))
    #expect(all.contains(.userDefined2))
    #expect(Signal._names.allSatisfy { all.contains($0.0) })
  }

  @available(System 199, *)
  @Test func aSetHoldsOnlyRealSignals() {
    var set = SignalSet()
    #expect(set.insert(Signal(rawValue: 0)).inserted == false)
    #expect(set.insert(Signal(rawValue: 1000)).inserted == false)
    #expect(set.isEmpty)
  }

  @available(System 199, *)
  @Test func rawValueRoundTrips() {
    let set: SignalSet = [.interrupt, .childStatusChange]
    #expect(SignalSet(rawValue: set.rawValue) == set)
    var raw = set.rawValue
    #expect(sigismember(&raw, SIGINT) == 1)
    #expect(sigismember(&raw, SIGTERM) == 0)
  }
}

@Suite("Signal.Action")
private struct SignalActionValueTests {
  @available(System 199, *)
  @Test func rawValueRoundTrips() {
    let actions: [Signal.Action] = [
      .default,
      .ignore,
      Signal.Action(handler: .function({ _ in }), mask: [.interrupt], flags: [.restart]),
      Signal.Action(handler: .functionWithInfo({ _, _, _ in }), flags: [.noDefer]),
    ]
    for action in actions {
      #expect(Signal.Action(rawValue: action.rawValue) == action)
    }
  }

  @available(System 199, *)
  @Test func infoFunctionsSetSIGINFO() {
    let plain = Signal.Action(handler: .function({ _ in }))
    let info = Signal.Action(handler: .functionWithInfo({ _, _, _ in }))
    #expect(plain.rawValue.sa_flags & SA_SIGINFO == 0)
    #expect(info.rawValue.sa_flags & SA_SIGINFO != 0)
    // The handler decides SA_SIGINFO, whatever the flags say.
    let mismatched = Signal.Action(
      handler: .function({ _ in }), flags: Signal.Action.Flags(rawValue: SA_SIGINFO))
    #expect(mismatched.rawValue.sa_flags & SA_SIGINFO == 0)
    #expect(Signal.Action(rawValue: info.rawValue).flags.rawValue & SA_SIGINFO == 0)
  }

  @available(System 199, *)
  @Test func handlersCompareByFunction() {
    let f: @convention(c) (CInt) -> Void = { _ in }
    let g: @convention(c) (CInt) -> Void = { _ in _ = 1 }
    #expect(Signal.Handler.function(f) == .function(f))
    #expect(Signal.Handler.default != .ignore)
    #expect(Signal.Handler.ignore == .ignore)
    #expect(Signal.Handler.function(f) != .default)
    if unsafeBitCast(f, to: Int.self) != unsafeBitCast(g, to: Int.self) {
      #expect(Signal.Handler.function(f) != .function(g))
    }
  }
}

#endif // !os(Windows) && !os(WASI)
