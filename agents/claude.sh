#!/usr/bin/env bash
# Claude Code (Anthropic). https://claude.ai/install.sh -> ~/.local/bin/claude

claude_init() {
  mkdir -p "$HOME/.claude"
  [ -f "$HOME/.claude.json" ] || echo '{}' > "$HOME/.claude.json"
  stage_path "$HOME/.claude"      ".claude"
  stage_path "$HOME/.claude.json" ".claude.json"
  stage_path "$HOME/.agents"      ".agents"
}

claude_install() {
  curl -fsSL https://claude.ai/install.sh | bash || log WARN "claude installer exited non-zero"
}

claude_sync() {
  restore_path ".claude"
  restore_path ".claude.json"
  restore_path ".agents"
}
