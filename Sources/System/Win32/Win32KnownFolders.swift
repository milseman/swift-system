/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Known folders: the directories that Windows identifies by GUID, wherever
// a system puts them, as Darwin's sysdir names its directories
// (SearchPaths.swift). The Shell's SHGetKnownFolderPath finds one's path,
// in memory that CoTaskMemFree frees.

@available(System 199, *)
extension Win32 {
  /// A known folder: a directory that Windows identifies with a GUID,
  /// such as Program Files or a user's documents, wherever it is on this
  /// system.
  ///
  ///     let programs = try Win32.KnownFolder.programFilesX86.path()
  ///
  /// The folders that Windows defines are static members, and
  /// ``init(rawValue:)`` makes one from any other GUID, such as one that
  /// an application registers.
  ///
  /// The corresponding C type is `KNOWNFOLDERID`.
  @frozen
  public struct KnownFolder: RawRepresentable, Hashable, Sendable {
    /// The folder's GUID.
    @_alwaysEmitIntoClient
    public var rawValue: KNOWNFOLDERID

    /// Creates a known folder from its GUID.
    @_alwaysEmitIntoClient
    public init(rawValue: KNOWNFOLDERID) { self.rawValue = rawValue }

    @_alwaysEmitIntoClient
    public static func == (lhs: KnownFolder, rhs: KnownFolder) -> Bool {
      withUnsafeBytes(of: lhs.rawValue) { lhs in
        withUnsafeBytes(of: rhs.rawValue) { rhs in lhs.elementsEqual(rhs) }
      }
    }

    @_alwaysEmitIntoClient
    public func hash(into hasher: inout Hasher) {
      withUnsafeBytes(of: rawValue) { hasher.combine(bytes: $0) }
    }
  }

  /// How ``KnownFolder/path(options:)`` finds a known folder's path.
  ///
  /// The empty set finds the folder where the user's settings put it, and
  /// fails if it doesn't exist.
  ///
  /// The corresponding C type is `KNOWN_FOLDER_FLAG`.
  @frozen
  public struct KnownFolderOptions: OptionSet, Sendable, Hashable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed set of options from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Create the folder if it doesn't exist.
    ///
    /// The corresponding C constant is `KF_FLAG_CREATE`.
    @_alwaysEmitIntoClient
    public static var create: KnownFolderOptions { KnownFolderOptions(rawValue: 0x0000_8000) }

    /// Return the path without checking that the folder exists.
    ///
    /// The corresponding C constant is `KF_FLAG_DONT_VERIFY`.
    @_alwaysEmitIntoClient
    public static var doNotVerify: KnownFolderOptions { KnownFolderOptions(rawValue: 0x0000_4000) }

    /// Return the folder's default path, not where the user moved it.
    ///
    /// The corresponding C constant is `KF_FLAG_DEFAULT_PATH`.
    @_alwaysEmitIntoClient
    public static var defaultPath: KnownFolderOptions { KnownFolderOptions(rawValue: 0x0000_0400) }

    /// Return the folder's own path, not an alias, such as a path through
    /// a library.
    ///
    /// The corresponding C constant is `KF_FLAG_NO_ALIAS`.
    @_alwaysEmitIntoClient
    public static var noAlias: KnownFolderOptions { KnownFolderOptions(rawValue: 0x0000_1000) }
  }
}

