# Popular packages beyond the toolchain

One package file per package in `../../popular.tsv` whose library code imports Darwin: the swift-server and swiftlang ecosystems' most used packages that swift's `update-checkout` doesn't clone, and the libraries they're built on (NIO's TLS, HTTP/2, SSH and transport services; gRPC; the web frameworks and their database client).

`Utilities/adopter-coverage/ecosystem.sh --popular survey` generates a file for each package that doesn't have one; it never rewrites an existing file, so a hand edit stays. The keys are the ones in `../README.md`. Every generated file says:

- `checkout = ../ecosystem/<name>`: the shallow clone `ecosystem.sh --popular clone` made, at popular.tsv's ref.
- `in-all = no`: `check.sh` with no arguments runs only the audited adopters.
- `strict = no`: the mapping has no entries for these packages, so the interfaces it doesn't name get entries of their own, derived, instead of failing the check.
- `build-targets = :libraries`: only the library targets are built and audited.

To add a package, add a line to popular.tsv (name, GitHub repository, ref, and why it's there) and run `clone` and `survey` again. Edit a file only to say what the generator can't know: C targets that exist to reach the OS (`shim-targets`), test-support targets (`skip.<Target>`), the platforms the package supports, or build settings.
