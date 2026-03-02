# remote_hosts_sync

Production-oriented Neovim plugin for remote deployment workflows over SSH/SFTP/rsync.

## Features

- Auto-upload on `BufWritePost` to the active host.
- Full project sync (`:RemoteSync`) with `--archive --delete --checksum` and optional dry run.
- Manual `:RemotePush` / `:RemoteFetch` directory sync via rsync.
- Remote tree TUI (`:RemoteTree`) built on `nui.nvim` with lazy directory loading and cache.
- Large directories are loaded incrementally in chunks to keep UI responsive during tree expansion.
- Tree expansion shows explicit progress markers (`[loading x/y]`) while chunked pages are still being appended.
- Conflict detection before upload (remote newer than local) with options:
  - Cancel
  - Overwrite remote
  - Show diff (`vimdiff` style split)
- Persistent SSH connection helper with reconnect every 5 seconds and retry limit.
- Password auth via `sshpass -e` using environment injection; secrets are redacted in logs.
- Asynchronous execution through `plenary.job`.

## Requirements

- Neovim >= 0.9
- Unix-like environment (Linux/macOS/WSL)
- `ssh`, `sftp`, `rsync`
- `sshpass` (required when using password/password_env auth)
- Neovim dependencies:
  - `nvim-lua/plenary.nvim`
  - `MunifTanjim/nui.nvim`

## Installation

Using lazy.nvim:

```lua
{
  "<your-org>/nvim-remote-sync",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
}
```

## Configuration

Create `.remote_hosts_sync.toml` in the project root and/or `~/.config/nvim/remote_hosts_sync.toml`.
Project config overrides global config.

```toml
active_host = "production"

[[hosts]]
name = "production"
type = "sftp"
host = "example.com"
port = 22
user = "deploy"
ssh_key = "~/.ssh/id_rsa"
remote_path = "/var/www/project"
excludes_local = ["node_modules/", ".git/"]
excludes_remote = ["cache/", "logs/"]
```

Authentication fields (one required): `ssh_key`, `password`, or `password_env`.

## Commands

- `:RemoteConnect` — opens/validates SSH connection and starts reconnect policy on failure.
- `:RemoteTree` — opens remote tree TUI (lazy-loaded directories).
- `:RemoteStatus` — shows active host and connection/reconnect state.
- `:RemoteSync [--dry-run]` — full project rsync.
- `:RemotePush [local_dir]` — push selected directory.
- `:RemoteFetch [local_dir]` — fetch remote directory.

## Logging

Logs are written to `.remote_hosts_sync.log`.
Logged events include uploads/downloads/sync/reconnect attempts/errors.
Passwords and `SSHPASS` values are redacted.

## Architecture

```text
lua/
├── config/loader.lua
├── core/
│   ├── logger.lua
│   └── state.lua
├── transport/
│   ├── ssh.lua
│   ├── sftp.lua
│   └── rsync.lua
├── sync/watcher.lua
├── tui/tree.lua
└── commands.lua
plugin/remote_hosts_sync.lua
```

## Security Notes

- Remote commands are invoked with argument arrays via `plenary.job`.
- Password auth is passed through process environment (not command arguments).
- Secrets are redacted in logs.

## Status / Scope

This codebase now closely follows the technical specification and core workflow requirements.
Some lower-level behavior (for example, exact remote `mtime` parsing differences across SFTP implementations) may require environment-specific hardening.

## License

MIT (see `LICENSE`).

## Development / Regression Tests

This repository includes lightweight automated regression checks under `tests/`.

```bash
pytest -q
```
