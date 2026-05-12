#!/usr/bin/env bash
# Onboard a project.
#
#   bash install.sh [PROJECT_DIR]
#
# Behavior:
#   - Writes .devcontainer/agents.sh                 (always)
#   - Writes .devcontainer/project-setup.sh stub     (if missing)
#   - Writes .devcontainer/devcontainer.json         (if missing — full scaffold)
#   - Prints merge snippet                           (if devcontainer.json already exists)
#
# Local mode (auto-detected when run from a checkout that has run.sh):
#   - Bakes a bind mount and "DCA_LOCAL": "/dca-local" into the scaffold,
#     so the shim runs the local checkout with zero manual editing.
set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
DEVC_DIR="$PROJECT_DIR/.devcontainer"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_RAW="${DCA_REPO_RAW:-https://raw.githubusercontent.com/<USER>/devcontainer-agents/main}"

# Local mode = this script lives in a checkout (run.sh is a sibling).
LOCAL_MODE=0
if [ -x "$SELF_DIR/run.sh" ]; then
  LOCAL_MODE=1
fi

mkdir -p "$DEVC_DIR"

# --- agents.sh (with host-side local path baked in for local-mode installs) ---
if [ -f "$SELF_DIR/templates/agents.sh" ]; then
  SHIM_SRC="$(cat "$SELF_DIR/templates/agents.sh")"
else
  SHIM_SRC="$(curl -fsSL "$REPO_RAW/templates/agents.sh")"
fi

if [ "$LOCAL_MODE" = "1" ]; then
  SHIM_OUT="${SHIM_SRC//__DCA_LOCAL_HOST__/$SELF_DIR}"
else
  SHIM_OUT="${SHIM_SRC//__DCA_LOCAL_HOST__/}"
fi

printf '%s' "$SHIM_OUT" > "$DEVC_DIR/agents.sh"
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
  if [ -f "$SELF_DIR/templates/devcontainer.full.jsonc" ]; then
    TEMPLATE="$(cat "$SELF_DIR/templates/devcontainer.full.jsonc")"
  else
    TEMPLATE="$(curl -fsSL "$REPO_RAW/templates/devcontainer.full.jsonc")"
  fi

  PROJECT_NAME="$(basename "$PROJECT_DIR")"

  if [ "$LOCAL_MODE" = "1" ]; then
    DCA_LOCAL_ENV=','$'\n    '\""DCA_LOCAL"\"': '\""/dca-local"\"
    DCA_LOCAL_MOUNT='  "mounts": ['$'\n    '\""source=$SELF_DIR,target=/dca-local,type=bind,readonly"\"$'\n  ],'$'\n'
  else
    DCA_LOCAL_ENV=''
    DCA_LOCAL_MOUNT=''
  fi

  OUT="$TEMPLATE"
  OUT="${OUT//__PROJECT_NAME__/$PROJECT_NAME}"
  OUT="${OUT//__DCA_LOCAL_ENV__/$DCA_LOCAL_ENV}"
  OUT="${OUT//__DCA_LOCAL_MOUNT__/$DCA_LOCAL_MOUNT}"

  printf '%s' "$OUT" > "$DEVC_DIR/devcontainer.json"
  echo "wrote   $DEVC_DIR/devcontainer.json (new, $([ "$LOCAL_MODE" = "1" ] && echo local || echo remote) mode)"

  echo
  echo "Done. Reopen the folder in a devcontainer."
  exit 0
fi

# --- devcontainer.json exists → print merge snippet ---
echo "found   $DEVC_DIR/devcontainer.json (not overwriting)"
echo
echo "Merge these keys into it:"
echo "----------------------------------------"
echo '  "initializeCommand": "./.devcontainer/agents.sh init",'
echo '  "postCreateCommand": "./.devcontainer/agents.sh install && ./.devcontainer/project-setup.sh",'
echo '  "postAttachCommand": "./.devcontainer/agents.sh sync",'
echo '  "containerEnv": {'
echo '    "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"'
if [ "$LOCAL_MODE" = "1" ]; then
  echo '    , "DCA_LOCAL": "/dca-local"'
fi
echo '  },'
if [ "$LOCAL_MODE" = "1" ]; then
  echo '  "mounts": ['
  echo "    \"source=$SELF_DIR,target=/dca-local,type=bind,readonly\""
  echo '  ],'
fi
echo '  "customizations": {'
echo '    "vscode": { "extensions": ["Anthropic.claude-code"] }'
echo '  }'
echo "----------------------------------------"
echo
echo "Then reopen the folder in a devcontainer."
