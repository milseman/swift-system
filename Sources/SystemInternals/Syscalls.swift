/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
#error("Unsupported Platform")
#endif

#if ENABLE_MOCKING
// Strip the mock_system prefix and the arg list suffix
private func originalSyscallName(_ s: String) -> String {
  precondition(s.starts(with: "system_"))
  return String(s.dropFirst("system_".count).prefix { $0.isLetter })
}

private func mockImpl(
  name: String,
  _ args: [AnyHashable]
) -> CInt {
  let origName = originalSyscallName(name)
  guard let driver = currentMockingDriver else {
    fatalError("Mocking requested from non-mocking context")
  }
  driver.trace.add(Trace.Entry(name: origName, args))

  switch driver.forceErrno {
  case .none: break
  case .always(let e):
    system_errno = e
    return -1
  case .counted(let e, let count):
    assert(count >= 1)
    system_errno = e
    driver.forceErrno = count > 1 ? .counted(errno: e, count: count-1) : .none
    return -1
  }

  return 0
}

private func mock(
  name: String = #function, _ args: AnyHashable...
) -> CInt {
  precondition(mockingEnabled)
  return mockImpl(name: name, args)
}
private func mockInt(
  name: String = #function, _ args: AnyHashable...
) -> Int {
  Int(mockImpl(name: name, args))
}

private func mockOffT(
  name: String = #function, _ args: AnyHashable...
) -> off_t {
  off_t(mockImpl(name: name, args))
}
#endif // ENABLE_MOCKING

// Interacting with the mocking system, tracing, etc., is a potentially significant
// amount of code size, so we hand outline that code for every syscall

// open
public func system_open(_ path: UnsafePointer<CChar>, _ oflag: Int32) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return mock(String(cString: path), oflag) }
#endif
  return open(path, oflag)
}

public func system_open(
  _ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return mock(String(cString: path), oflag, mode) }
#endif
  return open(path, oflag, mode)
}

// close
public func system_close(_ fd: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return mock(fd) }
#endif
  return close(fd)
}

// read
public func system_read(
  _ fd: Int32, _ buf: UnsafeMutableRawPointer!, _ nbyte: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return mockInt(fd, buf, nbyte) }
#endif
  return read(fd, buf, nbyte)
}

// pread
public func system_pread(
  _ fd: Int32, _ buf: UnsafeMutableRawPointer!, _ nbyte: Int, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return mockInt(fd, buf, nbyte, offset) }
#endif
  return pread(fd, buf, nbyte, offset)
}

// lseek
public func system_lseek(
  _ fd: Int32, _ off: off_t, _ whence: Int32
) -> off_t {
#if ENABLE_MOCKING
  if mockingEnabled { return mockOffT(fd, off, whence) }
#endif
  return lseek(fd, off, whence)
}

// write
public func system_write(
  _ fd: Int32, _ buf: UnsafeRawPointer!, _ nbyte: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return mockInt(fd, buf, nbyte) }
#endif
  return write(fd, buf, nbyte)
}

// pwrite
public func system_pwrite(
  _ fd: Int32, _ buf: UnsafeRawPointer!, _ nbyte: Int, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return mockInt(fd, buf, nbyte, offset) }
#endif
  return pwrite(fd, buf, nbyte, offset)
}

// TODO: Rewrite using conditional compilation style
@inline(never)
private func mock_system_pwrite(
  _ fd: Int32, _ buf: UnsafeRawPointer!, _ nbyte: Int, _ offset: off_t
) -> Int {
  mockInt(fd, buf, nbyte, offset)
}

// MARK: posix_spawn

// posix_spawn
public func system_posix_spawn(
  _ pid: UnsafeMutablePointer<pid_t>!,
  _ path: UnsafePointer<Int8>!,
  _ act: UnsafePointer<posix_spawn_file_actions_t?>!,
  _ attr: UnsafePointer<posix_spawnattr_t?>!,
  _ argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!,
  _ envp: UnsafePointer<UnsafeMutablePointer<Int8>?>!
) -> Int32 {
  if _fastPath(!mockingEnabled) { return posix_spawn(pid, path, act, attr, argv, envp) }
  return mock_system_posix_spawn(pid, path, act, attr, argv, envp)
}

@inline(never)
private func mock_system_posix_spawn(
  _ pid: UnsafeMutablePointer<pid_t>!,
  _ path: UnsafePointer<Int8>!,
  _ act: UnsafePointer<posix_spawn_file_actions_t?>!,
  _ attr: UnsafePointer<posix_spawnattr_t?>!,
  _ argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!,
  _ envp: UnsafePointer<UnsafeMutablePointer<Int8>?>!
) -> Int32 {
  mock(into: pid, path, act, attr, argv, envp)
}

