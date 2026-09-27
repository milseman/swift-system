/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring process and signal API. Not API. See Prototype/Processes
// for the design and Sources/Samples/Process*.swift for uses.

#if !os(Windows) && !os(WASI)

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

/// A set of signals, such as the signals that a thread blocks.
///
/// A signal set is a value, like `Set<Signal>`:
///
///     var signals: SignalSet = [.interrupt, .terminate]
///     signals.insert(.hangup)
///     for signal in signals { print(signal) }
///
/// A set holds only the signals that the platform has.
/// Inserting a number that isn't one, such as zero,
/// or a number that the C library reserves for its own use,
/// such as glibc's 32 and 33, leaves the set unchanged.
///
/// The corresponding C type is `sigset_t`.
@frozen
@available(System 199, *)
public struct SignalSet: RawRepresentable, Sendable {
  /// The raw C signal set.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.SignalSet

  /// Creates a strongly-typed signal set from a raw C signal set.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.SignalSet) { self.rawValue = rawValue }
}

@available(System 199, *)
extension SignalSet {
  /// The set of every signal that the platform has.
  ///
  /// The C library leaves out the signals it reserves for its own use.
  ///
  /// The corresponding C function is `sigfillset`.
  @_alwaysEmitIntoClient
  public static var all: SignalSet { SignalSet(rawValue: _full()) }

  @usableFromInline
  internal static func _empty() -> CInterop.SignalSet {
    var set = CInterop.SignalSet()
    _ = system_sigemptyset(&set)
    return set
  }

  @usableFromInline
  internal static func _full() -> CInterop.SignalSet {
    var set = CInterop.SignalSet()
    _ = system_sigfillset(&set)
    return set
  }

  // Darwin's sigaddset doesn't check its signal number, and shifts by it.
  // Every other operation on a set checks it here too.
  // (Signal numbers are 1 through _NSIG - 1.)

  // The members, in increasing order.
  @usableFromInline
  internal var _members: [Signal] {
    withUnsafePointer(to: rawValue) { set in
      (1..<_NSIG).filter { system_sigismember(set, $0) == 1 }.map(Signal.init(rawValue:))
    }
  }
}

@available(System 199, *)
extension Signal {
  // Whether a signal set can hold the number.
  @usableFromInline
  internal var _isInSetRange: Bool { rawValue > 0 && rawValue < _NSIG }
}

// MARK: - Set algebra

@available(System 199, *)
extension SignalSet: SetAlgebra {
  /// Creates an empty set.
  ///
  /// The corresponding C function is `sigemptyset`.
  @_alwaysEmitIntoClient
  public init() { self.init(rawValue: SignalSet._empty()) }

  /// Whether the set contains a signal.
  ///
  /// The corresponding C function is `sigismember`.
  @_alwaysEmitIntoClient
  public func contains(_ signal: Signal) -> Bool {
    _contains(signal)
  }

  @usableFromInline
  internal func _contains(_ signal: Signal) -> Bool {
    guard signal._isInSetRange else { return false }
    return withUnsafePointer(to: rawValue) { system_sigismember($0, signal.rawValue) == 1 }
  }

  /// Inserts a signal into the set, if the platform has it.
  ///
  /// The corresponding C function is `sigaddset`.
  @_alwaysEmitIntoClient
  @discardableResult
  public mutating func insert(
    _ signal: Signal
  ) -> (inserted: Bool, memberAfterInsert: Signal) {
    let inserted = !contains(signal) && _add(signal)
    return (inserted, signal)
  }

  // Returns whether the platform has the signal.
  @usableFromInline
  internal mutating func _add(_ signal: Signal) -> Bool {
    guard signal._isInSetRange else { return false }
    return system_sigaddset(&rawValue, signal.rawValue) == 0
  }

  /// Removes a signal from the set.
  ///
  /// The corresponding C function is `sigdelset`.
  @_alwaysEmitIntoClient
  @discardableResult
  public mutating func remove(_ signal: Signal) -> Signal? {
    guard contains(signal) else { return nil }
    _delete(signal)
    return signal
  }

  @usableFromInline
  internal mutating func _delete(_ signal: Signal) {
    guard signal._isInSetRange else { return }
    _ = system_sigdelset(&rawValue, signal.rawValue)
  }

