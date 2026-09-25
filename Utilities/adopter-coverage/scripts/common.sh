# Shell helpers shared by check.sh and package.sh. Sourced, not run.

# SwiftPM runs each manifest under sandbox-exec, which can fail when this
# tool itself runs in a sandbox ("sandbox_apply: Operation not permitted").
# See README.md.
SWIFTPM=(--disable-sandbox)

log() { printf '\n== %s\n' "$*"; }

fail() {
  echo "error: $1" >&2
  if [ -n "${2:-}" ]; then
    echo "-- last lines of $2:" >&2
    tail -n 20 "$2" >&2
  fi
  exit 1
}

logged() {
  local logfile="$1"
  shift
  "$@" >> "$logfile" 2>&1 || fail "command failed: $*" "$logfile"
}

# Absolute physical path of $1, which needn't exist yet.
abspath() {
  local dir="$1" rest="" base
  while [ ! -d "$dir" ]; do
    base="$(basename "$dir")"
    case "$base" in .|..) fail "$1: use a path without . or .. components" ;; esac
    rest="/$base$rest"
    dir="$(dirname "$dir")"
  done
  base="$(cd "$dir" && pwd -P)"
  base="${base%/}$rest"
  printf '%s\n' "${base:-/}"
}

# check_dir NAME DIR: refuses a directory that this tool mustn't create or
# delete: one holding a repository, $HOME or this tool, or one inside a git
# directory, or inside a worktree but not ignored by it.
check_dir() {
  local name="$1" dir="$2" keep probe
  [ "$dir" != / ] || fail "refusing $name=/"
  for keep in "$REPO" ${CHECKOUTS[@]+"${CHECKOUTS[@]}"} "$(cd "$HOME" && pwd -P)" "$TOOL"; do
    case "$keep/" in "$dir"/*) fail "refusing $name=$dir: it holds $keep" ;; esac
  done
  probe="$dir"
  while [ ! -d "$probe" ]; do probe="$(dirname "$probe")"; done
  if [ "$(git -C "$probe" rev-parse --is-inside-git-dir 2>/dev/null)" = true ]; then
    fail "refusing $name=$dir: it's inside a git directory"
  fi
  if [ "$(git -C "$probe" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
    git -C "$probe" check-ignore -q "$dir" || fail "refusing $name=$dir: it's in a git worktree and not ignored"
    [ -z "$(git -C "$probe" ls-files -- "$dir")" ] || fail "refusing $name=$dir: it holds tracked files"
  fi
}

# check_out DIR: refuses to replace a directory this tool didn't write.
check_out() {
  if [ -e "$1" ] && [ ! -f "$1/.adopter-coverage-out" ]; then
    fail "refusing to replace $1: it exists and isn't adopter-coverage output"
  fi
}

# resolve_package NAME: the package's settings (PKG_*, from packages/NAME.ini),
# and P_PATH, P_REF, P_COMMIT and P_SWIFT_EXEC from the environment.
resolve_package() {
  local var
  eval "$(python3 "$S/package.py" shell "$PACKAGES" "$1")"
  var="${PKG_VAR}_PATH"
  P_PATH="${!var:-}"
  if [ -z "$P_PATH" ]; then
    [ -n "$PKG_CHECKOUT" ] || fail "$1: set ${PKG_VAR}_PATH; its package file names no checkout"
    P_PATH="$REPO/$PKG_CHECKOUT"
  fi
  P_PATH="$(abspath "$P_PATH")"
  [ -d "$P_PATH" ] || fail "no $PKG_TITLE checkout at $P_PATH; set ${PKG_VAR}_PATH"
  P_PATH="$(git -C "$P_PATH" rev-parse --show-toplevel 2>/dev/null)" \
    || fail "$P_PATH isn't a git checkout; set ${PKG_VAR}_PATH"
  P_PATH="$(cd "$P_PATH" && pwd -P)"
  var="${PKG_VAR}_REF"
  P_REF="${!var:-HEAD}"
  P_COMMIT="$(git -C "$P_PATH" rev-parse --verify --quiet "$P_REF^{commit}")" \
    || fail "$P_REF isn't a commit in $P_PATH"
  var="${PKG_VAR}_SWIFT_EXEC"
  P_SWIFT_EXEC="${!var:-}"
  if [ -n "$P_SWIFT_EXEC" ]; then
    [ -x "$P_SWIFT_EXEC" ] || fail "${PKG_VAR}_SWIFT_EXEC=$P_SWIFT_EXEC isn't an executable"
    P_SWIFT_EXEC="$(abspath "$P_SWIFT_EXEC")"
  fi
}
