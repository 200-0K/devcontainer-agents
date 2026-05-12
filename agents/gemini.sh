#!/usr/bin/env bash
# Gemini CLI (Google). npm i -g @google/gemini-cli

gemini_init() {
  stage_path "$HOME/.gemini/oauth_creds.json" ".gemini/oauth_creds.json"
}

gemini_install() {
  npm_install_global @google/gemini-cli
}

gemini_sync() {
  restore_file_secret \
    "$HOST_FILES/.gemini/oauth_creds.json" \
    "$HOME/.gemini/oauth_creds.json"
}