  /// Inserts a signal into the set, if the platform has it,
  /// returning it if the set already contained it.
  @_alwaysEmitIntoClient
  @discardableResult
  public mutating func update(with signal: Signal) -> Signal? {
    if contains(signal) { return signal }
    _ = _add(signal)
    return nil
  }

  /// Returns the signals in either set.
  @_alwaysEmitIntoClient
  public func union(_ other: SignalSet) -> SignalSet {
    var result = self
    result.formUnion(other)
    return result
  }

  /// Returns the signals in both sets.
  @_alwaysEmitIntoClient
  public func intersection(_ other: SignalSet) -> SignalSet {
    var result = self
    result.formIntersection(other)
    return result
  }

  /// Returns the signals in one set or the other, but not both.
  @_alwaysEmitIntoClient
  public func symmetricDifference(_ other: SignalSet) -> SignalSet {
    var result = self
    result.formSymmetricDifference(other)
    return result
  }

  /// Inserts the signals in another set.
  @_alwaysEmitIntoClient
  public mutating func formUnion(_ other: SignalSet) {
    for signal in other._members { _ = _add(signal) }
  }

  /// Removes the signals that aren't in another set.
  @_alwaysEmitIntoClient
  public mutating func formIntersection(_ other: SignalSet) {
    for signal in _members where !other.contains(signal) { _delete(signal) }
  }

  /// Replaces the set with the signals in one set or the other,
  /// but not both.
  @_alwaysEmitIntoClient
  public mutating func formSymmetricDifference(_ other: SignalSet) {
    for signal in other._members {
      if contains(signal) { _delete(signal) } else { _ = _add(signal) }
    }
  }
}

@available(System 199, *)
extension SignalSet: Hashable {
  /// Whether two sets contain the same signals.
  @_alwaysEmitIntoClient
  public static func == (lhs: SignalSet, rhs: SignalSet) -> Bool {
    lhs._members == rhs._members
  }

  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_members)
  }
}

@available(System 199, *)
extension SignalSet: Sequence {
  /// An iterator over a signal set's members, in increasing order.
  @frozen
  public struct Iterator: IteratorProtocol {
    @usableFromInline
    internal var _members: Array<Signal>.Iterator

    @_alwaysEmitIntoClient
    internal init(_ set: SignalSet) { _members = set._members.makeIterator() }

    @_alwaysEmitIntoClient
    public mutating func next() -> Signal? { _members.next() }
  }

  /// Returns an iterator over the set's members, in increasing order.
  @_alwaysEmitIntoClient
  public func makeIterator() -> Iterator { Iterator(self) }
}

@available(System 199, *)
extension SignalSet: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the set's members, such as `[SIGINT, SIGTERM]`.
  public var description: String {
    "[" + _members.map(\.description).joined(separator: ", ") + "]"
  }

  /// A textual representation of the set's members, such as `[SIGINT, SIGTERM]`.
  public var debugDescription: String { description }
}

// MARK: - The calling thread's signals

@available(System 199, *)
extension PThread {
  /// Returns the signals that the calling thread blocks.
  ///
  /// The system holds a blocked signal as pending
  /// until the thread unblocks it,
  /// or takes it with ``waitForSignal(in:)``.
  /// A new thread starts with the mask of the thread that created it.
  ///
  /// The corresponding C function is `pthread_sigmask`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "The signal mask belongs to a thread, and an async function can resume on another")
  public static func currentSignalMask() -> SignalSet {
    _changeSignalMask(how: _SIG_BLOCK, nil)
  }

  /// Replaces the calling thread's signal mask.
  ///
  /// - Parameter mask: The signals for the thread to block.
  ///   The system ignores an attempt to block
  ///   ``Signal/kill`` or ``Signal/stop``.
  /// - Returns: The thread's previous mask.
  ///
  /// The corresponding C function is `pthread_sigmask`.
  @_alwaysEmitIntoClient
  @discardableResult
  @available(*, noasync, message: "The signal mask belongs to a thread, and an async function can resume on another")
  public static func setCurrentSignalMask(_ mask: SignalSet) -> SignalSet {
    _changeSignalMask(how: _SIG_SETMASK, mask)
  }

