/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned signalfd, on the pattern of OwnedFD.
// See Prototype/Processes for the design.

// signalfd exists on Linux and Android.
#if os(Linux) || os(Android)

import CSystem
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// A file descriptor that receives signals,
/// so that a thread can read them rather than handle them.
///
/// A signal descriptor receives the signals in its set
/// that are pending for the process or the reading thread.
/// Those signals must be blocked, in every thread,
/// or the system delivers them as usual instead:
///
///     let signals: SignalSet = [.interrupt, .terminate]
///     PThread.blockSignals(signals)    // before starting other threads
///     let receiver = try SignalDescriptor(signals: signals, options: .closeOnExec)
///     let information = try receiver.read()
///
/// Its descriptor is readable while a signal is pending,
/// so an ``EventPoll`` can watch for signals along with other descriptors,
/// and reading it takes the signal, as ``PThread/waitForSignal(in:)`` does.
/// A signal descriptor owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does.
///
/// The corresponding C function is `signalfd`.
///
/// - Note: Only available on Linux and Android.
@frozen
@available(System 199, *)
public struct SignalDescriptor: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates a signal descriptor that receives a set of signals.
  ///
  /// - Parameters:
  ///   - signals: The signals to receive.
  ///     The system ignores ``Signal/kill`` and ``Signal/stop``.
  ///   - options: Options for the descriptor.
  ///     The default is none.
  ///
  /// The corresponding C function is `signalfd`.
  @_alwaysEmitIntoClient
  public init(signals: SignalSet, options: Options = []) throws(Errno) {
    self._owner = OwnedFD(taking: try SignalDescriptor._create(signals, options).get())
  }

  @usableFromInline
  internal static func _create(
    _ signals: SignalSet, _ options: Options
  ) -> Result<FileDescriptor, Errno> {
    withUnsafePointer(to: signals.rawValue) { mask in
      valueOrErrno(retryOnInterrupt: false) {
        system_signalfd(-1, mask, options.rawValue)
      }
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that receives signals.
  ///
  /// This initializer doesn't check that `descriptor` is a signal descriptor.
  /// The descriptor is closed at the end of the instance's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The descriptor, for operations that `SignalDescriptor` doesn't provide,
  /// such as watching it with an ``EventPoll``.
  ///
  /// The returned value is valid only while this instance is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the descriptor.
  ///
  /// The descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

@available(System 199, *)
extension SignalDescriptor {
  /// Options for a signal descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Closes the descriptor when the process executes a new program.
    ///
    /// The corresponding C constant is `SFD_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: Options { Options(rawValue: _SFD_CLOEXEC) }

    /// Makes reading with no signal pending
    /// throw ``Errno/resourceTemporarilyUnavailable`` rather than wait.
    ///
    /// The corresponding C constant is `SFD_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: Options { Options(rawValue: _SFD_NONBLOCK) }
  }

  /// Changes the signals that the descriptor receives.
  ///
  /// The corresponding C function is `signalfd`.
  @_alwaysEmitIntoClient
  public func setSignals(_ signals: SignalSet) throws(Errno) {
    try _setSignals(signals).get()
  }

  @usableFromInline
  internal func _setSignals(_ signals: SignalSet) -> Result<(), Errno> {
    withUnsafePointer(to: signals.rawValue) { mask in
      nothingOrErrno(retryOnInterrupt: false) {
        system_signalfd(fileDescriptor.rawValue, mask, 0)
      }
    }
  }

  /// Takes a pending signal.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the read
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to try only once
  ///   and throw ``Errno/interrupted`` upon interruption.
  /// - Returns: The signal, and information about its cause.
  ///
  /// With no signal pending, this method waits for one,
  /// or with ``Options/nonBlocking``,
  /// throws ``Errno/resourceTemporarilyUnavailable``.
  ///
  /// The corresponding C function is `read`.
  @_alwaysEmitIntoClient
  public func read(retryOnInterrupt: Bool = true) throws(Errno) -> Information {
    try _read(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _read(retryOnInterrupt: Bool) -> Result<Information, Errno> {
    var record = csystem_signalfd_siginfo()
    return withUnsafeMutableBytes(of: &record) { buffer in
      fileDescriptor._read(into: buffer, retryOnInterrupt: retryOnInterrupt)
    }.flatMap { count in
      // The kernel returns whole records.
      guard count == MemoryLayout<csystem_signalfd_siginfo>.size else {
        return .failure(.invalidArgument)
      }
      return .success(Information(record))
    }
  }

  /// A signal that a signal descriptor received,
  /// and information about its cause.
  ///
  /// The corresponding C type is `struct signalfd_siginfo`.
  @frozen
  public struct Information: Hashable, Sendable {
    /// The signal.
    ///
    /// The corresponding C field is `ssi_signo`.
    public var signal: Signal

    /// Why the system delivered the signal,
    /// as ``Signal/Information/code`` reports it.
    ///
    /// The corresponding C field is `ssi_code`.
    public var code: CInt

    /// The process that sent the signal,
    /// or the child process that changed state.
    ///
    /// The corresponding C field is `ssi_pid`.
    public var processID: ProcessID

    /// The real user ID of the process that sent the signal.
    ///
    /// The corresponding C field is `ssi_uid`.
    public var userID: UserID

    /// For ``Signal/childStatusChange``,
    /// the child's exit status or signal number.
    ///
    /// The corresponding C field is `ssi_status`.
    public var status: CInt

    @usableFromInline
    internal init(_ record: csystem_signalfd_siginfo) {
      self.signal = Signal(rawValue: CInt(bitPattern: record.ssi_signo))
      self.code = record.ssi_code
      self.processID = ProcessID(rawValue: pid_t(bitPattern: record.ssi_pid))
      self.userID = UserID(rawValue: record.ssi_uid)
      self.status = record.ssi_status
    }
  }
}

#endif // os(Linux) || os(Android)
