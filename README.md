# Local dev defaults

CLI editor: `vim`

Unix shell: `zsh`

Terminal: Ghostty on macOS, WezTerm cross-platform

Operating systems: Windows 11 with WSL 2, macOS

## Setup

```sh
git clone <this repo> ~/repos/machine-config
cd ~/repos/machine-config
./install.sh
```

This will:
- Install Homebrew (macOS) or use apt (Linux/WSL)
- Install zsh, vim, git, starship, and nvm
- Check for a Nerd Font and warn when the prompt glyphs have nothing to render with
- Symlink native config files into `~/.config`, and `~/.zshrc` into `$HOME`
- Generate `~/.config/git/config` from your prompted identity, with optional work/personal repo overrides
- Offer to create missing SSH keys during initial setup, print public keys to copy, and never overwrite existing keys
- Require zsh and set it as your login shell when needed

Re-running it is safe. It skips anything already installed or linked correctly, including Git and SSH setup prompts. Pass `--setup-git` to reconfigure Git, `--setup-ssh` to reconfigure Git and offer missing keys, `-y`/`--yes` to answer yes to ordinary prompts, or `--verbose` to show package manager and installer output.

Notes:
- `~/.config/git/config` is generated from the repo's `.config/git/config` template rather than symlinked. Optional work/personal directories get their own `.gitconfig` and SSH key path.
- Global-only setup can create `~/.ssh/id_ed25519`, but leaves key selection to SSH defaults.
- `.config/ghostty/config`, `.config/git/ignore`, `.config/starship.toml`, `.config/vim/vimrc`, and `.config/wezterm/wezterm.lua` use native config paths.
- `.zshrc` uses platform-specific color aliases for GNU/Linux and macOS.
- `.zshrc` enables Starship only when the `starship` command exists.
- `.config/starship.toml` is the Pure preset plus a banner line above the prompt, shown as `repo-name (devbox)` when `.zshrc` detects a `devbox shell`.
- `.config/wezterm/wezterm.lua` configures WezTerm with JetBrains Mono, Rose Pine, tabs, bell notifications, and pane dimming.
- `.config/ghostty/config` configures Ghostty with JetBrains Mono, Rose Pine Moon, and `ctrl+a` prefixed split/tab keybinds.
- `--yes` needs Git identity env vars during initial setup, with `--setup-git`, or with `--setup-ssh`. On reruns, private key creation also needs `CREATE_SSH_KEYS=1`.
- zsh is non-optional. The installer will stop if zsh is unavailable and will run `chsh` when your login shell is not zsh.
