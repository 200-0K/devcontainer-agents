# devcontainer-agents

Drop-in AI coding-agent setup for any VS Code devcontainer. One shim per project; all logic lives here.

Supported agents: Claude Code, OpenCode, Gemini CLI, Codex.

## Onboard a project

From your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/200-0K/devcontainer-agents/master/install.sh | bash
```

Writes `.devcontainer/agents.sh` (5-line shim) and either scaffolds a new `devcontainer.json` or auto-injects the lifecycle keys into an existing one (with a `.dca.bak` backup). Reopen the container.

## What it does on each container lifecycle

| Hook                | Subcommand | Where     | What runs                                                                                |
| ------------------- | ---------- | --------- | ---------------------------------------------------------------------------------------- |
| `initializeCommand` | `init`     | host      | stage `~/.claude*`, `~/.gemini`, `~/.codex`, `~/.zshrc`, etc. into the workspace          |
| `postCreateCommand` | `install`  | container | install enabled agent CLIs (curl-bash and `npm i -g`)                                     |
| `postAttachCommand` | `sync`     | container | restore staged auth into `$HOME`, copy host shell rc to `~/.shellrc.host`, delete staging |

Your host's `~/.zshrc` (or `~/.bashrc`) is bridged into the container as `~/.shellrc.host` and sourced from `~/.bashrc` / `~/.zshrc`, so aliases like `ccc` defined on the host keep working. Host-specific commands that can't run in the container are swallowed silently.

## Toggle an agent off in one project

In that project's `devcontainer.json`:

```jsonc
"containerEnv": {
  "ENABLE_CODEX": "0"
}
```

Default: all agents on.

## Add a new agent

Two files touched. See [docs/adding-an-agent.md](docs/adding-an-agent.md).

## Test changes to this repo

```bash
bash test/smoke.sh      # init + sync round trip
bash test/install.sh    # onboarder behavior
```

To try an unreleased branch in a real project, override the tarball URL in your host shell before reopening the container, and mirror it in `containerEnv`:

```bash
export DCA_REPO_TARBALL='https://codeload.github.com/200-0K/devcontainer-agents/tar.gz/my-branch'
```

## Repo layout

```
run.sh                                   # dispatcher
install.sh                               # project onboarder
lib/{common,loader}.sh                   # helpers + manifest reader
agents/manifest.txt                      # one agent id per line
agents/<name>.sh                         # <name>_init / _install / _sync hooks
templates/agents.sh                      # shim dropped into each project
templates/devcontainer.{full,snippet}.jsonc
docs/{adding-an-agent,onboarding}.md
test/{lib,smoke,install}.sh
```
