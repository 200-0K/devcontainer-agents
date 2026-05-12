# devcontainer-agents

Drop-in AI coding-agent setup for any VS Code devcontainer. One file per project; all logic lives here.

## What you get

| Lifecycle hook       | Subcommand | Where     | What runs                                                  |
| -------------------- | ---------- | --------- | ---------------------------------------------------------- |
| `initializeCommand`  | `init`     | host      | stage `~/.claude*`, `~/.gemini`, `~/.codex`, etc. into the workspace |
| `postCreateCommand`  | `install`  | container | install enabled agent CLIs (curl-bash and `npm i -g`)      |
| `postAttachCommand`  | `sync`     | container | restore staged auth into `$HOME`, delete staging           |

## Onboard a project

```bash
# remote (after pushing this repo to GitHub):
curl -fsSL https://raw.githubusercontent.com/<USER>/devcontainer-agents/main/install.sh | bash

# local (from this checkout):
bash install.sh /path/to/your/project
```

Writes `.devcontainer/agents.sh` into your project and prints a JSON snippet to merge into `devcontainer.json`.

## Per-project footprint

```
.devcontainer/
└── agents.sh            # 5-line shim, never edited
```

Plus three lifecycle lines and `containerEnv.CLAUDE_CODE_OAUTH_TOKEN` in `devcontainer.json`. That's all.

## Toggling agents per project

```jsonc
"containerEnv": {
  "ENABLE_CODEX": "0"   // disable Codex for this project
}
```

Default: all four agents on.

## Adding a new agent

See [docs/adding-an-agent.md](docs/adding-an-agent.md). It's two files touched: drop `agents/<name>.sh` and append the name to `agents/manifest.txt`. Every project picks it up on the next reopen.

## Local testing

```bash
bash test/smoke.sh                              # tmp-dir round trip for init+sync
DCA_LOCAL=$PWD bash install.sh /path/to/project # wire the project to this checkout
```

In the project's `containerEnv`, set `"DCA_LOCAL": "/path/inside/container"` if you also bind-mount this repo into the container — the shim will skip the tarball fetch.

## Repo layout

```
run.sh                       # dispatcher
install.sh                   # project onboarder
lib/common.sh                # log, stage_path, restore_*, npm_install_global, agent_enabled
lib/loader.sh                # manifest reader + per-agent dispatch
agents/manifest.txt          # one agent id per line
agents/<name>.sh             # <name>_init / <name>_install / <name>_sync
templates/agents.sh          # shim that gets dropped into each project
templates/devcontainer.snippet.jsonc
docs/{adding-an-agent,onboarding}.md
test/smoke.sh
```
