/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The CSystem shim that spawns with other credentials: on Darwin it forks,
// sets the child's groups and user, and runs the program with
// POSIX_SPAWN_SETEXEC; on Linux it sets them on a thread of its own and
// spawns from that thread.

#if SYSTEM_PACKAGE_DARWIN || os(Linux)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Returns an error number. A mocked call records its arguments and starts
// nothing.
internal func system_spawn_with_credentials(
  _ pid: UnsafeMutablePointer<pid_t>,
  _ path: UnsafePointer<CChar>,
  searchingPath: Bool,
  _ fileActions: UnsafePointer<_SpawnFileActionsStorage>?,
  _ attributes: UnsafePointer<_SpawnAttributesStorage>,
  _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
  _ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>,
  user: uid_t?, group: gid_t?, groups: [gid_t]?, descriptors: [CInt]
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(path: path, searchingPath, user, group, groups, descriptors)
  }
#endif
  func withPointer<T>(to value: T?, _ body: (UnsafePointer<T>?) -> CInt) -> CInt {
    guard let value else { return body(nil) }
    return withUnsafePointer(to: value) { body($0) }
  }
  return withPointer(to: user) { user in
    withPointer(to: group) { group in
      (groups ?? []).withUnsafeBufferPointer { groupList in
        descriptors.withUnsafeBufferPointer { descriptorList in
          csystem_spawn_with_credentials(
            pid, path, searchingPath ? 1 : 0, fileActions, attributes, arguments, environment,
            user, group, groups == nil ? -1 : CInt(groupList.count), groupList.baseAddress,
            CInt(descriptorList.count), descriptorList.baseAddress)
        }
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux)
