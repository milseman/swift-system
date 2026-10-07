/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Standard handles

@available(System 199, *)
extension Win32 {
  /// One of a process's three standard handles.
  ///
  /// `GetStdHandle` takes one in its `nStdHandle` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct StandardHandle: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed standard handle from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The standard input handle.
    ///
    /// The corresponding C constant is `STD_INPUT_HANDLE`.
    @_alwaysEmitIntoClient
    public static var input: StandardHandle { StandardHandle(rawValue: DWORD(bitPattern: -10)) }

    /// The standard output handle.
    ///
    /// The corresponding C constant is `STD_OUTPUT_HANDLE`.
    @_alwaysEmitIntoClient
    public static var output: StandardHandle { StandardHandle(rawValue: DWORD(bitPattern: -11)) }

    /// The standard error handle.
    ///
    /// The corresponding C constant is `STD_ERROR_HANDLE`.
    @_alwaysEmitIntoClient
    public static var error: StandardHandle { StandardHandle(rawValue: DWORD(bitPattern: -12)) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Calls `body` with one of the process's standard handles, if it has
  /// one.
  ///
  /// The handle is **borrowed** from the process, which keeps it for
  /// `GetStdHandle` to return, and the borrow is valid only for the
  /// duration of the call. `body` isn't called if the process has no such
  /// handle, as a process without a console can lack them, or if the handle
  /// is overlapped, on which the synchronous I/O of ``Win32/FileHandle``
  /// isn't memory-safe.
  ///
  /// This is the handle the process holds now, which `SetStdHandle` can
  /// replace. The C runtime's standard descriptors keep the handles they
  /// were opened with; ``FileDescriptor/withWin32HandleIfAvailable(_:)``
  /// lends those.
  ///
  /// - Parameters:
  ///   - which: The standard handle to lend.
  ///   - body: A closure that receives the handle.
  /// - Returns: The value that `body` returns, or `nil` if it wasn't called.
  ///
  /// The corresponding C function is `GetStdHandle`.
  @_alwaysEmitIntoClient
  public static func withStandardHandle<R: ~Copyable, E: Error>(
    _ which: Win32.StandardHandle,
    _ body: (borrowing Win32.FileHandle) throws(E) -> R
  ) throws(E) -> R? {
    guard let handle = Win32._standardHandle(which.rawValue) else { return nil }
    // The process owns the handle, so the lent FileHandle is relinquished on
    // every path, and its deinit never closes it.
    let lent = Win32.FileHandle(_owning: handle)
    let result: R
    do throws(E) {
      result = try body(lent)
    } catch {
      _ = lent.relinquish()
      throw error
    }
    _ = lent.relinquish()
    return result
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Makes a handle one of the process's standard handles, which
  /// ``withStandardHandle(_:_:)`` lends from then on, and which the processes
  /// it creates without handles of their own inherit.
  ///
  /// - Parameters:
  ///   - which: The standard handle to replace.
  ///   - handle: The new standard handle, which the process keeps until it
  ///     exits. If the call throws, the handle is closed.
  ///
  /// The process's previous standard handle isn't closed, since something
  /// else can own it: the C runtime's descriptor 0, 1 or 2 opened with it,
  /// or the console. Those descriptors keep their handles, so `print` and
  /// `FileDescriptor.standardOutput` still write where they did.
  ///
  /// The corresponding C function is `SetStdHandle`.
  @_alwaysEmitIntoClient
  public static func setStandardHandle(
    _ which: Win32.StandardHandle, to handle: consuming Win32.FileHandle
  ) throws(Win32.Error) {
    let raw = handle._handle
    try Win32._setStandardHandle(which.rawValue, raw).get()
    // The process holds it now.
    _ = handle.relinquish()
  }
}

// MARK: - Console modes

@available(System 199, *)
extension Win32 {
  /// How a console handles the input or output of one of its handles.
  ///
  /// A console input handle and a screen buffer handle have different
  /// modes, whose flags share bits: each input flag here has the value of
  /// an output flag. So a mode holding ``processedInput`` also contains
  /// ``processedOutput``, and only the handle's kind tells which it means.
  ///
  /// `SetConsoleMode` takes a mode in its `dwMode` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ConsoleMode: OptionSet, Sendable, Hashable, Codable {
    /// The raw C mode.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed mode from a raw C mode.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Input: the console handles Ctrl+C and editing keys itself, rather
    /// than passing them to reads.
    ///
    /// The same bit as ``processedOutput``.
    ///
    /// The corresponding C constant is `ENABLE_PROCESSED_INPUT`.
    @_alwaysEmitIntoClient
    public static var processedInput: ConsoleMode { ConsoleMode(rawValue: 0x0001) }

    /// Input: a read returns once the user presses Enter, rather than as
    /// each character arrives.
    ///
    /// The same bit as ``wrapAtEndOfLine``.
    ///
    /// The corresponding C constant is `ENABLE_LINE_INPUT`.
    @_alwaysEmitIntoClient
    public static var lineInput: ConsoleMode { ConsoleMode(rawValue: 0x0002) }

    /// Input: the console shows characters as they're typed. It requires
    /// ``lineInput``.
    ///
    /// The same bit as ``virtualTerminalProcessing``.
    ///
    /// The corresponding C constant is `ENABLE_ECHO_INPUT`.
    @_alwaysEmitIntoClient
    public static var echoInput: ConsoleMode { ConsoleMode(rawValue: 0x0004) }

    /// Input: changes to the screen buffer's size are input events.
    ///
    /// The same bit as ``disableNewlineAutoReturn``.
    ///
    /// The corresponding C constant is `ENABLE_WINDOW_INPUT`.
    @_alwaysEmitIntoClient
    public static var windowInput: ConsoleMode { ConsoleMode(rawValue: 0x0008) }

    /// Input: mouse events in the console window are input events.
    ///
    /// The same bit as ``lvbGridWorldwide``.
    ///
    /// The corresponding C constant is `ENABLE_MOUSE_INPUT`.
    @_alwaysEmitIntoClient
    public static var mouseInput: ConsoleMode { ConsoleMode(rawValue: 0x0010) }

    /// Input: typed text is inserted at the cursor, rather than replacing
    /// the text there.
    ///
    /// The corresponding C constant is `ENABLE_INSERT_MODE`.
    @_alwaysEmitIntoClient
    public static var insertMode: ConsoleMode { ConsoleMode(rawValue: 0x0020) }

    /// Input: the user can select and copy text with the mouse. Setting or
    /// clearing it needs ``extendedFlags`` too.
    ///
    /// The corresponding C constant is `ENABLE_QUICK_EDIT_MODE`.
    @_alwaysEmitIntoClient
    public static var quickEditMode: ConsoleMode { ConsoleMode(rawValue: 0x0040) }

    /// Input: the mode sets or clears ``insertMode`` and ``quickEditMode``.
    ///
    /// The corresponding C constant is `ENABLE_EXTENDED_FLAGS`.
    @_alwaysEmitIntoClient
    public static var extendedFlags: ConsoleMode { ConsoleMode(rawValue: 0x0080) }

    /// Input: the console positions the cursor itself.
    ///
    /// The corresponding C constant is `ENABLE_AUTO_POSITION`.
    @_alwaysEmitIntoClient
    public static var autoPosition: ConsoleMode { ConsoleMode(rawValue: 0x0100) }

    /// Input: the console converts keys to virtual terminal sequences for
    /// reads, as a terminal sends them.
    ///
    /// The corresponding C constant is `ENABLE_VIRTUAL_TERMINAL_INPUT`.
    @_alwaysEmitIntoClient
    public static var virtualTerminalInput: ConsoleMode { ConsoleMode(rawValue: 0x0200) }

    /// Output: the console acts on control characters it's written, such as
    /// backspace, tab, and newline, rather than showing them.
    ///
    /// The same bit as ``processedInput``.
    ///
    /// The corresponding C constant is `ENABLE_PROCESSED_OUTPUT`.
    @_alwaysEmitIntoClient
    public static var processedOutput: ConsoleMode { ConsoleMode(rawValue: 0x0001) }

    /// Output: text that reaches the end of a row continues on the next.
    ///
    /// The same bit as ``lineInput``.
    ///
    /// The corresponding C constant is `ENABLE_WRAP_AT_EOL_OUTPUT`.
    @_alwaysEmitIntoClient
    public static var wrapAtEndOfLine: ConsoleMode { ConsoleMode(rawValue: 0x0002) }

    /// Output: the console interprets virtual terminal sequences it's
    /// written, such as those that set colors and move the cursor.
    ///
    /// The same bit as ``echoInput``.
    ///
    /// The corresponding C constant is `ENABLE_VIRTUAL_TERMINAL_PROCESSING`.
    @_alwaysEmitIntoClient
    public static var virtualTerminalProcessing: ConsoleMode { ConsoleMode(rawValue: 0x0004) }

    /// Output: a newline moves the cursor down without returning it to the
    /// first column.
    ///
    /// The same bit as ``windowInput``.
    ///
    /// The corresponding C constant is `DISABLE_NEWLINE_AUTO_RETURN`.
    @_alwaysEmitIntoClient
    public static var disableNewlineAutoReturn: ConsoleMode { ConsoleMode(rawValue: 0x0008) }

    /// Output: the console draws the grid attributes of characters'
    /// attribute words, for any code page.
    ///
    /// The same bit as ``mouseInput``.
    ///
    /// The corresponding C constant is `ENABLE_LVB_GRID_WORLDWIDE`.
    @_alwaysEmitIntoClient
    public static var lvbGridWorldwide: ConsoleMode { ConsoleMode(rawValue: 0x0010) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Whether this handle is a console input or screen buffer handle.
  ///
  /// A console is the only terminal Windows has. This is `false` for other
  /// character devices, such as `NUL` and serial ports, which
  /// ``fileType()`` also reports as ``Win32/FileType/character``.
  ///
  /// The corresponding C function is `GetConsoleMode`.
  @_alwaysEmitIntoClient
  public var isConsole: Bool {
    Win32._isConsole(_handle)
  }

  /// The console's mode for this handle.
  ///
  /// Needs ``Win32/AccessMask/genericRead``. Throws
  /// ``Win32/Error/invalidHandle`` for a handle that isn't a console's.
  ///
  /// The corresponding C function is `GetConsoleMode`.
  @_alwaysEmitIntoClient
  public func consoleMode() throws(Win32.Error) -> Win32.ConsoleMode {
    Win32.ConsoleMode(rawValue: try Win32._consoleMode(_handle).get())
  }

  /// Sets the console's mode for this handle.
  ///
  /// Needs ``Win32/AccessMask/genericRead`` or
  /// ``Win32/AccessMask/genericWrite``. Throws
  /// ``Win32/Error/invalidParameter`` for a mode the console doesn't
  /// support, such as ``Win32/ConsoleMode/virtualTerminalProcessing``
  /// before Windows 10.
  ///
  /// The mode belongs to the console, not to this process: it lasts after
  /// the process exits, and other processes attached to the console see it.
  ///
  /// The corresponding C function is `SetConsoleMode`.
  @_alwaysEmitIntoClient
  public func setConsoleMode(_ mode: Win32.ConsoleMode) throws(Win32.Error) {
    try Win32._setConsoleMode(_handle, mode.rawValue).get()
  }

  /// Sets the console's mode for this handle, runs `body`, and restores
  /// the previous mode.
  ///
  /// The mode is restored when `body` returns or throws. If `body` succeeds
  /// but restoring fails, the restore's error is thrown, discarding the
  /// result. If both fail, `body`'s error wins.
  ///
  /// The corresponding C functions are `GetConsoleMode` and
  /// `SetConsoleMode`.
  @_alwaysEmitIntoClient
  public func withConsoleMode<R: ~Copyable>(
    _ mode: Win32.ConsoleMode,
    _ body: () throws(Win32.Error) -> R
  ) throws(Win32.Error) -> R {
    let handle = _handle
    let previous = try consoleMode()
    try Win32._setConsoleMode(handle, mode.rawValue).get()
    let result = try Win32._restoringConsoleModeIfThrows(handle, previous.rawValue, body)
    try Win32._setConsoleMode(handle, previous.rawValue).get()
    return result
  }

  /// Sets the console's mode for this handle, runs `body`, and restores
  /// the previous mode.
  ///
  /// This overload is for a `body` that throws errors other than
  /// ``Win32/Error``. Otherwise, it behaves like the overload whose `body`
  /// throws `Win32.Error`, which Swift prefers where both apply.
  ///
  /// The corresponding C functions are `GetConsoleMode` and
  /// `SetConsoleMode`.
  @_alwaysEmitIntoClient
  @_disfavoredOverload
  public func withConsoleMode<R: ~Copyable>(
    _ mode: Win32.ConsoleMode,
    _ body: () throws -> R
  ) throws -> R {
    let handle = _handle
    let previous = try consoleMode()
    try Win32._setConsoleMode(handle, mode.rawValue).get()
    let result = try Win32._restoringConsoleModeIfThrows(handle, previous.rawValue, body)
    try Win32._setConsoleMode(handle, previous.rawValue).get()
    return result
  }
}

// MARK: - Screen buffers

@available(System 199, *)
extension Win32 {
  /// The state of a console screen buffer: its size, its cursor, and the
  /// part of it that the console window shows.
  ///
  /// Positions count character cells from 0, from the buffer's top left.
  ///
  /// The corresponding C type is `CONSOLE_SCREEN_BUFFER_INFO`.
  @frozen
  public struct ConsoleScreenBufferInfo: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: CONSOLE_SCREEN_BUFFER_INFO

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: CONSOLE_SCREEN_BUFFER_INFO) { self.rawValue = rawValue }

    /// The buffer's width, in columns of characters.
    ///
    /// The corresponding C field is `dwSize.X`.
    @_alwaysEmitIntoClient
    public var columns: Int { Int(rawValue.dwSize.X) }

    /// The buffer's height, in rows of characters.
    ///
    /// The corresponding C field is `dwSize.Y`.
    @_alwaysEmitIntoClient
    public var rows: Int { Int(rawValue.dwSize.Y) }

    /// The cursor's column.
    ///
    /// The corresponding C field is `dwCursorPosition.X`.
    @_alwaysEmitIntoClient
    public var cursorColumn: Int { Int(rawValue.dwCursorPosition.X) }

    /// The cursor's row.
    ///
    /// The corresponding C field is `dwCursorPosition.Y`.
    @_alwaysEmitIntoClient
    public var cursorRow: Int { Int(rawValue.dwCursorPosition.Y) }

    /// The first column the window shows.
    ///
    /// The corresponding C field is `srWindow.Left`.
    @_alwaysEmitIntoClient
    public var windowLeft: Int { Int(rawValue.srWindow.Left) }

    /// The first row the window shows.
    ///
    /// The corresponding C field is `srWindow.Top`.
    @_alwaysEmitIntoClient
    public var windowTop: Int { Int(rawValue.srWindow.Top) }

    /// How many columns the window shows: the width a program should lay
    /// its output out to.
    ///
    /// The corresponding C fields are `srWindow.Left` and `srWindow.Right`,
    /// inclusive.
    @_alwaysEmitIntoClient
    public var windowColumns: Int { Int(rawValue.srWindow.Right) - Int(rawValue.srWindow.Left) + 1 }

    /// How many rows the window shows.
    ///
    /// The corresponding C fields are `srWindow.Top` and `srWindow.Bottom`,
    /// inclusive.
    @_alwaysEmitIntoClient
    public var windowRows: Int { Int(rawValue.srWindow.Bottom) - Int(rawValue.srWindow.Top) + 1 }

    /// The most columns the window could show, given the buffer, the font,
    /// and the screen.
    ///
    /// The corresponding C field is `dwMaximumWindowSize.X`.
    @_alwaysEmitIntoClient
    public var maximumWindowColumns: Int { Int(rawValue.dwMaximumWindowSize.X) }

    /// The most rows the window could show.
    ///
    /// The corresponding C field is `dwMaximumWindowSize.Y`.
    @_alwaysEmitIntoClient
    public var maximumWindowRows: Int { Int(rawValue.dwMaximumWindowSize.Y) }

    /// The colors and other attributes that written characters get.
    ///
    /// The corresponding C field is `wAttributes`.
    @_alwaysEmitIntoClient
    public var attributes: WORD { rawValue.wAttributes }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// The state of the console screen buffer this handle refers to.
  ///
  /// Needs ``Win32/AccessMask/genericRead``. Throws
  /// ``Win32/Error/invalidHandle`` for a handle that isn't a screen
  /// buffer's.
  ///
  /// The corresponding C function is `GetConsoleScreenBufferInfo`.
  @_alwaysEmitIntoClient
  public func consoleScreenBufferInfo() throws(Win32.Error) -> Win32.ConsoleScreenBufferInfo {
    Win32.ConsoleScreenBufferInfo(rawValue: try Win32._consoleScreenBufferInfo(_handle).get())
  }
}

// MARK: - Control events

@available(System 199, *)
extension Win32 {
  /// An event that a console delivers to the processes attached to it.
  ///
  /// A `HandlerRoutine` receives one in its `dwCtrlType` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ConsoleControlEvent: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed event from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The user pressed Ctrl+C.
    ///
    /// The corresponding C constant is `CTRL_C_EVENT`.
    @_alwaysEmitIntoClient
    public static var controlC: ConsoleControlEvent { ConsoleControlEvent(rawValue: 0) }

    /// The user pressed Ctrl+Break.
    ///
    /// The corresponding C constant is `CTRL_BREAK_EVENT`.
    @_alwaysEmitIntoClient
    public static var controlBreak: ConsoleControlEvent { ConsoleControlEvent(rawValue: 1) }

    /// The user closed the console. The process ends soon after its
    /// handlers return.
    ///
    /// The corresponding C constant is `CTRL_CLOSE_EVENT`.
    @_alwaysEmitIntoClient
    public static var close: ConsoleControlEvent { ConsoleControlEvent(rawValue: 2) }

    /// A user is logging off. Only services receive it.
    ///
    /// The corresponding C constant is `CTRL_LOGOFF_EVENT`.
    @_alwaysEmitIntoClient
    public static var logoff: ConsoleControlEvent { ConsoleControlEvent(rawValue: 5) }

    /// The system is shutting down. Only services receive it.
    ///
    /// The corresponding C constant is `CTRL_SHUTDOWN_EVENT`.
    @_alwaysEmitIntoClient
    public static var shutdown: ConsoleControlEvent { ConsoleControlEvent(rawValue: 6) }
  }

  /// Adds a function that runs when the console delivers a control event to
  /// this process.
  ///
  /// - Parameter handler: A C function, which a closure that captures
  ///   nothing converts to. It receives the raw value of a
  ///   ``ConsoleControlEvent``, and returns `true` if it handled the event,
  ///   or `false` to pass it to the handler added before it. The last
  ///   handler, Windows' default, ends the process.
  ///
  /// Windows calls the handlers on a thread it creates for the event, most
  /// recently added first.
  ///
  /// The corresponding C function is `SetConsoleCtrlHandler`, with `Add`
  /// `TRUE`.
  @_alwaysEmitIntoClient
  public static func addConsoleControlHandler(_ handler: PHANDLER_ROUTINE) throws(Win32.Error) {
    try _setConsoleControlHandler(handler, add: true).get()
  }

  /// Removes a function that ``addConsoleControlHandler(_:)`` added.
  ///
  /// The corresponding C function is `SetConsoleCtrlHandler`, with `Add`
  /// `FALSE`.
  @_alwaysEmitIntoClient
  public static func removeConsoleControlHandler(_ handler: PHANDLER_ROUTINE) throws(Win32.Error) {
    try _setConsoleControlHandler(handler, add: false).get()
  }

  /// Sets whether this process ignores Ctrl+C.
  ///
  /// A process that ignores Ctrl+C still receives Ctrl+Break and the other
  /// events. The processes it creates inherit the setting.
  ///
  /// The corresponding C function is `SetConsoleCtrlHandler`, with a null
  /// `HandlerRoutine`.
  @_alwaysEmitIntoClient
  public static func setIgnoresConsoleInterrupt(_ ignores: Bool) throws(Win32.Error) {
    try _setConsoleControlHandler(nil, add: ignores).get()
  }
}

// MARK: - Attaching and generating events

@available(System 199, *)
extension Win32 {
  /// Attaches the calling process to another process's console.
  ///
  /// - Parameter process: The process whose console to attach to.
  ///
  /// A process has at most one console: one that has a console already
  /// throws ``Win32/Error/accessDenied``, and calls ``freeConsole()`` first.
  /// A process with no console throws ``Win32/Error/invalidHandle``, and
  /// one that doesn't exist ``Win32/Error/invalidParameter``.
  ///
  /// Attaching makes the console's input and screen buffer the process's
  /// standard handles, but not the C runtime's descriptors 0, 1 and 2,
  /// which keep the handles they were opened with.
  ///
  /// The corresponding C function is `AttachConsole`.
  @_alwaysEmitIntoClient
  public static func attachConsole(of process: ProcessID) throws(Win32.Error) {
    try _attachConsole(process.rawValue).get()
  }

