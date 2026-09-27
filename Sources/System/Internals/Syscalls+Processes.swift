/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Wrappers for the process and signal calls behind Sources/System/Processes:
// signals and their masks and actions, process groups and sessions, waiting,
// posix_spawn and exec, resource limits, credentials, and on Linux, process
// and signal descriptors.
//
// The calls that return an error number rather than setting errno
// (pthread_kill, pthread_sigmask, sigwait, and the posix_spawn family) use
// `_mockReturningErrno`. The calls that can't fail aren't mockable, and
// neither are the signal set and spawn attribute functions, which only fill
// in a local structure.

#if !os(Windows) && !os(WASI)

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Sending signals

internal func system_kill(_ pid: pid_t, _ signal: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, signal) }
#endif
  return kill(pid, signal)
}

internal func system_killpg(_ group: pid_t, _ signal: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(group, signal) }
#endif
  return killpg(group, signal)
}

internal func system_raise(_ signal: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(signal) }
#endif
  return raise(signal)
}

internal func system_pthread_kill(_ thread: pthread_t, _ signal: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(thread, signal) }
#endif
  return pthread_kill(thread, signal)
}

// MARK: - Signal sets
//
// Not mockable: these only fill in a local structure. They fail only for a
// signal number the platform doesn't have.

internal func system_sigemptyset(_ set: UnsafeMutablePointer<sigset_t>) -> CInt {
  sigemptyset(set)
}

internal func system_sigfillset(_ set: UnsafeMutablePointer<sigset_t>) -> CInt {
  sigfillset(set)
}

internal func system_sigaddset(_ set: UnsafeMutablePointer<sigset_t>, _ signal: CInt) -> CInt {
  sigaddset(set, signal)
}

internal func system_sigdelset(_ set: UnsafeMutablePointer<sigset_t>, _ signal: CInt) -> CInt {
  sigdelset(set, signal)
}

internal func system_sigismember(_ set: UnsafePointer<sigset_t>, _ signal: CInt) -> CInt {
  sigismember(set, signal)
}

// MARK: - Signal masks and waiting for signals

// Records the operation and the signals by value, rather than the pointers:
// the new set's members, or nil for none.
internal func system_pthread_sigmask(
  _ how: CInt,
  _ set: UnsafePointer<sigset_t>?,
  _ oldSet: UnsafeMutablePointer<sigset_t>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(how, set.map { _signalNumbers(in: $0) })
  }
#endif
  return pthread_sigmask(how, set, oldSet)
}

// Not mockable: it can't fail.
internal func system_sigpending(_ set: UnsafeMutablePointer<sigset_t>) -> CInt {
  sigpending(set)
}

internal func system_sigwait(
  _ set: UnsafePointer<sigset_t>, _ signal: UnsafeMutablePointer<CInt>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(_signalNumbers(in: set))
    // Report the lowest signal in the set, so that the caller reads a real
    // signal number.
    if result == 0 { signal.pointee = _signalNumbers(in: set).first ?? 0 }
    return result
  }
#endif
  return sigwait(set, signal)
}

internal func system_sigsuspend(_ mask: UnsafePointer<sigset_t>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(_signalNumbers(in: mask)) }
#endif
  return sigsuspend(mask)
}

// MARK: - Signal actions

// Records the signal and the new action's handler and flags by value, or -1
// and -1 for no new action. A mocked call leaves the old action as it was.
internal func system_sigaction(
  _ signal: CInt,
  _ action: UnsafePointer<sigaction>?,
  _ oldAction: UnsafeMutablePointer<sigaction>?
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      signal,
      action.map { Int(bitPattern: csystem_sigaction_handler($0)) } ?? -1,
      action.map { Int($0.pointee.sa_flags) } ?? -1)
  }
#endif
  return sigaction(signal, action, oldAction)
}

// MARK: - Process groups and sessions

internal func system_setsid() -> pid_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return setsid()
}

internal func system_setpgid(_ pid: pid_t, _ group: pid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, group) }
#endif
  return setpgid(pid, group)
}

