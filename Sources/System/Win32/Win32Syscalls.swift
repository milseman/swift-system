/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt
import WinSDK

// The only code that calls these C functions. Win32 functions report failure
// through their return value and GetLastError rather than -1 and errno, so,
// like the Win32 calls in WindowsSyscallAdapters.swift, they have no mock
// hook. The C runtime calls report -1 and errno, and have one.

// MARK: - Errors

// The variadic `Arguments` parameter is always NULL here, as
// FORMAT_MESSAGE_IGNORE_INSERTS requires.
internal func system_FormatMessageW(
  _ dwFlags: DWORD,
  _ lpSource: UnsafeRawPointer?,
  _ dwMessageId: DWORD,
  _ dwLanguageId: DWORD,
  _ lpBuffer: UnsafeMutablePointer<WCHAR>?,
  _ nSize: DWORD
) -> DWORD {
  FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, nil)
}

internal func system_LocalFree(_ hMem: UnsafeMutableRawPointer?) -> HLOCAL? {
  LocalFree(hMem)
}

#endif // os(Windows)
