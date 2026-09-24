/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

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

struct TerminalSize: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Display terminal window dimensions"
  )

  @Flag(name: .shortAndLong, help: "Show verbose output")
  var verbose: Bool = false

  @Flag(name: .long, help: "Draw a border using the terminal dimensions")
  var border: Bool = false

  @Option(name: .long, help: "Try to set terminal rows (height)")
  var setRows: UInt16?

  @Option(name: .long, help: "Try to set terminal columns (width)")
  var setColumns: UInt16?

  func run() throws {
    guard let terminal = FileDescriptor.standardOutput.asTerminal else {
      complain("Error: stdout is not a terminal")
      throw ExitCode.failure
    }

    // Try to set size if requested
    if let rows = setRows, let cols = setColumns {
      print("Attempting to set terminal size to \(cols)x\(rows)...")
      let newSize = TerminalDescriptor.WindowSize(rows: rows, columns: cols)
      do {
        try terminal.setWindowSize(newSize)
        print("✓ Successfully set terminal size")
      } catch {
        print("✗ Failed to set terminal size: \(error)")
        print("Note: Setting terminal size may not be supported by your terminal emulator")
      }
      print()
    } else if setRows != nil || setColumns != nil {
      complain("Error: Both --set-rows and --set-columns must be specified together")
      throw ExitCode.failure
    }

    let size = try terminal.windowSize()

    if verbose {
      print("Terminal Window Size:")
      print("  Rows (height):    \(size.rows)")
      print("  Columns (width):  \(size.columns)")

      // Access underlying C struct for pixel dimensions
      let xpixel = size.rawValue.ws_xpixel
      let ypixel = size.rawValue.ws_ypixel
      if xpixel > 0 || ypixel > 0 {
        print("  X pixels:         \(xpixel)")
        print("  Y pixels:         \(ypixel)")
      } else {
        print("  Pixel dimensions: not available")
      }
      print()
      print("This is useful for:")
      print("  - Formatting output to fit the terminal")
      print("  - Creating full-screen terminal UIs")
      print("  - Responsive command-line applications")
    } else if !border {
      print("\(size.columns)x\(size.rows)")
    }

    if border {
      // Leave the last row for the shell prompt, so the whole border stays
      // on screen.
      let width = Int(size.columns)
      let height = Int(size.rows) - 1
      // A terminal whose size was never set, such as a new pseudo-terminal,
      // reports 0x0.
      guard width >= 2, height >= 2 else {
        complain("Error: a \(size.columns)x\(size.rows) terminal is too small for a border")
        throw ExitCode.failure
      }
      drawBorder(width: width, height: height, label: "\(size.columns)x\(size.rows)")
    }
  }

  /// Draws a box `width` columns by `height` rows,
  /// with `label` in the middle if it fits.
  private func drawBorder(width: Int, height: Int, label: String) {
    let inner = width - 2
    print("┌" + String(repeating: "─", count: inner) + "┐")
    for row in 1..<height - 1 {
      if row == (height - 1) / 2 && label.count <= inner {
        let leftPad = (inner - label.count) / 2
        let rightPad = inner - label.count - leftPad
        print("│" + String(repeating: " ", count: leftPad) + label + String(repeating: " ", count: rightPad) + "│")
      } else {
        print("│" + String(repeating: " ", count: inner) + "│")
      }
    }
    print("└" + String(repeating: "─", count: inner) + "┘")
  }
}

#endif // !os(Windows) && !os(WASI)
