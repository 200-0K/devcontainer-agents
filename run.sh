#!/usr/bin/env bash
# Devcontainer agents — main dispatcher.
# Subcommands: init (host) | install (container, postCreate) | sync (container, postAttach)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/loader.sh
source "$SCRIPT_DIR/lib/loader.sh"

cmd="${1:-}"; shift || true

# Lifecycle hooks run with workspaceFolder as CWD (host & container alike).
# DCA_WORKSPACE overrides for testing.
WORKSPACE="${DCA_WORKSPACE:-$PWD}"
HOST_FILES="$WORKSPACE/.devcontainer/.host-files"
export HOST_FILES

case "$cmd" in
  init)
    mkdir -p "$HOST_FILES"
    printf '%s\n' "$HOME" > "$HOST_FILES/.host-home-path"
    load_and_run_agents "$SCRIPT_DIR" init
    log INFO "init complete -> $HOST_FILES"
    ;;

  install)
    load_and_run_agents "$SCRIPT_DIR" install
    log INFO "install complete"
    ;;

  sync)
    if [ ! -d "$HOST_FILES" ]; then
      log INFO "no staged host files at $HOST_FILES -- nothing to sync"
      exit 0
    fi
    HOST_HOME="$(cat "$HOST_FILES/.host-home-path" 2>/dev/null || true)"
    CONTAINER_HOME="$HOME"
    export HOST_HOME CONTAINER_HOME
    load_and_run_agents "$SCRIPT_DIR" sync
    rewrite_host_paths "$HOME"
    rm -rf "$HOST_FILES"
    log INFO "sync complete"
    ;;

  ""|-h|--help|help)
    cat >&2 <<'EOF'
usage: agents.sh {init|install|sync}

  init     (host)      stage host auth/config into $WORKSPACE/.devcontainer/.host-files/
  install  (container) install enabled agent CLIs (postCreateCommand)
  sync     (container) restore staged auth into $HOME, then remove staging (postAttachCommand)

env:
  ENABLE_CLAUDE / ENABLE_OPENCODE / ENABLE_GEMINI / ENABLE_CODEX   default 1
  DCA_WORKSPACE     override workspace dir (default: $PWD)
EOF
    [ -z "$cmd" ] && exit 2 || exit 0
    ;;

  *)
    log ERROR "unknown subcommand: $cmd"
    exit 2
    ;;
esac
