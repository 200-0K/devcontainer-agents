#!/usr/bin/env bash
# devcontainer-agents shim. Fetches latest setup from main and runs it.
# Override the URL by exporting DCA_REPO_TARBALL.
set -euo pipefail

REPO_TARBALL="${DCA_REPO_TARBALL:-https://codeload.github.com/200-0K/devcontainer-agents/tar.gz/master}"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
curl -fsSL "$REPO_TARBALL" | tar xz -C "$T" --strip-components=1
exec "$T/run.sh" "$@"
