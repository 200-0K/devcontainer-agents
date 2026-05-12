#!/usr/bin/env bash
# devcontainer-agents shim. Resolves run.sh from (in order):
#   1) $DCA_LOCAL env var          (container side, typically set via containerEnv -> bind mount)
#   2) hardcoded host path         (filled by install.sh when run from a local checkout)
#   3) tarball download from main  (default for remote installs)
set -euo pipefail

# 1) container-side local mode
if [ -n "${DCA_LOCAL:-}" ] && [ -x "$DCA_LOCAL/run.sh" ]; then
  exec "$DCA_LOCAL/run.sh" "$@"
fi

# 2) host-side local mode (path injected by install.sh; empty for remote installs)
DCA_LOCAL_HOST="__DCA_LOCAL_HOST__"
if [ -n "$DCA_LOCAL_HOST" ] && [ -x "$DCA_LOCAL_HOST/run.sh" ]; then
  exec "$DCA_LOCAL_HOST/run.sh" "$@"
fi

# 3) remote tarball
REPO_TARBALL="${DCA_REPO_TARBALL:-https://codeload.github.com/<USER>/devcontainer-agents/tar.gz/main}"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
curl -fsSL "$REPO_TARBALL" | tar xz -C "$T" --strip-components=1
exec "$T/run.sh" "$@"