internal func system_getpgid(_ pid: pid_t) -> pid_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid) }
#endif
  return getpgid(pid)
}

// Not mockable: it can't fail.
internal func system_getpgrp() -> pid_t {
  getpgrp()
}

internal func system_getsid(_ pid: pid_t) -> pid_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid) }
#endif
  return getsid(pid)
}

// MARK: - Waiting

// A mocked call leaves the status as it was, and returns 0.
internal func system_waitpid(
  _ pid: pid_t, _ status: UnsafeMutablePointer<CInt>, _ options: CInt
) -> pid_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, options) }
#endif
  return waitpid(pid, status, options)
}

// Records the identifier type by value. A mocked call leaves the
// information as it was.
internal func system_waitid(
  _ type: idtype_t, _ id: id_t, _ info: UnsafeMutablePointer<siginfo_t>, _ options: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(_idTypeValue(type), Int(id), options) }
#endif
  return waitid(type, id, info, options)
}

#if os(Android)
internal func _idTypeValue(_ type: idtype_t) -> Int { Int(type) }
#else
internal func _idTypeValue(_ type: idtype_t) -> Int { Int(type.rawValue) }
#endif

// MARK: - Spawning and executing
//
// posix_spawn is unavailable on watchOS and tvOS, and this package doesn't
// wrap it on Android, where it needs API level 28 and where its pointers'
// nullability has changed between NDK releases.

#if !os(watchOS) && !os(tvOS) && !os(Android)

// The storage types: opaque pointers on Darwin, FreeBSD, and OpenBSD, and
// structures elsewhere.
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@usableFromInline internal typealias _SpawnAttributesStorage = posix_spawnattr_t?
@usableFromInline internal typealias _SpawnFileActionsStorage = posix_spawn_file_actions_t?

internal var _spawnAttributesZero: _SpawnAttributesStorage { nil }
internal var _spawnFileActionsZero: _SpawnFileActionsStorage { nil }
#else
@usableFromInline internal typealias _SpawnAttributesStorage = posix_spawnattr_t
@usableFromInline internal typealias _SpawnFileActionsStorage = posix_spawn_file_actions_t

internal var _spawnAttributesZero: _SpawnAttributesStorage { posix_spawnattr_t() }
internal var _spawnFileActionsZero: _SpawnFileActionsStorage { posix_spawn_file_actions_t() }
#endif

// Records the path, the arguments, and the environment by value. A mocked
// call that succeeds reports a process ID that no process can have, so that
// code that later signals or waits for it affects nothing.
internal func system_posix_spawn(
  _ pid: UnsafeMutablePointer<pid_t>,
  _ path: UnsafePointer<CChar>,
  _ fileActions: UnsafePointer<_SpawnFileActionsStorage>?,
  _ attributes: UnsafePointer<_SpawnAttributesStorage>?,
  _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
  _ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(
      path: path, _strings(arguments), _strings(environment))
    if result == 0 { pid.pointee = _mockedChildProcessID }
    return result
  }
#endif
  return posix_spawn(pid, path, fileActions, attributes, arguments, environment)
}

internal func system_posix_spawnp(
  _ pid: UnsafeMutablePointer<pid_t>,
  _ file: UnsafePointer<CChar>,
  _ fileActions: UnsafePointer<_SpawnFileActionsStorage>?,
  _ attributes: UnsafePointer<_SpawnAttributesStorage>?,
  _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
  _ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    let result = _mockReturningErrno(
      path: file, _strings(arguments), _strings(environment))
    if result == 0 { pid.pointee = _mockedChildProcessID }
    return result
  }
#endif
  return posix_spawnp(pid, file, fileActions, attributes, arguments, environment)
}

// Larger than any system's maximum process ID, so no process has it.
internal var _mockedChildProcessID: pid_t { .max }

// Not mockable: these only fill in a local structure. They return an error
// number.

internal func system_posix_spawnattr_init(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>
) -> CInt {
  posix_spawnattr_init(attributes)
}

