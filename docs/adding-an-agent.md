# Adding an agent

Two file touches. No edits to `run.sh` or `lib/`.

## 1. Create `agents/<name>.sh`

Each agent file exposes up to three functions. Missing functions are skipped silently.

```bash
# agents/example.sh

example_init() {
  # HOST. Stage host auth/config into $HOST_FILES.
  stage_path "$HOME/.example/auth.json" ".example/auth.json"
}

example_install() {
  # CONTAINER, once. Install the CLI.
  curl -fsSL https://example.com/install.sh | bash || log WARN "example installer failed"
}

example_sync() {
  # CONTAINER, every attach. Restore staged auth into $HOME.
  restore_file_secret "$HOST_FILES/.example/auth.json" "$HOME/.example/auth.json"
}
```

## 2. Register it

Append the agent id (the filename without `.sh`) to `agents/manifest.txt`:

```
example
```

Push to `main`. Every project picks the new agent up on next container reopen.

## Helpers from `lib/common.sh`

| Helper | Purpose |
|---|---|
| `log INFO\|WARN\|ERROR …` | uniform stderr output, prefixed `[dca]` |
| `require_cmd NAME` | exit with error if `NAME` not on `$PATH` |
| `stage_path SRC REL` | copy SRC → `$HOST_FILES/REL`, preserving structure |
| `restore_path REL` | copy `$HOST_FILES/REL` → `$HOME/REL` |
| `restore_file_secret SRC DST` | copy + chmod 600. No-op if SRC missing |
| `rewrite_host_paths DIR` | sed `$HOST_HOME` → `$CONTAINER_HOME` in `*.json/yaml` under DIR |
| `npm_install_global PKG …` | tolerant `npm i -g` |
| `agent_enabled NAME` | true if `ENABLE_<NAME upper>=1` (default 1) |

## Env contract

`run.sh` exports these before sourcing your agent file:

| Var               | Where                 | Meaning                                         |
| ----------------- | --------------------- | ----------------------------------------------- |
| `HOST_FILES`      | all subcommands       | `$WORKSPACE/.devcontainer/.host-files`          |
| `HOST_HOME`       | sync only             | `$HOME` on the host (recorded by `init`)        |
| `CONTAINER_HOME`  | sync only             | `$HOME` in the container                        |

## Disabling per-project

Anyone can opt out of your agent by setting `"ENABLE_<NAME upper>": "0"` in their `devcontainer.json` `containerEnv`.
