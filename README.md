# devcontainer-agents

Drop-in AI coding-agent setup for any VS Code devcontainer. One file per project; all logic lives here.

## What you get

| Lifecycle hook       | Subcommand | Where     | What runs                                                                                  |
| -------------------- | ---------- | --------- | ------------------------------------------------------------------------------------------ |
| `initializeCommand`  | `init`     | host      | stage `~/.claude*`, `~/.gemini`, `~/.codex`, `~/.zshrc`, etc. into the workspace            |
| `postCreateCommand`  | `install`  | container | install enabled agent CLIs (curl-bash and `npm i -g`)                                       |
| `postAttachCommand`  | `sync`     | container | restore staged auth into `$HOME`, copy host shell rc to `~/.shellrc.host`, delete staging   |

Your host's `~/.zshrc` (or `~/.bashrc`) is staged as `~/.shellrc.host` inside the container, and `~/.bashrc`/`~/.zshrc` is wired to source it — so aliases and functions like `ccc` defined on the host keep working. Host-specific commands that can't run inside the container are swallowed silently by `2>/dev/null || true`.

## Onboard a project

```bash
cd /path/to/your/project
curl -fsSL https://raw.githubusercontent.com/200-0k/devcontainer-agents/main/install.sh | bash
```

Writes `.devcontainer/agents.sh` into your project, scaffolds `devcontainer.json` if missing, or prints a snippet to merge if it already exists. Reopen the container.

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

## Testing changes to this repo

```bash
bash test/smoke.sh   # tmp-dir round trip for init+sync (no network)
```

To try an unreleased branch in a real project, override the tarball URL in your host shell before reopening the container:

```bash
export DCA_REPO_TARBALL='https://codeload.github.com/200-0k/devcontainer-agents/tar.gz/my-branch'
```

For container-side hooks, set the same env in the project's `containerEnv`.

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
