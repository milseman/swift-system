/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

// Must import here to use sysdir's constants in @_alwaysEmitIntoClient
// API; the Darwin module doesn't include sysdir.
import Darwin
import Darwin.sysdir

/// The paths of one of the system's standard directories,
/// such as the caches directory, in the domains asked for,
/// in the order to search them.
///
///     for path in SearchPaths(.applicationSupport, in: [.user, .local]) {
///       print(path)
///     }
///     // Prints "~/Library/Application Support"
///     // Prints "/Library/Application Support"
///
/// A path in the user's domain begins with `~`, the user's home directory,
/// which this type leaves for the caller to replace:
/// which directory that is depends on the program.
/// The `HOME` environment variable names it for most programs,
/// and a sandboxed app's is its container;
/// ``UserEntry`` looks up the one that the user database lists.
///
/// Some of the paths may not exist,
/// and some combinations of a directory and domains have none.
/// If the `NEXT_ROOT` environment variable is set,
/// each path begins with its value,
/// unless the process is set-user-ID or has entitlements.
///
/// Each iteration asks the system again,
/// so the paths are the same each time.
///
/// The corresponding C functions are `sysdir_start_search_path_enumeration`
/// and `sysdir_get_next_search_path_enumeration`.
/// - Note: Only available on Darwin.
@frozen
@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
public struct SearchPaths: Sequence, Hashable, Sendable {
  /// The directory whose paths these are.
  public var directory: Directory

  /// The domains to look in.
  public var domains: Domains

  /// Creates the search paths of a directory in the given domains.
  @_alwaysEmitIntoClient
  public init(_ directory: Directory, in domains: Domains) {
    self.directory = directory
    self.domains = domains
  }

  /// Returns an iterator over the paths, which starts a new enumeration.
  ///
  /// The corresponding C function is `sysdir_start_search_path_enumeration`.
  @_alwaysEmitIntoClient
  public func makeIterator() -> Iterator { _makeIterator() }

  @usableFromInline
  internal func _makeIterator() -> Iterator {
    Iterator(_state: system_sysdir_start_search_path_enumeration(
      directory.rawValue, domains.rawValue))
  }

  /// An iterator over the paths of a directory.
  @frozen
  public struct Iterator: IteratorProtocol {
    @usableFromInline
    internal var _state: CUnsignedInt

    @usableFromInline
    internal init(_state: CUnsignedInt) { self._state = _state }

    /// Returns the next path, or `nil` if there are no more.
    ///
    /// The corresponding C function is
    /// `sysdir_get_next_search_path_enumeration`.
    @_alwaysEmitIntoClient
    public mutating func next() -> FilePath? { _next() }

    @usableFromInline
    internal mutating func _next() -> FilePath? {
      // A state of zero ends the enumeration.
      guard _state != 0 else { return nil }
      // The call writes as many as PATH_MAX - 1 bytes and a terminator.
      return withUnsafeTemporaryAllocation(
        of: CChar.self, capacity: Int(PATH_MAX)
      ) { buffer -> FilePath? in
        buffer.initialize(repeating: 0)
        _state = system_sysdir_get_next_search_path_enumeration(
          _state, buffer.baseAddress!)
        guard _state != 0 else { return nil }
        return FilePath(platformString: buffer.baseAddress!)
      }
    }
  }
}

