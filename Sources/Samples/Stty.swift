/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import ArgumentParser
import SystemPackage

struct Stty: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stty",
    abstract: "Show the settings of the terminal on standard input, and what raw mode would change"
  )

  func run() throws {
    guard let terminal = FileDescriptor.standardInput.asTerminal else {
      complain("Error: standard input is not a terminal")
      throw ExitCode.failure
    }
    let now = try terminal.attributes()
    // `raw()` returns a copy, so the terminal itself doesn't change.
    let raw = now.raw()
    let size = try terminal.windowSize()
    print("\(speed(now.outputSpeed)), \(size.columns) columns by \(size.rows) rows")

    let settings: [(name: String, value: (TerminalAttributes) -> String)] = [
      ("line editing", { onOff($0.localFlags.contains(.canonical)) }),
      ("echo", { onOff($0.localFlags.contains(.echo)) }),
      ("signal keys", { onOff($0.localFlags.contains(.signals)) }),
      ("flow control keys", { onOff($0.inputFlags.contains(.startStopOutput)) }),
      ("CR to NL on input", { onOff($0.inputFlags.contains(.mapCRToNL)) }),
      ("NL to CR NL on output", {
        onOff($0.outputFlags.isSuperset(of: [.postProcess, .mapNLToCRNL]))
      }),
      ("character size", { bits($0.characterSize) }),
      ("a read waits for", readWait),
    ]
    let rows = [("", "now", "in raw mode")]
      + settings.map { ($0.name, $0.value(now), $0.value(raw)) }
    let nameWidth = rows.map(\.0.count).max()! + 2
    let nowWidth = rows.map(\.1.count).max()! + 2
    for (name, nowValue, rawValue) in rows {
      print(pad(name, nameWidth) + pad(nowValue, nowWidth) + rawValue)
    }
    print("keys: \(keys(now.controlCharacters))")
  }
}

private func pad(_ text: String, _ width: Int) -> String {
  text + String(repeating: " ", count: width - text.count)
}

private func onOff(_ isOn: Bool) -> String { isOn ? "on" : "off" }

private func bits(_ size: TerminalAttributes.CharacterSize) -> String {
  switch size {
  case .bits5: return "5 bits"
  case .bits6: return "6 bits"
  case .bits7: return "7 bits"
  default: return "8 bits"
  }
}

/// Describes what a read waits for: a line with line editing on, and
/// otherwise the minimum number of bytes or the time allowed.
private func readWait(_ attributes: TerminalAttributes) -> String {
  guard !attributes.localFlags.contains(.canonical) else { return "a line" }
  let minimum = attributes.controlCharacters[.minimum]
  let tenths = attributes.controlCharacters[.time]
  switch (minimum, tenths) {
  case (0, 0): return "nothing"
  case (_, 0): return "\(minimum) \(minimum == 1 ? "byte" : "bytes")"
  case (0, _): return "1 byte or \(tenths)/10 s"
  default: return "\(minimum) bytes, or a \(tenths)/10 s pause"
  }
}

/// The keys for the control characters, as stty(1) shows them, such as ^C.
private func keys(_ characters: ControlCharacters) -> String {
  let named: [(String, ControlCharacter)] = [
    ("interrupt", .interrupt), ("quit", .quit), ("suspend", .suspend),
    ("end of file", .endOfFile), ("erase", .erase), ("erase line", .kill),
    ("erase word", .wordErase), ("literal next", .literalNext),
  ]
  return named.map { name, character in
    let value = characters[character]
    let key: String
    if value == ControlCharacters.disabled {
      key = "none"
    } else if value == 0x7F {
      key = "^?"
    } else if value < 0x20 {
      key = "^" + String(UnicodeScalar(value + 0x40))
    } else {
      key = String(UnicodeScalar(value))
    }
    return "\(name) \(key)"
  }.joined(separator: ", ")
}

/// The speed in bits per second, for common rates. On Linux, a BaudRate's
/// raw value is a code, such as B38400, rather than the rate itself.
private func speed(_ rate: BaudRate) -> String {
  let rates: [BaudRate: Int] = [
    .b1200: 1200, .b2400: 2400, .b4800: 4800, .b9600: 9600, .b19200: 19200,
    .b38400: 38400, .b57600: 57600, .b115200: 115200, .b230400: 230400,
  ]
  return rates[rate].map { "\($0) baud" } ?? "an uncommon speed"
}

#endif // !os(Windows) && !os(WASI)
