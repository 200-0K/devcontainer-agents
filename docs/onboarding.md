# Onboarding a project

## TL;DR

```bash
curl -fsSL https://raw.githubusercontent.com/<USER>/devcontainer-agents/main/install.sh | bash
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

## Testing against an unreleased version

Bind-mount this repo into your container and set `DCA_LOCAL`:

```yaml
# compose.local.yml (or compose.override.yml)
services:
  php:
    volumes:
      - /absolute/path/to/devcontainer-agents:/dca-local:ro
```

```jsonc
// devcontainer.json
"containerEnv": {
  "DCA_LOCAL": "/dca-local"
}
```

On the host side, just `export DCA_LOCAL=/absolute/path/to/devcontainer-agents` before opening the container — `initializeCommand` runs in your host shell and inherits it.

The shim takes `DCA_LOCAL` over the tarball fetch.
