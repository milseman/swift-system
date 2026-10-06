#!/bin/bash
# The state of every lane: swift-system's and swift-system-examples'
# worktrees, the adopter clones and worktrees, and the adopter workspaces,
# read-only. See README.md in this directory.
#
#   Utilities/lanes/lanes.sh                 # a Markdown table
#   Utilities/lanes/lanes.sh --json          # everything, as JSON
#   Utilities/lanes/lanes.sh --only 'tools-*' 'adopters/swift-nio'
#   Utilities/lanes/lanes.sh --root ~/development/base_dir/system-next
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1
exec python3 "$(cd "$(dirname "$0")" && pwd -P)/scripts/lanes.py" "$@"