// The GUIDs are spelled as values, as the Win32 namespace's constants are;
// Win32KnownFoldersTests checks each one against the SDK's.
@available(System 199, *)
extension Win32.KnownFolder {
  /// The Program Files directory, such as `C:\\Program Files`, for programs of the process's architecture.
  ///
  /// The corresponding C constant is `FOLDERID_ProgramFiles`.
  @_alwaysEmitIntoClient
  public static var programFiles: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x905e63b6, Data2: 0xc1bf, Data3: 0x494e, Data4: (0xb2, 0x9c, 0x65, 0xb7, 0x32, 0xd3, 0xd2, 0x1a)))
  }

  /// The Program Files directory for 32-bit x86 programs, such as `C:\\Program Files (x86)` on 64-bit Windows.
  ///
  /// The corresponding C constant is `FOLDERID_ProgramFilesX86`.
  @_alwaysEmitIntoClient
  public static var programFilesX86: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x7c5a40ef, Data2: 0xa0fb, Data3: 0x4bfc, Data4: (0x87, 0x4a, 0xc0, 0xf2, 0xe0, 0xb9, 0xfa, 0x8e)))
  }

  /// The directory for programs that one user installs, such as `C:\\Users\\name\\AppData\\Local\\Programs`.
  ///
  /// The corresponding C constant is `FOLDERID_UserProgramFiles`.
  @_alwaysEmitIntoClient
  public static var userProgramFiles: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x5cd7aee2, Data2: 0x2219, Data3: 0x4a67, Data4: (0xb8, 0x5d, 0x6c, 0x9c, 0xe1, 0x56, 0x60, 0xcb)))
  }

  /// The directory for data that programs share among users, such as `C:\\ProgramData`.
  ///
  /// The corresponding C constant is `FOLDERID_ProgramData`.
  @_alwaysEmitIntoClient
  public static var programData: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x62ab5d82, Data2: 0xfdc1, Data3: 0x4dc3, Data4: (0xa9, 0xdd, 0x07, 0x0d, 0x1d, 0x49, 0x5d, 0x97)))
  }

  /// The system directory, such as `C:\\Windows\\System32`, which holds Windows' own programs and libraries.
  ///
  /// The corresponding C constant is `FOLDERID_System`.
  @_alwaysEmitIntoClient
  public static var system: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x1ac14e77, Data2: 0x02e7, Data3: 0x4e5d, Data4: (0xb7, 0x44, 0x2e, 0xb1, 0xae, 0x51, 0x98, 0xb7)))
  }

  /// The Windows directory, such as `C:\\Windows`.
  ///
  /// The corresponding C constant is `FOLDERID_Windows`.
  @_alwaysEmitIntoClient
  public static var windows: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0xf38bf404, Data2: 0x1d43, Data3: 0x42f2, Data4: (0x93, 0x05, 0x67, 0xde, 0x0b, 0x28, 0xfc, 0x23)))
  }

  /// The user's local application data, such as `C:\\Users\\name\\AppData\\Local`, which stays on this computer.
  ///
  /// The corresponding C constant is `FOLDERID_LocalAppData`.
  @_alwaysEmitIntoClient
  public static var localAppData: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0xf1b32785, Data2: 0x6fba, Data3: 0x4fcf, Data4: (0x9d, 0x55, 0x7b, 0x8e, 0x7f, 0x15, 0x70, 0x91)))
  }

  /// The user's roaming application data, such as `C:\\Users\\name\\AppData\\Roaming`, which a roaming profile takes to other computers.
  ///
  /// The corresponding C constant is `FOLDERID_RoamingAppData`.
  @_alwaysEmitIntoClient
  public static var roamingAppData: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x3eb685db, Data2: 0x65f9, Data3: 0x4cf6, Data4: (0xa0, 0x3a, 0xe3, 0xef, 0x65, 0x72, 0x9f, 0x3d)))
  }

  /// The user's profile directory, such as `C:\\Users\\name`.
  ///
  /// The corresponding C constant is `FOLDERID_Profile`.
  @_alwaysEmitIntoClient
  public static var profile: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x5e6c858f, Data2: 0x0e22, Data3: 0x4760, Data4: (0x9a, 0xfe, 0xea, 0x33, 0x17, 0xb6, 0x71, 0x73)))
  }

  /// The directory of the users' profiles, such as `C:\\Users`.
  ///
  /// The corresponding C constant is `FOLDERID_UserProfiles`.
  @_alwaysEmitIntoClient
  public static var userProfiles: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x0762d272, Data2: 0xc50a, Data3: 0x4bb0, Data4: (0xa3, 0x82, 0x69, 0x7d, 0xcd, 0x72, 0x9b, 0x80)))
  }

  /// The user's desktop.
  ///
  /// The corresponding C constant is `FOLDERID_Desktop`.
  @_alwaysEmitIntoClient
  public static var desktop: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0xb4bfcc3a, Data2: 0xdb2c, Data3: 0x424c, Data4: (0xb0, 0x29, 0x7f, 0xe9, 0x9a, 0x87, 0xc6, 0x41)))
  }

  /// The user's documents.
  ///
  /// The corresponding C constant is `FOLDERID_Documents`.
  @_alwaysEmitIntoClient
  public static var documents: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0xfdd39ad0, Data2: 0x238f, Data3: 0x46af, Data4: (0xad, 0xb4, 0x6c, 0x85, 0x48, 0x03, 0x69, 0xc7)))
  }

  /// The user's downloads.
  ///
  /// The corresponding C constant is `FOLDERID_Downloads`.
  @_alwaysEmitIntoClient
  public static var downloads: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x374de290, Data2: 0x123f, Data3: 0x4565, Data4: (0x91, 0x64, 0x39, 0xc4, 0x92, 0x5e, 0x46, 0x7b)))
  }

  /// The user's music.
  ///
  /// The corresponding C constant is `FOLDERID_Music`.
  @_alwaysEmitIntoClient
  public static var music: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x4bd8d571, Data2: 0x6d19, Data3: 0x48d3, Data4: (0xbe, 0x97, 0x42, 0x22, 0x20, 0x08, 0x0e, 0x43)))
  }

  /// The user's pictures.
  ///
  /// The corresponding C constant is `FOLDERID_Pictures`.
  @_alwaysEmitIntoClient
  public static var pictures: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x33e28130, Data2: 0x4e1e, Data3: 0x4676, Data4: (0x83, 0x5a, 0x98, 0x39, 0x5c, 0x3b, 0xc3, 0xbb)))
  }

  /// The user's videos.
  ///
  /// The corresponding C constant is `FOLDERID_Videos`.
  @_alwaysEmitIntoClient
  public static var videos: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x18989b1d, Data2: 0x99b5, Data3: 0x455b, Data4: (0x84, 0x1c, 0xab, 0x7c, 0x74, 0xe4, 0xdd, 0xfc)))
  }

  /// The directory that all users share, such as `C:\\Users\\Public`.
  ///
  /// The corresponding C constant is `FOLDERID_Public`.
  @_alwaysEmitIntoClient
  public static var publicFolder: Win32.KnownFolder {
    Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0xdfdf76a2, Data2: 0xc82a, Data3: 0x4d63, Data4: (0x90, 0x6a, 0x56, 0x44, 0xac, 0x45, 0x73, 0x85)))
  }
}