  /// Adds signals to the ones that the calling thread blocks.
  ///
  /// To block signals for a scope, restore the previous mask afterward:
  ///
  ///     let previous = PThread.blockSignals([.interrupt, .terminate])
  ///     defer { PThread.setCurrentSignalMask(previous) }
  ///
  /// - Parameter signals: The signals to block.
  /// - Returns: The thread's previous mask.
  ///
  /// The corresponding C function is `pthread_sigmask`.
  @_alwaysEmitIntoClient
  @discardableResult
  @available(*, noasync, message: "The signal mask belongs to a thread, and an async function can resume on another")
  public static func blockSignals(_ signals: SignalSet) -> SignalSet {
    _changeSignalMask(how: _SIG_BLOCK, signals)
  }

  /// Removes signals from the ones that the calling thread blocks.
  ///
  /// The system delivers any of them that are pending
  /// before this method returns.
  ///
  /// - Parameter signals: The signals to unblock.
  /// - Returns: The thread's previous mask.
  ///
  /// The corresponding C function is `pthread_sigmask`.
  @_alwaysEmitIntoClient
  @discardableResult
  @available(*, noasync, message: "The signal mask belongs to a thread, and an async function can resume on another")
  public static func unblockSignals(_ signals: SignalSet) -> SignalSet {
    _changeSignalMask(how: _SIG_UNBLOCK, signals)
  }

  @usableFromInline
  internal static func _changeSignalMask(how: CInt, _ signals: SignalSet?) -> SignalSet {
    var previous = SignalSet()
    // pthread_sigmask fails only for an unknown `how`.
    if let signals {
      _ = withUnsafePointer(to: signals.rawValue) {
        system_pthread_sigmask(how, $0, &previous.rawValue)
      }
    } else {
      _ = system_pthread_sigmask(how, nil, &previous.rawValue)
    }
    return previous
  }

  /// Returns the signals that are pending for the calling thread,
  /// or for the process, and that the thread blocks.
  ///
  /// The corresponding C function is `sigpending`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "The signal mask belongs to a thread, and an async function can resume on another")
  public static func pendingSignals() -> SignalSet {
    _pendingSignals()
  }

  @usableFromInline
  internal static func _pendingSignals() -> SignalSet {
    var pending = SignalSet()
    // sigpending can't fail.
    _ = system_sigpending(&pending.rawValue)
    return pending
  }

  /// Waits until one of a set of signals is pending,
  /// and takes it.
  ///
  /// The calling thread must block the signals in `signals`:
  /// otherwise the system may deliver one to the thread's handler,
  /// or take its default action,
  /// before this method can take it.
  /// Taking a signal removes it from the pending signals
  /// without running its handler.
  ///
  ///     let signals: SignalSet = [.interrupt, .terminate]
  ///     PThread.blockSignals(signals)
  ///     let signal = try PThread.waitForSignal(in: signals)
  ///
  /// - Parameter signals: The signals to wait for.
  /// - Returns: The signal that this method took.
  ///
  /// The corresponding C function is `sigwait`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public static func waitForSignal(in signals: SignalSet) throws(Errno) -> Signal {
    try _waitForSignal(in: signals).get()
  }

  @usableFromInline
  internal static func _waitForSignal(in signals: SignalSet) -> Result<Signal, Errno> {
    var signal: CInt = 0
    return withUnsafePointer(to: signals.rawValue) { set in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_sigwait(set, &signal)
      }
    }.map { Signal(rawValue: signal) }
  }

  /// Suspends the calling thread until a signal runs a handler,
  /// with its signal mask replaced for the wait.
  ///
  /// This method replaces the thread's signal mask with `mask`,
  /// waits until the system delivers a signal
  /// whose action is to run a handler,
  /// then restores the mask, in one step,
  /// so that no signal can arrive between checking a condition
  /// and starting to wait:
  ///
  ///     let previous = PThread.blockSignals([.userDefined1])
  ///     while !handlerRan.load(ordering: .acquiring) {
  ///       PThread.suspendUntilSignal(mask: previous)
  ///     }
  ///
  /// It returns after the handler returns.
  /// A signal whose action ends the process doesn't return.
  ///
  /// - Parameter mask: The signals for the thread to block while it waits.
  ///
  /// The corresponding C function is `sigsuspend`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Waiting blocks the calling thread")
  public static func suspendUntilSignal(mask: SignalSet) {
    _suspendUntilSignal(mask: mask)
  }

  @usableFromInline
  internal static func _suspendUntilSignal(mask: SignalSet) {
    // sigsuspend returns only when a handler returns, and then fails with
    // EINTR.
    _ = withUnsafePointer(to: mask.rawValue) { system_sigsuspend($0) }
  }
}

#endif // !os(Windows) && !os(WASI)
