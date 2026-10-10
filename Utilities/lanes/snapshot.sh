#!/bin/bash
# A snapshot of every lane, the integration branches, the Linux logs, lint
# and the environment, for the coordinator's check-ins, read-only. Writes
# each section to DIR as JSON and Markdown and prints an index. See
# README.md and CHECKS.md in this directory.
#
#   Utilities/lanes/snapshot.sh --out /tmp/snap                 # every section
#   Utilities/lanes/snapshot.sh --out /tmp/snap --since '2 days ago'
#   Utilities/lanes/snapshot.sh --out /tmp/snap --section lanes # one section, printed
#   Utilities/lanes/snapshot.sh --out /tmp/snap --section activity --only adopters/swift-nio
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1
export SNAPSHOT_PROG="$0"
exec python3 "$(cd "$(dirname "$0")" && pwd -P)/scripts/snapshot.py" "$@"
