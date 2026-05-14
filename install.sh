#!/usr/bin/env bash
# Onboard a project.
#
#   curl -fsSL https://raw.githubusercontent.com/200-0K/devcontainer-agents/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/200-0K/devcontainer-agents/master/install.sh | bash -s -- /path/to/project
#
# Behavior:
#   - Writes .devcontainer/agents.sh                 (always)
#   - Writes .devcontainer/project-setup.sh stub     (if missing)
#   - Writes .devcontainer/devcontainer.json         (if missing — full scaffold)
#   - Otherwise: auto-injects the lifecycle keys into the existing
#     devcontainer.json when there are no conflicts; backs up to
#     devcontainer.json.dca.bak. If existing lifecycle keys are detected,
#     prints a snippet for manual merge and leaves the file untouched.
set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
DEVC_DIR="$PROJECT_DIR/.devcontainer"
DEVC_FILE="$DEVC_DIR/devcontainer.json"
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

REPO_RAW="${DCA_REPO_RAW:-https://raw.githubusercontent.com/200-0K/devcontainer-agents/master}"

LIFECYCLE_KEYS=(initializeCommand postCreateCommand postAttachCommand)
LIFECYCLE_BLOCK='  "initializeCommand": "./.devcontainer/agents.sh init",
  "postCreateCommand": "./.devcontainer/agents.sh install && ./.devcontainer/project-setup.sh",
  "postAttachCommand": "./.devcontainer/agents.sh sync"'

# Prefer SELF_DIR's copy of REL when present (running from a clone), else curl.
fetch() {
  local rel="$1"
  if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$rel" ]; then
    cat "$SELF_DIR/$rel"
  else
    curl -fsSL "$REPO_RAW/$rel"
  fi
}

has_top_key() {
  grep -qE "^[[:space:]]*\"$2\"[[:space:]]*:" "$1"
}

# Insert BLOCK before the last root-closing brace in FILE. Adds a trailing
# comma to the previous content line if needed; JSONC line comments preserved.
# Writes to "$file.dca.new"; caller mv's it into place.
# BLOCK is passed via env (DCA_BLOCK) because BSD awk rejects multiline -v values.
inject_before_root_close() {
  local file="$1" block="$2"
  DCA_BLOCK="$block" awk '
    BEGIN { block = ENVIRON["DCA_BLOCK"] }
    { lines[++n] = $0 }
    END {
      for (i = n; i >= 1; i--) {
        s = lines[i]; sub(/\/\/.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        if (s == "}") { last_close = i; break }
      }
      if (!last_close) { exit 1 }

      for (i = last_close - 1; i >= 1; i--) {
        s = lines[i]; sub(/\/\/.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        if (s != "") { prev = i; break }
      }

      needs_comma = 0
      if (prev) {
        s = lines[prev]; sub(/\/\/.*$/, "", s); sub(/[[:space:]]+$/, "", s)
        last = substr(s, length(s), 1)
        if (last != "," && last != "{") needs_comma = 1
      }

      for (i = 1; i <= n; i++) {
        if (i == prev && needs_comma) {
          line = lines[i]
          cpos = index(line, "//")
          if (!cpos) cpos = length(line) + 1
          code = substr(line, 1, cpos - 1); rest = substr(line, cpos)
          sub(/[[:space:]]+$/, "", code)
          print code "," (rest ? " " rest : "")
        } else if (i == last_close) {
          print block
          print lines[i]
        } else {
          print lines[i]
        }
      }
    }
  ' "$file" > "$file.dca.new"
}

print_manual_merge() {
  echo "skip    auto-merge ($1)"
  echo
  echo "Merge by hand. To run agents alongside your existing commands, move the"
  echo "existing postCreate body into .devcontainer/project-setup.sh and chain it."
  echo "----------------------------------------"
  fetch templates/devcontainer.snippet.jsonc
  echo "----------------------------------------"
}

mkdir -p "$DEVC_DIR"

fetch templates/agents.sh > "$DEVC_DIR/agents.sh"
chmod +x "$DEVC_DIR/agents.sh"
echo "wrote   $DEVC_DIR/agents.sh"

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

if [ ! -f "$DEVC_FILE" ]; then
  TEMPLATE="$(fetch templates/devcontainer.full.jsonc)"
  printf '%s' "${TEMPLATE//__PROJECT_NAME__/$(basename "$PROJECT_DIR")}" > "$DEVC_FILE"
  echo "wrote   $DEVC_FILE (new)"
  echo
  echo "Reopen the container."
  exit 0
fi

echo "found   $DEVC_FILE"

CONFLICTS=""
for k in "${LIFECYCLE_KEYS[@]}"; do
  has_top_key "$DEVC_FILE" "$k" && CONFLICTS="$CONFLICTS $k"
done

if [ -n "$CONFLICTS" ]; then
  print_manual_merge "existing keys:$CONFLICTS"
  exit 0
fi

cp "$DEVC_FILE" "$DEVC_FILE.dca.bak"

if ! inject_before_root_close "$DEVC_FILE" "$LIFECYCLE_BLOCK" \
   || [ ! -s "$DEVC_FILE.dca.new" ]; then
  rm -f "$DEVC_FILE.dca.new" "$DEVC_FILE.dca.bak"
  print_manual_merge "couldn't locate root closing brace"
  exit 0
fi

mv "$DEVC_FILE.dca.new" "$DEVC_FILE"
echo "wrote   $DEVC_FILE (lifecycle keys injected)"
echo "backup  $DEVC_FILE.dca.bak"

echo
echo "Reopen the container."
