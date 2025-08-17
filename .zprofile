# Login shell environment setup

# Add Homebrew to PATH on Apple Silicon
export PATH="/opt/homebrew/bin:$PATH"

export GOPATH="$HOME"
export PATH="$HOME/.local/bin:$GOPATH/bin:$HOME/.asdf/shims:$PATH"

typeset -U path PATH
