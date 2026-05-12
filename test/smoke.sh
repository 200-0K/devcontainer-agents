#!/usr/bin/env bash
# Local smoke test: simulates init (host) and sync (container) against a tmp workspace.
# Does NOT run `install` (would download real CLIs).
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

WS="$TMP/workspace"
HOST_HOME_MOCK="$TMP/host-home"
CTR_HOME_MOCK="$TMP/container-home"

mkdir -p "$WS/.devcontainer" "$HOST_HOME_MOCK" "$CTR_HOME_MOCK"

# Seed mock host auth
mkdir -p \
  "$HOST_HOME_MOCK/.claude" \
  "$HOST_HOME_MOCK/.gemini" \
  "$HOST_HOME_MOCK/.codex" \
  "$HOST_HOME_MOCK/.local/share/opencode"

echo '{"claude": "ok"}'   > "$HOST_HOME_MOCK/.claude.json"
echo '{"settings": true}' > "$HOST_HOME_MOCK/.claude/settings.json"
echo '{"gemini": "ok"}'   > "$HOST_HOME_MOCK/.gemini/oauth_creds.json"
echo '{"codex":  "ok"}'   > "$HOST_HOME_MOCK/.codex/auth.json"
echo '{"oc":     "ok"}'   > "$HOST_HOME_MOCK/.local/share/opencode/auth.json"

# Mock host shell rc with a sentinel alias (the "ccc" use case).
echo "alias ccc='echo claude-code'" > "$HOST_HOME_MOCK/.zshrc"

# Seed an existing container .bashrc to verify guard + idempotent append.
echo "# pre-existing line" > "$CTR_HOME_MOCK/.bashrc"

# Pretend host path is something different to verify path rewriting.
echo "host path marker: $HOST_HOME_MOCK" > "$HOST_HOME_MOCK/.claude/marker.json"

echo
echo "==> init (simulated HOST)"
HOME="$HOST_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" init

echo
echo "Staged into $WS/.devcontainer/.host-files:"
find "$WS/.devcontainer/.host-files" -type f | sed "s|$TMP|<TMP>|g"

echo
# Simulate `install` creating ~/.claude before sync (the real claude installer does this).
mkdir -p "$CTR_HOME_MOCK/.claude"
echo "pre-existing container file" > "$CTR_HOME_MOCK/.claude/install-marker"

echo "==> sync (simulated CONTAINER)"
HOME="$CTR_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" sync

echo
echo "Restored into \$HOME ($CTR_HOME_MOCK):"
find "$CTR_HOME_MOCK" -type f | sed "s|$TMP|<TMP>|g"

echo
echo "Staging dir should be gone:"
if [ -d "$WS/.devcontainer/.host-files" ]; then
  echo "  FAIL — still exists" >&2
  exit 1
else
  echo "  ok"
fi

echo
echo "No nested dir check (no ~/.claude/.claude):"
if [ -d "$CTR_HOME_MOCK/.claude/.claude" ]; then
  echo "  FAIL — nested ~/.claude/.claude exists" >&2
  exit 1
else
  echo "  ok"
fi

echo
echo "Merge preserves pre-existing container files:"
if [ -f "$CTR_HOME_MOCK/.claude/install-marker" ] \
   && [ -f "$CTR_HOME_MOCK/.claude/settings.json" ]; then
  echo "  ok (install-marker kept, host settings.json restored)"
else
  echo "  FAIL — merge dropped a file" >&2
  ls -la "$CTR_HOME_MOCK/.claude/" >&2
  exit 1
fi

echo
echo "Path rewrite check (host->container in marker.json):"
if grep -q "$CTR_HOME_MOCK" "$CTR_HOME_MOCK/.claude/marker.json" \
   && ! grep -q "$HOST_HOME_MOCK" "$CTR_HOME_MOCK/.claude/marker.json"; then
  echo "  ok"
else
  echo "  FAIL — host path still present or container path missing" >&2
  cat "$CTR_HOME_MOCK/.claude/marker.json" >&2
  exit 1
fi

echo
echo "Host shell rc bridge check:"
if [ -f "$CTR_HOME_MOCK/.shellrc.host" ] \
   && grep -q "alias ccc=" "$CTR_HOME_MOCK/.shellrc.host" \
   && grep -q ".shellrc.host" "$CTR_HOME_MOCK/.bashrc"; then
  echo "  ok (~/.shellrc.host present, .bashrc sources it)"
else
  echo "  FAIL — shell rc bridge incomplete" >&2
  ls -la "$CTR_HOME_MOCK/" >&2
  exit 1
fi

echo
echo "Idempotent re-sync (no duplicate source line):"
# Re-seed (sync deleted the staging) and run again
mkdir -p "$WS/.devcontainer/.host-files"
echo "$HOST_HOME_MOCK" > "$WS/.devcontainer/.host-files/.host-home-path"
cp "$HOST_HOME_MOCK/.zshrc" "$WS/.devcontainer/.host-files/.zshrc"
HOME="$CTR_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" sync >/dev/null
count=$(grep -c ".shellrc.host" "$CTR_HOME_MOCK/.bashrc")
if [ "$count" -eq 1 ]; then
  echo "  ok (source line present exactly once)"
else
  echo "  FAIL — source line count: $count" >&2
  exit 1
fi

echo
echo "Smoke test passed."
