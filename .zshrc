# ============================================================
# .zshrc
# ============================================================

# --- Base profile -------------------------------------------------
[[ -r ~/.profile ]] && source ~/.profile

# --- Homebrew -------------------------------------------------------
# Detect brew explicitly by known install location rather than
# assuming it's already on PATH.
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Add Homebrew completions directory to fpath
if type brew &>/dev/null; then
  fpath=( "$(brew --prefix)/share/zsh/site-functions" $fpath )
fi

# Initialize the autocompletion system
autoload -Uz compinit && compinit
_comp_options+=(globdots)

# --- Node (nvm) PATH setup -----------------------------------------
# Don't source nvm.sh here. It is slow (100ms+ on every shell).
# Instead, resolve the default version's bin dir manually and
# prepend it, so `node`/`npm`/`npx` are available immediately.
# The real `nvm` command lazy-loads on first use, see below.
#
# Runs AFTER Homebrew above on purpose: this prepend happens last,
# so nvm's node wins over any brew-installed node on PATH.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

resolve_nvm_default_version() {
    local alias_name="$1"
    local alias_file
    local -a versions
    local -a sorted_versions

    while [[ -n "$alias_name" ]]; do
        alias_name="${alias_name//$'\r'/}"
        alias_name="${alias_name//$'\n'/}"
        alias_name="${alias_name%% *}"

        case "$alias_name" in
            v*)
                print -r -- "$alias_name"
                return 0
                ;;
            node|stable)
                versions=("$NVM_DIR"/versions/node/v*(N/))
                (( $#versions )) || return 1
                sorted_versions=(${(On)versions})
                print -r -- "${sorted_versions[1]:t}"
                return 0
                ;;
        esac

        alias_file="$NVM_DIR/alias/$alias_name"
        [[ -r "$alias_file" ]] || return 1
        alias_name="$(<"$alias_file")"
    done

    return 1
}

if [[ -r "$NVM_DIR/alias/default" ]]; then
    nvm_default_version="$(resolve_nvm_default_version "$(<"$NVM_DIR/alias/default")")"
    nvm_default_bin="$NVM_DIR/versions/node/$nvm_default_version/bin"

    [[ -d "$nvm_default_bin" ]] && path=("$nvm_default_bin" $path)

    unset nvm_default_version nvm_default_bin
fi
unset -f resolve_nvm_default_version

# --- Local user binaries ---------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# --- De-dupe PATH -------------------------------------------------------
# Run after every PATH-modifying step above, so duplicates introduced
# by .profile/brew/nvm/local-bin all get cleaned up.
typeset -U path PATH

# --- Color support for ls/grep ------------------------------------------
if (( $+commands[dircolors] )); then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

# --- Platform-specific aliases --------------------------------------------
case "$(uname -s)" in
    Darwin)
        export CLICOLOR=1
        alias ls='ls -G'
        alias grep='grep'
        alias fgrep='grep -F'
        alias egrep='grep -E'
        ;;
    *)
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='grep -F --color=auto'
        alias egrep='grep -E --color=auto'
        ;;
esac

# --- Misc env --------------------------------------------------------------------
export CURRENT_UID="${UID}:${GID}"

# --- Claude Code shell compatibility ---------------------------------------------
# Claude Code writes bash-style commands, and zsh defaults trip them up: an
# unmatched `?`, `*` or `[...]` in a URL or ref aborts with "no matches found",
# and a leading `=` expands to a command path. CLAUDECODE is also set in IDE
# integrated terminals, so keep bash word splitting out of JetBrains ones.
if [[ -n "${CLAUDECODE:-}" ]]; then
  setopt NO_NOMATCH NO_EQUALS
  [[ "${TERMINAL_EMULATOR:-}" != JetBrains* ]] && setopt SH_WORD_SPLIT
fi

# --- Node (nvm) lazy-load wrapper -----------------------------------------------
# The default node version's bin dir is already on PATH (set above), so
# `node`/`npm`/`npx` work immediately without this ever running. The real
# `nvm` command (needed to switch versions) only loads the first time you
# actually call `nvm`.
load_nvm() {
  unset -f nvm node npm npx 2>/dev/null

  # 1. Homebrew (macOS / Linux)
  local brew_nvm_prefix
  for brew_nvm_prefix in /opt/homebrew/opt/nvm /usr/local/opt/nvm /home/linuxbrew/.linuxbrew/opt/nvm; do
    if [[ -s "$brew_nvm_prefix/nvm.sh" ]]; then
      source "$brew_nvm_prefix/nvm.sh"
    fi

    if [[ -s "$brew_nvm_prefix/etc/bash_completion.d/nvm" ]]; then
      source "$brew_nvm_prefix/etc/bash_completion.d/nvm"
    fi

    command -v nvm >/dev/null 2>&1 && break
  done
  unset brew_nvm_prefix

  # 2. Fallback: standard nvm install
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  fi

  # 3. Replace wrapper with real nvm after first load
  command -v nvm >/dev/null 2>&1 && {
    unalias nvm 2>/dev/null
  }
}

nvm() {
  load_nvm
  nvm "$@"
}

function tixshell() {
  local target_dir=~/repos/TixShell
  local current_dir
  current_dir="$(pwd)"

  if [[ "$current_dir" != "$target_dir" && "$current_dir" != "$target_dir/"* ]]; then
    cd "$target_dir" || return
    ./tixshell
  else
    "$target_dir"/tixshell
  fi
}

# --- Devbox shell banner -----------------------------------------------------------------
# devbox unconditionally prepends a quiet "(devbox) " to PS1 with no way to turn it
# off, and it is easy to miss weeks later. Surface it as a starship banner line
# instead: export the project name for starship to render, then drop devbox's own
# prefix. The prefix is applied after this file is sourced, so it has to be stripped
# from a precmd hook rather than here.
if [[ -n "${DEVBOX_SHELL_ENABLED:-}" && -n "${DEVBOX_PROJECT_ROOT:-}" ]]; then
  export DEVBOX_NAME="${DEVBOX_PROJECT_ROOT:t}"

  _strip_devbox_ps1_prefix() {
    PS1="${PS1#\(devbox\) }"
    precmd_functions=(${precmd_functions:#_strip_devbox_ps1_prefix})
    unset -f _strip_devbox_ps1_prefix
  }
  typeset -ag precmd_functions
  precmd_functions+=(_strip_devbox_ps1_prefix)
fi

# --- Prompt (keep last) --------------------------------------------------------------
if [[ "${TERM:-}" != "dumb" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# --- pnpm ------------------------------------------------------------------------
if [[ -d "${PNPM_HOME:-$HOME/Library/pnpm}" ]]; then
  export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
  path=("$PNPM_HOME" $path)
fi
