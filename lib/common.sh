#!/usr/bin/env bash
# Shared helpers. Sourced by run.sh before any agent file.

log() {
  local level="$1"; shift
  printf '[dca] %-5s %s\n' "$level" "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log ERROR "missing required command: $1"; exit 1; }
}

# True if env var ENABLE_<NAME upper>=1 (default 1 if unset).
agent_enabled() {
  local name="$1"
  local var="ENABLE_$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
  local val="${!var:-1}"
  [ "$val" = "1" ]
}

# Stage a host file/dir into $HOST_FILES at REL_DST, preserving structure.
# No-op if SRC missing. Used by <agent>_init().
stage_path() {
  local src="$1" rel="$2"
  [ -e "$src" ] || return 0
  local dst="$HOST_FILES/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -aL "$src" "$dst" 2>/dev/null || true
}

# Copy a file as a secret (mkdir parent, copy, chmod 600). No-op if SRC missing.
# Used by <agent>_sync() for per-file auth restores.
restore_file_secret() {
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  chmod 600 "$dst" 2>/dev/null || true
}

# Copy a file/dir tree from $HOST_FILES into $HOME at REL_DST.
# Dirs: contents are MERGED into dst (existing dst preserved, files overwritten).
# Files: dst is overwritten.
restore_path() {
  local rel="$1"
  local src="$HOST_FILES/$rel"
  [ -e "$src" ] || return 0
  local dst="$HOME/$rel"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    # `src/.` merges contents — avoids nesting when dst already exists.
    cp -rf "$src"/. "$dst"/
  else
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
  fi
}

# In-place sed wrapper. GNU sed: `sed -i EXPR FILE`. BSD/macOS sed: `sed -i '' EXPR FILE`.
sed_inplace() {
  local expr="$1" file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

# Rewrite host home path -> container home in *.json/yaml under DIR.
rewrite_host_paths() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  [ -n "${HOST_HOME:-}" ] || return 0
  [ -n "${CONTAINER_HOME:-}" ] || return 0
  find "$dir" -maxdepth 3 -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null \
    | while read -r f; do
        sed_inplace "s|${HOST_HOME}|${CONTAINER_HOME}|g" "$f" 2>/dev/null || true
      done
}

# --- Host shell rc bridge --------------------------------------------------
# Brings host shell aliases/functions into the container so things like a
# `ccc` alias from ~/.zshrc keep working. Host-specific commands that fail
# inside the container shell are swallowed by the source-line's `|| true`.

# init (host): stage ~/.zshrc and ~/.bashrc into $HOST_FILES.
stage_host_shell_rcs() {
  local rc
  for rc in .zshrc .bashrc; do
    [ -f "$HOME/$rc" ] || continue
    cp "$HOME/$rc" "$HOST_FILES/$rc" 2>/dev/null || true
  done
}

# sync (container): copy whichever host rc was staged into ~/.shellrc.host
# and ensure ~/.bashrc and ~/.zshrc (if present) source it. Idempotent.
restore_host_shell_rcs() {
  local src="" rc
  # prefer zsh (the typical host shell on macOS)
  for rc in .zshrc .bashrc; do
    if [ -f "$HOST_FILES/$rc" ]; then src="$HOST_FILES/$rc"; break; fi
  done
  [ -n "$src" ] || return 0
  cp -f "$src" "$HOME/.shellrc.host"

  local guard='[ -f ~/.shellrc.host ] && source ~/.shellrc.host 2>/dev/null || true'
  local ctrrc
  for ctrrc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$ctrrc" ] || continue
    grep -qF '.shellrc.host' "$ctrrc" 2>/dev/null && continue
    printf '\n# devcontainer-agents: host shell rc bridge\n%s\n' "$guard" >> "$ctrrc"
  done
}

# Tolerant `npm install -g`.
npm_install_global() {
  if ! command -v npm >/dev/null 2>&1; then
    log WARN "npm not found, skipping: $*"
    return 0
  fi
  npm install -g "$@" >/dev/null 2>&1 || log WARN "npm install -g failed: $*"
}
