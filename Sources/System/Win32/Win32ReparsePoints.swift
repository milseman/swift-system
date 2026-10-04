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
  /// What a reparse point holds: its tag, and the data that the tag's owner
  /// keeps in it.
  ///
  /// A symbolic link and a mount point, which name another file or
  /// directory, keep two names of it: the substitute name, which Windows
  /// follows, and the print name, for people. ``target`` is the substitute
  /// name as a path for Win32's functions.
  ///
  /// The corresponding C type is `REPARSE_DATA_BUFFER`, which the Windows
  /// Driver Kit declares, or, for a tag that isn't Microsoft's,
  /// `REPARSE_GUID_DATA_BUFFER`.
  public struct ReparsePoint: Sendable, Hashable {
    /// The reparse point's tag.
    public var tag: Win32.ReparseTag

    /// The data that the tag's owner keeps: the bytes after the tag and the
    /// data's length, and, for a tag that isn't Microsoft's, after its GUID.
    public var data: [UInt8]

    /// A symbolic link's or a mount point's substitute name: the target as
    /// Windows follows it, such as `\??\C:\target`, an NT path, or a
    /// relative path. `nil` for the other tags.
    ///
    /// The name is decoded from UTF-16 with any unpaired surrogate replaced,
    /// which ``target`` keeps.
    public var substituteName: String?

    /// A symbolic link's or a mount point's print name: the target as it's
    /// shown, such as `C:\target`. Some programs that make junctions leave
    /// it empty. `nil` for the other tags.
    public var printName: String?

    /// Whether a symbolic link's target is relative to the link's
    /// directory.
    ///
    /// The corresponding C constant is `SYMLINK_FLAG_RELATIVE`.
    public var isRelative: Bool

    /// A symbolic link's or a mount point's target, as a path for Win32's
    /// functions, or `nil` for the other tags.
    ///
    /// A relative target is the substitute name as it is. An absolute one
    /// begins with NT's `\??\`, which becomes `\\?\`, Win32's spelling of the
    /// same prefix; the prefix is then removed where the path means the same
    /// without it: a drive's path, or a UNC path, which becomes
    /// `\\server\share\…`, shorter than `MAX_PATH`, whose full path is
    /// itself. That's the rule Rust's `std::fs::read_link` follows.
    public var target: FilePath?

    internal init(
      _tag tag: Win32.ReparseTag,
      data: [UInt8],
      substituteName: String?,
      printName: String?,
      isRelative: Bool,
      target: FilePath?
    ) {
      self.tag = tag
      self.data = data
      self.substituteName = substituteName
      self.printName = printName
      self.isRelative = isRelative
      self.target = target
    }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// The reparse point this handle is open on.
  ///
  /// To open a reparse point itself, rather than the file it leads to, pass
  /// ``Win32/FileFlags/openReparsePoint``, and, for a directory's,
  /// ``Win32/FileFlags/backupSemantics``. The query needs no access rights:
  /// open the reparse point with an empty ``Win32/AccessMask`` to read one
  /// whose security descriptor denies the others, as the junction
  /// `C:\Documents and Settings` denies listing it.
  ///
  /// Throws ``Win32/Error/notAReparsePoint`` for a file that isn't one, and
  /// ``Win32/Error/invalidReparseData`` for data whose lengths are out of
  /// its bounds.
  ///
  /// The corresponding C function is `DeviceIoControl`, with
  /// `FSCTL_GET_REPARSE_POINT`.
  @_alwaysEmitIntoClient
  public func reparsePoint() throws(Win32.Error) -> Win32.ReparsePoint {
    try Win32._reparsePoint(_handle).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// The reparse point this handle is open on, such as a junction's or a
  /// directory symbolic link's.
  ///
  /// To open a reparse point itself, rather than the directory it leads to,
  /// pass ``Win32/FileFlags/openReparsePoint``. The query needs no access
  /// rights: open the reparse point with an empty ``Win32/AccessMask`` to
  /// read one whose security descriptor denies listing it, as the junction
  /// `C:\Documents and Settings`'s does.
  ///
  /// Throws ``Win32/Error/notAReparsePoint`` for a directory that isn't one,
  /// and ``Win32/Error/invalidReparseData`` for data whose lengths are out of
  /// its bounds.
  ///
  /// The corresponding C function is `DeviceIoControl`, with
  /// `FSCTL_GET_REPARSE_POINT`.
  @_alwaysEmitIntoClient
  public func reparsePoint() throws(Win32.Error) -> Win32.ReparsePoint {
    try Win32._reparsePoint(_handle).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _reparsePoint(_ handle: HANDLE) -> Result<Win32.ReparsePoint, Win32.Error> {
    // The largest reparse point there is, so the query never needs more.
    withUnsafeTemporaryAllocation(
      byteCount: _MAXIMUM_REPARSE_DATA_BUFFER_SIZE, alignment: 8
    ) { buffer in
      var returned: DWORD = 0
      guard system_DeviceIoControl(
        handle, _FSCTL_GET_REPARSE_POINT, nil, 0, buffer.baseAddress, DWORD(buffer.count),
        &returned
      ) else {
        return .failure(Win32.Error(GetLastError()))
      }
      let bytes = UnsafeRawBufferPointer(rebasing: buffer[..<min(Int(returned), buffer.count)])
      guard let parsed = Win32.ReparsePoint._parse(bytes) else {
        return .failure(.invalidReparseData)
      }
      return .success(Win32.ReparsePoint(
        _tag: parsed.tag,
        data: parsed.data,
        substituteName: parsed.substituteName.map { String(decoding: $0, as: UTF16.self) },
        printName: parsed.printName.map { String(decoding: $0, as: UTF16.self) },
        isRelative: parsed.isRelative,
        target: parsed.substituteName.map { name in
          _filePath(Win32.ReparsePoint._target(
            name, isRelative: parsed.isRelative, fullPath: _fullPathName))
        }))
    }
  }

  /// The path that `GetFullPathNameW` makes of `path`, or `nil` if it fails
  /// or the result is longer than twice `MAX_PATH`.
  internal static func _fullPathName(_ path: [UInt16]) -> [UInt16]? {
    (path + [0]).withUnsafeBufferPointer { path in
      withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: 2 * _win32MaxPath) { buffer in
        let length = system_GetFullPathNameW(
          path.baseAddress!, DWORD(buffer.count), buffer.baseAddress, nil)
        guard length > 0, Int(length) < buffer.count else { return nil }
        return Array(buffer[..<Int(length)])
      }
    }
  }

  /// A path from UTF-16 code units, unpaired surrogates and all.
  internal static func _filePath(_ codeUnits: [UInt16]) -> FilePath {
    (codeUnits + [0]).withUnsafeBufferPointer { FilePath(platformString: $0.baseAddress!) }
  }
}

@available(System 199, *)
extension Win32.ReparsePoint {
  /// The parts of a reparse point's bytes, as `FSCTL_GET_REPARSE_POINT`
  /// returns them, or `nil` if their lengths are out of their bounds.
  internal static func _parse(_ bytes: UnsafeRawBufferPointer) -> (
    tag: Win32.ReparseTag, data: [UInt8], substituteName: [UInt16]?, printName: [UInt16]?,
    isRelative: Bool
  )? {
    // The tag, 32 bits, the data's length, 16 bits, and 16 reserved bits,
    // little-endian, as Windows is everywhere.
    guard bytes.count >= 8 else { return nil }
    let tag = Win32.ReparseTag(rawValue: UInt32(littleEndian: bytes.loadUnaligned(as: UInt32.self)))
    let length = Int(UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: 4, as: UInt16.self)))
    // A tag that isn't Microsoft's has a 16-byte GUID after its header.
    let start = tag.isMicrosoft ? 8 : 24
    guard start + length <= bytes.count else { return nil }
    let data = Array(bytes[start..<(start + length)])
    guard tag == .symbolicLink || tag == .mountPoint else {
      return (tag, data, nil, nil, false)
    }
    // The substitute name's offset and length, and the print name's, 16
    // bits each and in bytes from the path buffer, which follows them, and,
    // for a symbolic link, 32 bits of flags first.
    let header = tag == .symbolicLink ? 12 : 8
    guard data.count >= header else { return nil }
    func field(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
    var isRelative = false
    if tag == .symbolicLink {
      let flags = (8..<12).reduce(UInt32(0)) { $0 | UInt32(data[$1]) << (8 * UInt32($1 - 8)) }
      isRelative = flags & _SYMLINK_FLAG_RELATIVE != 0
    }
    func name(_ offset: Int, _ length: Int) -> [UInt16]? {
      let start = header + offset
      guard offset % 2 == 0, length % 2 == 0, start + length <= data.count else { return nil }
      return stride(from: start, to: start + length, by: 2).map {
        UInt16(data[$0]) | UInt16(data[$0 + 1]) << 8
      }
    }
    guard let substituteName = name(field(0), field(2)),
      let printName = name(field(4), field(6))
    else { return nil }
    return (tag, data, substituteName, printName, isRelative)
  }

  /// A substitute name as a Win32 path: relative as it is; NT's `\??\` as
  /// `\\?\`, removed from a drive's or a UNC path shorter than `MAX_PATH`
  /// whose full path, by `fullPath`, is itself.
  internal static func _target(
    _ name: [UInt16], isRelative: Bool, fullPath: ([UInt16]) -> [UInt16]?
  ) -> [UInt16] {
    let backslash = UInt16(UInt8(ascii: "\\"))
    let question = UInt16(UInt8(ascii: "?"))
    guard !isRelative, name.starts(with: [backslash, question, question, backslash]) else {
      return name
    }
    var verbatim = name
    verbatim[1] = backslash
    let rest = Array(name.dropFirst(4))
    let shorter: [UInt16]
    if rest.count >= 3, rest[1] == UInt16(UInt8(ascii: ":")), rest[2] == backslash {
      shorter = rest
    } else if rest.starts(with: Array("UNC\\".utf16)) {
      shorter = [backslash, backslash] + rest.dropFirst(4)
    } else {
      return verbatim
    }
    guard shorter.count < _win32MaxPath, fullPath(shorter) == shorter else { return verbatim }
    return shorter
  }
}

#endif // os(Windows)
