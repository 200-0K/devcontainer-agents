#!/usr/bin/env bash
# Shared test helpers. Source from test scripts:
#   HERE="$(cd "$(dirname "$0")/.." && pwd)"
#   source "$HERE/test/lib.sh"
#   setup_tmp

pass() { printf '  ok %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1" >&2; exit 1; }

# Create a tmp dir and register EXIT cleanup. Sets $TMP.
setup_tmp() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
}

# Run a command silently unless DEBUG=1.
quiet() {
  if [ "${DEBUG:-0}" = "1" ]; then "$@"; else "$@" >/dev/null; fi
}

# Suppress shell error if grep fails; turn boolean into pass/fail.
assert_grep()    { grep -qF "$1" "$2"   && pass "$3" || fail "$3"; }
assert_egrep()   { grep -qE "$1" "$2"   && pass "$3" || fail "$3"; }
assert_no_grep() { grep -qF "$1" "$2"   && fail "$3" || pass "$3"; }

# Assert FILE has exactly COUNT lines matching fixed-string PATTERN.
assert_grep_count() {
  local pattern="$1" file="$2" expected="$3" msg="$4" actual
  actual=$(grep -cF "$pattern" "$file")
  if [ "$actual" = "$expected" ]; then pass "$msg"; else fail "$msg (got $actual, want $expected)"; fi
}

# True if FILE exists / does not exist.
assert_file()     { [ -f "$1" ] && pass "$2" || fail "$2"; }
assert_no_file()  { [ -f "$1" ] && fail "$2" || pass "$2"; }
assert_dir()      { [ -d "$1" ] && pass "$2" || fail "$2"; }
assert_no_dir()   { [ -d "$1" ] && fail "$2" || pass "$2"; }
assert_exec()     { [ -x "$1" ] && pass "$2" || fail "$2"; }

# Validate FILE is parseable JSON after stripping line comments.
assert_valid_jsonc() {
  if sed 's://[^"]*$::' "$1" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
    pass "$2"
  else
    fail "$2"
  fi
}
