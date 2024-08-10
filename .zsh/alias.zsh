## shell script alias
alias ide="source ~/.script/ide.sh"

## git alias
alias gs='git status --short --branch'
alias _git_current_branch="git rev-parse --abbrev-ref HEAD"
alias pull='git pull origin $(_git_current_branch)'
alias gp='git push origin $(_git_current_branch)'
alias gswc='git switch -c'
alias gcim='git commit -m'
alias gbd="git branch | grep -v '^[*+]' | awk '{print $1}' | fzf-tmux -p 80% -0 --multi --preview 'git show --color=always {-1}' | xargs -r git branch --delete"

## other alias
alias lsa="ls -a"
alias c="clear"
alias cat='bat --theme="Visual Studio Dark+"'

alias .='ls'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
