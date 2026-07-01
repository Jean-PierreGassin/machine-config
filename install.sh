#!/usr/bin/env bash
#
# install.sh - set up this machine-config repo on a fresh box.
#
# What it does, in order:
#   1. Detects the platform (macOS / apt-based Linux/WSL)
#   2. Installs required package-manager and tool dependencies
#      (Homebrew on macOS, apt on Debian/Ubuntu/WSL)
#   3. Installs the tools these dotfiles assume exist
#      (zsh, tmux, vim, git, starship, nvm)
#   4. Symlinks the dotfiles into $HOME, backing up anything
#      already there instead of overwriting it
#   5. Generates machine-local Git config, offers optional SSH keys,
#      and sets zsh as the default shell
#
# Safe to re-run. Existing files are backed up before replacement.
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
CYAN="$(tput setaf 6 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

step()    { printf "\n%s==>%s %s%s%s\n" "$BLUE$BOLD" "$RESET" "$BOLD" "$1" "$RESET"; }
info()    { printf "    %s\n" "$1"; }
ok()      { printf "    %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn()    { printf "    %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
err()     { printf "    %s✗%s %s\n" "$RED" "$RESET" "$1" >&2; }

run_quiet() {
  local message="$1"
  local log_file
  shift

  info "$message"
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    if "$@"; then
      return
    fi
    err "Failed: $message"
    return 1
  fi

  log_file="$(mktemp "${TMPDIR:-/tmp}/machine-config.XXXXXX")"
  if "$@" >"$log_file" 2>&1; then
    rm -f "$log_file"
    return
  fi

  err "Failed: $message"
  warn "Captured output:"
  sed 's/^/      /' "$log_file" >&2
  rm -f "$log_file"
  return 1
}

run_quiet_to_file() {
  local message="$1"
  local output_file="$2"
  local log_file
  shift 2

  info "$message"
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    if "$@" >"$output_file"; then
      return
    fi
    err "Failed: $message"
    return 1
  fi

  log_file="$(mktemp "${TMPDIR:-/tmp}/machine-config.XXXXXX")"
  if "$@" >"$output_file" 2>"$log_file"; then
    rm -f "$log_file"
    return
  fi

  err "Failed: $message"
  if [[ -s "$log_file" ]]; then
    warn "Captured stderr:"
    sed 's/^/      /' "$log_file" >&2
  fi
  if [[ -s "$output_file" ]]; then
    warn "Partial output:"
    sed 's/^/      /' "$output_file" >&2
  fi
  rm -f "$log_file"
  return 1
}

confirm() {
  # confirm "Question?" returns 0 (yes) or 1 (no). Defaults to no.
  local prompt="$1"
  local reply
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  read -r -p "    ${YELLOW}?${RESET} ${prompt} [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

confirm_sensitive() {
  local prompt="$1"
  local reply

  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    if [[ "${CREATE_SSH_KEYS:-0}" == "1" ]]; then
      return 0
    fi
    warn "Skipping sensitive action in --yes mode: $prompt Set CREATE_SSH_KEYS=1 to allow it."
    return 1
  fi

  read -r -p "    ${YELLOW}?${RESET} ${prompt} [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

prompt_value() {
  local prompt="$1"
  local default_value="${2:-}"
  local reply

  if [[ -n "$default_value" ]]; then
    read -r -p "    ${CYAN}>${RESET} $prompt [$default_value]: " reply
    printf "%s\n" "${reply:-$default_value}"
  else
    read -r -p "    ${CYAN}>${RESET} $prompt: " reply
    printf "%s\n" "$reply"
  fi
}

prompt_required_value() {
  local prompt="$1"
  local default_value="${2:-}"
  local value

  while true; do
    value="$(prompt_value "$prompt" "$default_value")"
    if [[ -n "$value" ]]; then
      printf "%s\n" "$value"
      return 0
    fi
    warn "$prompt is required."
  done
}

prompt_optional_path() {
  local prompt="$1"
  local example="$2"
  local value

  read -r -p "    ${CYAN}>${RESET} ${prompt} (example: ${example}, blank to skip): " value
  case "$value" in
    skip|Skip|SKIP|none|None|NONE) value="" ;;
  esac

  printf "%s\n" "$value"
}

prompt_optional_dir() {
  local prompt="$1"
  local example="$2"
  local value

  read -r -p "    ${CYAN}>${RESET} ${prompt} (example: ${example}, blank to skip): " value
  case "$value" in
    skip|Skip|SKIP|none|None|NONE) value="" ;;
  esac

  printf "%s\n" "$value"
}

normalize_config_dir() {
  local dir="$1"

  dir="${dir/#\~/$HOME}"
  dir="${dir%/}"
  if [[ -n "$dir" && "$dir" != /* ]]; then
    dir="$HOME/$dir"
  fi

  printf "%s\n" "$dir"
}

normalize_path() {
  local path="$1"

  path="${path/#\~/$HOME}"
  if [[ -n "$path" && "$path" != /* ]]; then
    path="$HOME/$path"
  fi

  printf "%s\n" "$path"
}

display_config_dir() {
  local dir="$1"

  if [[ "$dir" == "$HOME" ]]; then
    dir="~"
  elif [[ "$dir" == "$HOME/"* ]]; then
    dir="~/${dir#"$HOME/"}"
  fi
  dir="${dir%/}"

  printf "%s\n" "$dir"
}

shell_double_quote() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "$value"
}

git_config_double_quote() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

git_config_section_value() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf "%s" "$value"
}

git_config_path_value() {
  local value="$1"

  if [[ "$value" == "$HOME" ]]; then
    value="~"
  elif [[ "$value" == "$HOME/"* ]]; then
    value="~/${value#"$HOME/"}"
  fi
  value="${value%/}"

  printf "%s" "$value"
}

current_git_config_value() {
  local key="$1"
  local value

  value="$(git config --global "$key" 2>/dev/null || true)"
  case "$value" in
    \{\{*\}\}) value="" ;;
  esac

  printf "%s\n" "$value"
}

backup_existing_path() {
  local path="$1"
  local name="$2"

  mkdir -p "$BACKUP_DIR"
  mv "$path" "$BACKUP_DIR/$name"
  backed_up_any=1
}

make_temp_file() {
  local label="$1"
  local template="$2"
  local temp_file

  if ! temp_file="$(mktemp "$template")"; then
    err "Failed to create temporary file for $label."
    return 1
  fi

  printf "%s\n" "$temp_file"
}

print_public_key() {
  local label="$1"
  local pub_path="$2"

  if [[ -f "$pub_path" ]]; then
    info "Public key for $label ($(display_config_dir "$pub_path")). Copy this line to your Git host:"
    sed 's/^/      /' "$pub_path"
  else
    warn "No public key available to print for $label ($(display_config_dir "$pub_path"))."
  fi
}

prepare_generated_file() {
  local path="$1"
  local backup_name="$2"
  local prompt="$3"

  if [[ -e "$path" || -L "$path" ]]; then
    if confirm "$prompt"; then
      backup_existing_path "$path" "$backup_name"
    else
      return 1
    fi
  fi

  return 0
}

ensure_ssh_key() {
  local label="$1"
  local key_path="$2"
  local email="$3"
  local pub_path
  local pub_tmp

  [[ -n "$key_path" ]] || return 0

  pub_path="$key_path.pub"

  if [[ -e "$key_path" || -L "$key_path" ]]; then
    ok "$(display_config_dir "$key_path") already exists"
    if [[ ! -e "$pub_path" && ! -L "$pub_path" ]] && confirm_sensitive "Create missing public key $(display_config_dir "$pub_path") from existing $label private key?"; then
      pub_tmp="$(mktemp "${pub_path}.tmp.XXXXXX")"
      if ! run_quiet_to_file "Creating public key $(display_config_dir "$pub_path")..." "$pub_tmp" ssh-keygen -y -f "$key_path"; then
        rm -f "$pub_tmp"
        return 1
      fi
      mv "$pub_tmp" "$pub_path"
      ok "$(display_config_dir "$pub_path") created"
    fi
    print_public_key "$label" "$pub_path"
    return 0
  fi

  if [[ -e "$pub_path" || -L "$pub_path" ]]; then
    warn "$(display_config_dir "$pub_path") exists but $(display_config_dir "$key_path") does not. Not creating a private key beside an existing public key."
    return 1
  fi

  if ! command -v ssh-keygen >/dev/null 2>&1; then
    warn "ssh-keygen is not available, skipping $label SSH key setup"
    return 1
  fi

  if confirm_sensitive "Create $label SSH key at $(display_config_dir "$key_path")?"; then
    mkdir -p "$(dirname "$key_path")"
    chmod 700 "$(dirname "$key_path")" 2>/dev/null || true
    run_quiet "Creating $label SSH key..." ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    ok "$(display_config_dir "$key_path") created"
    print_public_key "$label" "$pub_path"
  else
    warn "Skipping $label SSH key creation"
    return 1
  fi
}

render_global_gitconfig() {
  local name="$1"
  local email="$2"
  local work_dir="$3"
  local personal_dir="$4"
  local template
  local include_blocks=""
  local work_config_path
  local work_gitdir
  local personal_config_path
  local personal_gitdir

  template="$(<"$SCRIPT_DIR/.gitconfig")"

  if [[ -n "$work_dir" || -n "$personal_dir" ]]; then
    include_blocks+=$'\n'
    include_blocks+="# ============================================================"$'\n'
    include_blocks+="# Directory-specific overrides"$'\n'
    include_blocks+="# These optional includes match the repo roots entered during install."$'\n'
    include_blocks+="# Each included .gitconfig can set a different identity or SSH key."$'\n'
    include_blocks+="# ============================================================"$'\n'
  fi

  if [[ -n "$work_dir" ]]; then
    work_gitdir="$(git_config_path_value "$work_dir")/"
    work_config_path="$(git_config_path_value "$work_dir")/.gitconfig"
    include_blocks+="[includeIf \"gitdir:$(git_config_section_value "$work_gitdir")\"]"$'\n'
    include_blocks+="	path = $(git_config_double_quote "$work_config_path")"$'\n\n'
  fi

  if [[ -n "$personal_dir" ]]; then
    personal_gitdir="$(git_config_path_value "$personal_dir")/"
    personal_config_path="$(git_config_path_value "$personal_dir")/.gitconfig"
    include_blocks+="[includeIf \"gitdir:$(git_config_section_value "$personal_gitdir")\"]"$'\n'
    include_blocks+="	path = $(git_config_double_quote "$personal_config_path")"$'\n'
  fi

  template="${template//\{\{GIT_USER_NAME\}\}/$name}"
  template="${template//\{\{GIT_USER_EMAIL\}\}/$email}"
  template="${template//\# \{\{GIT_INCLUDE_BLOCKS\}\}/$include_blocks}"

  printf "%s\n" "$template"
}

write_scoped_gitconfig() {
  local label="$1"
  local dir="$2"
  local name="$3"
  local email="$4"
  local ssh_key="$5"
  local config_path

  [[ -n "$dir" ]] || return 0

  config_path="$dir/.gitconfig"
  mkdir -p "$dir"

  if ! prepare_generated_file "$config_path" ".gitconfig-$label" "Replace existing $(display_config_dir "$config_path") with generated $label Git config?"; then
    warn "Skipping $label Git config"
    return 0
  fi

  ensure_ssh_key "$label" "$ssh_key" "$email" || ssh_key=""

  {
    printf "# ============================================================\n"
    printf "# %s Git defaults\n" "$label"
    printf "# Generated by machine-config/install.sh from local prompts.\n"
    printf "# ============================================================\n"
    printf "[user]\n"
    printf "\tname = %s\n" "$name"
    printf "\temail = %s\n" "$email"

    if [[ -n "$ssh_key" ]]; then
      printf "\n"
      printf "[core]\n"
      printf "\tsshCommand = %s\n" "$(git_config_double_quote "ssh -i $(shell_double_quote "$ssh_key") -o IdentitiesOnly=yes")"
    fi
  } > "$config_path"

  ok "$(display_config_dir "$config_path") generated"
}

# ============================================================
# Setup
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.machine-config-backup-$(date +%Y%m%d-%H%M%S)"
DOTFILES=(.gitignore_global .tmux.conf .vimrc .wezterm.lua .zshrc)

ASSUME_YES=0
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --verbose) VERBOSE=1 ;;
    -h|--help)
      echo "Usage: ./install.sh [-y|--yes] [--verbose]"
      echo "  -y, --yes   Answer yes to ordinary prompts. Git config needs GIT_USER_NAME/GIT_USER_EMAIL; SSH keys need CREATE_SSH_KEYS=1."
      echo "  --verbose   Show package manager and installer command output."
      echo "  zsh is required and is always set as the login shell when needed."
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
  fi
fi

if [[ "$OS" == "unknown" ]]; then
  err "Couldn't detect a supported platform (expected macOS or Linux/WSL). Stopping."
  exit 1
fi

ok "Detected: $OS (package manager: $PKG_MANAGER)"

if [[ "$PKG_MANAGER" == "none" ]]; then
  err "No supported package manager found. This installer supports macOS/Homebrew and apt-based Linux/WSL."
  exit 1
fi

# ============================================================
# 2. Package manager + packages
# ============================================================
step "Package manager & required tools"

load_brew_shellenv() {
  local brew_path
  local shellenv_file
  local shellenv_output

  for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$brew_path" ]] || continue

    shellenv_file="$(make_temp_file "Homebrew shell environment" "${TMPDIR:-/tmp}/brew-shellenv.XXXXXX")" || return 1
    if ! run_quiet_to_file "Loading Homebrew shell environment..." "$shellenv_file" "$brew_path" shellenv; then
      rm -f "$shellenv_file"
      return 1
    fi

    shellenv_output="$(<"$shellenv_file")"
    rm -f "$shellenv_file"
    if ! eval "$shellenv_output"; then
      err "Failed to load Homebrew shell environment."
      return 1
    fi
    return 0
  done

  return 1
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew already installed"
    return
  fi
  local homebrew_installer

  homebrew_installer="$(make_temp_file "Homebrew installer" "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")" || return 1
  if ! run_quiet "Downloading Homebrew installer..." curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$homebrew_installer"; then
    rm -f "$homebrew_installer"
    return 1
  fi
  if ! run_quiet "Setting up Homebrew..." env NONINTERACTIVE=1 /bin/bash "$homebrew_installer"; then
    rm -f "$homebrew_installer"
    return 1
  fi
  rm -f "$homebrew_installer"

  if ! load_brew_shellenv; then
    err "Homebrew installed but brew could not be added to this shell."
    return 1
  fi
  ok "Homebrew installed"
}

BREW_PACKAGES=(zsh tmux vim git starship nvm)
APT_PACKAGES=(zsh tmux vim git curl build-essential)

install_with_brew() {
  install_homebrew
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is required but is not available after install."
    exit 1
  fi
  run_quiet "Installing/updating brew packages..." brew install "${BREW_PACKAGES[@]}"
  ok "brew packages installed"

  # Homebrew's nvm formula still expects this directory to exist.
  mkdir -p "$HOME/.nvm"
  ok "nvm working directory exists"
}

install_with_apt() {
  info "Checking sudo access for apt..."
  if ! sudo -v; then
    err "Failed: checking sudo access for apt."
    return 1
  fi
  run_quiet "Updating apt package lists..." sudo apt-get update
  run_quiet "Installing apt packages..." sudo apt-get install -y "${APT_PACKAGES[@]}"
  ok "apt packages installed"

  # starship and nvm are not in apt, install via their official scripts
  if ! command -v starship >/dev/null 2>&1; then
    local starship_installer

    starship_installer="$(make_temp_file "Starship installer" "${TMPDIR:-/tmp}/starship-install.XXXXXX")" || return 1
    if ! run_quiet "Downloading Starship installer..." curl -fsSL https://starship.rs/install.sh -o "$starship_installer"; then
      rm -f "$starship_installer"
      return 1
    fi
    if ! run_quiet "Setting up Starship..." sh "$starship_installer" -y; then
      rm -f "$starship_installer"
      return 1
    fi
    rm -f "$starship_installer"
    ok "Starship installed"
  else
    ok "Starship already installed"
  fi

  if [[ ! -d "$HOME/.nvm" ]]; then
    local nvm_installer

    nvm_installer="$(make_temp_file "nvm installer" "${TMPDIR:-/tmp}/nvm-install.XXXXXX")" || return 1
    if ! run_quiet "Downloading nvm installer..." curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh -o "$nvm_installer"; then
      rm -f "$nvm_installer"
      return 1
    fi
    # PROFILE=/dev/null stops nvm's installer from appending its own
    # loader to .zshrc. This repo's .zshrc already lazy-loads nvm itself.
    if ! run_quiet "Setting up nvm..." env PROFILE=/dev/null bash "$nvm_installer"; then
      rm -f "$nvm_installer"
      return 1
    fi
    rm -f "$nvm_installer"
    ok "nvm installed"
  else
    ok "nvm already installed"
  fi
}

detect_nerd_font() {
  if command -v fc-list >/dev/null 2>&1; then
    local font_family
    font_family="$(fc-list : family 2>/dev/null | grep -Ei 'Nerd Font|FiraMono Nerd Font Mono' | head -n 1 || true)"
    if [[ -n "$font_family" ]]; then
      printf "%s\n" "$font_family"
      return 0
    fi
  fi

  local font_dir
  local font_file
  for font_dir in "$HOME/Library/Fonts" "$HOME/.local/share/fonts" "$HOME/.fonts" /Library/Fonts /System/Library/Fonts /opt/homebrew/share/fonts /usr/local/share/fonts /usr/share/fonts; do
    [[ -d "$font_dir" ]] || continue
    font_file="$(find "$font_dir" \( -iname '*Nerd*Font*' -o -iname '*NerdFont*' \) -print 2>/dev/null | head -n 1 || true)"
    if [[ -n "$font_file" ]]; then
      printf "%s\n" "$(display_config_dir "$font_file")"
      return 0
    fi
  done

  return 1
}

configure_starship() {
  step "Starship preset"
  local nerd_font

  if ! command -v starship >/dev/null 2>&1; then
    warn "Starship is not installed, skipping preset setup"
    return
  fi

  if nerd_font="$(detect_nerd_font)"; then
    ok "Nerd Font detected ($nerd_font)"
  else
    warn "No Nerd Font detected. Install and select one in your terminal, for example FiraMono Nerd Font Mono."
  fi

  local starship_config="$HOME/.config/starship.toml"

  if [[ -e "$starship_config" || -L "$starship_config" ]]; then
    if confirm "Replace existing ~/.config/starship.toml with the Pure preset?"; then
      backup_existing_path "$starship_config" "starship.toml"
    else
      warn "Skipping Starship preset setup"
      return
    fi
  fi

  mkdir -p "$HOME/.config"
  run_quiet "Writing Starship Pure preset..." starship preset pure-preset -o "$starship_config"
  ok "Starship Pure preset written"
}

case "$PKG_MANAGER" in
  brew)
    install_with_brew
    ;;
  apt)
    install_with_apt
    ;;
esac

configure_starship

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
      backup_existing_path "$dest" "$file"
    else
      warn "Skipping $file, left existing file untouched"
      continue
    fi
  fi

  ln -s "$src" "$dest"
  ok "Linked ~/$file -> $src"
done

# ============================================================
# 4. Git config and one-time shell settings
# ============================================================
step "Git config"

gitconfig_path="$HOME/.gitconfig"
git_name="${GIT_USER_NAME:-}"
git_email="${GIT_USER_EMAIL:-}"
global_ssh_key=""
work_dir="${GIT_WORK_DIR:-}"
personal_dir="${GIT_PERSONAL_DIR:-}"
work_name="${GIT_WORK_USER_NAME:-}"
work_email="${GIT_WORK_USER_EMAIL:-}"
work_ssh_key="${GIT_WORK_SSH_KEY:-}"
personal_name="${GIT_PERSONAL_USER_NAME:-}"
personal_email="${GIT_PERSONAL_USER_EMAIL:-}"
personal_ssh_key="${GIT_PERSONAL_SSH_KEY:-}"
global_gitconfig_generated=0

if [[ "${ASSUME_YES:-0}" == "1" ]]; then
  if [[ -z "$git_name" || -z "$git_email" ]]; then
    err "GIT_USER_NAME and GIT_USER_EMAIL are required when --yes is passed."
    exit 1
  fi
  if [[ -z "$work_dir" && -z "$personal_dir" ]]; then
    global_ssh_key="$HOME/.ssh/id_ed25519"
  fi
else
  info "This writes a machine-local ~/.gitconfig with the identity and repo roots you choose."
  info "Leave work/personal directories blank if this machine only needs one global Git identity."
  git_name="$(prompt_required_value "Git user.name" "$(current_git_config_value user.name)")"
  git_email="$(prompt_required_value "Git user.email" "$(current_git_config_value user.email)")"
  work_dir="$(prompt_optional_dir "Work repos directory to use or create" "${work_dir:-~/repos/work}")"
  if [[ -n "$work_dir" ]]; then
    work_name="$(prompt_required_value "Work Git user.name" "${work_name:-$git_name}")"
    work_email="$(prompt_required_value "Work Git user.email (example: you@company.com)" "$work_email")"
    work_ssh_key="$(prompt_optional_path "Work SSH key path" "${work_ssh_key:-~/.ssh/id_ed25519_work}")"
  fi
  personal_dir="$(prompt_optional_dir "Personal repos directory to use or create" "${personal_dir:-~/repos/personal}")"
  if [[ -n "$personal_dir" ]]; then
    personal_name="$(prompt_required_value "Personal Git user.name" "${personal_name:-$git_name}")"
    personal_email="$(prompt_required_value "Personal Git user.email (example: you@gmail.com)" "${personal_email:-$git_email}")"
    personal_ssh_key="$(prompt_optional_path "Personal SSH key path" "${personal_ssh_key:-~/.ssh/id_ed25519_personal}")"
  fi
  if [[ -z "$work_dir" && -z "$personal_dir" ]]; then
    if confirm "Create/check standard global SSH key ~/.ssh/id_ed25519?"; then
      global_ssh_key="$HOME/.ssh/id_ed25519"
    fi
  fi
fi

if [[ -n "$git_name" && -n "$git_email" ]]; then
  work_dir="$(normalize_config_dir "$work_dir")"
  personal_dir="$(normalize_config_dir "$personal_dir")"
  global_ssh_key="$(normalize_path "$global_ssh_key")"
  work_ssh_key="$(normalize_path "$work_ssh_key")"
  personal_ssh_key="$(normalize_path "$personal_ssh_key")"

  if [[ -n "$work_dir" && -n "$personal_dir" && "$work_dir" == "$personal_dir" ]]; then
    warn "Work and personal repo directories resolve to the same path. Skipping personal scoped Git config."
    personal_dir=""
  fi

  if [[ -n "$work_dir" && ( -z "$work_name" || -z "$work_email" ) ]]; then
    warn "Skipping work Git config because work user.name and user.email are required."
    work_dir=""
  fi

  if [[ -n "$personal_dir" && ( -z "$personal_name" || -z "$personal_email" ) ]]; then
    warn "Skipping personal Git config because personal user.name and user.email are required."
    personal_dir=""
  fi

  if prepare_generated_file "$gitconfig_path" ".gitconfig" "Replace existing ~/.gitconfig with a generated config using these values?"; then
    if [[ -n "$work_dir" || -n "$personal_dir" ]]; then
      global_ssh_key=""
    else
      ensure_ssh_key "global" "$global_ssh_key" "$git_email" || global_ssh_key=""
    fi

    render_global_gitconfig "$git_name" "$git_email" "$work_dir" "$personal_dir" > "$gitconfig_path"

    ok "~/.gitconfig generated"
    global_gitconfig_generated=1
  else
    warn "Skipping ~/.gitconfig generation"
  fi

  if [[ "$global_gitconfig_generated" == "1" ]]; then
    write_scoped_gitconfig "work" "$work_dir" "$work_name" "$work_email" "$work_ssh_key"
    write_scoped_gitconfig "personal" "$personal_dir" "$personal_name" "$personal_email" "$personal_ssh_key"
  elif [[ -n "$work_dir" || -n "$personal_dir" ]]; then
    warn "Skipping scoped Git configs because ~/.gitconfig was not generated."
  fi
else
  warn "Skipping ~/.gitconfig generation because git user.name and user.email are required."
fi

step "Login shell"

zsh_path="$(command -v zsh || true)"
if [[ -z "$zsh_path" ]]; then
  err "zsh is required but was not found on PATH."
  exit 1
elif [[ "$SHELL" != "$zsh_path" ]]; then
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    warn "$zsh_path isn't listed in /etc/shells, adding it (needs sudo)"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$zsh_path"
  ok "Default shell changed to zsh (takes effect next login)"
else
  ok "zsh already the default shell"
fi

if [[ "$backed_up_any" == "1" ]]; then
  info "Backups of replaced files saved to: $BACKUP_DIR"
else
  rmdir "$BACKUP_DIR" 2>/dev/null || true
fi

# ============================================================
# Done
# ============================================================
step "Done"
info "Open a new terminal (or 'exec zsh') to pick everything up."