internal func system_posix_spawnattr_destroy(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>
) -> CInt {
  posix_spawnattr_destroy(attributes)
}

internal func system_posix_spawnattr_setflags(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>, _ flags: CShort
) -> CInt {
  posix_spawnattr_setflags(attributes, flags)
}

internal func system_posix_spawnattr_setpgroup(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>, _ group: pid_t
) -> CInt {
  posix_spawnattr_setpgroup(attributes, group)
}

internal func system_posix_spawnattr_setsigmask(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>,
  _ mask: UnsafePointer<sigset_t>
) -> CInt {
  posix_spawnattr_setsigmask(attributes, mask)
}

internal func system_posix_spawnattr_setsigdefault(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>,
  _ signals: UnsafePointer<sigset_t>
) -> CInt {
  posix_spawnattr_setsigdefault(attributes, signals)
}

#if SYSTEM_PACKAGE_DARWIN
internal func system_posix_spawnattr_set_qos_class_np(
  _ attributes: UnsafeMutablePointer<_SpawnAttributesStorage>, _ qosClass: qos_class_t
) -> CInt {
  posix_spawnattr_set_qos_class_np(attributes, qosClass)
}
#endif

internal func system_posix_spawn_file_actions_init(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>
) -> CInt {
  posix_spawn_file_actions_init(actions)
}

internal func system_posix_spawn_file_actions_destroy(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>
) -> CInt {
  posix_spawn_file_actions_destroy(actions)
}

internal func system_posix_spawn_file_actions_addopen(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>,
  _ fd: CInt,
  _ path: UnsafePointer<CChar>,
  _ oflag: CInt,
  _ mode: CInterop.Mode
) -> CInt {
  posix_spawn_file_actions_addopen(actions, fd, path, oflag, mode)
}

internal func system_posix_spawn_file_actions_adddup2(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>, _ fd: CInt, _ target: CInt
) -> CInt {
  posix_spawn_file_actions_adddup2(actions, fd, target)
}

internal func system_posix_spawn_file_actions_addclose(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>, _ fd: CInt
) -> CInt {
  posix_spawn_file_actions_addclose(actions, fd)
}

// ENOSYS where the C library or OS version lacks it; see shims.c.
internal func system_posix_spawn_file_actions_addchdir(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>,
  _ path: UnsafePointer<CChar>
) -> CInt {
  csystem_posix_spawn_file_actions_addchdir(actions, path)
}

internal func system_posix_spawn_file_actions_addfchdir(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>, _ fd: CInt
) -> CInt {
  csystem_posix_spawn_file_actions_addfchdir(actions, fd)
}

internal func system_posix_spawn_file_actions_addclosefrom(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>, _ fd: CInt
) -> CInt {
  csystem_posix_spawn_file_actions_addclosefrom(actions, fd)
}

#if SYSTEM_PACKAGE_DARWIN
internal func system_posix_spawn_file_actions_addinherit_np(
  _ actions: UnsafeMutablePointer<_SpawnFileActionsStorage>, _ fd: CInt
) -> CInt {
  posix_spawn_file_actions_addinherit_np(actions, fd)
}
#endif

// Records the path, the arguments, and the environment by value. A mocked
// call fails with the forced error, or with ENOEXEC, since exec returns only
// when it fails.
internal func system_execve(
  _ path: UnsafePointer<CChar>,
  _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
  _ environment: UnsafePointer<UnsafeMutablePointer<CChar>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    if _mock(path: path, _strings(arguments), _strings(environment)) == 0 {
      system_errno = ENOEXEC
    }
    return -1
  }
#endif
  return execve(path, arguments, environment)
}

internal func system_execvp(
  _ file: UnsafePointer<CChar>,
  _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    if _mock(path: file, _strings(arguments)) == 0 {
      system_errno = ENOEXEC
    }
    return -1
  }
#endif
  return execvp(file, arguments)
}
#endif // !os(watchOS) && !os(tvOS) && !os(Android)

