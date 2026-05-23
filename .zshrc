# enable color support of ls and also add handy aliases
if (( $+commands[dircolors] )); then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

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

#alias dir='dir --color=auto'
#alias vdir='vdir --color=auto'

alias ga="git add"
alias gc="git commit"
alias gd="git diff"
alias gs="git status"
alias gl="git log"
alias gf="git fetch"
alias gp="git pull"
alias gpr="git pull -r"
alias gpush="git push"

export CURRENT_UID="${UID}:${GID}"

[[ -r ~/.profile ]] && source ~/.profile
typeset -U path PATH


gitSearch() {
    #search git history against a file for a string
    git log --no-merges -c -S"$2" -- "$1"
}

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

load_nvm() {
    unset -f load_nvm nvm

    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}

nvm() { load_nvm; nvm "$@"; }

eval "$(starship init zsh)"
