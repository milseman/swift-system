# Package files

One file per adopter the tool audits, named for the package: `check.sh nio` reads `nio.ini`. Everything the tool needs to know about a package that it can't learn from the package's manifest or its build is here. What System covers is in `../mapping.ini`, which all packages share.

Each file has one section, `[package]`. Lists are separated by whitespace, except `wrapper-files`, which takes one glob per line.

| Key | | |
|---|---|---|
| `title` | required | The package's name in reports: `swift-nio`. |
| `name` | required | The short name prose uses: `NIO`. |
| `variable` | | The prefix of the package's environment variables: `NIO` gives `NIO_PATH`, `NIO_REF` and `NIO_SWIFT_EXEC`. Defaults to the file name in capitals. |
| `checkout` | | The checkout, relative to this repository's top directory: `../swift-nio`. `<variable>_PATH` overrides it. |
| `in-all` | | `no` leaves the package out of `check.sh` with no arguments. Defaults to `yes`. |
| `shim-targets` | | C targets that exist to reach the OS. Their declarations are interfaces of their own, and the gap estimate counts their definitions. The package's other C targets are implementations: what they call in the C library counts, but their own functions don't. |
| `skip-targets` | | Regular targets that aren't library code, such as test support. `skip.<Target> = reason` skips one and says why. Test, executable, plugin, macro and snippet targets are always skipped; the report lists every skipped target. |
| `platforms` | | The platforms the package supports, of Darwin, Linux, Musl, Android, FreeBSD, OpenBSD, WASI and Windows. Defaults to all of them. Code on the others doesn't count. |
| `build-targets` | | Build only these targets, one `swift build --target` each, instead of everything `swift build` builds. `:libraries` means the library targets no other library target depends on: every library target, and no executable. |
| `build-flags` | | Extra arguments for `swift build` and `swift package`. |
| `unset-env` | | Environment variables to unset for the build, such as switches the manifest reads. |
| `build-hint` | | What to print when the build fails, such as which compiler the package needs. |
| `false-flags` | | Compilation flags only builds the tool doesn't model define, such as Foundation's FOUNDATION_FRAMEWORK: false everywhere, and the report counts the lines they hide. |
| `wrapper-files` | | The package's syscall layer: files whose functions exist only to reach the OS, one glob per line. The gap estimate counts the thin wrapper functions in them. |
| `twin-targets` | | Targets that are copies of each other, whose code the gap estimate counts twice; the report says so. |
| `through` | | Dependency packages (checkout names, `swift-tools-support-core`) whose OS use on the package's behalf the report dwells on. Every dependency is measured; these get their most used symbols listed. |