@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension SearchPaths {
  /// One of the system's standard directories.
  ///
  /// Not every directory has a useful path on every platform.
  ///
  /// The corresponding C type is `sysdir_search_path_directory_t`.
  @frozen
  public struct Directory: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CUnsignedInt

    /// Creates a strongly-typed directory from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }
  }

  /// A set of domains, the places a standard directory can be.
  ///
  /// The corresponding C type is `sysdir_search_path_domain_mask_t`.
  @frozen
  public struct Domains: OptionSet, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CUnsignedInt

    /// Creates a strongly-typed set of domains from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }

    /// The user's home directory,
    /// the place to install the user's own items.
    ///
    /// Paths in this domain begin with `~`.
    ///
    /// The corresponding C constant is `SYSDIR_DOMAIN_MASK_USER`.
    @_alwaysEmitIntoClient
    public static var user: Self { Self(rawValue: _SYSDIR_DOMAIN_MASK_USER) }

    /// The local machine,
    /// the place to install items for everyone who uses it.
    ///
    /// The corresponding C constant is `SYSDIR_DOMAIN_MASK_LOCAL`.
    @_alwaysEmitIntoClient
    public static var local: Self { Self(rawValue: _SYSDIR_DOMAIN_MASK_LOCAL) }

    /// The local area network,
    /// the place to install items for everyone on it: `/Network`.
    ///
    /// The corresponding C constant is `SYSDIR_DOMAIN_MASK_NETWORK`.
    @_alwaysEmitIntoClient
    public static var network: Self { Self(rawValue: _SYSDIR_DOMAIN_MASK_NETWORK) }

    /// The items that Apple provides: `/System`.
    ///
    /// The corresponding C constant is `SYSDIR_DOMAIN_MASK_SYSTEM`.
    @_alwaysEmitIntoClient
    public static var system: Self { Self(rawValue: _SYSDIR_DOMAIN_MASK_SYSTEM) }

    /// Every domain, including any that the system adds later.
    ///
    /// The corresponding C constant is `SYSDIR_DOMAIN_MASK_ALL`.
    @_alwaysEmitIntoClient
    public static var all: Self { Self(rawValue: _SYSDIR_DOMAIN_MASK_ALL) }
  }
}

