#!/usr/bin/env bash
# Test the project onboarder: scaffold, auto-merge, conflict detection.
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/test/lib.sh"
setup_tmp

INSTALL="$HERE/install.sh"

# -----------------------------------------------------------------------
echo "==> case 1: greenfield (no devcontainer.json)"
P="$TMP/greenfield"
mkdir -p "$P"
quiet bash "$INSTALL" "$P"

assert_exec  "$P/.devcontainer/agents.sh"           "agents.sh written + executable"
assert_exec  "$P/.devcontainer/project-setup.sh"    "project-setup.sh stub written"
assert_file  "$P/.devcontainer/devcontainer.json"   "devcontainer.json scaffolded"
assert_grep  '"name": "greenfield"' "$P/.devcontainer/devcontainer.json" "PROJECT_NAME substituted"
assert_grep  '"initializeCommand"'  "$P/.devcontainer/devcontainer.json" "lifecycle keys present"

# -----------------------------------------------------------------------
echo
echo "==> case 2: existing devcontainer.json, no conflicts, no containerEnv"
P="$TMP/case2"
mkdir -p "$P/.devcontainer"
cat > "$P/.devcontainer/devcontainer.json" <<'EOF'
// header comment
{
    "name": "case2",
    "image": "ubuntu"
}
EOF
quiet bash "$INSTALL" "$P"

assert_file  "$P/.devcontainer/devcontainer.json.dca.bak" "backup created"
assert_grep  '"initializeCommand": "./.devcontainer/agents.sh init"' "$P/.devcontainer/devcontainer.json" "initializeCommand injected"
assert_grep  '"postCreateCommand"'        "$P/.devcontainer/devcontainer.json" "postCreateCommand injected"
assert_grep  '"CLAUDE_CODE_OAUTH_TOKEN"'  "$P/.devcontainer/devcontainer.json" "containerEnv injected"
assert_grep  '"name": "case2"'            "$P/.devcontainer/devcontainer.json" "existing keys preserved"
assert_egrep '^// header comment'         "$P/.devcontainer/devcontainer.json" "comments preserved"
assert_valid_jsonc                        "$P/.devcontainer/devcontainer.json" "result is valid JSON"

# -----------------------------------------------------------------------
echo
echo "==> case 3: existing containerEnv → don't add a second one"
P="$TMP/case3"
mkdir -p "$P/.devcontainer"
cat > "$P/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "case3",
  "image": "ubuntu",
  "containerEnv": {
    "MY_VAR": "1"
  }
}
EOF
quiet bash "$INSTALL" "$P"

assert_grep_count '"containerEnv"' "$P/.devcontainer/devcontainer.json" 1 "single containerEnv block"
assert_grep       '"MY_VAR": "1"'  "$P/.devcontainer/devcontainer.json"   "existing containerEnv preserved"
assert_grep       '"initializeCommand"' "$P/.devcontainer/devcontainer.json" "lifecycle keys still injected"
assert_valid_jsonc                 "$P/.devcontainer/devcontainer.json"   "result is valid JSON"

# -----------------------------------------------------------------------
echo
echo "==> case 4: conflict — existing initializeCommand → skip auto-merge"
P="$TMP/case4"
mkdir -p "$P/.devcontainer"
cat > "$P/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "case4",
  "initializeCommand": "./my-init.sh"
}
EOF
ORIG=$(cat "$P/.devcontainer/devcontainer.json")
quiet bash "$INSTALL" "$P"

assert_no_file "$P/.devcontainer/devcontainer.json.dca.bak" "no backup created (untouched)"
[ "$(cat "$P/.devcontainer/devcontainer.json")" = "$ORIG" ] \
  && pass "devcontainer.json unchanged" || fail "devcontainer.json was modified despite conflict"

# -----------------------------------------------------------------------
echo
echo "==> case 5: re-run on a fresh-scaffolded project is a no-op"
P="$TMP/greenfield"
ORIG_DEVC=$(cat "$P/.devcontainer/devcontainer.json")
quiet bash "$INSTALL" "$P"
[ "$(cat "$P/.devcontainer/devcontainer.json")" = "$ORIG_DEVC" ] \
  && pass "re-run leaves devcontainer.json untouched" || fail "re-run modified the file"

echo
echo "All install.sh tests passed."
