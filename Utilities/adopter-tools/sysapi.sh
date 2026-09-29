#!/bin/bash
# Grep swift-system's public declarations (SystemPackage's and SystemSockets') for a pattern.
#
#   sysapi.sh [--system DIR] [--ref REF] EXTENDED-REGEX
#
# Takes every source line that declares something public (after any attributes)
# and prints those that match, as `System/File.swift:LINE: declaration`. The
# declaration's first line only: cfuncs.py prints whole signatures, with the
# type they're in. System is the checkout these tools are in, or --system DIR,
# or $ADOPTER_TOOLS_SYSTEM: its working tree, or with --ref a commit, read with
# `git grep` (nothing is checked out).
set -euo pipefail

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd -P)"
system="${ADOPTER_TOOLS_SYSTEM:-$here/../..}"
ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --system) system="$2"; shift 2 ;;
    --ref) ref="$2"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ $# -eq 1 ] || usage
[ -d "$system/Sources/System" ] || { echo "sysapi.sh: $system isn't a swift-system checkout (no Sources/System)" >&2; exit 1; }

decl='^[[:space:]]*(@[A-Za-z_]+(\([^)]*\))?[[:space:]]+)*public[[:space:]]'
if [ -n "$ref" ]; then
  commit="$(git -C "$system" rev-parse --verify --quiet "$ref^{commit}")" || { echo "sysapi.sh: $ref: no such commit" >&2; exit 1; }
  git -C "$system" grep -nE "$decl" "$commit" -- 'Sources/System/*.swift' 'Sources/SystemSockets/*.swift' \
    | sed "s|^$commit:Sources/||" | grep -E -- "$1" || true
else
  (cd "$system/Sources" && grep -rnE --include='*.swift' "$decl" System SystemSockets) | grep -E -- "$1" || true
fi
