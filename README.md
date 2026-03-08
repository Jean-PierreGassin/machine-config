# Local dev defaults

CLI editor: `vim`

Unix shell: `zsh` via Oh My Zsh

Terminal: Windows Terminal on WSL, Terminal.app/iTerm2 on macOS

Multiplexer: `tmux` with `/bin/zsh` as the default shell

Operating systems: Windows 11 with WSL 2, macOS

Notes:
- `.gitconfig` includes separate overrides for `~/repos/work` and `~/repos/personal`.
- `.tmux.conf` prefers `tmux-256color` and falls back to `screen-256color`.
- `.zshrc` uses platform-specific color aliases for GNU/Linux and macOS.
