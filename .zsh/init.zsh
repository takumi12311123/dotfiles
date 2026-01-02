plugins=(
  git
)

# PATH and GOPATH are set in .zprofile (login shell)
export GOKU_EDN_CONFIG_FILE="$HOME/.config/gokurakujoudo/karabiner.edn"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#00ff00'

## syntax-highlighting
source "$(brew --prefix)/share/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" 2>/dev/null || \
  source ~/Git-Project/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

## zsh-completions and autosuggestions
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION-$HOST"

## docker desktop
source /Users/takumiakasaka/.docker/init-zsh.sh || true

## starship
eval "$(starship init zsh)"

## atuin setting
# Keep only one initialization to avoid conflicts
# eval "$(atuin init zsh)"
eval "$(atuin init zsh --disable-ctrl-r)"

## tmux setting
export FZF_TMUX=1

## asdf setting
. /opt/homebrew/opt/asdf/libexec/asdf.sh

## zsh history setting
export HISTFILE=${HOME}/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
