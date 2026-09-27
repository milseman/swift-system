#!/bin/bash
# The toolchain's Swift packages that import Darwin: clone them, audit them
# with check.sh, and write the ecosystem report. See README.md.
#
#   Utilities/adopter-coverage/ecosystem.sh clone      # ../ecosystem: swift (sparse) and the main scheme's packages
#   Utilities/adopter-coverage/ecosystem.sh survey     # which import Darwin; package files for them
#   Utilities/adopter-coverage/ecosystem.sh run        # check.sh over all of them (SYSTEM_REF as for check.sh)
#   Utilities/adopter-coverage/ecosystem.sh report [RUN]   # the ecosystem report for a run (default: the latest
#                                                           # ecosystem run)
#
# ADOPTER_COVERAGE_ECOSYSTEM names the clones' directory (default: ecosystem
# next to this worktree). Clones are shallow and made once; the scheme's
# refs decide what they check out.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
. "$S/common.sh"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
ECO="$(abspath "${ADOPTER_COVERAGE_ECOSYSTEM:-$(dirname "$REPO")/ecosystem}")"
RESULTS="$(abspath "${ADOPTER_COVERAGE_RESULTS:-$(dirname "$REPO")/coverage-results}")"

cmd="${1:-}"
[ -n "$cmd" ] || { sed -n '2,13p' "$0"; exit 1; }
shift

case "$cmd" in
  clone)
    mkdir -p "$ECO"
    if [ ! -d "$ECO/swift/.git" ]; then
      log "cloning swiftlang/swift (sparse: update-checkout's config, SwiftShims, the stdlib and runtime)"
      git clone --quiet --filter=blob:none --no-checkout --depth 1 https://github.com/swiftlang/swift.git "$ECO/swift"
      git -C "$ECO/swift" sparse-checkout init --cone
      git -C "$ECO/swift" sparse-checkout set utils/update_checkout stdlib/public/SwiftShims stdlib/public/core \
        stdlib/public/runtime stdlib/public/stubs stdlib/public/Concurrency stdlib/public/Synchronization \
        stdlib/public/Platform stdlib/public/threading stdlib/include lib/Threading include/swift/Threading
      git -C "$ECO/swift" checkout --quiet
    fi
    python3 "$S/ecosystem.py" clone "$ECO" ;;
  survey)
    python3 "$S/ecosystem.py" survey "$ECO" "$ECO/survey.json"
    python3 "$S/ecosystem.py" packages "$ECO/survey.json" "$TOOL/packages" ;;
  run)
    [ -f "$ECO/survey.json" ] || fail "run \`ecosystem.sh survey\` first"
    # shellcheck disable=SC2046
    exec "$TOOL/check.sh" $(python3 "$S/ecosystem.py" specs "$ECO/survey.json") ;;
  report)
    run="${1:-}"
    if [ -z "$run" ]; then
      run="$(python3 "$S/ecosystem.py" latest-run "$ECO/survey.json" "$RESULTS")" \
        || fail "no stored run covers the ecosystem's packages; run \`ecosystem.sh run\`"
    fi
    dir="$(python3 "$S/results.py" resolve "$run" --results "$RESULTS")"
    sys="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["systemCommit"])' "$dir/run.json")"
    derived="$(ls -d "$RESULTS/systems/$sys"/*/derived.json | head -n 1)"
    vocab="$(ls -t "$RESULTS"/vocab/*.json.gz | head -n 1)"
    python3 "$S/swiftshims.py" "$ECO/swift" "$vocab" "$derived" "$dir/swiftshims.json"
    python3 "$S/ecosystem.py" report "$dir" "$RESULTS" "$ECO/survey.json" "$TOOL/mapping.ini" "$dir/swiftshims.json" \
      "$dir/ECOSYSTEM.md"
    echo "$dir/ECOSYSTEM.md" ;;
  *)
    fail "unknown command $cmd; see $0" ;;
esac
