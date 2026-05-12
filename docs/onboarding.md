# Onboarding a project

## TL;DR

```bash
curl -fsSL https://raw.githubusercontent.com/200-0K/devcontainer-agents/master/install.sh | bash
```

Run from the project root. Writes `.devcontainer/agents.sh`, prints a snippet to paste into `devcontainer.json`. Reopen the container.

## What the snippet adds

```jsonc
"initializeCommand": "./.devcontainer/agents.sh init",
"postCreateCommand": "./.devcontainer/agents.sh install && ./.devcontainer/project-setup.sh",
"postAttachCommand": "./.devcontainer/agents.sh sync",

"containerEnv": {
  "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"
}
```

## Existing lifecycle commands

If your `devcontainer.json` already has `postCreateCommand` etc., move its body into `.devcontainer/project-setup.sh` and chain it as shown. Example for a Laravel project that previously ran `composer install && php artisan storage:link`:

```bash
# .devcontainer/project-setup.sh
#!/usr/bin/env bash
set -e
composer install
php artisan storage:link -q
```

Then in `devcontainer.json`:

```jsonc
"postCreateCommand": "./.devcontainer/agents.sh install && ./.devcontainer/project-setup.sh"
```

## /app vs /workspace vs anything else

The shim reads `$PWD`. Dev Containers CLI sets that to `workspaceFolder` for every lifecycle command on both host and container. No hardcoded paths.

## Disabling an agent in one project

```jsonc
"containerEnv": {
  "ENABLE_GEMINI": "0"
}
```

## Pointing the shim at a fork or branch

Override the tarball URL by exporting `DCA_REPO_TARBALL` in the host shell before opening the container (it inherits into `initializeCommand`):

```bash
export DCA_REPO_TARBALL='https://codeload.github.com/me/devcontainer-agents/tar.gz/my-branch'
```

For container-side hooks, add the same env to `containerEnv`.
