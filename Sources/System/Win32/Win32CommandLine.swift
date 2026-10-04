/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

// Quoting a command line for `Win32.ProcessHandle.create(commandLine:...)`,
// which passes the program one string that it splits into arguments itself.

@available(System 199, *)
extension Win32 {
  /// Returns a command line that runs a program with arguments, quoted so
  /// that a program that splits its command line by the C runtime's rules
  /// receives each argument as it's given.
  ///
  ///     let line = Win32.commandLine(
  ///       program: "C:\\Tools\\tool.exe", arguments: ["--name", "two words", ""])
  ///     // "C:\Tools\tool.exe" --name "two words" ""
  ///
  /// - Parameters:
  ///   - program: The program's path or name, the command line's first token.
  ///     It's always quoted, so that `CreateProcessW`, which reads the
  ///     program from the command line when it isn't given one, doesn't take
  ///     a shorter path that ends at a space for it. Its backslashes are left
  ///     as they are, since the C runtime reads a program name to the next
  ///     quotation mark; a program name can't contain one.
  ///   - arguments: The program's arguments. One that's empty, or that holds
  ///     a space, a tab, a line feed, a vertical tab or a quotation mark, is
  ///     quoted, with its quotation marks, and the backslashes before them
  ///     and before the closing one, escaped; any other is left as it is.
  ///
  /// The rules are the C runtime's, which C, C++ and Swift programs follow,
  /// as `CommandLineToArgvW` does. cmd.exe splits its command line by rules
  /// of its own, and so does a batch file, which runs in cmd.exe: an
  /// argument quoted this way can still run a command there, so don't pass
  /// one that someone else chose to a batch file.
  ///
  /// The rules are those of Daniel Colascione's "Everyone quotes command
  /// line arguments the wrong way", which Rust's standard library also
  /// follows.
  @_alwaysEmitIntoClient
  public static func commandLine(program: String, arguments: [String]) -> String {
    _commandLine(program: program, arguments: arguments)
  }

  @usableFromInline
  internal static func _commandLine(program: String, arguments: [String]) -> String {
    var line = "\"" + program + "\""
    for argument in arguments {
      line += " "
      _appendQuoted(argument, to: &line)
    }
    return line
  }

  internal static func _appendQuoted(_ argument: String, to line: inout String) {
    let special: Set<Unicode.Scalar> = [" ", "\t", "\n", "\u{0B}", "\""]
    guard argument.isEmpty || argument.unicodeScalars.contains(where: special.contains) else {
      line += argument
      return
    }
    line += "\""
    var backslashes = 0
    for scalar in argument.unicodeScalars {
      switch scalar {
      case "\\":
        backslashes += 1
      case "\"":
        // 2n + 1 backslashes and a quotation mark are n backslashes and a
        // literal quotation mark.
        line += String(repeating: "\\", count: 2 * backslashes + 1) + "\""
        backslashes = 0
      default:
        // Backslashes before anything else are literal.
        line += String(repeating: "\\", count: backslashes)
        line.unicodeScalars.append(scalar)
        backslashes = 0
      }
    }
    // 2n backslashes and the closing quotation mark are n backslashes and
    // the end of the argument.
    line += String(repeating: "\\", count: 2 * backslashes) + "\""
  }
}

#endif // os(Windows)
