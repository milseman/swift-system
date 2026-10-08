// The Winsock part of the WinSDK overlay model (../WinSDK.swift), for
// Prototype/Win32/check-winsock.sh, which builds the two files together as
// the Swift module WinSDK.

// The Winsock model's Clang module; see module.modulemap.
@_exported import WinSock2Model

// WinSock2.h. The SDK's macro, (SOCKET)(~0), casts an expression, which
// doesn't import, so the overlay declares it.
@inlinable
public var INVALID_SOCKET: SOCKET { // mirrors: stdlib/public/Windows/WinSDK.swift
  SOCKET(bitPattern: -1)
}

// WinSock2.h. The SDK computes it with _IOW, a function-like macro.
@inlinable
public var FIONBIO: Int32 { // mirrors: stdlib/public/Windows/WinSDK.swift
  Int32(bitPattern: 0x8004667e)
}
