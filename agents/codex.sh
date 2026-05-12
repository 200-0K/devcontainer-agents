#!/usr/bin/env bash
# Codex (OpenAI). npm i -g @openai/codex

codex_init() {
  stage_path "$HOME/.codex/auth.json" ".codex/auth.json"
}

codex_install() {
  npm_install_global @openai/codex
}

codex_sync() {
  restore_file_secret \
    "$HOST_FILES/.codex/auth.json" \
    "$HOME/.codex/auth.json"
}
