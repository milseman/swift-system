/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

/// An index identifying a specific control character.
@frozen
@available(System 199, *)
public struct ControlCharacter: RawRepresentable, Hashable, Sendable {
  /// The raw C index into the control characters.
  @_alwaysEmitIntoClient
  public var rawValue: CInt

  /// Creates a strongly-typed control character
  /// from a raw C index into the control characters.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) {
    self.rawValue = rawValue
  }

  /// The end-of-file character, Control-D by default.
  ///
  /// In canonical mode, it makes the line typed so far available to read,
  /// without a newline. At the start of a line, it makes a read return
  /// zero bytes, which indicates the end of the file.
  ///
  /// The corresponding C constant is `VEOF`.
  @_alwaysEmitIntoClient
  public static var endOfFile: Self { Self(rawValue: _VEOF) }

  /// An additional character that ends a line in canonical mode,
  /// disabled by default.
  ///
  /// The corresponding C constant is `VEOL`.
  @_alwaysEmitIntoClient
  public static var endOfLine: Self { Self(rawValue: _VEOL) }

  /// The erase character, which erases the previous character
  /// in canonical mode.
  ///
  /// The corresponding C constant is `VERASE`.
  @_alwaysEmitIntoClient
  public static var erase: Self { Self(rawValue: _VERASE) }

  /// The interrupt character, Control-C by default.
  ///
  /// When ``LocalFlags/signals`` is set, it sends `SIGINT`
  /// to the terminal's foreground process group.
  ///
  /// The corresponding C constant is `VINTR`.
  @_alwaysEmitIntoClient
  public static var interrupt: Self { Self(rawValue: _VINTR) }

  /// The kill character, Control-U by default,
  /// which erases the line in canonical mode.
  ///
  /// The corresponding C constant is `VKILL`.
  @_alwaysEmitIntoClient
  public static var kill: Self { Self(rawValue: _VKILL) }

  /// In noncanonical mode, the number of bytes a read waits for.
  ///
  /// This element is a count, not a character.
  ///
  /// The corresponding C constant is `VMIN`.
  @_alwaysEmitIntoClient
  public static var minimum: Self { Self(rawValue: _VMIN) }

  /// The quit character, Control-Backslash by default.
  ///
  /// When ``LocalFlags/signals`` is set, it sends `SIGQUIT`
  /// to the terminal's foreground process group.
  ///
  /// The corresponding C constant is `VQUIT`.
  @_alwaysEmitIntoClient
  public static var quit: Self { Self(rawValue: _VQUIT) }

  /// The start character, Control-Q by default.
  ///
  /// When ``InputFlags/startStopOutput`` is set, it resumes output;
  /// when ``InputFlags/startStopInput`` is set, the terminal sends it
  /// to resume input.
  ///
  /// The corresponding C constant is `VSTART`.
  @_alwaysEmitIntoClient
  public static var start: Self { Self(rawValue: _VSTART) }

  /// The stop character, Control-S by default.
  ///
  /// When ``InputFlags/startStopOutput`` is set, it suspends output;
  /// when ``InputFlags/startStopInput`` is set, the terminal sends it
  /// to stop input.
  ///
  /// The corresponding C constant is `VSTOP`.
  @_alwaysEmitIntoClient
  public static var stop: Self { Self(rawValue: _VSTOP) }

  /// The suspend character, Control-Z by default.
  ///
  /// When ``LocalFlags/signals`` is set, it sends `SIGTSTP`
  /// to the terminal's foreground process group.
  ///
  /// The corresponding C constant is `VSUSP`.
  @_alwaysEmitIntoClient
  public static var suspend: Self { Self(rawValue: _VSUSP) }

  /// In noncanonical mode, how long a read waits for input,
  /// in tenths of a second.
  ///
  /// This element is a duration, not a character.
  ///
  /// The corresponding C constant is `VTIME`.
  @_alwaysEmitIntoClient
  public static var time: Self { Self(rawValue: _VTIME) }

  /// A second additional character that ends a line in canonical mode,
  /// disabled by default.
  ///
  /// The corresponding C constant is `VEOL2`.
  @_alwaysEmitIntoClient
  public static var endOfLine2: Self { Self(rawValue: _VEOL2) }

  /// The word erase character, Control-W by default,
  /// which erases the previous word in canonical mode
  /// when ``LocalFlags/extendedInput`` is set.
  ///
  /// The corresponding C constant is `VWERASE`.
  @_alwaysEmitIntoClient
  public static var wordErase: Self { Self(rawValue: _VWERASE) }

  /// The reprint character, Control-R by default,
  /// which reprints the line so far in canonical mode
  /// when ``LocalFlags/extendedInput`` is set.
  ///
  /// The corresponding C constant is `VREPRINT`.
  @_alwaysEmitIntoClient
  public static var reprint: Self { Self(rawValue: _VREPRINT) }

  /// The discard character, Control-O by default,
  /// which starts or stops discarding output
  /// when ``LocalFlags/extendedInput`` is set.
  ///
  /// Linux doesn't support it.
  ///
  /// The corresponding C constant is `VDISCARD`.
  @_alwaysEmitIntoClient
  public static var discard: Self { Self(rawValue: _VDISCARD) }

  /// The literal next character, Control-V by default,
  /// which makes the character after it ordinary input
  /// when ``LocalFlags/extendedInput`` is set.
  ///
  /// The corresponding C constant is `VLNEXT`.
  @_alwaysEmitIntoClient
  public static var literalNext: Self { Self(rawValue: _VLNEXT) }

  #if canImport(Darwin)
  /// The status character, Control-T by default,
  /// which sends `SIGINFO` to the terminal's foreground process group,
  /// and prints a line of status
  /// unless ``LocalFlags/noKernelInfo`` is set.
  ///
  /// The corresponding C constant is `VSTATUS`.
  @_alwaysEmitIntoClient
  public static var status: Self { Self(rawValue: _VSTATUS) }

  /// The delayed suspend character, Control-Y by default.
  ///
  /// When ``LocalFlags/signals`` is set, it sends `SIGTSTP`
  /// to the terminal's foreground process group
  /// when a process reads it, rather than when it's typed.
  ///
  /// The corresponding C constant is `VDSUSP`.
  @_alwaysEmitIntoClient
  public static var delayedSuspend: Self { Self(rawValue: _VDSUSP) }
  #endif

  #if os(Linux)
  /// The switch character, which Linux doesn't use.
  ///
  /// The corresponding C constant is `VSWTC`.
  @_alwaysEmitIntoClient
  public static var switchCharacter: Self { Self(rawValue: _VSWTC) }
  #endif
}

