// A model of the parts of Swift's WinSDK overlay
// (stdlib/public/Windows/WinSDK.swift) that System's Win32 namespace and its
// tests use, for Prototype/Win32/check-windows.sh. Built as the Swift module
// WinSDK over WinSDK.h, the way the real overlay is built over the SDK.

@_exported import ucrt
@_exported import WinSDK // Clang module
@_exported import ObjectiveC // For ObjCBool, which stands in for WindowsBool.

// WinBase.h
@inlinable
public var HANDLE_FLAG_INHERIT: DWORD {
  0x00000001
}

// WinBase.h
@inlinable
public var INFINITE: DWORD {
  DWORD(bitPattern: -1)
}

// handleapi.h
@inlinable
public var INVALID_HANDLE_VALUE: HANDLE {
  HANDLE(bitPattern: -1)!
}

// fileapi.h
@inlinable
public var INVALID_FILE_ATTRIBUTES: DWORD {
  DWORD(bitPattern: -1)
}

// The real overlay declares WindowsBool, and the importer imports BOOL as
// it, bridged to Bool in function signatures. WinSDK.h's BOOL imports as
// ObjCBool, which has the same members and bridging.
public typealias WindowsBool = ObjCBool
