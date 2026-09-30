/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

/// A namespace for Win32 APIs on Windows.
///
/// The types and functions nested here wrap the Win32 base API, the
/// documented, ABI-stable interface exported by `kernel32.dll` and
/// `kernelbase.dll`. Failures are reported as ``Win32/Error``, not `Errno`.
///
/// Everything in the namespace exists only on Windows, so cross-platform
/// code must guard its uses with `#if os(Windows)`.
@frozen
@available(System 199, *)
public enum Win32 {}

#endif // os(Windows)