  /// Attaches the calling process to its parent's console.
  ///
  /// See ``attachConsole(of:)``.
  ///
  /// The corresponding C function is `AttachConsole`, with
  /// `ATTACH_PARENT_PROCESS`.
  @_alwaysEmitIntoClient
  public static func attachParentConsole() throws(Win32.Error) {
    try _attachConsole(_ATTACH_PARENT_PROCESS).get()
  }

  /// Detaches the calling process from its console.
  ///
  /// The console closes when no process is attached to it. The process's
  /// handles to it, its standard handles included, stop working.
  ///
  /// The corresponding C function is `FreeConsole`.
  @_alwaysEmitIntoClient
  public static func freeConsole() throws(Win32.Error) {
    try _freeConsole().get()
  }

  /// Creates a console for the calling process, which has none, and makes
  /// its input and screen buffer the process's standard handles.
  ///
  /// A process that has a console throws ``Win32/Error/accessDenied``. The
  /// C runtime's descriptors 0, 1 and 2 keep the handles they were opened
  /// with.
  ///
  /// The corresponding C function is `AllocConsole`.
  @_alwaysEmitIntoClient
  public static func allocateConsole() throws(Win32.Error) {
    try _allocateConsole().get()
  }

  /// Delivers Ctrl+C or Ctrl+Break to the processes attached to the calling
  /// process's console.
  ///
  /// - Parameters:
  ///   - event: ``ConsoleControlEvent/controlC`` or
  ///     ``ConsoleControlEvent/controlBreak``; another event throws
  ///     ``Win32/Error/invalidParameter``.
  ///   - group: The process group to deliver it to, the ID of the process
  ///     that ``ProcessCreationFlags/newProcessGroup`` created, or `nil` for
  ///     every process attached to the console, the calling one included.
  ///
  /// Ctrl+C doesn't reach a process group: a process created with
  /// ``ProcessCreationFlags/newProcessGroup`` ignores it, so deliver
  /// Ctrl+Break to one. A process with no handler of its own ends, as
  /// ``addConsoleControlHandler(_:)`` describes.
  ///
  /// The corresponding C function is `GenerateConsoleCtrlEvent`.
  @_alwaysEmitIntoClient
  public static func generateConsoleControlEvent(
    _ event: ConsoleControlEvent, toProcessGroup group: ProcessID? = nil
  ) throws(Win32.Error) {
    try _generateConsoleControlEvent(event.rawValue, group?.rawValue ?? 0).get()
  }
}

// MARK: - Terminals

@available(System 199, *)
extension FileDescriptor {
  /// Whether this file descriptor refers to a console, which is Windows'
  /// terminal.
  ///
  /// Unlike the C runtime's `_isatty`, which reports every character
  /// device, this is `false` for `NUL` and serial ports. A terminal
  /// emulator that runs programs through pipes rather than a console, such
  /// as MSYS2's mintty, is `false` too.
  ///
  /// The corresponding C function is `GetConsoleMode`, on the handle that
  /// `_get_osfhandle` returns.
  @_alwaysEmitIntoClient
  public var isTerminal: Bool {
    _isConsole()
  }

