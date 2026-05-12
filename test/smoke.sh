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

# Pretend host path is something different to verify path rewriting.
echo "host path marker: $HOST_HOME_MOCK" > "$HOST_HOME_MOCK/.claude/marker.json"

echo
echo "==> init (simulated HOST)"
HOME="$HOST_HOME_MOCK" DCA_WORKSPACE="$WS" "$HERE/run.sh" init

echo
echo "Staged into $WS/.devcontainer/.host-files:"
find "$WS/.devcontainer/.host-files" -type f | sed "s|$TMP|<TMP>|g"

echo
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
echo "Smoke test passed."