func someKindaMock(_ args: Any...) -> CInt {
  fatalError()
}

// int posix_spawn_file_actions_addfchdir_np(file_actions, filedes)
@available(OSX 10.15, *)
public func system_posix_spawn_file_actions_addfchdir_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_addfchdir_np(file_actions, filedes)
  }
  return mock_system_posix_spawn_file_actions_addfchdir_np(file_actions, filedes)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_addfchdir_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  someKindaMock(file_actions, filedes)
}

// int posix_spawn_file_actions_addchdir_np(file_actions, path)
@available(OSX 10.15, *)
public func system_posix_spawn_file_actions_addchdir_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ path: UnsafePointer<Int8>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_addchdir_np(file_actions, path)
  }
  return mock_system_posix_spawn_file_actions_addchdir_np(file_actions, path)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_addchdir_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ path: UnsafePointer<Int8>
) -> CInt {
  someKindaMock(file_actions, path)
}

// int posix_spawn_file_actions_addinherit_np(file_actions, filedes)
public func system_posix_spawn_file_actions_addinherit_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_addinherit_np(file_actions, filedes)
  }
  return mock_system_posix_spawn_file_actions_addinherit_np(file_actions, filedes)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_addinherit_np(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  someKindaMock(file_actions, filedes)
}

// int posix_spawn_file_actions_adddup2(file_actions, filedes, newfiledes)
public func system_posix_spawn_file_actions_adddup2(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32, _ newfiledes: Int32
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_adddup2(file_actions, filedes, newfiledes)
  }
  return mock_system_posix_spawn_file_actions_adddup2(file_actions, filedes, newfiledes)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_adddup2(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32, _ newfiledes: Int32
) -> CInt {
  someKindaMock(file_actions, filedes, newfiledes)
}

// int posix_spawn_file_actions_addopen(restrict file_actions, filedes, path, oflag, mode)
public func system_posix_spawn_file_actions_addopen(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32, _ path: UnsafePointer<Int8>, _ oflag: Int32, _ mode: mode_t
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_addopen(file_actions, filedes, path, oflag, mode)
  }
  return mock_system_posix_spawn_file_actions_addopen(file_actions, filedes, path, oflag, mode)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_addopen(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32, _ path: UnsafePointer<Int8>, _ oflag: Int32, _ mode: mode_t
) -> CInt {
  someKindaMock(file_actions, filedes, path, oflag, mode)
}

// int posix_spawn_file_actions_addclose(file_actions, filedes)
public func system_posix_spawn_file_actions_addclose(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_addclose(file_actions, filedes)
  }
  return mock_system_posix_spawn_file_actions_addclose(file_actions, filedes)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_addclose(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ filedes: Int32
) -> CInt {
  someKindaMock(file_actions, filedes)
}

// int posix_spawn_file_actions_destroy(file_actions)
public func system_posix_spawn_file_actions_destroy(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_destroy(file_actions)
  }
  return mock_system_posix_spawn_file_actions_destroy(file_actions)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_destroy(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>
) -> CInt {
  someKindaMock(file_actions)
}

// int posix_spawn_file_actions_init(file_actions)
public func system_posix_spawn_file_actions_init(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawn_file_actions_init(file_actions)
  }
  return mock_system_posix_spawn_file_actions_init(file_actions)
}
@inline(never)
private func mock_system_posix_spawn_file_actions_init(
  _ file_actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>
) -> CInt {
  someKindaMock(file_actions)
}

// int posix_spawnattr_getsigdefault(attr, sigdefault)
public func system_posix_spawnattr_getsigdefault(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ sigdefault: UnsafeMutablePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_getsigdefault(attr, sigdefault)
  }
  return mock_system_posix_spawnattr_getsigdefault(attr, sigdefault)
}
@inline(never)
private func mock_system_posix_spawnattr_getsigdefault(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ sigdefault: UnsafeMutablePointer<sigset_t>
) -> CInt {
  someKindaMock(attr, sigdefault)
}

// int posix_spawnattr_setsigdefault(attr, sigdefault)
public func system_posix_spawnattr_setsigdefault(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ sigdefault: UnsafePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_setsigdefault(attr, sigdefault)
  }
  return mock_system_posix_spawnattr_setsigdefault(attr, sigdefault)
}
@inline(never)
private func mock_system_posix_spawnattr_setsigdefault(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ sigdefault: UnsafePointer<sigset_t>
) -> CInt {
  someKindaMock(attr, sigdefault)
}