  @usableFromInline
  internal func _isConsole() -> Bool {
    guard let handle = _win32HandleIfAvailable() else { return false }
    return Win32._isConsole(handle)
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _standardHandle(_ which: DWORD) -> HANDLE? {
    // NULL for no handle; INVALID_HANDLE_VALUE if it can't be read.
    guard let handle = system_GetStdHandle(which), handle != INVALID_HANDLE_VALUE else {
      return nil
    }
    // A parent can pass an overlapped handle, such as one end of a named
    // pipe it created that way.
    guard _isSynchronous(handle) else { return nil }
    return handle
  }

  @usableFromInline
  internal static func _consoleMode(_ handle: HANDLE) -> Result<DWORD, Win32.Error> {
    var mode: DWORD = 0
    guard system_GetConsoleMode(handle, &mode) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(mode)
  }

  @usableFromInline
  internal static func _isConsole(_ handle: HANDLE) -> Bool {
    var mode: DWORD = 0
    return system_GetConsoleMode(handle, &mode)
  }

  @usableFromInline
  internal static func _setConsoleMode(_ handle: HANDLE, _ mode: DWORD) -> Result<Void, Win32.Error> {
    guard system_SetConsoleMode(handle, mode) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  /// Runs `body`, restoring `mode` if it throws. `body`'s error wins over
  /// the restore's.
  @_alwaysEmitIntoClient
  internal static func _restoringConsoleModeIfThrows<R: ~Copyable, E: Swift.Error>(
    _ handle: HANDLE, _ mode: DWORD, _ body: () throws(E) -> R
  ) throws(E) -> R {
    do throws(E) {
      return try body()
    } catch {
      _ = _setConsoleMode(handle, mode)
      throw error
    }
  }

  @usableFromInline
  internal static func _consoleScreenBufferInfo(
    _ handle: HANDLE
  ) -> Result<CONSOLE_SCREEN_BUFFER_INFO, Win32.Error> {
    var info = CONSOLE_SCREEN_BUFFER_INFO()
    guard system_GetConsoleScreenBufferInfo(handle, &info) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(info)
  }

  @usableFromInline
  internal static func _setStandardHandle(_ which: DWORD, _ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_SetStdHandle(which, handle) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _attachConsole(_ process: DWORD) -> Result<Void, Win32.Error> {
    guard system_AttachConsole(process) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _freeConsole() -> Result<Void, Win32.Error> {
    guard system_FreeConsole() else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _allocateConsole() -> Result<Void, Win32.Error> {
    guard system_AllocConsole() else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _generateConsoleControlEvent(
    _ event: DWORD, _ group: DWORD
  ) -> Result<Void, Win32.Error> {
    guard system_GenerateConsoleCtrlEvent(event, group) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _setConsoleControlHandler(
    _ handler: PHANDLER_ROUTINE?, add: Bool
  ) -> Result<Void, Win32.Error> {
    guard system_SetConsoleCtrlHandler(handler, add) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