// The environment that spawn and execute pass on by default. Not mockable:
// it can't fail.
internal func system_spawn_environ() -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
  csystem_spawn_environ()
}

// MARK: - Resource limits

internal func system_getrlimit(_ resource: CInt, _ limit: UnsafeMutablePointer<rlimit>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(resource) }
#endif
  return getrlimit(numericCast(resource), limit)
}

// Records the new limit by value.
internal func system_setrlimit(_ resource: CInt, _ limit: UnsafePointer<rlimit>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(resource, UInt64(limit.pointee.rlim_cur), UInt64(limit.pointee.rlim_max))
  }
#endif
  return setrlimit(numericCast(resource), limit)
}

// MARK: - Credentials

internal func system_setuid(_ id: uid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(id) }
#endif
  return setuid(id)
}

internal func system_seteuid(_ id: uid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(id) }
#endif
  return seteuid(id)
}

internal func system_setreuid(_ real: uid_t, _ effective: uid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(real, effective) }
#endif
  return setreuid(real, effective)
}

internal func system_setgid(_ id: gid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(id) }
#endif
  return setgid(id)
}

internal func system_setegid(_ id: gid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(id) }
#endif
  return setegid(id)
}

internal func system_setregid(_ real: gid_t, _ effective: gid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(real, effective) }
#endif
  return setregid(real, effective)
}

// Records the groups by value.
internal func system_setgroups(_ count: Int, _ groups: UnsafePointer<gid_t>?) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(count, Array(UnsafeBufferPointer(start: groups, count: count)))
  }
#endif
  return setgroups(numericCast(count), groups)
}

internal func system_initgroups(_ user: UnsafePointer<CChar>, _ group: gid_t) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: user, group) }
#endif
  #if SYSTEM_PACKAGE_DARWIN
  // Darwin's takes an int.
  return initgroups(user, CInt(bitPattern: group))
  #else
  return initgroups(user, group)
  #endif
}

// MARK: - Process descriptors, signal descriptors, and closing ranges

#if os(Linux) || os(Android)
internal func system_pidfd_open(_ pid: pid_t, _ flags: CUnsignedInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pid, flags) }
#endif
  return csystem_pidfd_open(pid, flags)
}

internal func system_pidfd_send_signal(
  _ pidfd: CInt, _ signal: CInt, _ flags: CUnsignedInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(pidfd, signal, flags) }
#endif
  return csystem_pidfd_send_signal(pidfd, signal, nil, flags)
}

// Records the signals by value, rather than the pointer.
internal func system_signalfd(
  _ fd: CInt, _ mask: UnsafePointer<sigset_t>, _ flags: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, _signalNumbers(in: mask), flags) }
#endif
  return csystem_signalfd(fd, mask, flags)
}
#endif // os(Linux) || os(Android)

#if os(Linux) || os(Android) || os(FreeBSD)
internal func system_close_range(
  _ first: CUnsignedInt, _ last: CUnsignedInt, _ flags: CUnsignedInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(first, last, flags) }
#endif
  #if os(FreeBSD)
  return close_range(first, last, CInt(flags))
  #else
  return csystem_close_range(first, last, flags)
  #endif
}
#endif // os(Linux) || os(Android) || os(FreeBSD)

#if os(OpenBSD)
internal func system_closefrom(_ fd: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return closefrom(fd)
}
#endif // os(OpenBSD)

// MARK: - Mocking helpers

#if ENABLE_MOCKING
// The signal numbers in a set, in increasing order, for recording a set by
// value.
internal func _signalNumbers(in set: UnsafePointer<sigset_t>) -> [CInt] {
  (1..<_NSIG).filter { sigismember(set, $0) == 1 }
}

// The strings of a null-terminated array of C strings.
internal func _strings(_ array: UnsafePointer<UnsafeMutablePointer<CChar>?>) -> [String] {
  var result: [String] = []
  var index = 0
  while let string = array[index] {
    result.append(String(cString: string))
    index += 1
  }
  return result
}
#endif // ENABLE_MOCKING

#endif // !os(Windows) && !os(WASI)
