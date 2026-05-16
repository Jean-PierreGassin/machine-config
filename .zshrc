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

export NVM_DIR="$HOME/.nvm"

load_nvm() {
    unset -f load_nvm nvm node npm npx corepack yarn pnpm

    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}

nvm() { load_nvm; nvm "$@"; }
node() { load_nvm; node "$@"; }
npm() { load_nvm; npm "$@"; }
npx() { load_nvm; npx "$@"; }
corepack() { load_nvm; corepack "$@"; }
yarn() { load_nvm; yarn "$@"; }
pnpm() { load_nvm; pnpm "$@"; }

eval "$(starship init zsh)"
