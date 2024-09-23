plugins=(
  git
)

export GOPATH="$HOME"
export PATH="$HOME/.local/bin:$GOPATH/bin:$HOME/.asdf/shims:$PATH"
export GOKU_EDN_CONFIG_FILE="$HOME/.config/gokurakujoudo/karabiner.edn"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#00ff00'

## syntax-highlighting
source ~/Git-Project/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

## zsh-completions
## zsh-autosuggestions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  autoload -Uz compinit && compinit
fi

## docker desktop
source /Users/takumiakasaka/.docker/init-zsh.sh || true

## starship
eval "$(starship init zsh)"

## atuin setting
# FIXME: maybe remove
# NOTE: brew uninstall atuin
eval "$(atuin init zsh)"
eval "$(atuin init zsh --disable-ctrl-r)"

## tmux setting
export FZF_TMUX=1

## asdf setting
. /opt/homebrew/opt/asdf/libexec/asdf.sh

## zsh history setting
export HISTFILE=${HOME}/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
