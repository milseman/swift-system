/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Reading a passphrase without echo, from the console the process is
// attached to: the Windows counterpart of TerminalDescriptor's
// readPassphrase(prompt:maxByteCount:options:), over CONIN$ and CONOUT$,
// as readpassphrase reads /dev/tty, so that redirected standard streams
// don't matter.

@available(System 199, *)
extension Win32 {
  /// Shows a prompt on the console and reads a passphrase from it, without
  /// echo.
  ///
  /// - Parameters:
  ///   - prompt: The prompt, such as `"Password: "`.
  ///   - maxCount: The most UTF-16 code units of the passphrase to keep,
  ///     which can't be negative; the rest of the line is discarded. The
  ///     default is 1024.
  /// - Returns: The passphrase, without the end of its line.
  ///
  /// This reads the console that the process is attached to, whatever its
  /// standard input and output are, and throws the error that opening
  /// `CONIN$` reports for a process with no console. While it reads, the
  /// console's input mode is line input, with Ctrl+C processed but no
  /// echo; it restores the mode, and writes the line end that the user's
  /// Enter didn't, before it returns or throws. A Ctrl+C reaches the
  /// process's control handlers, whose default ends the process, with the
  /// mode not restored.
  ///
  /// The memory the passphrase was read into is cleared before this
  /// method returns; the string it returns isn't.
  ///
  /// The corresponding C functions are `ReadConsoleW` and `WriteConsoleW`,
  /// with `ENABLE_LINE_INPUT` and `ENABLE_PROCESSED_INPUT`.
  @_alwaysEmitIntoClient
  public static func readPassphrase(
    prompt: String, maxCount: Int = 1024
  ) throws(Win32.Error) -> String {
    try _readPassphrase(prompt: prompt, maxCount: maxCount).get()
  }

  @usableFromInline
  internal static func _readPassphrase(
    prompt: String, maxCount: Int
  ) -> Result<String, Win32.Error> {
    precondition(maxCount >= 0, "maxCount can't be negative")
    // Setting the input's mode needs write access too.
    let access = Win32.AccessMask([.genericRead, .genericWrite]).rawValue
    let share = Win32.ShareMode([.read, .write]).rawValue
    let existing = Win32.CreationDisposition.openExisting.rawValue
    let input: HANDLE
    switch _createFile(
      "CONIN$", access: access, shareMode: share, disposition: existing, flagsAndAttributes: 0,
      inheritable: false, securityDescriptor: nil, templateFile: nil)
    {
    case .success(let opened): input = opened.handle
    case .failure(let error): return .failure(error)
    }
    defer { _ = system_CloseHandle(input) }
    let output: HANDLE
    switch _createFile(
      "CONOUT$", access: access, shareMode: share, disposition: existing, flagsAndAttributes: 0,
      inheritable: false, securityDescriptor: nil, templateFile: nil)
    {
    case .success(let opened): output = opened.handle
    case .failure(let error): return .failure(error)
    }
    defer { _ = system_CloseHandle(output) }
    if let error = _writeConsole(output, prompt) { return .failure(error) }
    let original: DWORD
    switch _consoleMode(input) {
    case .success(let mode): original = mode
    case .failure(let error): return .failure(error)
    }
    let mode = Win32.ConsoleMode([.lineInput, .processedInput]).rawValue
    if case .failure(let error) = _setConsoleMode(input, mode) { return .failure(error) }
    let result = _readConsoleLine(input, maxCount: maxCount)
    _ = _setConsoleMode(input, original)
    // Without echo, the console didn't show the user's Enter.
    _ = _writeConsole(output, "\r\n")
    return result
  }

  /// Writes `text` to a console's output, or returns the error.
  internal static func _writeConsole(_ console: HANDLE, _ text: String) -> Win32.Error? {
    var units = Array(text.utf16)
    var start = 0
    while start < units.count {
      var written: DWORD = 0
      let succeeded = units.withUnsafeMutableBufferPointer { buffer in
        system_WriteConsoleW(
          console, buffer.baseAddress! + start, DWORD(buffer.count - start), &written)
      }
      guard succeeded else { return Win32.Error(GetLastError()) }
      start += Int(written)
    }
    return nil
  }

  /// Reads a line from a console's input in line mode, keeping at most
  /// `maxCount` code units and discarding the rest of the line.
  internal static func _readConsoleLine(
    _ console: HANDLE, maxCount: Int
  ) -> Result<String, Win32.Error> {
    var kept: [UInt16] = []
    kept.reserveCapacity(maxCount)
    defer { kept.withUnsafeMutableBytes { Memory._secureZero($0) } }
    // A read in line mode returns at most the buffer's code units of the
    // line, the rest staying for the next read, and the line ends with
    // "\r\n" when it fits.
    let chunk = UnsafeMutableBufferPointer<UInt16>.allocate(capacity: 256)
    defer {
      Memory._secureZero(UnsafeMutableRawBufferPointer(chunk))
      chunk.deallocate()
    }
    while true {
      var count: DWORD = 0
      guard system_ReadConsoleW(console, chunk.baseAddress!, DWORD(chunk.count), &count) else {
        return .failure(Win32.Error(GetLastError()))
      }
      // The end of input, as for a console whose input was closed.
      if count == 0 { break }
      let read = UnsafeBufferPointer(rebasing: chunk[..<Int(count)])
      let newline = read.firstIndex(of: UInt16(UInt8(ascii: "\n")))
      for unit in read[..<(newline ?? read.endIndex)] where kept.count < maxCount {
        kept.append(unit)
      }
      if newline != nil { break }
    }
    while kept.last == UInt16(UInt8(ascii: "\r")) { kept.removeLast() }
    return .success(String(decoding: kept, as: UTF16.self))
  }
}

#endif // os(Windows)
