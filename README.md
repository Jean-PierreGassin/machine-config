# Local dev defaults

CLI editor: `vim`

Unix shell: `zsh`

Terminal: Windows Terminal on WSL, Terminal.app/iTerm2 on macOS

Multiplexer: `tmux` with `$SHELL` as the default shell

Operating systems: Windows 11 with WSL 2, macOS

## Setup

```sh
git clone <this repo> ~/repos/machine-config
cd ~/repos/machine-config
./install.sh
```

This will (asking before each step):
- Install Homebrew (macOS) or use apt (Linux/WSL) if no package manager is present
- Install zsh, tmux, vim, git, starship, and nvm
- Symlink the dotfiles into `$HOME`, backing up anything already there to `~/.machine-config-backup-<timestamp>/` rather than overwriting it
- Prompt for your git `user.name`/`user.email` if `.gitconfig` still has placeholder values, and set them as your default identity (still overridable per-directory via `~/repos/work/.gitconfig` / `~/repos/personal/.gitconfig`)
- Set `~/.gitignore_global` as your global git excludesfile and offer to switch your default shell to zsh

Re-running it is safe — it skips anything already installed/linked correctly. Pass `-y`/`--yes` to skip all prompts.

Notes:
- `.gitconfig` includes separate overrides for `~/repos/work` and `~/repos/personal`. The global `[core]` block is ordered before the `includeIf` blocks so per-directory configs can still override it if needed.
- `.tmux.conf` prefers `tmux-256color` and falls back to `screen-256color`.
- `.zshrc` uses platform-specific color aliases for GNU/Linux and macOS.
- **Must** install Starship: <https://starship.rs/guide/> (I prefer <https://starship.rs/presets/gruvbox-rainbow>)
- **Must** install Homebrew first on macOS: <https://brew.sh> — `.zshenv` detects it by known install path rather than assuming it's already on PATH, but it still needs to actually be installed.