/// The control characters for a terminal.
///
/// Each element is the byte that performs a special function,
/// such as interrupting, or in noncanonical mode, a count or a time.
/// Set an element to ``disabled`` to turn its function off.
@frozen
@available(System 199, *)
public struct ControlCharacters: Sendable {
  #if SYSTEM_PACKAGE_DARWIN
  @usableFromInline
  internal var storage: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
  #elseif os(Linux)
  @usableFromInline
  internal var storage: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
  #endif

  /// Creates control characters with every element zero.
  ///
  /// Zero isn't ``disabled`` on every platform:
  /// on Darwin, it makes byte 0 every control character.
  @_alwaysEmitIntoClient
  public init() {
    #if SYSTEM_PACKAGE_DARWIN
    self.storage = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    #elseif os(Linux)
    self.storage = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    #endif
  }

  /// The number of elements, including ones without a name.
  ///
  /// The corresponding C constant is `NCCS`.
  @_alwaysEmitIntoClient
  public static var count: Int { Int(_NCCS) }

  /// The value that disables a control character.
  ///
  /// Setting a control character to this value turns off its function,
  /// so no input byte performs it.
  /// The value is 0xFF on Darwin and 0 on Linux,
  /// where each is otherwise a rarely typed byte.
  ///
  /// The corresponding C constant is `_POSIX_VDISABLE`.
  @_alwaysEmitIntoClient
  public static var disabled: CInterop.ControlCharacterValue { __POSIX_VDISABLE }

  /// Accesses the value of the given control character.
  ///
  /// - Precondition: The character's raw value is in `0..<count`,
  ///   as those of the predefined characters are.
  @_alwaysEmitIntoClient
  public subscript(_ character: ControlCharacter) -> CInterop.ControlCharacterValue {
    get { self[rawIndex: Int(character.rawValue)] }
    set { self[rawIndex: Int(character.rawValue)] = newValue }
  }

  /// Accesses the element at the given index of the C array.
  ///
  /// - Precondition: `index` is in `0..<count`.
  @_alwaysEmitIntoClient
  public subscript(rawIndex index: Int) -> CInterop.ControlCharacterValue {
    get {
      precondition(index >= 0 && index < Self.count, "Index out of bounds")
      return withUnsafeBytes(of: storage) { $0[index] }
    }
    set {
      precondition(index >= 0 && index < Self.count, "Index out of bounds")
      withUnsafeMutableBytes(of: &storage) { $0[index] = newValue }
    }
  }
}

// Manual Hashable conformance
@available(System 199, *)
extension ControlCharacters: Hashable {
  /// Returns whether two values have the same elements.
  @_alwaysEmitIntoClient
  public static func == (lhs: ControlCharacters, rhs: ControlCharacters) -> Bool {
    withUnsafeBytes(of: lhs.storage) { lhsBytes in
      withUnsafeBytes(of: rhs.storage) { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }

  /// Hashes the elements.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    withUnsafeBytes(of: storage) { bytes in
      hasher.combine(bytes: bytes)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
