plugins=(
  git
  zsh-autosuggestions
)

export ZSH="$HOME/.oh-my-zsh"
export GOPATH="$HOME"
export PATH="$HOME/.local/bin:$GOPATH/bin:$HOME/.asdf/shims:$PATH"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#00ff00'

## oh-my-zsh
source $ZSH/oh-my-zsh.sh

## syntax-highlighting
source ~/Git-Project/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

## docker desktop
source /Users/takumiakasaka/.docker/init-zsh.sh || true

## starship
eval "$(starship init zsh)"

## tmux setting
export FZF_TMUX=1

## asdf setting
. /opt/homebrew/opt/asdf/libexec/asdf.sh

## zsh history setting
export HISTFILE=${HOME}/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
