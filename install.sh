#!/usr/bin/env bash
#
# install.sh — set up this machine-config repo on a fresh box.
#
# What it does, in order:
#   1. Detects the platform (macOS / WSL / generic Linux)
#   2. Installs a package manager if needed (Homebrew on macOS,
#      apt on Debian/Ubuntu/WSL) — always asks first
#   3. Installs the tools these dotfiles assume exist
#      (zsh, tmux, vim, git, starship, nvm)
#   4. Symlinks the dotfiles into $HOME, backing up anything
#      already there instead of overwriting it
#   5. Wires up a couple of one-time settings (global gitignore,
#      default shell) — also asks first
#
# Safe to re-run. Nothing destructive happens without a prompt.
#
set -euo pipefail

# ============================================================
# Output helpers
# ============================================================
BOLD="$(tput bold 2>/dev/null || true)"
DIM="$(tput dim 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
BLUE="$(tput setaf 4 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

step()    { printf "\n%s==>%s %s%s%s\n" "$BLUE$BOLD" "$RESET" "$BOLD" "$1" "$RESET"; }
info()    { printf "    %s\n" "$1"; }
ok()      { printf "    %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn()    { printf "    %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
err()     { printf "    %s✗%s %s\n" "$RED" "$RESET" "$1" >&2; }

confirm() {
    # confirm "Question?" — returns 0 (yes) / 1 (no). Defaults to no.
    local prompt="$1"
    local reply
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        return 0
    fi
    read -r -p "    ${YELLOW}?${RESET} ${prompt} [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ============================================================
# Setup
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.machine-config-backup-$(date +%Y%m%d-%H%M%S)"
DOTFILES=(.gitconfig .gitignore_global .tmux.conf .vimrc .zshrc)

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help)
            echo "Usage: ./install.sh [-y|--yes]"
            echo "  -y, --yes   Don't prompt — assume yes to everything"
            exit 0
            ;;
    esac
done

printf "%s%s machine-config installer %s\n" "$BOLD" "$BLUE" "$RESET"
printf "%sRunning from: %s%s\n" "$DIM" "$SCRIPT_DIR" "$RESET"

# ============================================================
# 1. Detect platform
# ============================================================
step "Detecting platform"

OS="unknown"
PKG_MANAGER="none"

if [[ "$(uname -s)" == "Darwin" ]]; then
    OS="macos"
    PKG_MANAGER="brew"
elif [[ "$(uname -s)" == "Linux" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
    else
        OS="linux"
    fi
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    fi
fi

if [[ "$OS" == "unknown" ]]; then
    err "Couldn't detect a supported platform (expected macOS or Linux/WSL). Stopping."
    exit 1
fi

ok "Detected: $OS (package manager: $PKG_MANAGER)"

if [[ "$PKG_MANAGER" == "none" ]]; then
    err "No supported package manager found (apt/dnf/pacman). Install packages manually: zsh tmux vim git, then re-run with --yes to skip package install and just symlink."
    exit 1
fi

# ============================================================
# 2. Package manager + packages
# ============================================================
step "Package manager & required tools"

install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew already installed"
        return
    fi
    if confirm "Homebrew isn't installed. Install it now (via the official install script)?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Make brew available for the rest of this script run
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        ok "Homebrew installed"
    else
        warn "Skipping Homebrew install — brew-managed packages will be skipped too"
    fi
}

BREW_PACKAGES=(zsh tmux vim git starship nvm)
APT_PACKAGES=(zsh tmux vim git curl build-essential)

install_with_brew() {
    install_homebrew
    if ! command -v brew >/dev/null 2>&1; then
        return
    fi
    if confirm "Install/update packages via brew (${BREW_PACKAGES[*]})?"; then
        brew install "${BREW_PACKAGES[@]}"
        ok "brew packages installed"
    else
        warn "Skipped brew package install"
    fi
}

install_with_apt() {
    if confirm "Install packages via apt (${APT_PACKAGES[*]})? This will run 'sudo apt-get update' first."; then
        sudo apt-get update
        sudo apt-get install -y "${APT_PACKAGES[@]}"
        ok "apt packages installed"
    else
        warn "Skipped apt package install"
    fi

    # starship and nvm aren't in apt — install via their official scripts
    if ! command -v starship >/dev/null 2>&1; then
        if confirm "Install Starship prompt (via the official install script)?"; then
            curl -sS https://starship.rs/install.sh | sh
            ok "Starship installed"
        else
            warn "Skipped Starship"
        fi
    else
        ok "Starship already installed"
    fi

    if [[ ! -d "$HOME/.nvm" ]]; then
        if confirm "Install nvm (Node Version Manager, via the official install script)?"; then
            # PROFILE=/dev/null stops nvm's installer from appending its own
            # loader to .zshrc — this repo's .zshrc already lazy-loads nvm itself.
            export PROFILE=/dev/null
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
            unset PROFILE
            ok "nvm installed"
        else
            warn "Skipped nvm"
        fi
    else
        ok "nvm already installed"
    fi
}

case "$PKG_MANAGER" in
    brew)
        install_with_brew
        ;;
    apt)
        install_with_apt
        ;;
    dnf|pacman)
        warn "Automatic package install isn't wired up for $PKG_MANAGER yet."
        warn "Install these manually, then re-run: zsh tmux vim git curl, plus starship and nvm via their official install scripts."
        ;;
