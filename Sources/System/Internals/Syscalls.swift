/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import CSystem
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// Interacting with the mocking system, tracing, etc., is a potentially significant
// amount of code size, so we hand outline that code for every syscall

// open
internal func system_open(
  _ path: UnsafePointer<CInterop.PlatformChar>, _ oflag: Int32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: path, oflag)
  }
#endif
  return open(path, oflag)
}

internal func system_open(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ oflag: Int32, _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: path, oflag, mode)
  }
#endif
  return open(path, oflag, mode)
}

// close
internal func system_close(_ fd: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return close(fd)
}

// read
internal func system_read(
  _ fd: Int32, _ buf: UnsafeMutableRawPointer?, _ nbyte: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, buf, nbyte) }
#endif
  return read(fd, buf, nbyte)
}

// pread
internal func system_pread(
  _ fd: Int32, _ buf: UnsafeMutableRawPointer?, _ nbyte: Int, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, buf, nbyte, offset) }
#endif
#if os(Android)
  var zero = UInt8.zero
  return withUnsafeMutablePointer(to: &zero) {
    // this pread has a non-nullable `buf` pointer
    pread(fd, buf ?? UnsafeMutableRawPointer($0), nbyte, offset)
  }
#else
  return pread(fd, buf, nbyte, offset)
#endif
}

// lseek
internal func system_lseek(
  _ fd: Int32, _ off: off_t, _ whence: Int32
) -> off_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockOffT(fd, off, whence) }
#endif
  return lseek(fd, off, whence)
}

// write
internal func system_write(
  _ fd: Int32, _ buf: UnsafeRawPointer?, _ nbyte: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, buf, nbyte) }
#endif
  return write(fd, buf, nbyte)
}

// pwrite
internal func system_pwrite(
  _ fd: Int32, _ buf: UnsafeRawPointer?, _ nbyte: Int, _ offset: off_t
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd, buf, nbyte, offset) }
#endif
#if os(Android)
  var zero = UInt8.zero
  return withUnsafeMutablePointer(to: &zero) {
    // this pwrite has a non-nullable `buf` pointer
    pwrite(fd, buf ?? UnsafeRawPointer($0), nbyte, offset)
  }
#else
  return pwrite(fd, buf, nbyte, offset)
#endif
}

#if !os(WASI)
internal func system_dup(_ fd: Int32) -> Int32 {
  #if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
  #endif
  return dup(fd)
}

internal func system_dup2(_ fd: Int32, _ fd2: Int32) -> Int32 {
  #if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, fd2) }
  #endif
  return dup2(fd, fd2)
}

@available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
internal func system_dup3(_ fd: Int32, _ fd2: Int32, _ oflag: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, fd2, oflag) }
#endif
  return csystem_posix_dup3(fd, fd2, oflag)
}
#endif // !os(WASI)

#if !os(WASI)
internal func system_pipe(_ fds: UnsafeMutablePointer<Int32>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fds) }
#endif
  return pipe(fds)
}

@available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
internal func system_pipe2(_ fds: UnsafeMutablePointer<Int32>, _ oflag: Int32) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fds, oflag) }
#endif
  return csystem_posix_pipe2(fds, oflag)
}
#endif // !os(WASI)

internal func system_ftruncate(_ fd: Int32, _ length: off_t) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, length) }
#endif
  return ftruncate(fd, length)
}

#if !os(Windows)
internal func system_fsync(_ fd: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return fsync(fd)
}
#endif // !os(Windows)

#if !os(Windows) && !SYSTEM_PACKAGE_DARWIN
internal func system_fdatasync(_ fd: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return fdatasync(fd)
}
#endif // !os(Windows) && !SYSTEM_PACKAGE_DARWIN

#if !os(Windows) && !os(WASI)
internal func system_fchmod(_ fd: Int32, _ mode: CInterop.Mode) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, mode) }
#endif
  return fchmod(fd, mode)
}

internal func system_fchown(_ fd: Int32, _ owner: uid_t, _ group: gid_t) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, owner, group) }
#endif
  return fchown(fd, owner, group)
}
#endif // !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
internal func system_fchflags(_ fd: Int32, _ flags: UInt32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, flags) }
#endif
  // The flags parameter is `unsigned long` on FreeBSD.
  return fchflags(fd, numericCast(flags))
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if !os(Windows)
internal func system_fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, cmd) }
#endif
  return fcntl(fd, cmd)
}

