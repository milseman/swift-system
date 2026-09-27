# StatFS on Linux, typechecked on macOS

Nothing on this Mac builds for Linux, and StatFS's Linux code differs from its
Darwin code more than most: `StatFS` wraps `statvfs` there rather than
`statfs`, `MountFlags` reads the `ST_*` constants through getters in CSystem,
and `FileSystemType` gets its `f_type` from two CSystem shims. `check-linux.sh`
compiles that code anyway.

It copies SystemPackage's sources to `$TMPDIR/swift-system-statfs-linux`. In
StatFS's files it turns the Darwin and BSD conditions off and the Linux ones
on, so that `CInterop.StatFS` is Darwin's own `statvfs`, which has the same
fields as Linux's in different widths. `LinuxModel/StatFSLinuxModel.h`
declares what Darwin lacks, as `CSystemLinux.h` does. Then it builds the
module for macOS, and compiles StatFS's tests and the `statfs` sample
against it, through SIL. `SampleSupport.swift` stands in for the sample's
helpers from `Sources/Samples/Util.swift`, which imports SystemSockets.

```sh
swift build                        # for the sample's ArgumentParser
Prototype/StatFS/check-linux.sh    # prints each diagnostic; nonzero if any step fails
```

It catches Swift errors: a name, a type, a missing conversion. It can't catch
a difference between Darwin's `statvfs` and a Linux C library's beyond the
field names, or a wrong constant value. The tests do that on Linux, where
`fileSystemTypesMatchProcMounts` checks each magic number against the kernel
for every file system type that the machine has mounted.

It follows `Prototype/Events/check-linux.sh`, which does the same for the
event notification code with a model of the Linux declarations it calls.