@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension SearchPaths.Directory {
  /// Supported applications: `Applications`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_APPLICATION`.
  @_alwaysEmitIntoClient
  public static var applications: Self { Self(rawValue: _SYSDIR_DIRECTORY_APPLICATION) }

  /// Unsupported applications and demonstration versions: `Applications/Demos`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DEMO_APPLICATION`.
  @_alwaysEmitIntoClient
  public static var demoApplications: Self { Self(rawValue: _SYSDIR_DIRECTORY_DEMO_APPLICATION) }

  /// Developer applications: `Developer/Applications`.
  ///
  /// There's no longer one such directory; Xcode is a self-contained application.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DEVELOPER_APPLICATION`.
  @_alwaysEmitIntoClient
  public static var developerApplications: Self { Self(rawValue: _SYSDIR_DIRECTORY_DEVELOPER_APPLICATION) }

  /// System and network administration applications: `Applications/Utilities`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_ADMIN_APPLICATION`.
  @_alwaysEmitIntoClient
  public static var adminApplications: Self { Self(rawValue: _SYSDIR_DIRECTORY_ADMIN_APPLICATION) }

  /// Documentation, support, and configuration files, and resources: `Library`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_LIBRARY`.
  @_alwaysEmitIntoClient
  public static var library: Self { Self(rawValue: _SYSDIR_DIRECTORY_LIBRARY) }

  /// Developer resources: `Developer`.
  ///
  /// There's no longer one such directory; Xcode is a self-contained application.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DEVELOPER`.
  @_alwaysEmitIntoClient
  public static var developer: Self { Self(rawValue: _SYSDIR_DIRECTORY_DEVELOPER) }

  /// Users' home directories: `Users`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_USER`.
  @_alwaysEmitIntoClient
  public static var users: Self { Self(rawValue: _SYSDIR_DIRECTORY_USER) }

  /// Documentation: `Library/Documentation`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DOCUMENTATION`.
  @_alwaysEmitIntoClient
  public static var documentation: Self { Self(rawValue: _SYSDIR_DIRECTORY_DOCUMENTATION) }

  /// Documents: `Documents`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DOCUMENT`.
  @_alwaysEmitIntoClient
  public static var documents: Self { Self(rawValue: _SYSDIR_DIRECTORY_DOCUMENT) }

  /// Core services: `Library/CoreServices`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_CORESERVICE`.
  @_alwaysEmitIntoClient
  public static var coreServices: Self { Self(rawValue: _SYSDIR_DIRECTORY_CORESERVICE) }

  /// Autosaved documents: `Library/Autosave Information`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_AUTOSAVED_INFORMATION`.
  @_alwaysEmitIntoClient
  public static var autosavedInformation: Self { Self(rawValue: _SYSDIR_DIRECTORY_AUTOSAVED_INFORMATION) }

  /// The desktop: `Desktop`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DESKTOP`.
  @_alwaysEmitIntoClient
  public static var desktop: Self { Self(rawValue: _SYSDIR_DIRECTORY_DESKTOP) }

  /// Discardable cache files: `Library/Caches`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_CACHES`.
  @_alwaysEmitIntoClient
  public static var caches: Self { Self(rawValue: _SYSDIR_DIRECTORY_CACHES) }

  /// Application support files, such as plug-ins: `Library/Application Support`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_APPLICATION_SUPPORT`.
  @_alwaysEmitIntoClient
  public static var applicationSupport: Self { Self(rawValue: _SYSDIR_DIRECTORY_APPLICATION_SUPPORT) }

  /// Downloads: `Downloads`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_DOWNLOADS`.
  @_alwaysEmitIntoClient
  public static var downloads: Self { Self(rawValue: _SYSDIR_DIRECTORY_DOWNLOADS) }

  /// Input methods: `Library/Input Methods`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_INPUT_METHODS`.
  @_alwaysEmitIntoClient
  public static var inputMethods: Self { Self(rawValue: _SYSDIR_DIRECTORY_INPUT_METHODS) }

  /// Movies: `Movies`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_MOVIES`.
  @_alwaysEmitIntoClient
  public static var movies: Self { Self(rawValue: _SYSDIR_DIRECTORY_MOVIES) }

  /// Music: `Music`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_MUSIC`.
  @_alwaysEmitIntoClient
  public static var music: Self { Self(rawValue: _SYSDIR_DIRECTORY_MUSIC) }

  /// Pictures: `Pictures`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_PICTURES`.
  @_alwaysEmitIntoClient
  public static var pictures: Self { Self(rawValue: _SYSDIR_DIRECTORY_PICTURES) }

  /// Printer descriptions: `Library/Printers/PPDs`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_PRINTER_DESCRIPTION`.
  @_alwaysEmitIntoClient
  public static var printerDescriptions: Self { Self(rawValue: _SYSDIR_DIRECTORY_PRINTER_DESCRIPTION) }

  /// The public sharing directory: `Public`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_SHARED_PUBLIC`.
  @_alwaysEmitIntoClient
  public static var sharedPublic: Self { Self(rawValue: _SYSDIR_DIRECTORY_SHARED_PUBLIC) }

  /// Preference panes for System Settings: `Library/PreferencePanes`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_PREFERENCE_PANES`.
  @_alwaysEmitIntoClient
  public static var preferencePanes: Self { Self(rawValue: _SYSDIR_DIRECTORY_PREFERENCE_PANES) }

  /// Every directory where applications can be, such as `Applications` and `Applications/Utilities`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_ALL_APPLICATIONS`.
  @_alwaysEmitIntoClient
  public static var allApplications: Self { Self(rawValue: _SYSDIR_DIRECTORY_ALL_APPLICATIONS) }

  /// Every directory where resources can be: `Library` and `Developer`.
  ///
  /// The corresponding C constant is `SYSDIR_DIRECTORY_ALL_LIBRARIES`.
  @_alwaysEmitIntoClient
  public static var allLibraries: Self { Self(rawValue: _SYSDIR_DIRECTORY_ALL_LIBRARIES) }
}

#endif // SYSTEM_PACKAGE_DARWIN
