#!/usr/bin/env bash
# Onboard a project.
#
#   curl -fsSL https://raw.githubusercontent.com/200-0k/devcontainer-agents/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/200-0k/devcontainer-agents/main/install.sh | bash -s -- /path/to/project
#
# Behavior:
#   - Writes .devcontainer/agents.sh                 (always)
#   - Writes .devcontainer/project-setup.sh stub     (if missing)
#   - Writes .devcontainer/devcontainer.json         (if missing — full scaffold)
#   - Prints merge snippet                           (if devcontainer.json already exists)
set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
DEVC_DIR="$PROJECT_DIR/.devcontainer"
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

REPO_RAW="${DCA_REPO_RAW:-https://raw.githubusercontent.com/200-0k/devcontainer-agents/main}"

# fetch REL [LOCAL_FALLBACK]: prefer SELF_DIR's copy when present (running from a
# clone), else curl from REPO_RAW.
fetch() {
  local rel="$1"
  if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$rel" ]; then
    cat "$SELF_DIR/$rel"
  else
    curl -fsSL "$REPO_RAW/$rel"
  fi
}

mkdir -p "$DEVC_DIR"

# --- agents.sh ---
fetch templates/agents.sh > "$DEVC_DIR/agents.sh"
chmod +x "$DEVC_DIR/agents.sh"
echo "wrote   $DEVC_DIR/agents.sh"

# --- project-setup.sh (stub, if missing) ---
if [ ! -f "$DEVC_DIR/project-setup.sh" ]; then
  cat > "$DEVC_DIR/project-setup.sh" <<'EOF'
#!/usr/bin/env bash
# Project-specific postCreate steps. Runs after agent CLIs are installed.
# Put your composer/npm/build/etc. commands here.
set -e
EOF
  chmod +x "$DEVC_DIR/project-setup.sh"
  echo "wrote   $DEVC_DIR/project-setup.sh (stub)"
else
  echo "kept    $DEVC_DIR/project-setup.sh (already present)"
fi

# --- devcontainer.json: scaffold if missing, else print snippet ---
if [ ! -f "$DEVC_DIR/devcontainer.json" ]; then
  TEMPLATE="$(fetch templates/devcontainer.full.jsonc)"
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  OUT="${TEMPLATE//__PROJECT_NAME__/$PROJECT_NAME}"

  printf '%s' "$OUT" > "$DEVC_DIR/devcontainer.json"
  echo "wrote   $DEVC_DIR/devcontainer.json (new)"
  echo
  echo "Done. Reopen the folder in a devcontainer."
  exit 0
fi

# devcontainer.json exists — print merge snippet
echo "found   $DEVC_DIR/devcontainer.json (not overwriting)"
echo
echo "Merge these keys into it:"
echo "----------------------------------------"
fetch templates/devcontainer.snippet.jsonc
echo "----------------------------------------"
echo
echo "Then reopen the folder in a devcontainer."
