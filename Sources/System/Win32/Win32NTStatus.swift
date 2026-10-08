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
  /// A status code of the Windows kernel and its native API: what the
  /// functions of `ntdll.dll`, such as `NtSuspendProcess` and
  /// `RtlGetVersion`, return, and what a process that crashes exits with.
  ///
  /// An `NTSTATUS` packs a severity into its top two bits (success,
  /// information, warning, or error), then a customer bit, a facility, and
  /// the code itself in the low 16 bits. A negative value, a warning or an
  /// error, reports that the call failed.
  ///
  /// System's Win32 API throws ``Win32/Error``. This type is for the native
  /// functions it doesn't wrap, so code that calls one can test and throw
  /// what it returns, as ``Win32/HResult`` is for COM's result codes.
  ///
  /// The corresponding C type is `NTSTATUS`.
  @frozen
  public struct NTStatus: RawRepresentable, Swift.Error, Sendable, Hashable, Codable {
    /// The raw C status code.
    @_alwaysEmitIntoClient
    public let rawValue: NTSTATUS

    /// Creates a strongly-typed status code from a raw C status code.
    @_alwaysEmitIntoClient
    public init(rawValue: NTSTATUS) { self.rawValue = rawValue }

    /// Creates a strongly-typed status code from a raw C status code.
    @_alwaysEmitIntoClient
    public init(_ rawValue: NTSTATUS) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Win32.NTStatus {
  /// The operation succeeded.
  ///
  /// The corresponding C constant is `STATUS_SUCCESS`.
  @_alwaysEmitIntoClient
  public static var success: Win32.NTStatus { Win32.NTStatus(rawValue: 0) }

  /// Whether the status reports success: a success or an informational
  /// status, whose value isn't negative.
  ///
  /// The corresponding C macro is `NT_SUCCESS`.
  @_alwaysEmitIntoClient
  public var isSuccess: Bool { rawValue >= 0 }

  /// Whether the status reports an error: its severity, in the top two
  /// bits, is 3.
  ///
  /// A warning, whose severity is 2, isn't an error, though it isn't a
  /// success either.
  ///
  /// The corresponding C macro is `NT_ERROR`.
  @_alwaysEmitIntoClient
  public var isError: Bool { UInt32(bitPattern: rawValue) >> 30 == 3 }
}

@available(System 199, *)
extension Win32.NTStatus: CustomStringConvertible, CustomDebugStringConvertible {
  /// The system's message for this status code, from the message table of
  /// `ntdll.dll`.
  ///
  /// As with ``Win32/Error/description``, the message is localized, so it
  /// suits display and logging, not matching. A code with no message is
  /// rendered as a number.
  ///
  /// The corresponding C function is `FormatMessageW`.
  @inline(never)
  public var description: String {
    let ntdll = "ntdll.dll".withCString(encodedAs: UTF16.self) { system_GetModuleHandleW($0) }
    return ntdll.flatMap {
      _win32Message(DWORD(bitPattern: rawValue), flags: _FORMAT_MESSAGE_FROM_HMODULE, source: $0)
    } ?? "Unknown status \(debugDescription)"
  }

  /// The status code in hexadecimal, as Windows documents it, such as
  /// `0xC0000005`.
  ///
  /// Unlike ``description``, this is independent of the locale.
  @inline(never)
  public var debugDescription: String {
    "0x" + String(UInt32(bitPattern: rawValue), radix: 16, uppercase: true)
  }
}

#endif // os(Windows)
