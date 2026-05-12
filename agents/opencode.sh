#!/usr/bin/env bash
# OpenCode. https://opencode.ai/install -> ~/.opencode/bin/opencode

opencode_init() {
  stage_path "$HOME/.local/share/opencode/auth.json" ".local/share/opencode/auth.json"
}

opencode_install() {
  curl -fsSL https://opencode.ai/install | bash || log WARN "opencode installer exited non-zero"
}

opencode_sync() {
  restore_file_secret \
    "$HOST_FILES/.local/share/opencode/auth.json" \
    "$HOME/.local/share/opencode/auth.json"
}
