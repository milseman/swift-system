#[[
This source file is part of the Swift System open source project

Copyright (c) 2026 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

# Winsock, Windows' sockets; Sources/CMakeLists.txt adds this directory only
# when building for Windows.
add_library(SystemWinSocks
  Internals/WinsockConstants.swift
  Internals/WinsockStartup.swift
  Internals/WinsockSyscalls.swift
  Sockets/SocketDescriptor.swift
  Sockets/SocketOperations.swift
  Util.swift
  Win32Error+Winsock.swift)
set_target_properties(SystemWinSocks PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

# SystemPackage's Swift options, its availability macros among them, so that
# the two stay the same.
get_target_property(SWIFT_SYSTEM_WINSOCKS_OPTIONS SystemPackage COMPILE_OPTIONS)
target_compile_options(SystemWinSocks PRIVATE
  ${SWIFT_SYSTEM_WINSOCKS_OPTIONS})
target_link_libraries(SystemWinSocks PUBLIC
  SystemPackage
  ws2_32)

_install_target(SystemWinSocks)
set_property(GLOBAL APPEND PROPERTY SWIFT_SYSTEM_EXPORTS SystemWinSocks)