internal func system_fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, cmd, value) }
#endif
  return fcntl(fd, cmd, value)
}
#endif // !os(Windows)

// These return an error number rather than setting errno.
#if os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
internal func system_posix_fallocate(
  _ fd: Int32, _ offset: off_t, _ length: off_t
) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(fd, offset, length) }
#endif
  return posix_fallocate(fd, offset, length)
}

internal func system_posix_fadvise(
  _ fd: Int32, _ offset: off_t, _ length: off_t, _ advice: Int32
) -> Int32 {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(fd, offset, length, advice) }
#endif
  return posix_fadvise(fd, offset, length, advice)
}
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(WASI)

internal func system_mkdir(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, mode) }
#endif
  return mkdir(path, mode)
}

internal func system_rmdir(
    _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path) }
#endif
  return rmdir(path)
}

#if SYSTEM_PACKAGE_DARWIN
internal let SYSTEM_CS_DARWIN_USER_TEMP_DIR = _CS_DARWIN_USER_TEMP_DIR

internal func system_confstr(
  _ name: CInt,
  _ buf: UnsafeMutablePointer<CInterop.PlatformChar>,
  _ len: Int
) -> Int {
  return confstr(name, buf, len)
}
#endif // SYSTEM_PACKAGE_DARWIN

#if !os(Windows)
internal let SYSTEM_AT_REMOVE_DIR = AT_REMOVEDIR
#if os(WASI)
internal let SYSTEM_DT_DIR = _getConst_DT_DIR()
internal typealias system_dirent = _system_dirent
#else
internal let SYSTEM_DT_DIR = DT_DIR
internal typealias system_dirent = dirent
#endif
#if os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD) || os(WASI)
internal typealias system_DIRPtr = OpaquePointer
#else
internal typealias system_DIRPtr = UnsafeMutablePointer<DIR>
#endif

internal func system_unlinkat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), flag)
  }
#endif
return unlinkat(fd, path, flag)
}

internal func system_fdopendir(
  _ fd: CInt
) -> system_DIRPtr? {
  return fdopendir(fd)
}

internal func system_readdir(
  _ dir: system_DIRPtr
) -> UnsafeMutablePointer<system_dirent>? {
  #if os(WASI)
  return _system_dirent_from_wasi_dirent(readdir(dir))
  #else
  return readdir(dir)
  #endif
}

internal func system_rewinddir(
  _ dir: system_DIRPtr
) {
  return rewinddir(dir)
}

internal func system_closedir(
  _ dir: system_DIRPtr
) -> CInt {
  return closedir(dir)
}

internal func system_openat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ oflag: Int32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), oflag)
  }
#endif
  return openat(fd, path, oflag)
}

internal func system_openat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ oflag: Int32,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), oflag, mode)
  }
#endif
  return openat(fd, path, oflag, mode)
}
internal func system_mkdirat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), mode)
  }
#endif
  return mkdirat(fd, path, mode)
}

internal func system_unlink(
  _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path) }
#endif
  return unlink(path)
}

internal func system_rename(
  _ old: UnsafePointer<CInterop.PlatformChar>,
  _ new: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: old, String(_errorCorrectingPlatformString: new))
  }
#endif
  return rename(old, new)
}

internal func system_renameat(
  _ oldFD: CInt,
  _ old: UnsafePointer<CInterop.PlatformChar>,
  _ newFD: CInt,
  _ new: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      oldFD, String(_errorCorrectingPlatformString: old),
      newFD, String(_errorCorrectingPlatformString: new))
  }
#endif
  return renameat(oldFD, old, newFD, new)
}

#if SYSTEM_PACKAGE_DARWIN
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_renamex_np(
  _ old: UnsafePointer<CInterop.PlatformChar>,
  _ new: UnsafePointer<CInterop.PlatformChar>,
  _ flags: CUnsignedInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: old, String(_errorCorrectingPlatformString: new), flags)
  }
#endif
  return renamex_np(old, new, flags)
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal func system_renameatx_np(
  _ oldFD: CInt,
  _ old: UnsafePointer<CInterop.PlatformChar>,
  _ newFD: CInt,
  _ new: UnsafePointer<CInterop.PlatformChar>,
  _ flags: CUnsignedInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      oldFD, String(_errorCorrectingPlatformString: old),
      newFD, String(_errorCorrectingPlatformString: new), flags)
  }
