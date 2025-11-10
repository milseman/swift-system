#!/bin/bash

# Extract Swift API - A tool to analyze Swift packages and extract public API
# declarations with documentation and precise locations for Claude Code.
#
# Usage: Run this script from a Swift package directory
#
# The script will:
# 1. Build the swift-analysis tool if not already built
# 2. Extract all public API declarations from the package
# 3. Output JSON with:
#    - Declaration names and types (function, struct, class, etc.)
#    - Full signatures (complete Swift code)
#    - Documentation comments
#    - Precise file locations (path:line:column)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOOL_PATH="$SCRIPT_DIR/.build/debug/SwiftAnalysisTool"

# Build if needed
if [ ! -f "$TOOL_PATH" ]; then
    echo "Building swift-analysis tool..." >&2
    cd "$SCRIPT_DIR"
    swift build -c debug
fi

# Run from the current directory (which should be a Swift package)
"$TOOL_PATH" --format json "$@"
