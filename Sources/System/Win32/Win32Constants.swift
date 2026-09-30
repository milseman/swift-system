/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Win32 constants that the Win32 namespace uses internally, spelled as their
// values like its public constants: Win32 values are fixed ABI, and literals
// don't depend on which Windows SDK builds System. The Win32 tests check
// each one against the SDK. The names here, unlike the ones in
// WinSDK+Overlay.swift, begin with an underscore, as Constants.swift's do.

// MARK: - Errors

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_ALLOCATE_BUFFER: DWORD { 0x0000_0100 }

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_FROM_SYSTEM: DWORD { 0x0000_1000 }

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_IGNORE_INSERTS: DWORD { 0x0000_0200 }

#endif // os(Windows)
