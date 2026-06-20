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

# --- Node (nvm) — PATH setup -----------------------------------------
# Don't source nvm.sh here — it's slow (100ms+ on every shell).
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

# --- Git shortcuts -----------------------------------------------------------
alias ga="git add"
alias gc="git commit"
alias gd="git diff"
alias gs="git status"
alias gl="git log"
alias gf="git fetch"
alias gp="git pull"
alias gpr="git pull -r"
alias gpush="git push"

# --- Misc env --------------------------------------------------------------------
export CURRENT_UID="${UID}:${GID}"

# --- Node (nvm) — lazy-load wrapper -----------------------------------------------
# The default node version's bin dir is already on PATH (set above), so
# `node`/`npm`/`npx` work immediately without this ever running. The real
# `nvm` command (needed to switch versions) only loads the first time you
# actually call `nvm`.
load_nvm() {
  unset -f nvm node npm npx 2>/dev/null

  # 1. Homebrew (macOS / Linux)
  if command -v brew >/dev/null 2>&1; then
    local brew_prefix
    brew_prefix="$(brew --prefix nvm 2>/dev/null)"

    if [[ -s "$brew_prefix/nvm.sh" ]]; then
      source "$brew_prefix/nvm.sh"
    fi

    if [[ -s "$brew_prefix/etc/bash_completion.d/nvm" ]]; then
      source "$brew_prefix/etc/bash_completion.d/nvm"
    fi
  fi

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

# --- Prompt (keep last) --------------------------------------------------------------
eval "$(starship init zsh)"