#endif
  return renameatx_np(oldFD, old, newFD, new, flags)
}
#elseif os(Linux) || os(Android)
internal func system_renameat2(
  _ oldFD: CInt,
  _ old: UnsafePointer<CInterop.PlatformChar>,
  _ newFD: CInt,
  _ new: UnsafePointer<CInterop.PlatformChar>,
  _ flags: CUnsignedInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      oldFD, String(_errorCorrectingPlatformString: old),
      newFD, String(_errorCorrectingPlatformString: new), flags)
  }
#endif
  return csystem_renameat2(oldFD, old, newFD, new, flags)
}
#endif

internal func system_link(
  _ existing: UnsafePointer<CInterop.PlatformChar>,
  _ new: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: existing, String(_errorCorrectingPlatformString: new))
  }
#endif
  return link(existing, new)
}

internal func system_linkat(
  _ existingFD: CInt,
  _ existing: UnsafePointer<CInterop.PlatformChar>,
  _ newFD: CInt,
  _ new: UnsafePointer<CInterop.PlatformChar>,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      existingFD, String(_errorCorrectingPlatformString: existing),
      newFD, String(_errorCorrectingPlatformString: new), flag)
  }
#endif
  return linkat(existingFD, existing, newFD, new, flag)
}

internal func system_symlink(
  _ target: UnsafePointer<CInterop.PlatformChar>,
  _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: target, String(_errorCorrectingPlatformString: path))
  }
#endif
  return symlink(target, path)
}

internal func system_symlinkat(
  _ target: UnsafePointer<CInterop.PlatformChar>,
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(path: target, fd, String(_errorCorrectingPlatformString: path))
  }
#endif
  return symlinkat(target, fd, path)
}

internal func system_readlink(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ buffer: UnsafeMutablePointer<CInterop.PlatformChar>,
  _ size: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(path: path, buffer, size) }
#endif
  return readlink(path, buffer, size)
}

internal func system_readlinkat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ buffer: UnsafeMutablePointer<CInterop.PlatformChar>,
  _ size: Int
) -> Int {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockInt(fd, String(_errorCorrectingPlatformString: path), buffer, size)
  }
#endif
  return readlinkat(fd, path, buffer, size)
}

internal func system_truncate(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ length: off_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, length) }
#endif
  return truncate(path, length)
}

internal func system_access(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, mode) }
#endif
  return access(path, mode)
}

internal func system_faccessat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInt,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), mode, flag)
  }
#endif
  return faccessat(fd, path, mode, flag)
}

@available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
internal func system_futimens(
  _ fd: CInt,
  _ times: UnsafePointer<timespec>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      fd, times[0].tv_sec, times[0].tv_nsec, times[1].tv_sec, times[1].tv_nsec)
  }
#endif
  return futimens(fd, times)
}

@available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
internal func system_utimensat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ times: UnsafePointer<timespec>,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(
      fd, String(_errorCorrectingPlatformString: path),
      times[0].tv_sec, times[0].tv_nsec, times[1].tv_sec, times[1].tv_nsec, flag)
  }
#endif
  return utimensat(fd, path, times, flag)
}

internal func system_getcwd(
  _ buffer: UnsafeMutablePointer<CInterop.PlatformChar>,
  _ size: Int
) -> UnsafeMutablePointer<CInterop.PlatformChar>? {
#if ENABLE_MOCKING
  if mockingEnabled {
    guard _mock(buffer, size) == 0 else { return nil }
    buffer.initialize(to: 0)
    return buffer
  }
#endif
  return getcwd(buffer, size)
}

internal func system_chdir(_ path: UnsafePointer<CInterop.PlatformChar>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path) }
#endif
  return chdir(path)
}

#if !os(WASI)
internal func system_fchdir(_ fd: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd) }
#endif
  return fchdir(fd)
}
#endif // !os(WASI)

#if !os(WASI)
internal func system_chmod(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, mode) }
#endif
  return chmod(path, mode)
}

internal func system_lchmod(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, mode) }
#endif
#if os(Android) || os(OpenBSD)
  // Not every Android API level, nor OpenBSD, declares lchmod.
  // This is its POSIX spelling.
  return fchmodat(AT_FDCWD, path, mode, AT_SYMLINK_NOFOLLOW)
#else
  return lchmod(path, mode)
#endif
}

internal func system_fchmodat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), mode, flag)
  }
#endif
  return fchmodat(fd, path, mode, flag)
}

