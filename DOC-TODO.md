# Documentation TODO

This file tracks documentation that should be added to the repository.

## Architecture Documentation Needed

### Mocking System
- **Where**: Could be `Documentation/Testing.md` or inline code documentation
- **What to document**:
  - How the mocking system works: `ENABLE_MOCKING` define (debug only) → `MockingDriver` (thread-local) → `system_*` wrappers in `Syscalls.swift`
  - Why all syscalls must go through `system_*` wrappers (not direct libc calls)
  - How to write tests using `MockingDriver.withMockingEnabled`
  - The trace system for verifying syscall arguments in tests

### Platform-Specific Code Organization
- **Where**: `Documentation/Contributing.md` or `CONTRIBUTING.md` expansion
- **What to document**:
  - Pattern: Use `#if SYSTEM_PACKAGE_DARWIN` / `#if canImport(Glibc)` / `#if os(Windows)` within files rather than separate platform files
  - When to use `CInterop.swift` for platform type abstraction
  - How platform-specific exclusions work in `Package.swift` (`filesToExclude`, `testsToExclude`)

### io_uring Support (Linux)
- **Where**: `Documentation/IORing.md` or inline documentation in `Sources/System/IORing/IORing.swift`
- **What to document**:
  - Why it requires Swift 6.2+ (lifetime features, `~Copyable`)
  - Why it's excluded from builds on non-Linux platforms (both code conditionals and Package.swift exclusions)
  - How to use the IORing API
  - Performance characteristics vs traditional I/O

### CI and Build Configurations
- **Where**: `Documentation/Development.md` or expansion of `CONTRIBUTING.md`
- **What to document**:
  - What `-DSYSTEM_CI` does (enables strict availability checking)
  - What `-DSYSTEM_ABI_STABLE` does (changes availability to match Darwin ABI-stable version)
  - How to test platform-specific code locally
  - Relationship between `Package.swift` availability macros and OS availability

### SystemString and FilePath Internals
- **Where**: Inline documentation or `Documentation/Architecture.md`
- **What to document**:
  - Why `SystemString` is always null-terminated
  - FilePath normalization behavior (separator handling, Windows backslash conversion)
  - The invariants that must be maintained
  - Relationship between `SystemChar`, `SystemString`, and `FilePath`

## API Documentation Needed

Currently missing or incomplete DocC documentation for:
- Many public APIs in `FileDescriptor`
- `FilePath` component operations
- `FilePermissions` and file system types
- Error handling patterns

Note: Issue #224 mentions docs check is currently disabled in CI.
