#!/bin/sh
# Builds the harness once per deinit policy, runs every scenario in its own
# process, and prints a Markdown table of the outcomes. A trap shows as TRAP.
# Run from anywhere: ./Prototype/CloseErrors/run.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${TMPDIR:-/tmp}/close-errors
mkdir -p "$out"
policies="DROP TRAP MUST_CLOSE EBADF"
for policy in $policies; do
  swiftc -Onone -swift-version 6 -D "POLICY_$policy" -o "$out/$policy" \
    "$here/Kernel.swift" "$here/OwnedFD.swift" "$here/Scenarios.swift" "$here/main.swift"
done
printf '| scenario | modeled on | drop | trap | must-close | EBADF trap |\n'
printf '|---|---|---|---|---|---|\n'
"$out/DROP" --list | while IFS="$(printf '\t')" read -r name source; do
  row="| $name | $source |"
  for policy in $policies; do
    if result=$("$out/$policy" "$name" 2>/dev/null); then :; else result="TRAP"; fi
    row="$row $result |"
  done
  printf '%s\n' "$row"
done
