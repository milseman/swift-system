/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// The local heap, for the memory that Win32 functions allocate for their
// results: FormatMessageW's buffer, PathAllocCanonicalize's path,
// ConvertSidToStringSidW's string. System's own API frees what it gets this
// way; this is for the functions it doesn't wrap.

@available(System 199, *)
extension Win32 {
  /// Frees memory that a Win32 function allocated for its result from the
  /// local heap.
  ///
  /// - Parameter memory: The memory, or `nil`, which does nothing.
  ///
  /// A function whose documentation says to free its result with
  /// `LocalFree` allocated it this way, such as `FormatMessageW` with
  /// `FORMAT_MESSAGE_ALLOCATE_BUFFER`, `PathAllocCanonicalize`, and
  /// `ConvertSidToStringSidW`. Memory from the C runtime's allocator,
  /// ``Memory``, and from `CoTaskMemAlloc` have frees of their own.
  /// Freeing memory twice, or memory that the local heap didn't allocate,
  /// is undefined behavior.
  ///
  /// The corresponding C function is `LocalFree`.
  @_alwaysEmitIntoClient
  public static func freeLocalMemory(_ memory: UnsafeMutableRawPointer?) {
    _freeLocalMemory(memory)
  }

  @usableFromInline
  internal static func _freeLocalMemory(_ memory: UnsafeMutableRawPointer?) {
    // LocalFree fails only for memory it didn't allocate, which this
    // can't recover from.
    _ = system_LocalFree(memory)
  }
}

#endif // os(Windows)