esac

# ============================================================
# 3. Symlink dotfiles
# ============================================================
step "Symlinking dotfiles into \$HOME"

mkdir -p "$BACKUP_DIR"
backed_up_any=0

for file in "${DOTFILES[@]}"; do
    src="$SCRIPT_DIR/$file"
    dest="$HOME/$file"

    if [[ ! -e "$src" ]]; then
        warn "$file not found in repo, skipping"
        continue
    fi

    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        ok "$file already linked correctly"
        continue
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        if confirm "$file already exists at ~/$file. Back it up and replace with the symlink?"; then
            mv "$dest" "$BACKUP_DIR/$file"
            backed_up_any=1
        else
            warn "Skipping $file — left existing file untouched"
            continue
        fi
    fi

    ln -s "$src" "$dest"
    ok "Linked ~/$file -> $src"
done

if [[ "$backed_up_any" == "1" ]]; then
    info "Backups of replaced files saved to: $BACKUP_DIR"
else
    rmdir "$BACKUP_DIR" 2>/dev/null || true
fi

# ============================================================
# 4. One-time git/shell settings
# ============================================================
step "Optional one-time settings"

current_name="$(git config --global user.name 2>/dev/null || true)"
current_email="$(git config --global user.email 2>/dev/null || true)"

if [[ -z "$current_name" || "$current_name" == "Your Name" || -z "$current_email" || "$current_email" == "you@example.com" ]]; then
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        warn "git user.name/email isn't set (placeholder still in .gitconfig) — skipping prompt because --yes was passed."
        warn "Set it manually later with: git config --global user.name \"...\" / user.email \"...\""
    else
        info "~/.gitconfig has no real identity set yet (this is your default — ~/repos/work or ~/repos/personal can still override it)."
        read -r -p "    Git user.name: " git_name
        read -r -p "    Git user.email: " git_email
        if [[ -n "$git_name" ]]; then
            git config --global user.name "$git_name"
        fi
        if [[ -n "$git_email" ]]; then
            git config --global user.email "$git_email"
        fi
        if [[ -n "$git_name" || -n "$git_email" ]]; then
            ok "git identity set (default — overridden inside ~/repos/work or ~/repos/personal if those .gitconfig files set their own)"
        else
            warn "Left blank — skipped"
        fi
    fi
else
    ok "git identity already set ($current_name <$current_email>)"
fi

if [[ -z "$(git config --global core.excludesfile 2>/dev/null || true)" ]]; then
    if confirm "Set ~/.gitignore_global as your global git excludesfile?"; then
        git config --global core.excludesfile "$HOME/.gitignore_global"
        ok "git core.excludesfile set"
    fi
else
    ok "git core.excludesfile already set"
fi

zsh_path="$(command -v zsh || true)"
if [[ -n "$zsh_path" && "$SHELL" != "$zsh_path" ]]; then
    if confirm "Set zsh ($zsh_path) as your default login shell?"; then
        if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
            warn "$zsh_path isn't listed in /etc/shells — adding it (needs sudo)"
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi
        chsh -s "$zsh_path"
        ok "Default shell changed to zsh (takes effect next login)"
    fi
else
    ok "zsh already the default shell"
fi

# ============================================================
# Done
# ============================================================
step "Done"
info "Open a new terminal (or 'exec zsh') to pick everything up."
