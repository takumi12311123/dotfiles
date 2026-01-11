## shell script alias
alias ide="source ~/.script/ide.sh"
alias review-pr="zsh ~/.script/review-pr.sh"
alias dev="~/.script/dev.sh"

## git alias
alias gs='git status --short --branch'
git_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -v HEAD || git describe --tags --always 2>/dev/null; }
alias pull='git pull --ff-only origin $(git_current_branch)'
alias gp='git push origin $(git_current_branch)'
alias gswc='git switch -c'
alias gcim='git commit -m'
alias gbd="git branch | grep -v '^[*+]' | awk '{print $1}' | fzf-tmux -p 80% -0 --multi --preview 'git show --color=always {-1}' | xargs -r git branch --delete"

## other alias
alias lsa="ls -a"
alias c="clear"
alias cat='bat --theme="Visual Studio Dark+" --paging=never -pp'
command -v unbuffer >/dev/null 2>&1 || alias unbuffer=cat

alias .='ls'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
