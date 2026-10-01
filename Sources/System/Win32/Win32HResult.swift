/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// A COM-style result code, which COM, the Shell, the Windows Runtime and
  /// some Win32 functions, such as the `PathCch` family, return.
  ///
  /// An `HRESULT` packs three parts into 32 bits: a severity, in bit 31,
  /// which is set for a failure; a facility, in bits 16 through 28, which
  /// says what defined the code; and the code itself, in the low 16 bits. A
  /// failure in `FACILITY_WIN32` carries a Win32 error code, which
  /// ``win32Error`` extracts, and ``init(win32Error:)`` makes one from a
  /// ``Win32/Error``.
  ///
  /// System's Win32 API throws ``Win32/Error`` where a function it wraps
  /// returns an `HRESULT`: a failure's Win32 error code, or, in another
  /// facility, the failure's bit pattern, which Windows reads as an `HRESULT`
  /// wherever it expects a system error code. This type is for the
  /// functions System doesn't wrap, so code that calls one can test and
  /// throw what it returns.
  ///
  /// The corresponding C type is `HRESULT`.
  @frozen
  public struct HResult: RawRepresentable, Swift.Error, Sendable, Hashable, Codable {
    /// The raw C result code.
    @_alwaysEmitIntoClient
    public let rawValue: HRESULT

    /// Creates a strongly-typed result code from a raw C result code.
    @_alwaysEmitIntoClient
    public init(rawValue: HRESULT) { self.rawValue = rawValue }

    /// Creates a strongly-typed result code from a raw C result code.
    @_alwaysEmitIntoClient
    public init(_ rawValue: HRESULT) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Win32.HResult {
  /// Creates the result code that carries a Win32 error code.
  ///
  /// ``Win32/Error/success`` becomes ``ok``, and a code whose bit 31 is set,
  /// such as one System synthesizes, stays as it is: it's already an
  /// `HRESULT`'s bit pattern. Any other code becomes a failure in
  /// `FACILITY_WIN32`, with the code's low 16 bits.
  ///
  /// The corresponding C macro is `HRESULT_FROM_WIN32`.
  @_alwaysEmitIntoClient
  public init(win32Error: Win32.Error) {
    let bits = win32Error.rawValue
    guard bits != 0, bits & 0x8000_0000 == 0 else {
      self.init(rawValue: HRESULT(bitPattern: bits))
      return
    }
    self.init(rawValue: HRESULT(bitPattern: 0x8000_0000 | (_FACILITY_WIN32 << 16) | (bits & 0xFFFF)))
  }

  /// Whether the result reports success: its severity bit is clear.
  ///
  /// ``ok`` and ``false`` both report success.
  ///
  /// The corresponding C macro is `SUCCEEDED`.
  @_alwaysEmitIntoClient
  public var isSuccess: Bool { rawValue >= 0 }

  /// Whether the result reports a failure: its severity bit is set.
  ///
  /// The corresponding C macro is `FAILED`.
  @_alwaysEmitIntoClient
  public var isFailure: Bool { rawValue < 0 }

  /// The facility, which says what defined the code: 7, `FACILITY_WIN32`,
  /// for a Win32 error code, for instance, and 0, `FACILITY_NULL`, for the
  /// common codes such as ``unspecifiedFailure``.
  ///
  /// The corresponding C macro is `HRESULT_FACILITY`.
  @_alwaysEmitIntoClient
  public var facility: UInt16 {
    UInt16(truncatingIfNeeded: (UInt32(bitPattern: rawValue) >> 16) & 0x1FFF)
  }

  /// The code, the low 16 bits, whose meaning depends on the facility.
  ///
  /// The corresponding C macro is `HRESULT_CODE`.
  @_alwaysEmitIntoClient
  public var code: UInt16 { UInt16(truncatingIfNeeded: rawValue) }

  /// The Win32 error code that a failure in `FACILITY_WIN32` carries, or
  /// `nil` for a success or a failure in another facility.
  ///
  /// The corresponding C macro is `HRESULT_CODE`, for a failure whose
  /// `HRESULT_FACILITY` is `FACILITY_WIN32`.
  @_alwaysEmitIntoClient
  public var win32Error: Win32.Error? {
    guard isFailure, DWORD(facility) == _FACILITY_WIN32 else { return nil }
    return Win32.Error(rawValue: DWORD(code))
  }
}

// The codes are spelled as literals, as Win32.Error's are, and must be: the
// SDK spells its failures through `_HRESULT_TYPEDEF_`, a function-like macro,
// so Swift imports none of them, and wouldn't hold their values in an
// `HRESULT` literal if it did.
@available(System 199, *)
extension Win32.HResult {
  /// The operation succeeded.
  ///
  /// The corresponding C constant is `S_OK`.
  @_alwaysEmitIntoClient
  public static var ok: Win32.HResult { Win32.HResult(rawValue: 0) }

  /// The operation succeeded, with a result of false, or nothing to do.
  ///
  /// The corresponding C constant is `S_FALSE`.
  @_alwaysEmitIntoClient
  public static var `false`: Win32.HResult { Win32.HResult(rawValue: 1) }

  /// The operation was aborted.
  ///
  /// The corresponding C constant is `E_ABORT`.
  @_alwaysEmitIntoClient
  public static var aborted: Win32.HResult { Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_4004)) }

  /// Access is denied: ``Win32/Error/accessDenied`` in `FACILITY_WIN32`.
  ///
  /// The corresponding C constant is `E_ACCESSDENIED`.
  @_alwaysEmitIntoClient
  public static var accessDenied: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8007_0005))
  }

  /// An unspecified failure.
  ///
  /// The corresponding C constant is `E_FAIL`.
  @_alwaysEmitIntoClient
  public static var unspecifiedFailure: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_4005))
  }

  /// A handle isn't valid: ``Win32/Error/invalidHandle`` in
  /// `FACILITY_WIN32`.
  ///
  /// The corresponding C constant is `E_HANDLE`.
  @_alwaysEmitIntoClient
  public static var invalidHandle: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8007_0006))
  }

  /// An argument isn't valid: ``Win32/Error/invalidParameter`` in
  /// `FACILITY_WIN32`.
  ///
  /// The corresponding C constant is `E_INVALIDARG`.
  @_alwaysEmitIntoClient
  public static var invalidArgument: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8007_0057))
  }

  /// The object doesn't support the interface asked for.
  ///
  /// The corresponding C constant is `E_NOINTERFACE`.
  @_alwaysEmitIntoClient
  public static var noInterface: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_4002))
  }

  /// The operation isn't implemented.
  ///
  /// The corresponding C constant is `E_NOTIMPL`.
  @_alwaysEmitIntoClient
  public static var notImplemented: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_4001))
  }

  /// There isn't enough memory: `ERROR_OUTOFMEMORY` in `FACILITY_WIN32`.
  ///
  /// The corresponding C constant is `E_OUTOFMEMORY`.
  @_alwaysEmitIntoClient
  public static var outOfMemory: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8007_000E))
  }

  /// A pointer isn't valid.
  ///
  /// The corresponding C constant is `E_POINTER`.
  @_alwaysEmitIntoClient
  public static var invalidPointer: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_4003))
  }

  /// A catastrophic, unexpected failure.
  ///
  /// The corresponding C constant is `E_UNEXPECTED`.
  @_alwaysEmitIntoClient
  public static var unexpectedFailure: Win32.HResult {
    Win32.HResult(rawValue: HRESULT(bitPattern: 0x8000_FFFF))
  }
}

