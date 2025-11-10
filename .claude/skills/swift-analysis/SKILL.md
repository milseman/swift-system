# Swift API Extraction

Extract public API declarations from Swift packages with documentation and precise locations.

## Usage

Run from any Swift package directory:
```bash
./extract-api.sh
```

## Output

Returns JSON with all public declarations:
- Function signatures
- Types (structs, classes, protocols, enums)
- Properties and typealiases
- Doc comments
- Exact file locations (file:line:column)

## Options

- `--target <name>` - Analyze specific target
- `--access-level <level>` - Minimum access (public/internal/all)
- `--format <format>` - Output format (json/markdown)

## Use Cases

- API audits and reviews
- Documentation validation
- Public interface analysis
- Breaking change detection
