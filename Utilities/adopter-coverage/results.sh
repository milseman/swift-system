#!/bin/bash
# The results store: list the stored runs, compare two, repeat or verify
# one, and measure a migration branch against its base. See README.md.
#
#   Utilities/adopter-coverage/results.sh list
#   Utilities/adopter-coverage/results.sh show RUN
#   Utilities/adopter-coverage/results.sh delta RUN_A RUN_B [--package nio ...] [--markdown OUT.md]
#   Utilities/adopter-coverage/results.sh rerun RUN            # the same commits, with this tool
#   Utilities/adopter-coverage/results.sh verify RUN [--rebuild]
#                                    # the same commits, with the tool the run recorded; compares the results
#   Utilities/adopter-coverage/results.sh migration NAME PATH REF [BASE]
#                                    # REF and its base (default: the merge base with the checkout's
#                                    # default branch), against this System commit (SYSTEM_REF)
#
# RUN is a run id or a prefix of one, `latest`, or a System commit (the
# latest run of it). ADOPTER_COVERAGE_RESULTS names the store, as for
# check.sh.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

TOOL="$(cd "$(dirname "$0")" && pwd -P)"
S="$TOOL/scripts"
. "$S/common.sh"
REPO="$(git -C "$TOOL" rev-parse --show-toplevel)"
RESULTS="$(abspath "${ADOPTER_COVERAGE_RESULTS:-$(dirname "$REPO")/coverage-results}")"
export ADOPTER_COVERAGE_RESULTS="$RESULTS"

cmd="${1:-}"
[ -n "$cmd" ] || { sed -n '2,17p' "$0"; exit 1; }
shift

run_specs() {
  # The run's System commit, then its packages' specs, pinned to commits.
  python3 "$S/results.py" specs "$1" --results "$RESULTS"
}

case "$cmd" in
  list|show|delta)
    exec python3 "$S/results.py" "$cmd" "$@" --results "$RESULTS" ;;
  rerun)
    [ $# -eq 1 ] || fail "usage: results.sh rerun RUN"
    { read -r system; read -r specs; } < <(run_specs "$1")
    # shellcheck disable=SC2086
    SYSTEM_REF="$system" exec "$TOOL/check.sh" $specs ;;
  verify)
    [ $# -ge 1 ] || fail "usage: results.sh verify RUN [--rebuild]"
    run="$1"
    rebuild="${2:-}"
    dir="$(python3 "$S/results.py" resolve "$run" --results "$RESULTS")"
    tool_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tool"])' "$dir/run.json")"
    tool_commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolCommit"])' "$dir/run.json")"
    case "$tool_id" in *-dirty-*) fail "run $(basename "$dir") was made by a tool with uncommitted changes, which can't be recreated" ;; esac
    { read -r system; read -r specs; } < <(run_specs "$run")
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/adopter-coverage-verify.XXXXXX")"
    log "verifying run $(basename "$dir"): the tool at ${tool_commit:0:10} ($tool_id), in $tmp"
    git -C "$REPO" archive "$tool_commit" -- Utilities/adopter-coverage Utilities/api-delta | tar -x -C "$tmp"
    status=0
    # shellcheck disable=SC2086
    env ADOPTER_COVERAGE_REPO="$REPO" ADOPTER_COVERAGE_TOOL_ID="$tool_id" ADOPTER_COVERAGE_TOOL_COMMIT="$tool_commit" \
      SYSTEM_REF="$system" ADOPTER_COVERAGE_VERIFY_DIR="$tmp/verify" ADOPTER_COVERAGE_WORK="$tmp/work" \
      ADOPTER_COVERAGE_OUT="$tmp/out" ${rebuild:+ADOPTER_COVERAGE_REBUILD=1} \
      "$tmp/Utilities/adopter-coverage/check.sh" $specs > "$tmp/verify.log" 2>&1 || status=$?
    [ "$status" -le 2 ] || fail "the verification run failed" "$tmp/verify.log"
    bad=0
    for p in $(python3 -c 'import json,sys; print(" ".join(p["name"] + ":" + p["result"] for p in json.load(open(sys.argv[1]))["packages"]))' "$dir/run.json"); do
      name="${p%%:*}"
      echo
      echo "$name:"
      python3 "$S/results.py" compare-results "$RESULTS/${p#*:}" "$tmp/verify/$name" || bad=1
    done
    echo
    if [ "$bad" = 0 ]; then echo "verified: every package's result reproduced"; else echo "not reproduced; see above (log: $tmp/verify.log)"; fi
    exit "$bad" ;;
  migration)
    [ $# -ge 3 ] || fail "usage: results.sh migration NAME PATH REF [BASE]"
    name="$1"; path="$(abspath "$2")"; ref="$3"; base="${4:-}"
    if [ -z "$base" ]; then
      default="$(git -C "$path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo main)"
      base="$(git -C "$path" merge-base "$ref" "$default")" || fail "no merge base of $ref and $default in $path"
    fi
    before="$(git -C "$path" rev-parse "$base^{commit}")"
    after="$(git -C "$path" rev-parse "$ref^{commit}")"
    log "migration $name: $base (${before:0:10}) -> $ref (${after:0:10})"
    s1=0; s2=0
    "$TOOL/check.sh" "$name=$path@$before" || s1=$?
    [ "$s1" = 0 ] || [ "$s1" = 2 ] || fail "the run of $base failed"
    a="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$(abspath "${ADOPTER_COVERAGE_OUT:-$REPO/.build/adopter-coverage}")/run.json")"
    "$TOOL/check.sh" "$name=$path@$after" || s2=$?
    [ "$s2" = 0 ] || [ "$s2" = 2 ] || fail "the run of $ref failed"
    b="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$(abspath "${ADOPTER_COVERAGE_OUT:-$REPO/.build/adopter-coverage}")/run.json")"
    exec python3 "$S/results.py" delta "$a" "$b" --results "$RESULTS" \
      --markdown "$RESULTS/runs/$b/migration-from-$a.md" ;;
  *)
    fail "unknown command $cmd; see $0" ;;
esac
