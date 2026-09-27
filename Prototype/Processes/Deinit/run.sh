#!/bin/sh
# Builds the harness once per deinit policy, runs every scenario in its own
# process, and prints a Markdown table of the outcomes. A trap shows as TRAP,
# and a scenario that SIGALRM ends after five seconds as HANG.
# Run from anywhere: ./Prototype/Processes/Deinit/run.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${TMPDIR:-/tmp}/child-deinit
mkdir -p "$out"
policies="KILL WAIT TERMINATE REAP LEAK TRAP"
for policy in $policies; do
  swiftc -Onone -swift-version 6 -suppress-warnings -D "POLICY_$policy" -o "$out/$policy" \
    "$here/OwnedChild.swift" "$here/Scenarios.swift" "$here/main.swift"
done
printf '| scenario | modeled on | kill | wait | terminate | reap | leak | trap |\n'
printf '|---|---|---|---|---|---|---|---|\n'
"$out/KILL" --list | while IFS="$(printf '\t')" read -r name source; do
  row="| $name | $source |"
  for policy in $policies; do
    status=0
    result=$("$out/$policy" "$name" 2>/dev/null) || status=$?
    if [ "$status" -eq 142 ]; then
      result="HANG"
    elif [ "$status" -ne 0 ]; then
      result="TRAP"
    fi
    row="$row $result |"
  done
  printf '%s\n' "$row"
done
