#!/bin/bash
# The compiler's own list of what a package still takes from the platform C
# modules. See README.md in this directory.
#
#   Utilities/import-probe/probe.sh ../adopters/swift-log                 # macOS, newest migration branch
#   Utilities/import-probe/probe.sh --linux ../adopters-unix/swift-nio    # Linux, in a container
#   Utilities/import-probe/probe.sh --branch main ../adopters/swift-log
#   Utilities/import-probe/probe.sh --targets NIOCore --keep ../adopters-unix/swift-nio
#   Utilities/import-probe/probe.sh --nested ../adopters/swift-nio-imap     # and its nested packages
#   Utilities/import-probe/probe.sh --linux --own-modules ../adopters/swift-nio-ssl
#   Utilities/import-probe/probe.sh --linux --reexport --branch main ../adopters/swift-nio-extras
#
# Only the clones' commits are read, with `git archive`; everything is built
# in a scratch directory under this worktree's .build/import-probe, deleted
# when each package is done (--keep keeps it). Nothing is fetched for the
# package's own dependencies; SwiftPM resolves a remote dependency's own
# (README.md, step 2).
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1
exec python3 "$(cd "$(dirname "$0")" && pwd -P)/scripts/probe.py" "$@"
