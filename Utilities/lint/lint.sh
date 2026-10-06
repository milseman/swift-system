#!/bin/bash
# Convention checks for swift-system and its adopters. See README.md in this
# directory.
#
#   Utilities/lint/lint.sh                          # every check
#   Utilities/lint/lint.sh cmake api                # some
#   Utilities/lint/lint.sh markers --clone ../adopters/swift-nio
#   Utilities/lint/lint.sh conditionals --clone ../adopters/swift-nio --base main
#   Utilities/lint/lint.sh --rules                  # the rules and their levels
#
# Findings are `file:line: rule: message`; the exit status is 1 when one is
# an error, 2 when a check couldn't run. Nothing tracked is written; scratch
# goes under .build/lint.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export GIT_NO_LAZY_FETCH=1
exec python3 "$(cd "$(dirname "$0")" && pwd -P)/scripts/lint.py" "$@"