internal func system_chown(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ owner: uid_t,
  _ group: gid_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, owner, group) }
#endif
  return chown(path, owner, group)
}

internal func system_lchown(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ owner: uid_t,
  _ group: gid_t
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, owner, group) }
#endif
  return lchown(path, owner, group)
}

internal func system_fchownat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ owner: uid_t,
  _ group: gid_t,
  _ flag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), owner, group, flag)
  }
#endif
  return fchownat(fd, path, owner, group, flag)
}

internal func system_mkfifo(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, mode) }
#endif
  return mkfifo(path, mode)
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
internal func system_mkfifoat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ mode: CInterop.Mode
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), mode)
  }
#endif
  return mkfifoat(fd, path, mode)
}
#endif // !os(WASI)

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
internal func system_chflags(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, flags) }
#endif
  // The flags parameter is `unsigned long` on FreeBSD.
  return chflags(path, numericCast(flags))
}

internal func system_lchflags(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path, flags) }
#endif
#if os(OpenBSD)
  // OpenBSD has no lchflags. This is its equivalent.
  return chflagsat(AT_FDCWD, path, flags, AT_SYMLINK_NOFOLLOW)
#else
  // The flags parameter is `unsigned long` on FreeBSD.
  return lchflags(path, numericCast(flags))
#endif
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if os(FreeBSD) || os(OpenBSD)
internal func system_chflagsat(
  _ fd: CInt,
  _ path: UnsafePointer<CInterop.PlatformChar>,
  _ flags: UInt32,
  _ atFlag: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mock(fd, String(_errorCorrectingPlatformString: path), flags, atFlag)
  }
#endif
  // The flags parameter is `unsigned long` on FreeBSD.
  return chflagsat(fd, path, numericCast(flags), atFlag)
}
#endif // os(FreeBSD) || os(OpenBSD)
#endif // !os(Windows)

#if !os(WASI) // WASI has no umask
internal func system_umask(
  _ mode: CInterop.Mode
) -> CInterop.Mode {
  return umask(mode)
}
#endif // !os(WASI)

// Not mockable: these return an ID and can't fail.
#if !os(Windows) && !os(WASI)
internal func system_getuid() -> CInterop.UserID {
  return getuid()
}

internal func system_geteuid() -> CInterop.UserID {
  return geteuid()
}

internal func system_getgid() -> CInterop.GroupID {
  return getgid()
}

internal func system_getegid() -> CInterop.GroupID {
  return getegid()
}
#endif // !os(Windows) && !os(WASI)

// These return an error number rather than setting errno.
#if !os(Windows) && !os(WASI)
internal func system_getpwuid_r(
  _ uid: uid_t,
  _ entry: UnsafeMutablePointer<passwd>,
  _ buffer: UnsafeMutablePointer<CChar>,
  _ size: Int,
  _ result: UnsafeMutablePointer<UnsafeMutablePointer<passwd>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(uid, entry, buffer, size, result) }
#endif
  return getpwuid_r(uid, entry, buffer, size, result)
}

internal func system_getpwnam_r(
  _ name: UnsafePointer<CChar>,
  _ entry: UnsafeMutablePointer<passwd>,
  _ buffer: UnsafeMutablePointer<CChar>,
  _ size: Int,
  _ result: UnsafeMutablePointer<UnsafeMutablePointer<passwd>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(path: name, entry, buffer, size, result)
  }
#endif
  return getpwnam_r(name, entry, buffer, size, result)
}

internal func system_getgrgid_r(
  _ gid: gid_t,
  _ entry: UnsafeMutablePointer<group>,
  _ buffer: UnsafeMutablePointer<CChar>,
  _ size: Int,
  _ result: UnsafeMutablePointer<UnsafeMutablePointer<group>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(gid, entry, buffer, size, result) }
#endif
  return getgrgid_r(gid, entry, buffer, size, result)
}

internal func system_getgrnam_r(
  _ name: UnsafePointer<CChar>,
  _ entry: UnsafeMutablePointer<group>,
  _ buffer: UnsafeMutablePointer<CChar>,
  _ size: Int,
  _ result: UnsafeMutablePointer<UnsafeMutablePointer<group>?>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(path: name, entry, buffer, size, result)
  }
#endif
  return getgrnam_r(name, entry, buffer, size, result)
}
#endif // !os(Windows) && !os(WASI)

internal func system_getenv(
  _ name: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return getenv(name)
}