@available(System 199, *)
extension Win32.KnownFolder {
  /// Returns the folder's path.
  ///
  /// - Parameter options: How to find the path. The default is none: where
  ///   the user's settings put the folder, which must exist.
  /// - Returns: The path, which Windows gives without a trailing separator.
  ///
  /// Throws ``Win32/Error/fileNotFound`` for a folder that doesn't exist,
  /// unless `options` has ``Win32/KnownFolderOptions/create`` or
  /// ``Win32/KnownFolderOptions/doNotVerify``, and
  /// ``Win32/Error/invalidParameter`` for a GUID that names no known folder
  /// on this system, such as ``programFilesX86`` on 32-bit Windows.
  ///
  /// The corresponding C function is `SHGetKnownFolderPath`, with
  /// `KF_FLAG_DEFAULT` for no options, and `CoTaskMemFree`, which frees its
  /// result.
  @_alwaysEmitIntoClient
  public func path(options: Win32.KnownFolderOptions = []) throws(Win32.Error) -> FilePath {
    try Win32._knownFolderPath(rawValue, options.rawValue).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _knownFolderPath(
    _ folder: KNOWNFOLDERID, _ flags: DWORD
  ) -> Result<FilePath, Win32.Error> {
    var path: PWSTR? = nil
    let result = withUnsafePointer(to: folder) { folder in
      system_SHGetKnownFolderPath(folder, flags, nil, &path)
    }
    // The path is allocated even when the call fails, and freeing nil does
    // nothing.
    defer { system_CoTaskMemFree(path) }
    guard result >= 0, let path else {
      return .failure(Win32.Error(hResult: Win32.HResult(rawValue: result)))
    }
    return .success(FilePath(platformString: path))
  }
}

#endif // os(Windows)
