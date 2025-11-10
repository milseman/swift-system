# Swift API Extraction Tool

A Swift analysis tool that extracts public API declarations from Swift packages, providing Claude Code with detailed information about the codebase including documentation and precise file locations.

## Features

- **Comprehensive API Extraction**: Extracts all public declarations including:
  - Functions with full signatures
  - Structs, classes, protocols, enums
  - Properties and type aliases

- **Documentation Preservation**: Captures doc comments (both `///` and `/** */` styles)

- **Precise Locations**: Provides exact file paths, line numbers, and columns for every declaration

- **Flexible Output**: Supports both JSON (for programmatic use) and Markdown (for human reading)

## Usage

### From Command Line

```bash
# Build the tool
swift build

# Extract API from current directory (JSON format)
.build/debug/SwiftAnalysisTool

# Extract API with markdown output
.build/debug/SwiftAnalysisTool --format markdown

# Extract from specific target
.build/debug/SwiftAnalysisTool --target MyTarget

# Include internal declarations
.build/debug/SwiftAnalysisTool --access-level internal
```

### From Claude Code

The tool is designed to integrate with Claude Code workflows:

```bash
# Run from a Swift package directory
cd /path/to/swift/package
/path/to/swift-analysis/extract-api.sh
```

## Output Format

### JSON Output

The JSON output includes:
- `packageName`: Name of the Swift package
- `totalDeclarations`: Count of extracted declarations
- `declarations`: Array of API declarations, each containing:
  - `name`: Declaration name
  - `kind`: Type (function, struct, class, protocol, enum, property, typealias)
  - `accessLevel`: Access modifier (public, internal, private)
  - `signature`: Complete Swift code for the declaration
  - `documentation`: Doc comment text (if present)
  - `location`: Precise source location with file path, line, and column

### Example JSON Entry

```json
{
  "name": "closeAfter",
  "kind": "function",
  "accessLevel": "public",
  "signature": "public func closeAfter<R>(_ body: () throws -> R) throws -> R { ... }",
  "documentation": "Runs a closure and then closes the file descriptor...",
  "location": {
    "file": "/path/to/file.swift",
    "line": 23,
    "column": 3
  }
}
```

## Command Options

**Options:**
- `--target <name>`: Analyze specific target (default: all non-test targets)
- `--access-level <level>`: Minimum access level (public, internal, all; default: public)
- `--format <format>`: Output format (json, markdown; default: json)

## Use Cases for Claude Code

This tool enables Claude Code to:

1. **Understand APIs**: Get complete context about public interfaces
2. **Navigate Code**: Use precise locations (file:line:column) to read and edit
3. **Preserve Documentation**: Maintain existing doc comments when refactoring
4. **Validate Changes**: Ensure public API contracts are maintained
5. **Generate Documentation**: Create API references from extracted data

## Example Workflow

```bash
# 1. Extract API from your Swift package
cd ~/my-swift-project
~/.claude/skills/swift-analysis/extract-api.sh > api.json

# 2. Provide to Claude Code
# Claude Code can now see all public declarations with their:
# - Complete signatures
# - Documentation
# - Exact file locations for editing
```

## Building from Source

```bash
swift build -c release
```

The tool requires:
- Swift 6.0 or later
- swift-syntax 509.0.0+
- swift-argument-parser 1.0.0+
