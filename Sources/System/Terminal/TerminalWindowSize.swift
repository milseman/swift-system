/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

// Must import here to use C winsize properties.
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

// MARK: - Window Size

@available(System 199, *)
extension TerminalDescriptor {
  /// The size of a terminal window in characters.
  @frozen
  @available(System 199, *)
  public struct WindowSize: RawRepresentable, Hashable, Sendable {
    /// The raw C window size,
    /// which also holds the window's width and height in pixels.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.WinSize

    /// Creates a strongly-typed window size from a raw C window size.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.WinSize) {
      self.rawValue = rawValue
    }

    /// Creates a window size with the given number of rows and columns,
    /// and a size in pixels of zero, which means unknown.
    @_alwaysEmitIntoClient
    public init(rows: UInt16, columns: UInt16) {
      var size = CInterop.WinSize()
      size.ws_row = rows
      size.ws_col = columns
      self.rawValue = size
    }

    /// The number of rows, or lines of text.
    @_alwaysEmitIntoClient
    public var rows: UInt16 {
      get { rawValue.ws_row }
      set { rawValue.ws_row = newValue }
    }

    /// The number of columns, or characters per line.
    @_alwaysEmitIntoClient
    public var columns: UInt16 {
      get { rawValue.ws_col }
      set { rawValue.ws_col = newValue }
    }

    // MARK: - Equatable & Hashable

    /// Returns whether two window sizes have the same rows and columns.
    ///
    /// The sizes in pixels aren't compared.
    @_alwaysEmitIntoClient
    public static func == (lhs: WindowSize, rhs: WindowSize) -> Bool {
      lhs.rows == rhs.rows && lhs.columns == rhs.columns
    }

    /// Hashes the rows and columns.
    @_alwaysEmitIntoClient
    public func hash(into hasher: inout Hasher) {
      hasher.combine(rows)
      hasher.combine(columns)
    }
  }

  /// Returns the terminal's window size.
  ///
  /// - Returns: The window size, which is zero if nothing has set it,
  ///   as for a new pseudoterminal.
  ///
  /// The corresponding C function is `ioctl`, with the `TIOCGWINSZ` request.
  @_alwaysEmitIntoClient
  public func windowSize() throws(Errno) -> WindowSize {
    try _windowSize().get()
  }

  @usableFromInline
  internal func _windowSize() -> Result<WindowSize, Errno> {
    var size = CInterop.WinSize()
    let result = withUnsafeMutablePointer(to: &size) { sizePtr in
      valueOrErrno(retryOnInterrupt: false) {
        system_tiocgwinsz(rawValue, sizePtr)
      }
    }
    return result.map { _ in WindowSize(rawValue: size) }
  }

  /// Sets the terminal's window size.
  ///
  /// - Parameters:
  ///   - size: The new window size.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// If the size changes, the system sends `SIGWINCH`
  /// to the terminal's foreground process group.
  ///
  /// The corresponding C function is `ioctl`, with the `TIOCSWINSZ` request.
  @_alwaysEmitIntoClient
  public func setWindowSize(_ size: WindowSize, retryOnInterrupt: Bool = true) throws(Errno) {
    try _setWindowSize(size, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setWindowSize(
    _ size: WindowSize, retryOnInterrupt: Bool
  ) -> Result<Void, Errno> {
    var ws = size.rawValue
    return withUnsafePointer(to: &ws) { sizePtr in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_tiocswinsz(rawValue, sizePtr)
      }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
