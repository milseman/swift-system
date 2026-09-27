# The toolchain's packages

One package file per Swift package that swift's `update-checkout` clones for the `main` branch scheme and whose library code imports Darwin, other than the four audited adopters (swift-nio, swift-foundation, swiftpm and swift-subprocess keep their files in `..`, and the ecosystem run points them at the ecosystem's clones) and swift-system itself.

`Utilities/adopter-coverage/ecosystem.sh survey` generates a file for each package that doesn't have one; it never rewrites an existing file, so a hand edit stays. The keys are the ones in `../README.md`. Every generated file says:

- `checkout = ../ecosystem/<name>`: the shallow clone `ecosystem.sh clone` made, at the scheme's ref.
- `in-all = no`: `check.sh` with no arguments runs only the audited adopters.
- `strict = no`: the mapping has no entries for these packages, so the interfaces it doesn't name get entries of their own, derived, instead of failing the check.
- `build-targets = :libraries`: only the library targets are built and audited.

Edit a file only to say what the generator can't know: C targets that exist to reach the OS (`shim-targets`), test-support targets (`skip.<Target>`), the platforms the package supports, or build settings.
