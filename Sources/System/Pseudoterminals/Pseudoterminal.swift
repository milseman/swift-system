/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

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

@available(System 199, *)
@available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
extension TerminalDescriptor {
  /// Opens a new pseudoterminal, and returns its two ends.
  ///
  ///     let (controller, terminal) = try TerminalDescriptor.openPseudoterminal()
  ///     defer {
  ///       try? controller.close()
  ///       try? terminal.fileDescriptor.close()
  ///     }
  ///
  /// - Parameters:
  ///   - attributes: The terminal's attributes,
  ///     or `nil` for the system's defaults,
  ///     which are canonical mode with echo.
  ///   - windowSize: The terminal's window size,
  ///     or `nil` for the system's default, 0 rows and 0 columns.
  ///   - closeOnExec: Whether executing a program closes both descriptors.
  ///     The default is `true`,
  ///     so that a program that another thread starts doesn't inherit them.
  ///     A spawn file action that duplicates the terminal
  ///     hands it to a child all the same.
  /// - Returns: The controller and the terminal.
  ///   What the controller writes is the terminal's input,
  ///   and what the terminal writes can be read from the controller.
  ///   You're responsible for closing both.
  ///
  /// A pseudoterminal is a pair of devices that act as a terminal
  /// and the hardware behind it.
  /// A program that reads and writes the terminal end,
  /// usually as its standard input, output, and error,
  /// sees a terminal, with its line editing, echo, signal characters,
  /// and window size,
  /// while the program that holds the controller acts as its keyboard
  /// and its screen, as a terminal emulator, `ssh`'s server,
  /// and `script` do.
  ///
  /// Neither end becomes the calling process's controlling terminal.
  /// To make the terminal a child's controlling terminal,
  /// as `login_tty` does after `forkpty` forks,
  /// spawn the child in a new session and have it open the terminal
  /// by its path, ``FileDescriptor/pseudoterminalPath()``,
  /// with a spawn file action,
  /// rather than duplicate the descriptor this method returns.
  ///
  /// On Darwin, a process that writes to the terminal and then closes it,
  /// as it does when it exits, blocks until the controller reads what it
  /// wrote, so read from the controller before waiting for such a child.
  ///
  /// The corresponding C function is `openpty`.
  /// This method does what `openpty` does with POSIX's functions,
  /// which need no separate library.
  /// The corresponding C functions are `posix_openpt`, `grantpt`,
  /// and `unlockpt`.
  @_alwaysEmitIntoClient
  public static func openPseudoterminal(
    attributes: TerminalAttributes? = nil,
    windowSize: WindowSize? = nil,
    closeOnExec: Bool = true
  ) throws(Errno) -> (controller: FileDescriptor, terminal: TerminalDescriptor) {
    try _openPseudoterminal(
      attributes: attributes, windowSize: windowSize, closeOnExec: closeOnExec
    ).get()
  }

  @usableFromInline
  internal static func _openPseudoterminal(
    attributes: TerminalAttributes?,
    windowSize: WindowSize?,
    closeOnExec: Bool
  ) -> Result<(controller: FileDescriptor, terminal: TerminalDescriptor), Errno> {
    let flags = _O_RDWR | _O_NOCTTY | (closeOnExec ? _O_CLOEXEC : 0)
    let controller: FileDescriptor
    switch valueOrErrno(retryOnInterrupt: true, { system_posix_openpt(flags) }) {
    case .success(let fd): controller = FileDescriptor(rawValue: fd)
    case .failure(let error): return .failure(error)
    }
    let terminal = controller._openControlledTerminal(
      flags: flags, attributes: attributes, windowSize: windowSize)
    if case .failure = terminal {
      _ = system_close(controller.rawValue)
    }
    return terminal.map { (controller, $0) }
  }
}

@available(System 199, *)
@available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
extension FileDescriptor {
  /// Returns the path of the terminal
  /// that this pseudoterminal controller controls.
  ///
  /// The path names a device such as `/dev/pts/3` on Linux,
  /// or `/dev/ttys003` on Darwin.
  /// It's how a child process opens the terminal
  /// as its controlling terminal;
  /// see ``TerminalDescriptor/openPseudoterminal(attributes:windowSize:closeOnExec:)``.
  ///
  /// If this descriptor isn't a pseudoterminal's controller,
  /// this method throws, with an error that differs by platform,
  /// such as ``Errno/notTerminal``.
  ///
  /// The corresponding C function is `ptsname_r`.
  @_alwaysEmitIntoClient
  public func pseudoterminalPath() throws(Errno) -> FilePath {
    try _pseudoterminalPath().get()
  }

  @usableFromInline
  internal func _pseudoterminalPath() -> Result<FilePath, Errno> {
    // Darwin's paths are 12 bytes long, and Linux's 9 and up.
    var capacity = 128
    while true {
      let result = withUnsafeTemporaryAllocation(
        of: CChar.self, capacity: capacity
      ) { buffer in
        buffer.initialize(repeating: 0)
        // Leave the last character zero, whatever the call writes.
        return nothingOrReturnedErrno(retryOnInterrupt: false) {
          system_ptsname_r(rawValue, buffer.baseAddress!, buffer.count - 1)
        }.map { FilePath(platformString: buffer.baseAddress!) }
      }
      guard case .failure(.outOfRange) = result, capacity < 1 << 12 else { return result }
      capacity *= 2
    }
  }

  /// Grants access to the terminal that this pseudoterminal controller
  /// controls, unlocks it, and opens it, as `openpty` does.
  internal func _openControlledTerminal(
    flags: CInt,
    attributes: TerminalAttributes?,
    windowSize: TerminalDescriptor.WindowSize?
  ) -> Result<TerminalDescriptor, Errno> {
    let path: FilePath
    switch nothingOrErrno(retryOnInterrupt: false, { system_grantpt(rawValue) })
      .flatMap({ nothingOrErrno(retryOnInterrupt: false) { system_unlockpt(rawValue) } })
      .flatMap({ _pseudoterminalPath() })
    {
    case .success(let terminalPath): path = terminalPath
    case .failure(let error): return .failure(error)
    }
    let fd: CInt
    switch path.withPlatformString({ path in
      valueOrErrno(retryOnInterrupt: true) { system_open(path, flags) }
    }) {
    case .success(let opened): fd = opened
    case .failure(let error): return .failure(error)
    }
    let terminal = TerminalDescriptor(rawValue: fd)
    var configured: Result<Void, Errno> = .success(())
    if let attributes {
      configured = terminal._setAttributes(attributes, when: .now, retryOnInterrupt: true)
    }
    if case .success = configured, let windowSize {
      configured = terminal._setWindowSize(windowSize, retryOnInterrupt: true)
    }
    if case .failure(let error) = configured {
      _ = system_close(fd)
      return .failure(error)
    }
    return .success(terminal)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
