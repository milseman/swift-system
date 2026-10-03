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

// WinIoCtl.h. The SDK computes it with CTL_CODE, a function-like macro,
// which doesn't import, and the adopters' uses of it mean the overlay
// declares it.
@inlinable
public var FSCTL_GET_REPARSE_POINT: DWORD {
  0x000900A8
}

// WinBase.h
@inlinable
public var INFINITE: DWORD {
  DWORD(bitPattern: -1)
}

// WinBase.h. The SDK's macro, ((STATUS_WAIT_0 ) + 0 ), adds to a cast, which
// the importer doesn't evaluate (WinSDK.h spells it that way, and it doesn't
// import), so the adopters' uses of it mean the overlay declares it.
@inlinable
public var WAIT_OBJECT_0: DWORD {
  0
}

// processenv.h. The SDK's macros, such as ((DWORD)-10), import as a DWORD
// constant with a negative literal, which is an error to use (WinSDK.h spells
// them that way), so the adopters' uses of them mean the overlay declares
// them.
@inlinable
public var STD_INPUT_HANDLE: DWORD {
  DWORD(bitPattern: -10)
}

@inlinable
public var STD_OUTPUT_HANDLE: DWORD {
  DWORD(bitPattern: -11)
}

@inlinable
public var STD_ERROR_HANDLE: DWORD {
  DWORD(bitPattern: -12)
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
