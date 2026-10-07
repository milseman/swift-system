#!/bin/bash
# The compiler's own list of what a package still takes from the platform C
# modules. See README.md in this directory.
#
#   Utilities/import-probe/probe.sh ../adopters/swift-log                 # macOS, newest migration branch
#   Utilities/import-probe/probe.sh --linux ../adopters-unix/swift-nio    # Linux, in a container
#   Utilities/import-probe/probe.sh --branch main ../adopters/swift-log
#   Utilities/import-probe/probe.sh --targets NIOCore --keep ../adopters-unix/swift-nio
#
# Only the clones' commits are read, with `git archive`; everything is built
# in a scratch directory under this worktree's .build/import-probe, deleted
# when each package is done (--keep keeps it). Nothing is fetched.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1
exec python3 "$(cd "$(dirname "$0")" && pwd -P)/scripts/probe.py" "$@"
