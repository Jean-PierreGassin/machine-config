# Local dev defaults

CLI editor: `vim`

Unix shell: `zsh`

Terminal: WezTerm cross-platform

Multiplexer: `tmux` with `$SHELL` as the default shell

Operating systems: Windows 11 with WSL 2, macOS

## Setup

```sh
git clone <this repo> ~/repos/machine-config
cd ~/repos/machine-config
./install.sh
```

This will:
- Install Homebrew (macOS) or use apt (Linux/WSL)
- Install zsh, tmux, vim, git, starship, and nvm
- Configure Starship with the Pure preset
- Symlink the dotfiles into `$HOME`, backing up anything already there to `~/.machine-config-backup-<timestamp>/` rather than overwriting it
- Generate `~/.gitconfig` from your prompted identity, with optional work/personal repo overrides
- Offer to create missing SSH keys, print public keys to copy, and never overwrite existing keys
- Require zsh and set it as your login shell when needed

Re-running it is safe. It skips anything already installed or linked correctly. Pass `-y`/`--yes` to answer yes to ordinary prompts, or `--verbose` to show package manager and installer output.

Notes:
- `~/.gitconfig` is generated from the repo's `.gitconfig` template rather than symlinked. Optional work/personal directories get their own `.gitconfig` and SSH key path.
- Global-only setup can create `~/.ssh/id_ed25519`, but leaves key selection to SSH defaults.
- `.tmux.conf` prefers `tmux-256color` and falls back to `screen-256color`.
- `.zshrc` uses platform-specific color aliases for GNU/Linux and macOS.
- `.zshrc` enables Starship only when the `starship` command exists.
- `.wezterm.lua` configures WezTerm with JetBrains Mono, Rose Pine, tabs, bell notifications, and pane dimming.
- `--yes` still needs env vars for generated Git config, and `CREATE_SSH_KEYS=1` before creating private keys.
- zsh is non-optional. The installer will stop if zsh is unavailable and will run `chsh` when your login shell is not zsh.