// int posix_spawnattr_getsigmask(attr, sigmask)
public func system_posix_spawnattr_getsigmask(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ sigmask: UnsafeMutablePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_getsigmask(attr, sigmask)
  }
  return mock_system_posix_spawnattr_getsigmask(attr, sigmask)
}
@inline(never)
private func mock_system_posix_spawnattr_getsigmask(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ sigmask: UnsafeMutablePointer<sigset_t>
) -> CInt {
  someKindaMock(attr, sigmask)
}

// int posix_spawnattr_setsigmask(attr, sigmask)
public func system_posix_spawnattr_setsigmask(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ sigmask: UnsafePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_setsigmask(attr, sigmask)
  }
  return mock_system_posix_spawnattr_setsigmask(attr, sigmask)
}
@inline(never)
private func mock_system_posix_spawnattr_setsigmask(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ sigmask: UnsafePointer<sigset_t>
) -> CInt {
  someKindaMock(attr, sigmask)
}

// int posix_spawnattr_getflags(attr, flags)
public func system_posix_spawnattr_getflags(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ flags: UnsafeMutablePointer<Int16>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_getflags(attr, flags)
  }
  return mock_system_posix_spawnattr_getflags(attr, flags)
}
@inline(never)
private func mock_system_posix_spawnattr_getflags(
  _ attr: UnsafePointer<posix_spawnattr_t?>, _ flags: UnsafeMutablePointer<Int16>
) -> CInt {
  someKindaMock(attr, flags)
}

// int posix_spawnattr_setflags(attr, flags)
public func system_posix_spawnattr_setflags(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ flags: Int16
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_setflags(attr, flags)
  }
  return mock_system_posix_spawnattr_setflags(attr, flags)
}
@inline(never)
private func mock_system_posix_spawnattr_setflags(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ flags: Int16
) -> CInt {
  someKindaMock(attr, flags)
}

// int posix_spawnattr_destroy(attr)
public func system_posix_spawnattr_destroy(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_destroy(attr)
  }
  return mock_system_posix_spawnattr_destroy(attr)
}
@inline(never)
private func mock_system_posix_spawnattr_destroy(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>
) -> CInt {
  someKindaMock(attr)
}

// int posix_spawnattr_init(attr)
public func system_posix_spawnattr_init(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return posix_spawnattr_init(attr)
  }
  return mock_system_posix_spawnattr_init(attr)
}
@inline(never)
private func mock_system_posix_spawnattr_init(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>
) -> CInt {
  someKindaMock(attr)
}

// MARK: signal sets

// int sigaddset(sigset_t *set, int signo)
public func system_sigaddset(
  _ set: UnsafeMutablePointer<sigset_t>, _ signo: CInt
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return sigaddset(set, signo)
  }
  return mock_system_sigaddset(set, signo)
}
@inline(never)
private func mock_system_sigaddset(
  _ set: UnsafeMutablePointer<sigset_t>, _ signo: CInt
) -> CInt {
  someKindaMock(set, signo)
}

// int sigdelset(sigset_t *set, int signo)
public func system_sigdelset(
  _ set: UnsafeMutablePointer<sigset_t>, _ signo: CInt
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return sigdelset(set, signo)
  }
  return mock_system_sigdelset(set, signo)
}
@inline(never)
private func mock_system_sigdelset(
  _ set: UnsafeMutablePointer<sigset_t>, _ signo: CInt
) -> CInt {
  someKindaMock(set, signo)
}

// int sigemptyset(sigset_t *set)
public func system_sigemptyset(
  _ set: UnsafeMutablePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return sigemptyset(set)
  }
  return mock_system_sigemptyset(set)
}
@inline(never)
private func mock_system_sigemptyset(
  _ set: UnsafeMutablePointer<sigset_t>
) -> CInt {
  someKindaMock(set)
}
// int sigfillset(sigset_t *set)
public func system_sigfillset(
  _ set: UnsafeMutablePointer<sigset_t>
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return sigfillset(set)
  }
  return mock_system_sigfillset(set)
}
@inline(never)
private func mock_system_sigfillset(
  _ set: UnsafeMutablePointer<sigset_t>
) -> CInt {
  someKindaMock(set)
}

// int sigismember(const sigset_t *set, int signo)
public func system_sigismember(
  _ set: UnsafePointer<sigset_t>, _ signo: CInt
) -> CInt {
  if _fastPath(!mockingEnabled) {
    return sigismember(set, signo)
  }
  return mock_system_sigismember(set, signo)
}
@inline(never)
private func mock_system_sigismember(
  _ set: UnsafePointer<sigset_t>, _ signo: CInt
) -> CInt {
  someKindaMock(set, signo)
}



