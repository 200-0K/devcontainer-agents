#!/usr/bin/env bash
# Local smoke test: simulates init (host) and sync (container) against a tmp workspace.
# Does NOT run `install` (would download real CLIs).
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/test/lib.sh"
setup_tmp

WS="$TMP/workspace"
HOST_HOME_MOCK="$TMP/host-home"
CTR_HOME_MOCK="$TMP/container-home"

mkdir -p "$WS/.devcontainer" "$HOST_HOME_MOCK" "$CTR_HOME_MOCK" \
  "$HOST_HOME_MOCK/.claude" "$HOST_HOME_MOCK/.gemini" "$HOST_HOME_MOCK/.codex" \
  "$HOST_HOME_MOCK/.local/share/opencode"

echo '{"claude": "ok"}'                 > "$HOST_HOME_MOCK/.claude.json"
echo '{"settings": true}'               > "$HOST_HOME_MOCK/.claude/settings.json"
echo '{"gemini": "ok"}'                 > "$HOST_HOME_MOCK/.gemini/oauth_creds.json"
echo '{"codex":  "ok"}'                 > "$HOST_HOME_MOCK/.codex/auth.json"
echo '{"oc":     "ok"}'                 > "$HOST_HOME_MOCK/.local/share/opencode/auth.json"
echo "alias ccc='echo claude-code'"     > "$HOST_HOME_MOCK/.zshrc"
echo "# pre-existing line"              > "$CTR_HOME_MOCK/.bashrc"
echo "host path marker: $HOST_HOME_MOCK" > "$HOST_HOME_MOCK/.claude/marker.json"

echo
echo "==> init (simulated HOST)"
HOME="$HOST_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" init

echo
echo "Staged into $WS/.devcontainer/.host-files:"
find "$WS/.devcontainer/.host-files" -type f | sed "s|$TMP|<TMP>|g"

# Simulate `install` creating ~/.claude before sync (the real claude installer does this).
mkdir -p "$CTR_HOME_MOCK/.claude"
echo "pre-existing container file" > "$CTR_HOME_MOCK/.claude/install-marker"

echo
echo "==> sync (simulated CONTAINER)"
HOME="$CTR_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" sync

echo
echo "Restored into \$HOME ($CTR_HOME_MOCK):"
find "$CTR_HOME_MOCK" -type f | sed "s|$TMP|<TMP>|g"

echo
assert_no_dir "$WS/.devcontainer/.host-files"            "staging dir cleaned up"
assert_no_dir "$CTR_HOME_MOCK/.claude/.claude"           "no nested ~/.claude/.claude"
assert_file   "$CTR_HOME_MOCK/.claude/install-marker"    "pre-existing container file kept"
assert_file   "$CTR_HOME_MOCK/.claude/settings.json"     "host settings.json restored"
assert_grep   "$CTR_HOME_MOCK"      "$CTR_HOME_MOCK/.claude/marker.json" "container path rewritten in"
assert_no_grep "$HOST_HOME_MOCK"    "$CTR_HOME_MOCK/.claude/marker.json" "host path scrubbed from"
assert_file   "$CTR_HOME_MOCK/.shellrc.host"             "~/.shellrc.host present"
assert_grep   "alias ccc="          "$CTR_HOME_MOCK/.shellrc.host"  "host ccc alias in .shellrc.host"
assert_grep   ".shellrc.host"       "$CTR_HOME_MOCK/.bashrc"        ".bashrc sources .shellrc.host"

# Re-seed staging and re-run sync to verify the bashrc append is idempotent.
mkdir -p "$WS/.devcontainer/.host-files"
echo "$HOST_HOME_MOCK"             > "$WS/.devcontainer/.host-files/.host-home-path"
cp "$HOST_HOME_MOCK/.zshrc"          "$WS/.devcontainer/.host-files/.zshrc"
HOME="$CTR_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" sync >/dev/null
assert_grep_count ".shellrc.host"   "$CTR_HOME_MOCK/.bashrc" 1 "source line present exactly once after re-sync"

echo
echo "Smoke test passed."
