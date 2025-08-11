# Login shell environment setup

# Prefer Homebrew early in PATH on Apple Silicon
if command -v brew >/dev/null 2>&1; then
  export PATH="$(brew --prefix)/bin:$PATH"
fi

export GOPATH="$HOME"
export PATH="$HOME/.local/bin:$GOPATH/bin:$HOME/.asdf/shims:$PATH"

typeset -U path PATH
