/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's standard directories and their domains, from <sysdir.h>.

#if SYSTEM_PACKAGE_DARWIN

import Darwin
import Darwin.sysdir

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_APPLICATION: CUnsignedInt { SYSDIR_DIRECTORY_APPLICATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DEMO_APPLICATION: CUnsignedInt { SYSDIR_DIRECTORY_DEMO_APPLICATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DEVELOPER_APPLICATION: CUnsignedInt { SYSDIR_DIRECTORY_DEVELOPER_APPLICATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_ADMIN_APPLICATION: CUnsignedInt { SYSDIR_DIRECTORY_ADMIN_APPLICATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_LIBRARY: CUnsignedInt { SYSDIR_DIRECTORY_LIBRARY.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DEVELOPER: CUnsignedInt { SYSDIR_DIRECTORY_DEVELOPER.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_USER: CUnsignedInt { SYSDIR_DIRECTORY_USER.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DOCUMENTATION: CUnsignedInt { SYSDIR_DIRECTORY_DOCUMENTATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DOCUMENT: CUnsignedInt { SYSDIR_DIRECTORY_DOCUMENT.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_CORESERVICE: CUnsignedInt { SYSDIR_DIRECTORY_CORESERVICE.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_AUTOSAVED_INFORMATION: CUnsignedInt { SYSDIR_DIRECTORY_AUTOSAVED_INFORMATION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DESKTOP: CUnsignedInt { SYSDIR_DIRECTORY_DESKTOP.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_CACHES: CUnsignedInt { SYSDIR_DIRECTORY_CACHES.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_APPLICATION_SUPPORT: CUnsignedInt { SYSDIR_DIRECTORY_APPLICATION_SUPPORT.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_DOWNLOADS: CUnsignedInt { SYSDIR_DIRECTORY_DOWNLOADS.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_INPUT_METHODS: CUnsignedInt { SYSDIR_DIRECTORY_INPUT_METHODS.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_MOVIES: CUnsignedInt { SYSDIR_DIRECTORY_MOVIES.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_MUSIC: CUnsignedInt { SYSDIR_DIRECTORY_MUSIC.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_PICTURES: CUnsignedInt { SYSDIR_DIRECTORY_PICTURES.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_PRINTER_DESCRIPTION: CUnsignedInt { SYSDIR_DIRECTORY_PRINTER_DESCRIPTION.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_SHARED_PUBLIC: CUnsignedInt { SYSDIR_DIRECTORY_SHARED_PUBLIC.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_PREFERENCE_PANES: CUnsignedInt { SYSDIR_DIRECTORY_PREFERENCE_PANES.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_ALL_APPLICATIONS: CUnsignedInt { SYSDIR_DIRECTORY_ALL_APPLICATIONS.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DIRECTORY_ALL_LIBRARIES: CUnsignedInt { SYSDIR_DIRECTORY_ALL_LIBRARIES.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DOMAIN_MASK_USER: CUnsignedInt { sysdir_search_path_domain_mask_t.SYSDIR_DOMAIN_MASK_USER.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DOMAIN_MASK_LOCAL: CUnsignedInt { sysdir_search_path_domain_mask_t.SYSDIR_DOMAIN_MASK_LOCAL.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DOMAIN_MASK_NETWORK: CUnsignedInt { sysdir_search_path_domain_mask_t.SYSDIR_DOMAIN_MASK_NETWORK.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DOMAIN_MASK_SYSTEM: CUnsignedInt { sysdir_search_path_domain_mask_t.SYSDIR_DOMAIN_MASK_SYSTEM.rawValue }

@_alwaysEmitIntoClient
internal var _SYSDIR_DOMAIN_MASK_ALL: CUnsignedInt { sysdir_search_path_domain_mask_t.SYSDIR_DOMAIN_MASK_ALL.rawValue }

#endif // SYSTEM_PACKAGE_DARWIN