@available(System 199, *)
extension Win32.HResult: CustomStringConvertible, CustomDebugStringConvertible {
  /// The system's message for this result code.
  ///
  /// As with ``Win32/Error/description``, the message is localized, so it
  /// suits display and logging, not matching. A code with no system
  /// message, such as one another component defined, is rendered as a
  /// number.
  ///
  /// The corresponding C function is `FormatMessageW`.
  @inline(never)
  public var description: String {
    Win32.Error(rawValue: DWORD(bitPattern: rawValue))._systemMessage
      ?? "Unknown error \(_hexadecimal)"
  }

  /// The symbolic constant with the hexadecimal value, such as
  /// `E_ACCESSDENIED (0x80070005)`, or the value alone for a code with no
  /// name here. A failure in `FACILITY_WIN32` whose code ``Win32/Error``
  /// names is spelled as the macro that makes it, such as
  /// `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) (0x80070002)`.
  @inline(never)
  public var debugDescription: String {
    if let name = _symbolicName { return "\(name) (\(_hexadecimal))" }
    if let error = win32Error, let name = error._symbolicName {
      return "HRESULT_FROM_WIN32(\(name)) (\(_hexadecimal))"
    }
    return _hexadecimal
  }
}

@available(System 199, *)
extension Win32.HResult {
  internal var _hexadecimal: String {
    "0x" + String(UInt32(bitPattern: rawValue), radix: 16, uppercase: true)
  }

  internal var _symbolicName: String? {
    switch UInt32(bitPattern: rawValue) {
    case 0: return "S_OK"
    case 1: return "S_FALSE"
    case 0x8000_4001: return "E_NOTIMPL"
    case 0x8000_4002: return "E_NOINTERFACE"
    case 0x8000_4003: return "E_POINTER"
    case 0x8000_4004: return "E_ABORT"
    case 0x8000_4005: return "E_FAIL"
    case 0x8000_FFFF: return "E_UNEXPECTED"
    case 0x8007_0005: return "E_ACCESSDENIED"
    case 0x8007_0006: return "E_HANDLE"
    case 0x8007_000E: return "E_OUTOFMEMORY"
    case 0x8007_0057: return "E_INVALIDARG"
    default: return nil
    }
  }
}

#endif // os(Windows)
