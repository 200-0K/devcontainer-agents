#!/usr/bin/env bash
# Reads agents/manifest.txt and runs <agent>_<cmd> for each enabled agent.
# Expects: REPO_DIR (path to repo), CMD (init|install|sync), $HOST_FILES exported.

load_and_run_agents() {
  local repo_dir="$1" cmd="$2"
  local manifest="$repo_dir/agents/manifest.txt"
  [ -f "$manifest" ] || { log ERROR "manifest not found: $manifest"; exit 1; }

  local agent
  while IFS= read -r agent || [ -n "$agent" ]; do
    # Trim whitespace
    agent="${agent#"${agent%%[![:space:]]*}"}"
    agent="${agent%"${agent##*[![:space:]]}"}"
    [ -z "$agent" ] && continue
    case "$agent" in \#*) continue ;; esac

    if ! agent_enabled "$agent"; then
      log INFO "skip $agent (disabled)"
      continue
    fi

    local f="$repo_dir/agents/$agent.sh"
    if [ ! -f "$f" ]; then
      log WARN "agent file missing: $f"
      continue
    fi

    # shellcheck disable=SC1090
    source "$f"

    local fn="${agent}_${cmd}"
    if declare -f "$fn" >/dev/null 2>&1; then
      log INFO "$agent: $cmd"
      "$fn" || log WARN "$agent: $cmd failed"
    else
      log INFO "$agent: no $cmd hook"
    fi
  done < "$manifest"
}
